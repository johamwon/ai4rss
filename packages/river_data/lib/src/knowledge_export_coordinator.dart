import 'dart:async';
import 'dart:convert';

import 'package:river_domain/river_domain.dart';

import 'job_queue.dart';

final class DurableKnowledgeExportManager implements KnowledgeExportManager {
  DurableKnowledgeExportManager({
    required PersistentJobQueue jobs,
    required KnowledgeRepository repository,
    required Iterable<KnowledgeConnector> connectors,
    required Clock clock,
    required IdGenerator ids,
    this.maxAttempts = 5,
    this.leaseDuration = const Duration(minutes: 2),
    this.connectorTimeout = const Duration(seconds: 45),
    this.retryBaseDelay = const Duration(seconds: 30),
    this.maxRetryDelay = const Duration(minutes: 30),
  }) : assert(maxAttempts > 0),
       assert(leaseDuration > Duration.zero),
       assert(connectorTimeout > Duration.zero),
       assert(!retryBaseDelay.isNegative),
       assert(!maxRetryDelay.isNegative),
       _jobs = jobs,
       _repository = repository,
       _connectors = _connectorMap(connectors),
       _clock = clock,
       _ids = ids;

  static const jobTypePrefix = 'knowledge-export/v1/';
  static const upsertJobType = '${jobTypePrefix}upsert';
  static const deleteJobType = '${jobTypePrefix}delete';

  final PersistentJobQueue _jobs;
  final KnowledgeRepository _repository;
  final Map<String, KnowledgeConnector> _connectors;
  final Clock _clock;
  final IdGenerator _ids;
  final int maxAttempts;
  final Duration leaseDuration;
  final Duration connectorTimeout;
  final Duration retryBaseDelay;
  final Duration maxRetryDelay;
  final StreamController<KnowledgeExportState> _changes =
      StreamController<KnowledgeExportState>.broadcast(sync: true);

  Future<void>? _activeRun;
  Timer? _retryTimer;
  DateTime? _retryAt;
  var _started = false;
  var _closed = false;

  Future<void> start() async {
    if (_started || _closed) return;
    _started = true;
    await _jobs.recoverExpiredLeases(
      _clock.now().toUtc(),
      typePrefix: jobTypePrefix,
      includeUnexpired: true,
    );
    await resumePending();
  }

  @override
  Stream<KnowledgeExportState> watch(
    KnowledgeExportTarget target,
    KnowledgeExportOperation operation,
  ) async* {
    yield await status(target, operation);
    yield* _changes.stream.where(
      (state) =>
          state.operation == operation &&
          state.target.stableKey == target.stableKey,
    );
  }

  @override
  Future<KnowledgeExportState> status(
    KnowledgeExportTarget target,
    KnowledgeExportOperation operation,
  ) async {
    final job = await _jobs.findByIdempotencyKey(_jobKey(target, operation));
    final mapping = operation == KnowledgeExportOperation.upsert
        ? await _mapping(target)
        : null;
    if (job == null) {
      return KnowledgeExportState(
        target: target,
        operation: operation,
        phase: KnowledgeExportPhase.notQueued,
        externalUrl: mapping?.externalUrl,
      );
    }
    return _stateForJob(target, operation, job, mapping?.externalUrl);
  }

  @override
  Future<void> enqueueUpsert(KnowledgeExportTarget target) =>
      _enqueue(target, KnowledgeExportOperation.upsert);

  @override
  Future<void> enqueueDelete(KnowledgeExportTarget target) =>
      _enqueue(target, KnowledgeExportOperation.delete);

  Future<void> _enqueue(
    KnowledgeExportTarget target,
    KnowledgeExportOperation operation,
  ) async {
    final now = _clock.now().toUtc();
    final key = _jobKey(target, operation);
    final existing = await _jobs.findByIdempotencyKey(key);
    var changed = false;
    if (existing == null) {
      changed = await _jobs.enqueue(
        NewDurableJob(
          id: _ids.next(),
          type: _jobType(operation),
          idempotencyKey: key,
          payloadJson: _payload(target),
          availableAt: now,
          maxAttempts: maxAttempts,
        ),
        now,
      );
    } else if (existing.status == DurableJobStatus.completed ||
        existing.status == DurableJobStatus.cancelled) {
      changed = await _jobs.requeue(idempotencyKey: key, now: now);
    }
    if (changed) {
      _emit(
        KnowledgeExportState(
          target: target,
          operation: operation,
          phase: KnowledgeExportPhase.queued,
        ),
      );
    } else {
      _emit(await status(target, operation));
    }
    await resumePending();
  }

