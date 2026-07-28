import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:river_data/river_data.dart';
import 'package:river_domain/river_domain.dart';
import 'package:test/test.dart';

void main() {
  test('create is durable, idempotent, and stores only target IDs', () async {
    final fixture = await _Fixture.create();
    addTearDown(fixture.close);

    await fixture.manager.enqueueUpsert(_target);
    await fixture.manager.enqueueUpsert(_target);

    final mappings = await fixture.repository
        .watchExternalMappings('knowledge-1')
        .first;
    final jobs = await fixture.jobs.list(
      type: DurableKnowledgeExportManager.upsertJobType,
    );
    expect(fixture.connector.creates, hasLength(1));
    expect(fixture.connector.updates, isEmpty);
    expect(mappings, hasLength(1));
    expect(mappings.single.externalObjectId, 'page-knowledge-1');
    expect(mappings.single.exportedContentHash, _hash('a'));
    expect(jobs, hasLength(1));
    expect(jobs.single.status, DurableJobStatus.completed);
    expect(jsonDecode(jobs.single.payloadJson), <String, Object>{
      'knowledgeItemId': 'knowledge-1',
      'connectorId': 'notion',
      'destinationId': 'dest',
    });
    expect(jobs.single.payloadJson, isNot(contains('Article body')));
  });

  test('changed content updates the existing external object', () async {
    final fixture = await _Fixture.create();
    addTearDown(fixture.close);
    await fixture.manager.enqueueUpsert(_target);

    fixture.clock.advance(const Duration(minutes: 1));
    await fixture.repository.saveItem(
      _item(hashCharacter: 'b', updatedAt: fixture.clock.now()),
    );
    await fixture.manager.enqueueUpsert(_target);

    final mapping =
        (await fixture.repository.watchExternalMappings('knowledge-1').first)
            .single;
    expect(fixture.connector.creates, hasLength(1));
    expect(fixture.connector.updates, hasLength(1));
    expect(
      fixture.connector.updates.single.idempotencyKey,
      endsWith(_hash('b')),
    );
    expect(mapping.externalObjectId, 'page-knowledge-1');
    expect(mapping.exportedContentHash, _hash('b'));
  });

  test(
    'retry exhaustion enters dead letter and manual retry resets budget',
    () async {
      final fixture = await _Fixture.create(maxAttempts: 2);
      addTearDown(fixture.close);
      fixture.connector.createFailures.addAll(<KnowledgeConnectorFailure>[
        const KnowledgeConnectorFailure(
          code: KnowledgeConnectorFailureCode.offline,
          retryable: true,
        ),
        const KnowledgeConnectorFailure(
          code: KnowledgeConnectorFailureCode.offline,
          retryable: true,
        ),
      ]);

      await fixture.manager.enqueueUpsert(_target);

      final failed = await fixture.manager.status(
        _target,
        KnowledgeExportOperation.upsert,
      );
      expect(failed.phase, KnowledgeExportPhase.failed);
      expect(failed.attempt, 2);
      expect(failed.failureCode, 'offline');

      await fixture.manager.retry(_target, KnowledgeExportOperation.upsert);

      final recovered = await fixture.manager.status(
        _target,
        KnowledgeExportOperation.upsert,
      );
      expect(recovered.phase, KnowledgeExportPhase.succeeded);
      expect(recovered.attempt, 1);
      expect(fixture.connector.creates, hasLength(3));
      expect(
        fixture.connector.creates
            .map((request) => request.idempotencyKey)
            .toSet(),
        hasLength(1),
      );
    },
  );

  test(
    'connector retry-after is bounded without leaking remote errors',
    () async {
      final fixture = await _Fixture.create(
        maxAttempts: 2,
        retryBaseDelay: const Duration(minutes: 1),
        maxRetryDelay: const Duration(minutes: 30),
      );
      addTearDown(fixture.close);
      fixture.connector.createFailures.add(
        const KnowledgeConnectorFailure(
          code: KnowledgeConnectorFailureCode.rateLimited,
          retryable: true,
          retryAfter: Duration(hours: 2),
        ),
      );

      await fixture.manager.enqueueUpsert(_target);

      final job = (await fixture.jobs.list(
        type: DurableKnowledgeExportManager.upsertJobType,
      )).single;
      expect(job.status, DurableJobStatus.queued);
      expect(
        job.availableAt.toUtc(),
        fixture.clock.now().add(const Duration(minutes: 30)),
      );
      expect(job.lastErrorCode, 'rateLimited');
    },
  );

  test('non-retryable connector failure stops immediately', () async {
    final fixture = await _Fixture.create(maxAttempts: 5);
    addTearDown(fixture.close);
    fixture.connector.createFailures.add(
      const KnowledgeConnectorFailure(
        code: KnowledgeConnectorFailureCode.authenticationRequired,
        retryable: false,
      ),
    );

    await fixture.manager.enqueueUpsert(_target);

    final state = await fixture.manager.status(
      _target,
      KnowledgeExportOperation.upsert,
    );
    expect(state.phase, KnowledgeExportPhase.failed);
    expect(state.attempt, 1);
    expect(state.failureCode, 'authenticationRequired');
    expect(fixture.connector.creates, hasLength(1));
  });

  test('delete treats an already missing remote object as success', () async {
    final fixture = await _Fixture.create();
    addTearDown(fixture.close);
    await fixture.manager.enqueueUpsert(_target);
    fixture.connector.deleteFailure = const KnowledgeConnectorFailure(
      code: KnowledgeConnectorFailureCode.notFound,
      retryable: false,
    );

    await fixture.manager.enqueueDelete(_target);

    final mappings = await fixture.repository
        .watchExternalMappings('knowledge-1')
        .first;
    final state = await fixture.manager.status(
      _target,
      KnowledgeExportOperation.delete,
    );
    expect(fixture.connector.deletes, hasLength(1));
    expect(mappings, isEmpty);
    expect(state.phase, KnowledgeExportPhase.succeeded);
  });

  test('cold start reclaims an unexpired export lease', () async {
    final database = RiverDatabase(NativeDatabase.memory());
    final jobs = PersistentJobQueue(database);
    final repository = DriftKnowledgeRepository(database);
    final clock = _Clock(DateTime.utc(2026, 7, 28, 8));
    final connector = _Connector();
    await repository.saveItem(_item(updatedAt: clock.now()));
    await jobs.enqueue(
      NewDurableJob(
        id: 'job-1',
        type: DurableKnowledgeExportManager.upsertJobType,
        idempotencyKey:
            'knowledge-export:v1:upsert:11:knowledge-16:notion4:dest',
        payloadJson: jsonEncode(<String, String>{
          'knowledgeItemId': 'knowledge-1',
          'connectorId': 'notion',
          'destinationId': 'dest',
        }),
        availableAt: clock.now(),
      ),
      clock.now(),
    );
    await jobs.claimNext(
      now: clock.now(),
      leaseDuration: const Duration(hours: 1),
      type: DurableKnowledgeExportManager.upsertJobType,
    );
    final manager = DurableKnowledgeExportManager(
      jobs: jobs,
      repository: repository,
      connectors: <KnowledgeConnector>[connector],
      clock: clock,
      ids: _Ids(),
      retryBaseDelay: Duration.zero,
    );
    addTearDown(() async {
      await manager.close();
      await database.close();
    });

    await manager.start();

    expect(connector.creates, hasLength(1));
    expect(
      (await manager.status(_target, KnowledgeExportOperation.upsert)).phase,
      KnowledgeExportPhase.succeeded,
    );
  });

  test('an edit during create is requeued and exported as an update', () async {
    final fixture = await _Fixture.create();
    addTearDown(fixture.close);
    var changed = false;
    fixture.connector.beforeCreateReturns = (_) async {
      if (changed) return;
      changed = true;
      fixture.clock.advance(const Duration(minutes: 1));
      await fixture.repository.saveItem(
        _item(hashCharacter: 'b', updatedAt: fixture.clock.now()),
      );
    };

    await fixture.manager.enqueueUpsert(_target);

    final mapping =
        (await fixture.repository.watchExternalMappings('knowledge-1').first)
            .single;
    expect(fixture.connector.creates, hasLength(1));
    expect(fixture.connector.updates, hasLength(1));
    expect(mapping.exportedContentHash, _hash('b'));
  });
}

