import 'dart:math';

import 'package:river_sync/river_sync.dart';
import 'package:test/test.dart';

void main() {
  test('two devices incrementally exchange all six bounded object kinds',
      () async {
    final fixture = _Fixture(batchSize: 2);
    final payloads = List<SyncObjectPayload>.generate(6, _payloadFor);
    for (final payload in payloads) {
      await fixture.controllerA.queueUpsert(
        session: fixture.sessionA,
        dataKey: fixture.keyA,
        payload: payload,
      );
    }

    final first = await fixture.controllerA.synchronize(
      session: fixture.sessionA,
      dataKey: fixture.keyA,
    ) as IncrementalSyncSuccess;
    final second = await fixture.controllerB.synchronize(
      session: fixture.sessionB,
      dataKey: fixture.keyB,
    ) as IncrementalSyncSuccess;

    expect(first.pushed, 6);
    expect(first.applied, 0);
    expect(second.pulled, 6);
    expect(second.applied, 6);
    expect(fixture.storeB.records, hasLength(6));
    expect(second.cursor.serverSequence, 6);

    final updated = SyncObjectPayload.subscription(
      objectId: payloads.first.objectId,
      canonicalUrl: 'https://example.com/feed/0.xml',
      title: 'Updated on phone',
      enabled: false,
      folderId: 'folder-1',
    );
    final updatedEnvelope = await fixture.controllerB.queueUpsert(
      session: fixture.sessionB,
      dataKey: fixture.keyB,
      payload: updated,
    );
    expect(
      updatedEnvelope.versionVector,
      VersionVector(<String, int>{'device-a': 1, 'device-b': 1}),
    );
    await fixture.controllerB.synchronize(
      session: fixture.sessionB,
      dataKey: fixture.keyB,
    );
    final received = await fixture.controllerA.synchronize(
      session: fixture.sessionA,
      dataKey: fixture.keyA,
    ) as IncrementalSyncSuccess;

    expect(received.pulled, 1);
    expect(received.applied, 1);
    expect(
      fixture.storeA
          .upsert(
            SyncObjectKind.subscription,
            updated.objectId,
          )
          .fields['title'],
      'Updated on phone',
    );

    final previousPullCount = fixture.server.pullCalls;
    final noChanges = await fixture.controllerA.synchronize(
      session: fixture.sessionA,
      dataKey: fixture.keyA,
    ) as IncrementalSyncSuccess;
    expect(noChanges.pulled, 0);
    expect(noChanges.cursor.serverSequence, 7);
    expect(fixture.server.pullCalls, previousPullCount + 1);
    expect(fixture.server.requestedSequences.last, 7);
  });

  test('tombstones are encrypted, pulled, and applied causally', () async {
    final fixture = _Fixture();
    final payload = _payloadFor(0);
    await fixture.controllerA.queueUpsert(
      session: fixture.sessionA,
      dataKey: fixture.keyA,
      payload: payload,
    );
    await fixture.syncBoth();

    final tombstoneEnvelope = await fixture.controllerB.queueTombstone(
      session: fixture.sessionB,
      dataKey: fixture.keyB,
      objectKind: payload.objectKind,
      objectId: payload.objectId,
    );
    expect(
      tombstoneEnvelope.versionVector,
      VersionVector(<String, int>{'device-a': 1, 'device-b': 1}),
    );
    await fixture.controllerB.synchronize(
      session: fixture.sessionB,
      dataKey: fixture.keyB,
    );
    await fixture.controllerA.synchronize(
      session: fixture.sessionA,
      dataKey: fixture.keyA,
    );

    final record = fixture.storeA.record(
      payload.objectKind,
      payload.objectId,
    );
    expect(record.decodedPayload, isA<DecodedSyncTombstone>());
    expect(record.envelope.ciphertextBase64, isNot(contains(payload.objectId)));
  });

  test('offline transport preserves outbox and cursor for retry', () async {
    final fixture = _Fixture();
    await fixture.controllerA.queueUpsert(
      session: fixture.sessionA,
      dataKey: fixture.keyA,
      payload: _payloadFor(0),
    );
    fixture.server.offline = true;

    final failed = await fixture.controllerA.synchronize(
      session: fixture.sessionA,
      dataKey: fixture.keyA,
    ) as IncrementalSyncFailure;

    expect(failed.code, IncrementalSyncFailureCode.offline);
    expect(failed.retryable, isTrue);
    expect(fixture.storeA.outbox, hasLength(1));
    expect((await fixture.storeA.readCursor()).serverSequence, 0);

    fixture.server.offline = false;
    final recovered = await fixture.controllerA.synchronize(
      session: fixture.sessionA,
      dataKey: fixture.keyA,
    ) as IncrementalSyncSuccess;
    expect(recovered.pushed, 1);
    expect(fixture.storeA.outbox, isEmpty);
  });

  test('fresh authorization blocks a revoked device before transport',
      () async {
    final fixture = _Fixture();
    await fixture.controllerA.queueUpsert(
      session: fixture.sessionA,
      dataKey: fixture.keyA,
      payload: _payloadFor(0),
    );
    fixture.authorizerA.result = const SyncAuthFailure<SyncSession>(
      code: SyncAuthFailureCode.deviceRevoked,
    );

    final result = await fixture.controllerA.synchronize(
      session: fixture.sessionA,
      dataKey: fixture.keyA,
    ) as IncrementalSyncFailure;

    expect(result.code, IncrementalSyncFailureCode.unauthorized);
    expect(fixture.server.envelopes, isEmpty);
    expect(fixture.storeA.outbox, hasLength(1));
  });

  test('invalid authenticated payload never advances the durable cursor',
      () async {
    final fixture = _Fixture();
    final occurredAt = DateTime.utc(2026, 7, 27, 4);
    final malformed = await fixture.cryptoB.encryptEnvelope(
      mutationId: 'malformed-1',
      accountId: fixture.sessionB.accountId,
      objectKind: SyncObjectKind.folder,
      objectId: 'folder-invalid',
      payloadKind: SyncPayloadKind.upsert,
      authorDeviceId: fixture.sessionB.deviceId,
      versionVector: VersionVector(<String, int>{'device-b': 1}),
      occurredAt: occurredAt,
      clearText: const <int>[123, 125],
      dataKey: fixture.keyB,
    );
    fixture.server.seed(malformed);

    final result = await fixture.controllerA.synchronize(
      session: fixture.sessionA,
      dataKey: fixture.keyA,
    ) as IncrementalSyncFailure;

    expect(result.code, IncrementalSyncFailureCode.invalidPayload);
    expect((await fixture.storeA.readCursor()).serverSequence, 0);
    expect(fixture.storeA.records, isEmpty);
  });

  test('remote page commit is atomic and retryable after storage failure',
      () async {
    final fixture = _Fixture();
    await fixture.controllerB.queueUpsert(
      session: fixture.sessionB,
      dataKey: fixture.keyB,
      payload: _payloadFor(1),
    );
    await fixture.controllerB.synchronize(
      session: fixture.sessionB,
      dataKey: fixture.keyB,
    );
    fixture.storeA.failNextRemoteCommit = true;

    final failed = await fixture.controllerA.synchronize(
      session: fixture.sessionA,
      dataKey: fixture.keyA,
    ) as IncrementalSyncFailure;
    expect(failed.code, IncrementalSyncFailureCode.storage);
    expect((await fixture.storeA.readCursor()).serverSequence, 0);
    expect(fixture.storeA.records, isEmpty);

    final retried = await fixture.controllerA.synchronize(
      session: fixture.sessionA,
      dataKey: fixture.keyA,
    ) as IncrementalSyncSuccess;
    expect(retried.applied, 1);
    expect(retried.cursor.serverSequence, 1);
  });

  test('partial push acknowledgement cannot discard durable mutations',
      () async {
    final fixture = _Fixture();
    await fixture.controllerA.queueUpsert(
      session: fixture.sessionA,
      dataKey: fixture.keyA,
      payload: _payloadFor(0),
    );
    fixture.server.returnPartialReceipt = true;

    final result = await fixture.controllerA.synchronize(
      session: fixture.sessionA,
      dataKey: fixture.keyA,
    ) as IncrementalSyncFailure;

    expect(result.code, IncrementalSyncFailureCode.incompatibleProtocol);
    expect(fixture.storeA.outbox, hasLength(1));
  });

  test('a non-advancing non-empty pull page is rejected', () async {
    final fixture = _Fixture();
    await fixture.controllerB.queueUpsert(
      session: fixture.sessionB,
      dataKey: fixture.keyB,
      payload: _payloadFor(1),
    );
    await fixture.controllerB.synchronize(
      session: fixture.sessionB,
      dataKey: fixture.keyB,
    );
    fixture.server.returnNonAdvancingPage = true;

    final result = await fixture.controllerA.synchronize(
      session: fixture.sessionA,
      dataKey: fixture.keyA,
    ) as IncrementalSyncFailure;

    expect(result.code, IncrementalSyncFailureCode.incompatibleProtocol);
    expect((await fixture.storeA.readCursor()).serverSequence, 0);
    expect(fixture.storeA.records, isEmpty);
  });

  test('duplicate replay is idempotent and mutation collision is rejected',
      () async {
    final fixture = _Fixture();
    await fixture.controllerB.queueUpsert(
      session: fixture.sessionB,
      dataKey: fixture.keyB,
      payload: _payloadFor(0),
    );
    await fixture.controllerB.synchronize(
      session: fixture.sessionB,
      dataKey: fixture.keyB,
    );
    await fixture.controllerA.synchronize(
      session: fixture.sessionA,
      dataKey: fixture.keyA,
    );
    final original = fixture.server.envelopes.single;
    fixture.server.forceAppend(original);

    final replayed = await fixture.controllerA.synchronize(
      session: fixture.sessionA,
      dataKey: fixture.keyA,
    ) as IncrementalSyncSuccess;

    expect(replayed.pulled, 1);
    expect(replayed.applied, 0);
    expect(replayed.conflicts, 0);
    expect(replayed.cursor.serverSequence, 2);
    expect(fixture.storeA.records, hasLength(1));

    final different = _payloadFor(1);
    final collision = await fixture.cryptoB.encryptEnvelope(
      mutationId: original.mutationId,
      accountId: fixture.sessionB.accountId,
      objectKind: different.objectKind,
      objectId: different.objectId,
      payloadKind: SyncPayloadKind.upsert,
      authorDeviceId: fixture.sessionB.deviceId,
      versionVector: VersionVector(<String, int>{'device-b': 2}),
      occurredAt: DateTime.utc(2026, 7, 28),
      clearText: SyncPayloadCodec.encodeUpsert(different),
      dataKey: fixture.keyB,
    );
    fixture.server.forceAppend(collision);

    final rejected = await fixture.controllerA.synchronize(
      session: fixture.sessionA,
      dataKey: fixture.keyA,
    ) as IncrementalSyncFailure;

    expect(rejected.code, IncrementalSyncFailureCode.incompatibleProtocol);
    expect((await fixture.storeA.readCursor()).serverSequence, 2);
    expect(fixture.storeA.records, hasLength(1));
  });

  test('concurrent edits are staged without blocking cursor progress',
      () async {
    final fixture = _Fixture();
    final base = _payloadFor(0);
    await fixture.controllerA.queueUpsert(
      session: fixture.sessionA,
      dataKey: fixture.keyA,
      payload: base,
    );
    await fixture.syncBoth();
    await fixture.controllerA.queueUpsert(
      session: fixture.sessionA,
      dataKey: fixture.keyA,
      payload: SyncObjectPayload.subscription(
        objectId: base.objectId,
        canonicalUrl: 'https://example.com/feed/0.xml',
        title: 'Desktop edit',
        enabled: true,
      ),
    );
    await fixture.controllerB.queueUpsert(
      session: fixture.sessionB,
      dataKey: fixture.keyB,
      payload: SyncObjectPayload.subscription(
        objectId: base.objectId,
        canonicalUrl: 'https://example.com/feed/0.xml',
        title: 'Phone edit',
        enabled: true,
      ),
    );

    await fixture.controllerA.synchronize(
      session: fixture.sessionA,
      dataKey: fixture.keyA,
    );
    final phone = await fixture.controllerB.synchronize(
      session: fixture.sessionB,
      dataKey: fixture.keyB,
    ) as IncrementalSyncSuccess;
    final desktop = await fixture.controllerA.synchronize(
      session: fixture.sessionA,
      dataKey: fixture.keyA,
    ) as IncrementalSyncSuccess;

    expect(phone.conflicts, 1);
    expect(desktop.conflicts, 1);
    expect(fixture.storeA.conflicts, hasLength(1));
    expect(fixture.storeB.conflicts, hasLength(1));
    expect(desktop.cursor.serverSequence, 3);
    expect(phone.cursor.serverSequence, 3);
  });

  test('concurrent edits to different fields converge through merged mutations',
      () async {
    final fixture = _Fixture();
    final base = _payloadFor(0);
    await fixture.controllerA.queueUpsert(
      session: fixture.sessionA,
      dataKey: fixture.keyA,
      payload: base,
    );
    await fixture.syncBoth();
    await fixture.controllerA.queueUpsert(
      session: fixture.sessionA,
      dataKey: fixture.keyA,
      payload: SyncObjectPayload.subscription(
        objectId: base.objectId,
        canonicalUrl: 'https://example.com/feed/0.xml',
        title: 'Desktop title',
        enabled: base.fields['enabled']! as bool,
        folderId: base.fields['folderId'] as String?,
      ),
    );
    await fixture.controllerB.queueUpsert(
      session: fixture.sessionB,
      dataKey: fixture.keyB,
      payload: SyncObjectPayload.subscription(
        objectId: base.objectId,
        canonicalUrl: 'https://example.com/feed/0.xml',
        title: base.fields['title']! as String,
        enabled: !(base.fields['enabled']! as bool),
        folderId: base.fields['folderId'] as String?,
      ),
    );

    await fixture.controllerA.synchronize(
      session: fixture.sessionA,
      dataKey: fixture.keyA,
    );
    await fixture.controllerB.synchronize(
      session: fixture.sessionB,
      dataKey: fixture.keyB,
    );
    expect(fixture.storeB.outbox, hasLength(1));
    await fixture.controllerB.synchronize(
      session: fixture.sessionB,
      dataKey: fixture.keyB,
    );
    await fixture.controllerA.synchronize(
      session: fixture.sessionA,
      dataKey: fixture.keyA,
    );
    await fixture.controllerA.synchronize(
      session: fixture.sessionA,
      dataKey: fixture.keyA,
    );
    await fixture.controllerB.synchronize(
      session: fixture.sessionB,
      dataKey: fixture.keyB,
    );

    final desktop = fixture.storeA.upsert(
      SyncObjectKind.subscription,
      base.objectId,
    );
    final phone = fixture.storeB.upsert(
      SyncObjectKind.subscription,
      base.objectId,
    );
    expect(desktop.fields['title'], 'Desktop title');
    expect(desktop.fields['enabled'], isTrue);
    expect(phone.fields, desktop.fields);
    expect(phone.fieldVersions, desktop.fieldVersions);
    expect(fixture.storeA.outbox, isEmpty);
    expect(fixture.storeB.outbox, isEmpty);
  });

  test('random disjoint offline edits converge after bounded paging', () async {
    final fixture = _Fixture(batchSize: 7);
    final random = Random(20260727);
    const mutationCount = 72;
    for (var index = 0; index < mutationCount; index += 1) {
      final useA = random.nextBool();
      final controller = useA ? fixture.controllerA : fixture.controllerB;
      await controller.queueUpsert(
        session: useA ? fixture.sessionA : fixture.sessionB,
        dataKey: useA ? fixture.keyA : fixture.keyB,
        payload: _payloadFor(index),
      );
      if (index % 11 == 0) {
        fixture.server.offline = true;
        final failed = await controller.synchronize(
          session: useA ? fixture.sessionA : fixture.sessionB,
          dataKey: useA ? fixture.keyA : fixture.keyB,
        );
        expect(failed, isA<IncrementalSyncFailure>());
        fixture.server.offline = false;
      }
    }

    await fixture.controllerA.synchronize(
      session: fixture.sessionA,
      dataKey: fixture.keyA,
    );
    await fixture.controllerB.synchronize(
      session: fixture.sessionB,
      dataKey: fixture.keyB,
    );
    await fixture.controllerA.synchronize(
      session: fixture.sessionA,
      dataKey: fixture.keyA,
    );

    expect(fixture.storeA.records, hasLength(mutationCount));
    expect(fixture.storeB.records, hasLength(mutationCount));
    expect(fixture.storeA.conflicts, isEmpty);
    expect(fixture.storeB.conflicts, isEmpty);
    for (var index = 0; index < mutationCount; index += 1) {
      final payload = _payloadFor(index);
      expect(
        fixture.storeA.upsert(payload.objectKind, payload.objectId).fields,
        fixture.storeB.upsert(payload.objectKind, payload.objectId).fields,
      );
    }
    expect(fixture.server.envelopes, hasLength(mutationCount));
  });
}

