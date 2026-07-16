import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:math';

import 'package:river_domain/river_domain.dart';
import 'package:river_feed/river_feed.dart';

import 'job_queue.dart';

typedef FeedRefreshOperation = Future<FeedRefreshResult> Function(Uri uri);

enum FeedRefreshBatchPhase { idle, running, cancelling, completed, cancelled }

final class FeedRefreshBatchState {
  const FeedRefreshBatchState({
    required this.phase,
    required this.total,
    required this.succeeded,
    required this.failed,
    required this.cancelled,
    required this.inFlight,
    this.batchId,
  });

  const FeedRefreshBatchState.idle()
    : phase = FeedRefreshBatchPhase.idle,
      batchId = null,
      total = 0,
      succeeded = 0,
      failed = 0,
      cancelled = 0,
      inFlight = 0;

  final FeedRefreshBatchPhase phase;
  final String? batchId;
  final int total;
  final int succeeded;
  final int failed;
  final int cancelled;
  final int inFlight;

  int get settled => succeeded + failed + cancelled;

  bool get isActive =>
      phase == FeedRefreshBatchPhase.running ||
      phase == FeedRefreshBatchPhase.cancelling;

  double? get progress => total == 0 ? null : settled / total;
}

final class FeedRefreshCoordinator {
  FeedRefreshCoordinator({
    required PersistentJobQueue jobs,
    required FeedRefreshOperation refresh,
    required Clock clock,
    required IdGenerator ids,
    this.maxConcurrent = 4,
    this.maxPerHost = 2,
    this.leaseDuration = const Duration(minutes: 2),
  }) : assert(maxConcurrent > 0),
       assert(maxPerHost > 0),
       _jobs = jobs,
       _refresh = refresh,
       _clock = clock,
       _ids = ids;

  static const jobTypePrefix = 'feed-refresh/';

  final PersistentJobQueue _jobs;
  final FeedRefreshOperation _refresh;
  final Clock _clock;
  final IdGenerator _ids;
  final int maxConcurrent;
  final int maxPerHost;
  final Duration leaseDuration;
  final StreamController<FeedRefreshBatchState> _states =
      StreamController<FeedRefreshBatchState>.broadcast(sync: true);
  final Map<String, _PermitPool> _hostPools = <String, _PermitPool>{};

  FeedRefreshBatchState _state = const FeedRefreshBatchState.idle();
  Future<FeedRefreshBatchState>? _activeRun;
  String? _activeType;
  var _cancelRequested = false;
  var _total = 0;
  var _succeeded = 0;
  var _failed = 0;
  var _cancelled = 0;
  var _inFlight = 0;

  FeedRefreshBatchState get state => _state;

  Stream<FeedRefreshBatchState> get states => _states.stream;

  Future<FeedRefreshBatchState> start(
    Iterable<FeedSubscriptionRecord> subscriptions,
  ) {
    final active = _activeRun;
    if (active != null) return active;
    return _track(() => _startNew(subscriptions));
  }

  Future<FeedRefreshBatchState> resumePending() {
    final active = _activeRun;
    if (active != null) return active;
    return _track(_resumePending);
  }

  Future<FeedRefreshBatchState> cancel() async {
    final type = _activeType;
    if (type == null || !_state.isActive) return _state;
    _cancelRequested = true;
    _emit(FeedRefreshBatchPhase.cancelling);
    await _jobs.cancelType(type, _clock.now().toUtc());
    await _reloadCounters(type);
    _emit(FeedRefreshBatchPhase.cancelling);
    return _state;
  }

  Future<void> close() async {
    await cancel();
    await _activeRun;
    await _states.close();
  }

  Future<FeedRefreshBatchState> _track(
    Future<FeedRefreshBatchState> Function() operation,
  ) {
    late final Future<FeedRefreshBatchState> tracked;
    tracked = operation().whenComplete(() {
      if (identical(_activeRun, tracked)) {
        _activeRun = null;
      }
    });
    _activeRun = tracked;
    return tracked;
  }

  Future<FeedRefreshBatchState> _startNew(
    Iterable<FeedSubscriptionRecord> subscriptions,
  ) async {
    final enabled = subscriptions.where((feed) => feed.enabled).toList();
    if (enabled.isEmpty) {
      _resetCounters();
      _emit(FeedRefreshBatchPhase.completed);
      return _state;
    }

    final batchId = _ids.next();
    final type = '$jobTypePrefix${Uri.encodeComponent(batchId)}';
    final now = _clock.now().toUtc();
    for (final feed in _roundRobinByHost(enabled)) {
      await _jobs.enqueue(
        NewDurableJob(
          id: _ids.next(),
          type: type,
          idempotencyKey: '$type:${feed.id}',
          payloadJson: jsonEncode(<String, String>{
            'feedId': feed.id,
            'canonicalUrl': feed.canonicalUrl.toString(),
          }),
          availableAt: now,
          maxAttempts: 1,
        ),
        now,
      );
    }
    return _runBatch(type);
  }

  Future<FeedRefreshBatchState> _resumePending() async {
    final now = _clock.now().toUtc();
    await _jobs.recoverExpiredLeases(
      now,
      typePrefix: jobTypePrefix,
      includeUnexpired: true,
    );
    final pending = await _jobs.list(
      typePrefix: jobTypePrefix,
      statuses: const <DurableJobStatus>{
        DurableJobStatus.queued,
        DurableJobStatus.running,
      },
    );
    if (pending.isEmpty) return _state;

    final types = LinkedHashSet<String>.of(pending.map((job) => job.type));
    var result = _state;
    for (final type in types) {
      result = await _runBatch(type);
      if (result.phase == FeedRefreshBatchPhase.cancelled) break;
    }
    return result;
  }