final _target = KnowledgeExportTarget(
  knowledgeItemId: 'knowledge-1',
  connectorId: 'notion',
  destinationId: 'dest',
);

final class _Fixture {
  _Fixture({
    required this.database,
    required this.jobs,
    required this.repository,
    required this.connector,
    required this.clock,
    required this.manager,
  });

  final RiverDatabase database;
  final PersistentJobQueue jobs;
  final DriftKnowledgeRepository repository;
  final _Connector connector;
  final _Clock clock;
  final DurableKnowledgeExportManager manager;

  static Future<_Fixture> create({
    int maxAttempts = 5,
    Duration retryBaseDelay = Duration.zero,
    Duration maxRetryDelay = const Duration(minutes: 30),
  }) async {
    final database = RiverDatabase(NativeDatabase.memory());
    final jobs = PersistentJobQueue(database);
    final repository = DriftKnowledgeRepository(database);
    final connector = _Connector();
    final clock = _Clock(DateTime.utc(2026, 7, 28, 8));
    await repository.saveItem(_item(updatedAt: clock.now()));
    final manager = DurableKnowledgeExportManager(
      jobs: jobs,
      repository: repository,
      connectors: <KnowledgeConnector>[connector],
      clock: clock,
      ids: _Ids(),
      maxAttempts: maxAttempts,
      retryBaseDelay: retryBaseDelay,
      maxRetryDelay: maxRetryDelay,
    );
    await manager.start();
    return _Fixture(
      database: database,
      jobs: jobs,
      repository: repository,
      connector: connector,
      clock: clock,
      manager: manager,
    );
  }