final class _Fixture {
  _Fixture({int batchSize = SyncProtocol.maximumBatchItems})
      : storeA = _MemoryStore(),
        storeB = _MemoryStore(),
        server = _MemoryServer(),
        clock = _Clock(),
        keyA = _key(),
        keyB = _key(),
        cryptoA = SyncCryptoEngine(
          random: DartSyncCryptoRandomSource(Random(1)),
        ),
        cryptoB = SyncCryptoEngine(
          random: DartSyncCryptoRandomSource(Random(2)),
        ) {
    sessionA = _session('device-a');
    sessionB = _session('device-b');
    authorizerA = _Authorizer(SyncAuthSuccess<SyncSession>(sessionA));
    authorizerB = _Authorizer(SyncAuthSuccess<SyncSession>(sessionB));
    controllerA = IncrementalSyncController(
      store: storeA,
      transport: server,
      crypto: cryptoA,
      authorizer: authorizerA,
      clock: clock,
      mutationIds: _Ids('a'),
      batchSize: batchSize,
    );
    controllerB = IncrementalSyncController(
      store: storeB,
      transport: server,
      crypto: cryptoB,
      authorizer: authorizerB,
      clock: clock,
      mutationIds: _Ids('b'),
      batchSize: batchSize,
    );
  }

  final _MemoryStore storeA;
  final _MemoryStore storeB;
  final _MemoryServer server;
  final _Clock clock;
  final SyncDataKeyMaterial keyA;
  final SyncDataKeyMaterial keyB;
  final SyncCryptoEngine cryptoA;
  final SyncCryptoEngine cryptoB;
  late final SyncSession sessionA;
  late final SyncSession sessionB;
  late final _Authorizer authorizerA;
  late final _Authorizer authorizerB;
  late final IncrementalSyncController controllerA;
  late final IncrementalSyncController controllerB;