  @override
  Future<void> retry(
    KnowledgeExportTarget target,
    KnowledgeExportOperation operation,
  ) async {
    final retried = await _jobs.retryFailed(
      idempotencyKey: _jobKey(target, operation),
      now: _clock.now().toUtc(),
    );
    if (!retried) return;
    _emit(
      KnowledgeExportState(
        target: target,
        operation: operation,
        phase: KnowledgeExportPhase.queued,
      ),
    );
    await resumePending();
  }

  Future<void> resumePending() {
    if (_closed) return Future<void>.value();
    final active = _activeRun;
    if (active != null) return active;
    late final Future<void> tracked;
    tracked = _resumePending().whenComplete(() {
      if (identical(_activeRun, tracked)) _activeRun = null;
    });
    _activeRun = tracked;
    return tracked;
  }

  Future<void> _resumePending() async {
    var now = _clock.now().toUtc();
    await _jobs.recoverExpiredLeases(now, typePrefix: jobTypePrefix);
    while (!_closed) {
      final job = await _jobs.claimNext(
        now: now,
        leaseDuration: leaseDuration,
        typePrefix: jobTypePrefix,
      );
      if (job == null) return;
      await _process(job);
      now = _clock.now().toUtc();
    }
  }

  Future<void> _process(ClaimedDurableJob job) async {
    final operation = _operationForType(job.type);
    final target = _decodeTarget(job.payloadJson);
    if (operation == null || target == null) {
      await _jobs.failPermanently(
        id: job.id,
        errorCode: 'invalid_payload',
        now: _clock.now().toUtc(),
      );
      return;
    }
    _emit(
      KnowledgeExportState(
        target: target,
        operation: operation,
        phase: KnowledgeExportPhase.running,
        attempt: job.attempt,
      ),
    );
    final connector = _connectors[target.connectorId];
    if (connector == null) {
      await _failPermanently(job, target, operation, 'connector_missing');
      return;
    }
    try {
      switch (operation) {
        case KnowledgeExportOperation.upsert:
          await _upsert(job, target, connector);
        case KnowledgeExportOperation.delete:
          await _delete(job, target, connector);
      }
    } on KnowledgeConnectorFailure catch (failure) {
      if (operation == KnowledgeExportOperation.delete &&
          failure.code == KnowledgeConnectorFailureCode.notFound) {
        await _finishDelete(job, target);
        return;
      }
      await _fail(
        job,
        target,
        operation,
        failure.code.name,
        retryable: failure.retryable,
        retryAfter: failure.retryAfter,
      );
    } on TimeoutException {
      await _fail(
        job,
        target,
        operation,
        KnowledgeConnectorFailureCode.timeout.name,
        retryable: true,
      );
    } on Object {
      await _fail(
        job,
        target,
        operation,
        KnowledgeConnectorFailureCode.unexpected.name,
        retryable: true,
      );
    }
  }

  Future<void> _upsert(
    ClaimedDurableJob job,
    KnowledgeExportTarget target,
    KnowledgeConnector connector,
  ) async {
    final item = await _repository.watchItem(target.knowledgeItemId).first;
    if (item == null) {
      await _failPermanently(
        job,
        target,
        KnowledgeExportOperation.upsert,
        'knowledge_missing',
      );
      return;
    }
    final existing = await _mapping(target);
    if (existing != null && existing.exportedContentHash == item.contentHash) {
      await _complete(job, target, KnowledgeExportOperation.upsert);
      return;
    }

    final object = existing == null
        ? await _bounded(
            connector.create(
              KnowledgeConnectorCreateRequest(
                item: item,
                destinationId: target.destinationId,
                idempotencyKey: 'river:create:v1:${_targetKey(target)}',
              ),
            ),
          )
        : await _bounded(
            connector.update(
              KnowledgeConnectorUpdateRequest(
                item: item,
                destinationId: target.destinationId,
                externalObjectId: existing.externalObjectId,
                idempotencyKey:
                    'river:update:v1:${_targetKey(target)}:${item.contentHash}',
              ),
            ),
          );
    final now = _clock.now().toUtc();
    final mappingTime = existing != null && !now.isAfter(existing.updatedAt)
        ? existing.updatedAt.add(const Duration(microseconds: 1))
        : now;
    await _repository.upsertExternalMapping(
      KnowledgeExternalMapping(
        knowledgeItemId: item.id,
        connectorId: target.connectorId,
        destinationId: target.destinationId,
        externalObjectId: object.externalObjectId,
        externalUrl: object.externalUrl,
        exportedContentHash: item.contentHash,
        createdAt: existing?.createdAt ?? mappingTime,
        updatedAt: mappingTime,
      ),
    );
    await _complete(job, target, KnowledgeExportOperation.upsert);

    final latest = await _repository.watchItem(target.knowledgeItemId).first;
    if (latest != null && latest.contentHash != item.contentHash) {
      final requeued = await _jobs.requeue(
        idempotencyKey: _jobKey(target, KnowledgeExportOperation.upsert),
        now: _clock.now().toUtc(),
      );
      if (requeued) {
        _emit(
          KnowledgeExportState(
            target: target,
            operation: KnowledgeExportOperation.upsert,
            phase: KnowledgeExportPhase.queued,
            externalUrl: object.externalUrl,
          ),
        );
      }
    }
  }