  Future<void> close() async {
    await manager.close();
    await database.close();
  }
}

final class _Connector implements KnowledgeConnector {
  @override
  String get id => 'notion';

  final List<KnowledgeConnectorCreateRequest> creates =
      <KnowledgeConnectorCreateRequest>[];
  final List<KnowledgeConnectorUpdateRequest> updates =
      <KnowledgeConnectorUpdateRequest>[];
  final List<KnowledgeConnectorDeleteRequest> deletes =
      <KnowledgeConnectorDeleteRequest>[];
  final List<KnowledgeConnectorFailure> createFailures =
      <KnowledgeConnectorFailure>[];
  Future<void> Function(KnowledgeConnectorCreateRequest)? beforeCreateReturns;
  KnowledgeConnectorFailure? deleteFailure;

  @override
  Future<KnowledgeConnectorObject> create(
    KnowledgeConnectorCreateRequest request,
  ) async {
    creates.add(request);
    if (createFailures.isNotEmpty) throw createFailures.removeAt(0);
    await beforeCreateReturns?.call(request);
    return KnowledgeConnectorObject(
      externalObjectId: 'page-${request.item.id}',
      externalUrl: Uri.parse('https://notion.test/${request.item.id}'),
    );
  }

  @override
  Future<void> delete(KnowledgeConnectorDeleteRequest request) async {
    deletes.add(request);
    final failure = deleteFailure;
    if (failure != null) throw failure;
  }

  @override
  Future<KnowledgeConnectorObjectStatus> status(
    KnowledgeConnectorStatusRequest request,
  ) async {
    return KnowledgeConnectorObjectStatus(
      phase: KnowledgeConnectorObjectPhase.available,
      externalUrl: Uri.parse('https://notion.test/${request.externalObjectId}'),
    );
  }

  @override
  Future<KnowledgeConnectorConnectionStatus> testConnection() async {
    return const KnowledgeConnectorConnectionStatus(
      phase: KnowledgeConnectorConnectionPhase.connected,
    );
  }

  @override
  Future<KnowledgeConnectorObject> update(
    KnowledgeConnectorUpdateRequest request,
  ) async {
    updates.add(request);
    return KnowledgeConnectorObject(
      externalObjectId: request.externalObjectId,
      externalUrl: Uri.parse('https://notion.test/${request.item.id}'),
    );
  }
}

final class _Clock implements Clock {
  _Clock(this._now);

  DateTime _now;

  void advance(Duration duration) => _now = _now.add(duration);

  @override
  DateTime now() => _now;
}

final class _Ids implements IdGenerator {
  var _next = 0;

  @override
  String next() => 'knowledge-export-job-${_next++}';
}

KnowledgeItem _item({String hashCharacter = 'a', required DateTime updatedAt}) {
  return KnowledgeItem(
    id: 'knowledge-1',
    source: KnowledgeSourceReference(
      kind: KnowledgeSourceKind.article,
      sourceId: 'article-1',
      originalUrl: Uri.parse('https://example.test/article-1'),
      sourceTitle: 'River Weekly',
    ),
    title: 'Knowledge',
    markdown: '# Article body',
    sanitizedHtml: '<h1>Article body</h1>',
    contentHash: _hash(hashCharacter),
    savedAt: DateTime.utc(2026, 7, 28, 8),
    updatedAt: updatedAt,
  );
}

String _hash(String character) =>
    'sha256:${List<String>.filled(64, character).join()}';