  Future<void> syncBoth() async {
    await controllerA.synchronize(session: sessionA, dataKey: keyA);
    await controllerB.synchronize(session: sessionB, dataKey: keyB);
  }
}

final class _MemoryStore implements SyncReplicaStore {
  SyncCursor cursor = SyncCursor.initial();
  final Map<String, SyncReplicaRecord> records = <String, SyncReplicaRecord>{};
  final List<EncryptedSyncEnvelope> outbox = <EncryptedSyncEnvelope>[];
  final List<SyncReplicaRecord> conflicts = <SyncReplicaRecord>[];
  final Map<String, EncryptedSyncEnvelope> seen =
      <String, EncryptedSyncEnvelope>{};
  bool failNextRemoteCommit = false;

  @override
  Future<void> acknowledgeOutbox(Set<String> mutationIds) async {
    outbox.removeWhere((item) => mutationIds.contains(item.mutationId));
  }

  @override
  Future<void> commitLocal(SyncReplicaRecord record) async {
    records[_keyFor(record.envelope.objectKind, record.envelope.objectId)] =
        record;
    outbox.add(record.envelope);
    seen[record.envelope.mutationId] = record.envelope;
  }

  @override
  Future<void> commitRemotePage({
    required SyncCursor expectedCursor,
    required SyncCursor nextCursor,
    required List<SyncIncomingRecord> records,
  }) async {
    if (failNextRemoteCommit) {
      failNextRemoteCommit = false;
      throw StateError('simulated transaction failure');
    }
    if (!_sameCursor(cursor, expectedCursor)) {
      throw StateError('cursor compare-and-swap failed');
    }
    for (final incoming in records) {
      seen[incoming.record.envelope.mutationId] = incoming.record.envelope;
      switch (incoming.action) {
        case SyncIncomingAction.accept:
          this.records[_keyFor(
            incoming.record.envelope.objectKind,
            incoming.record.envelope.objectId,
          )] = incoming.record;
        case SyncIncomingAction.ignore:
          break;
        case SyncIncomingAction.conflict:
          conflicts.add(incoming.record);
        case SyncIncomingAction.resolve:
          conflicts.add(incoming.record);
          final resolved = incoming.resolvedRecord!;
          this.records[_keyFor(
            resolved.envelope.objectKind,
            resolved.envelope.objectId,
          )] = resolved;
          if (incoming.uploadResolution) {
            outbox.add(resolved.envelope);
            seen[resolved.envelope.mutationId] = resolved.envelope;
          }
      }
    }
    cursor = nextCursor;
  }