  Future<void> _delete(
    ClaimedDurableJob job,
    KnowledgeExportTarget target,
    KnowledgeConnector connector,
  ) async {
    final mapping = await _mapping(target);
    if (mapping == null) {
      await _complete(job, target, KnowledgeExportOperation.delete);
      return;
    }
    await _bounded(
      connector.delete(
        KnowledgeConnectorDeleteRequest(
          knowledgeItemId: target.knowledgeItemId,
          destinationId: target.destinationId,
          externalObjectId: mapping.externalObjectId,
          idempotencyKey:
              'river:delete:v1:${_targetKey(target)}:'
              '${mapping.externalObjectId}',
        ),
      ),
    );
    await _finishDelete(job, target);
  }

  Future<void> _finishDelete(
    ClaimedDurableJob job,
    KnowledgeExportTarget target,
  ) async {
    await _repository.deleteExternalMapping(
      knowledgeItemId: target.knowledgeItemId,
      connectorId: target.connectorId,
      destinationId: target.destinationId,
    );
    await _complete(job, target, KnowledgeExportOperation.delete);
  }

  Future<void> _complete(
    ClaimedDurableJob job,
    KnowledgeExportTarget target,
    KnowledgeExportOperation operation,
  ) async {
    await _jobs.complete(job.id, _clock.now().toUtc());
    final mapping = operation == KnowledgeExportOperation.upsert
        ? await _mapping(target)
        : null;
    _emit(
      KnowledgeExportState(
        target: target,
        operation: operation,
        phase: KnowledgeExportPhase.succeeded,
        attempt: job.attempt,
        externalUrl: mapping?.externalUrl,
      ),
    );
  }

  Future<void> _fail(
    ClaimedDurableJob job,
    KnowledgeExportTarget target,
    KnowledgeExportOperation operation,
    String errorCode, {
    required bool retryable,
    Duration? retryAfter,
  }) async {
    if (!retryable) {
      await _failPermanently(job, target, operation, errorCode);
      return;
    }
    final delay = _boundedDelay(retryAfter ?? _retryDelay(job.attempt));
    final jobStatus = await _jobs.failOrRetry(
      id: job.id,
      errorCode: errorCode,
      now: _clock.now().toUtc(),
      retryDelay: delay,
    );
    _emit(
      KnowledgeExportState(
        target: target,
        operation: operation,
        phase: jobStatus == DurableJobStatus.failed
            ? KnowledgeExportPhase.failed
            : KnowledgeExportPhase.queued,
        attempt: job.attempt,
        failureCode: errorCode,
      ),
    );
    if (jobStatus == DurableJobStatus.queued) _scheduleRetry(delay);
  }

  Future<void> _failPermanently(
    ClaimedDurableJob job,
    KnowledgeExportTarget target,
    KnowledgeExportOperation operation,
    String errorCode,
  ) async {
    await _jobs.failPermanently(
      id: job.id,
      errorCode: errorCode,
      now: _clock.now().toUtc(),
    );
    _emit(
      KnowledgeExportState(
        target: target,
        operation: operation,
        phase: KnowledgeExportPhase.failed,
        attempt: job.attempt,
        failureCode: errorCode,
      ),
    );
  }

  Future<KnowledgeExternalMapping?> _mapping(
    KnowledgeExportTarget target,
  ) async {
    final mappings = await _repository
        .watchExternalMappings(target.knowledgeItemId)
        .first;
    for (final mapping in mappings) {
      if (mapping.connectorId == target.connectorId &&
          mapping.destinationId == target.destinationId) {
        return mapping;
      }
    }
    return null;
  }