  Future<FeedRefreshBatchState> _runBatch(String type) async {
    _activeType = type;
    _cancelRequested = false;
    _hostPools.clear();
    await _reloadCounters(type);
    _emit(FeedRefreshBatchPhase.running);

    final queued = await _jobs.list(
      type: type,
      statuses: const <DurableJobStatus>{DurableJobStatus.queued},
    );
    final workerCount = min(maxConcurrent, queued.length);
    await Future.wait<void>(
      List<Future<void>>.generate(workerCount, (_) => _runWorker(type)),
    );

    await _reloadCounters(type);
    final terminalPhase = _cancelRequested || _cancelled > 0
        ? FeedRefreshBatchPhase.cancelled
        : FeedRefreshBatchPhase.completed;
    _emit(terminalPhase);
    _activeType = null;
    return _state;
  }

  Future<void> _runWorker(String type) async {
    while (!_cancelRequested) {
      final job = await _jobs.claimNext(
        now: _clock.now().toUtc(),
        leaseDuration: leaseDuration,
        type: type,
      );
      if (job == null) return;

      _inFlight += 1;
      _emit(FeedRefreshBatchPhase.running);
      try {
        final uri = _uriFromPayload(job.payloadJson);
        final pool = _hostPools.putIfAbsent(
          _originKey(uri),
          () => _PermitPool(maxPerHost),
        );
        await pool.run(() {
          if (_cancelRequested) {
            throw const _RefreshCancelled();
          }
          return _refresh(uri);
        });
        if (await _jobs.complete(job.id, _clock.now().toUtc())) {
          _succeeded += 1;
        }
      } catch (_) {
        final status = await _jobs.failOrRetry(
          id: job.id,
          errorCode: 'feed_refresh_failed',
          now: _clock.now().toUtc(),
        );
        if (status == DurableJobStatus.failed) {
          _failed += 1;
        }
      } finally {
        _inFlight -= 1;
        _emit(
          _cancelRequested
              ? FeedRefreshBatchPhase.cancelling
              : FeedRefreshBatchPhase.running,
        );
      }
    }
  }

  Future<void> _reloadCounters(String type) async {
    final records = await _jobs.list(type: type);
    _total = records.length;
    _succeeded = records
        .where((job) => job.status == DurableJobStatus.completed)
        .length;
    _failed = records
        .where((job) => job.status == DurableJobStatus.failed)
        .length;
    _cancelled = records
        .where((job) => job.status == DurableJobStatus.cancelled)
        .length;
  }

  void _resetCounters() {
    _total = 0;
    _succeeded = 0;
    _failed = 0;
    _cancelled = 0;
    _inFlight = 0;
  }

  void _emit(FeedRefreshBatchPhase phase) {
    final type = _activeType;
    _state = FeedRefreshBatchState(
      phase: phase,
      batchId: type == null
          ? null
          : Uri.decodeComponent(type.substring(jobTypePrefix.length)),
      total: _total,
      succeeded: _succeeded,
      failed: _failed,
      cancelled: _cancelled,
      inFlight: _inFlight,
    );
    if (!_states.isClosed) {
      _states.add(_state);
    }
  }
}

Uri _uriFromPayload(String payloadJson) {
  final payload = jsonDecode(payloadJson);
  if (payload is! Map<String, dynamic>) {
    throw const FormatException('Refresh payload must be an object.');
  }
  final canonicalUrl = payload['canonicalUrl'];
  if (canonicalUrl is! String) {
    throw const FormatException('Refresh payload is missing canonicalUrl.');
  }
  return Uri.parse(canonicalUrl);
}

List<FeedSubscriptionRecord> _roundRobinByHost(
  List<FeedSubscriptionRecord> feeds,
) {
  final buckets = LinkedHashMap<String, ListQueue<FeedSubscriptionRecord>>();
  for (final feed in feeds) {
    buckets
        .putIfAbsent(
          _originKey(feed.canonicalUrl),
          ListQueue<FeedSubscriptionRecord>.new,
        )
        .add(feed);
  }
  final ordered = <FeedSubscriptionRecord>[];
  while (buckets.values.any((bucket) => bucket.isNotEmpty)) {
    for (final bucket in buckets.values) {
      if (bucket.isNotEmpty) ordered.add(bucket.removeFirst());
    }
  }
  return ordered;
}

String _originKey(Uri uri) {
  final port = uri.hasPort
      ? uri.port
      : switch (uri.scheme.toLowerCase()) {
          'http' => 80,
          'https' => 443,
          _ => 0,
        };
  return '${uri.scheme.toLowerCase()}://${uri.host.toLowerCase()}:$port';
}

final class _PermitPool {
  _PermitPool(this.limit);

  final int limit;
  final Queue<Completer<void>> _waiters = Queue<Completer<void>>();
  var _active = 0;

  Future<T> run<T>(Future<T> Function() operation) async {
    if (_active >= limit) {
      final waiter = Completer<void>();
      _waiters.addLast(waiter);
      await waiter.future;
    }
    _active += 1;
    try {
      return await operation();
    } finally {
      _active -= 1;
      if (_waiters.isNotEmpty) {
        _waiters.removeFirst().complete();
      }
    }
  }
}

final class _RefreshCancelled implements Exception {
  const _RefreshCancelled();
}