  @override
  Future<List<EncryptedSyncEnvelope>> readOutbox({
    required int limit,
  }) async =>
      List<EncryptedSyncEnvelope>.unmodifiable(outbox.take(limit));

  @override
  Future<SyncCursor> readCursor() async => cursor;

  @override
  Future<SyncReplicaRecord?> readRecord(
    SyncObjectKind objectKind,
    String objectId,
  ) async =>
      records[_keyFor(objectKind, objectId)];

  @override
  Future<EncryptedSyncEnvelope?> readSeenMutation(String mutationId) async =>
      seen[mutationId];

  SyncReplicaRecord record(SyncObjectKind kind, String id) =>
      records[_keyFor(kind, id)]!;

  SyncObjectPayload upsert(SyncObjectKind kind, String id) =>
      (record(kind, id).decodedPayload as DecodedSyncUpsert).payload;
}

final class _MemoryServer implements IncrementalSyncTransport {
  final List<EncryptedSyncEnvelope> envelopes = <EncryptedSyncEnvelope>[];
  final Set<String> _mutationIds = <String>{};
  final List<int> requestedSequences = <int>[];
  bool offline = false;
  bool returnPartialReceipt = false;
  bool returnNonAdvancingPage = false;
  int pullCalls = 0;

  void seed(EncryptedSyncEnvelope envelope) {
    if (_mutationIds.add(envelope.mutationId)) envelopes.add(envelope);
  }