  Future<T> _bounded<T>(Future<T> operation) =>
      operation.timeout(connectorTimeout);

  Duration _retryDelay(int attempt) {
    final exponent = (attempt - 1).clamp(0, 5).toInt();
    return _boundedDelay(retryBaseDelay * (1 << exponent));
  }

  Duration _boundedDelay(Duration delay) {
    if (delay.isNegative) return Duration.zero;
    return delay > maxRetryDelay ? maxRetryDelay : delay;
  }

  void _scheduleRetry(Duration delay) {
    final retryAt = _clock.now().toUtc().add(delay);
    final scheduled = _retryAt;
    if (scheduled != null && !retryAt.isBefore(scheduled)) return;
    _retryTimer?.cancel();
    _retryAt = retryAt;
    _retryTimer = Timer(delay, () {
      _retryTimer = null;
      _retryAt = null;
      unawaited(resumePending());
    });
  }

  KnowledgeExportState _stateForJob(
    KnowledgeExportTarget target,
    KnowledgeExportOperation operation,
    DurableJobRecord job,
    Uri? externalUrl,
  ) {
    return KnowledgeExportState(
      target: target,
      operation: operation,
      phase: switch (job.status) {
        DurableJobStatus.queued => KnowledgeExportPhase.queued,
        DurableJobStatus.running => KnowledgeExportPhase.running,
        DurableJobStatus.completed => KnowledgeExportPhase.succeeded,
        DurableJobStatus.failed => KnowledgeExportPhase.failed,
        DurableJobStatus.cancelled => KnowledgeExportPhase.cancelled,
      },
      attempt: job.attempt,
      failureCode: job.lastErrorCode,
      externalUrl: externalUrl,
    );
  }

  void _emit(KnowledgeExportState state) {
    if (!_closed) _changes.add(state);
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _retryTimer?.cancel();
    _retryTimer = null;
    _retryAt = null;
    await _activeRun;
    await _changes.close();
  }
}

Map<String, KnowledgeConnector> _connectorMap(
  Iterable<KnowledgeConnector> connectors,
) {
  final result = <String, KnowledgeConnector>{};
  for (final connector in connectors) {
    final id = connector.id.trim();
    if (connector.id != id || id.isEmpty || id.length > 256) {
      throw ArgumentError.value(connector.id, 'connectors');
    }
    if (result.containsKey(id)) {
      throw ArgumentError.value(id, 'connectors', 'Duplicate connector ID.');
    }
    result[id] = connector;
  }
  return Map<String, KnowledgeConnector>.unmodifiable(result);
}

String _jobType(KnowledgeExportOperation operation) => switch (operation) {
  KnowledgeExportOperation.upsert =>
    DurableKnowledgeExportManager.upsertJobType,
  KnowledgeExportOperation.delete =>
    DurableKnowledgeExportManager.deleteJobType,
};

KnowledgeExportOperation? _operationForType(String type) => switch (type) {
  DurableKnowledgeExportManager.upsertJobType =>
    KnowledgeExportOperation.upsert,
  DurableKnowledgeExportManager.deleteJobType =>
    KnowledgeExportOperation.delete,
  _ => null,
};

String _payload(KnowledgeExportTarget target) => jsonEncode(<String, String>{
  'knowledgeItemId': target.knowledgeItemId,
  'connectorId': target.connectorId,
  'destinationId': target.destinationId,
});

KnowledgeExportTarget? _decodeTarget(String payload) {
  try {
    final decoded = jsonDecode(payload);
    if (decoded is! Map<String, dynamic>) return null;
    final itemId = decoded['knowledgeItemId'];
    final connectorId = decoded['connectorId'];
    final destinationId = decoded['destinationId'];
    if (itemId is! String ||
        connectorId is! String ||
        destinationId is! String) {
      return null;
    }
    return KnowledgeExportTarget(
      knowledgeItemId: itemId,
      connectorId: connectorId,
      destinationId: destinationId,
    );
  } on Object {
    return null;
  }
}

String _jobKey(
  KnowledgeExportTarget target,
  KnowledgeExportOperation operation,
) => 'knowledge-export:v1:${operation.name}:${_targetKey(target)}';

String _targetKey(KnowledgeExportTarget target) =>
    '${_component(target.knowledgeItemId)}'
    '${_component(target.connectorId)}'
    '${_component(target.destinationId)}';

String _component(String value) => '${value.length}:$value';