  void forceAppend(EncryptedSyncEnvelope envelope) {
    envelopes.add(envelope);
  }

  @override
  Future<SyncPullPage> pull({
    required SyncSession session,
    required SyncPullRequest request,
  }) async {
    _checkOnline();
    pullCalls += 1;
    requestedSequences.add(request.cursor.serverSequence);
    if (request.accountId != session.accountId ||
        request.deviceId != session.deviceId) {
      throw const SyncTransportException(
        code: SyncTransportFailureCode.unauthorized,
      );
    }
    final start = request.cursor.serverSequence;
    final selected = envelopes.skip(start).take(request.limit).toList();
    final nextSequence = start + selected.length;
    final nextCursor = selected.isEmpty || returnNonAdvancingPage
        ? request.cursor
        : SyncCursor(
            serverSequence: nextSequence,
            opaqueToken: 'cursor-$nextSequence',
          );
    return SyncPullPage(
      previousCursor: request.cursor,
      nextCursor: nextCursor,
      envelopes: selected,
      hasMore: nextSequence < envelopes.length,
    );
  }

  @override
  Future<SyncPushReceipt> push({
    required SyncSession session,
    required SyncPushBatch batch,
  }) async {
    _checkOnline();
    if (batch.accountId != session.accountId ||
        batch.deviceId != session.deviceId) {
      throw const SyncTransportException(
        code: SyncTransportFailureCode.unauthorized,
      );
    }
    for (final envelope in batch.envelopes) {
      seed(envelope);
    }
    final accepted = batch.envelopes.map((item) => item.mutationId).toSet();
    if (returnPartialReceipt && accepted.isNotEmpty)
      accepted.remove(accepted.first);
    return SyncPushReceipt(acceptedMutationIds: accepted);
  }

  void _checkOnline() {
    if (offline) {
      throw const SyncTransportException(
        code: SyncTransportFailureCode.offline,
      );
    }
  }
}

final class _Clock implements IncrementalSyncClock {
  DateTime value = DateTime.utc(2026, 7, 27);

  @override
  DateTime now() {
    final current = value;
    value = value.add(const Duration(seconds: 1));
    return current;
  }
}

final class _Ids implements SyncMutationIdSource {
  _Ids(this.prefix);

  final String prefix;
  var next = 0;

  @override
  String nextId() => 'mutation-$prefix-${next += 1}';
}

final class _Authorizer implements SyncAuthorizer {
  _Authorizer(this.result);

  SyncAuthResult<SyncSession> result;

  @override
  Future<SyncAuthResult<SyncSession>> authorizeSync() async => result;
}

SyncSession _session(String deviceId) => SyncSession(
      id: 'session-$deviceId',
      accountId: 'account-1',
      deviceId: deviceId,
      accessToken: OpaqueSyncToken('access-$deviceId'),
      refreshToken: OpaqueSyncToken('refresh-$deviceId'),
      issuedAt: DateTime.utc(2026, 7, 27),
      expiresAt: DateTime.utc(2027),
      deviceStatus: SyncDeviceStatus.active,
    );

SyncDataKeyMaterial _key() => SyncDataKeyMaterial(
      descriptor: SyncDataKeyDescriptor(
        id: 'data-key-1',
        accountId: 'account-1',
        version: 1,
        createdAt: DateTime.utc(2026, 7, 27),
      ),
      keyBytes: List<int>.generate(32, (index) => index + 1),
    );

SyncObjectPayload _payloadFor(int index) {
  final kindIndex = index % SyncObjectKind.values.length;
  return switch (SyncObjectKind.values[kindIndex]) {
    SyncObjectKind.subscription => SyncObjectPayload.subscription(
        objectId: 'subscription-$index',
        canonicalUrl: 'https://example.com/feed/$index.xml',
        title: 'Subscription $index',
        folderId: index.isEven ? 'folder-shared' : null,
        enabled: index % 3 != 0,
      ),
    SyncObjectKind.folder => SyncObjectPayload.folder(
        objectId: 'folder-$index',
        name: 'Folder $index',
        position: index,
      ),
    SyncObjectKind.articleState => SyncObjectPayload.articleState(
        objectId: 'article-$index',
        read: index.isEven,
        starred: index % 3 == 0,
        readLater: index % 5 == 0,
        activeReadSeconds: index * 2,
        scrollDepth: (index % 10) / 10,
      ),
    SyncObjectKind.readerSettings => SyncObjectPayload.readerSettings(
        objectId: 'reader-settings-$index',
        fontFamily: index.isEven ? 'system' : 'serif',
        fontScale: 1,
        lineHeight: 1.75,
        contentWidth: 760,
        theme: 'system',
      ),
    SyncObjectKind.audioProgress => SyncObjectPayload.audioProgress(
        objectId: 'audio-$index',
        itemKind: index.isEven ? 'articleTts' : 'podcast',
        positionMs: index * 1000,
        contentRevision: 'revision-$index',
      ),
    SyncObjectKind.knowledgeMetadata => SyncObjectPayload.knowledgeMetadata(
        objectId: 'knowledge-$index',
        title: 'Knowledge $index',
        originalUrl: 'https://example.com/article/$index',
        contentHash: 'hash-$index',
        tags: <String>['tag-${index % 4}'],
        externalMappings: <String, String>{'notion': 'page-$index'},
      ),
  };
}

String _keyFor(SyncObjectKind kind, String id) => '${kind.name}:$id';

bool _sameCursor(SyncCursor left, SyncCursor right) =>
    left.protocolVersion == right.protocolVersion &&
    left.serverSequence == right.serverSequence &&
    left.opaqueToken == right.opaqueToken;
