import 'dart:convert';

import 'package:river_sync/river_sync.dart';
import 'package:test/test.dart';

void main() {
  test('causal versions always beat older versions', () {
    final local = _envelope(
      mutationId: 'local',
      vector: <String, int>{'device-a': 2},
    );
    final remote = _envelope(
      mutationId: 'remote',
      deviceId: 'device-b',
      vector: <String, int>{'device-a': 2, 'device-b': 1},
    );

    final conflict = classifyEnvelopeConflict(local: local, remote: remote);

    expect(conflict.relation, VersionVectorRelation.dominatedBy);
    expect(conflict.decision, SyncEnvelopeDecision.acceptRemote);
    expect(conflict.winner?.mutationId, 'remote');
  });

  test('concurrent article state requires semantic payload merge', () {
    final local = _envelope(
      mutationId: 'local',
      vector: <String, int>{'device-a': 2},
    );
    final remote = _envelope(
      mutationId: 'remote',
      deviceId: 'device-b',
      vector: <String, int>{'device-b': 3},
    );

    final conflict = classifyEnvelopeConflict(local: local, remote: remote);

    expect(conflict.relation, VersionVectorRelation.concurrent);
    expect(conflict.decision, SyncEnvelopeDecision.mergeConcurrentPayloads);
    expect(conflict.winner, isNull);
    expect(
      conflict.rule.concurrentUpdates,
      ConcurrentUpdatePolicy.semanticArticleStateMerge,
    );
  });

  test('subscription tombstone wins a concurrent update', () {
    final update = _envelope(
      mutationId: 'update',
      objectKind: SyncObjectKind.subscription,
      vector: <String, int>{'device-a': 2},
    );
    final deletion = _envelope(
      mutationId: 'delete',
      objectKind: SyncObjectKind.subscription,
      payloadKind: SyncPayloadKind.tombstone,
      deviceId: 'device-b',
      vector: <String, int>{'device-b': 3},
    );

    final conflict = classifyEnvelopeConflict(local: update, remote: deletion);

    expect(conflict.decision, SyncEnvelopeDecision.keepTombstone);
    expect(conflict.winner?.mutationId, 'delete');
  });

  test('article state update wins a concurrent cleanup tombstone', () {
    final deletion = _envelope(
      mutationId: 'cleanup',
      payloadKind: SyncPayloadKind.tombstone,
      vector: <String, int>{'device-a': 2},
    );
    final update = _envelope(
      mutationId: 'read',
      deviceId: 'device-b',
      vector: <String, int>{'device-b': 3},
    );

    final conflict = classifyEnvelopeConflict(local: deletion, remote: update);

    expect(conflict.decision, SyncEnvelopeDecision.acceptRemote);
  });

  test('equal clocks resolve deterministically without argument-order bias',
      () {
    final earlier = _envelope(
      mutationId: 'mutation-a',
      vector: <String, int>{'device-a': 2},
    );
    final later = _envelope(
      mutationId: 'mutation-b',
      vector: <String, int>{'device-a': 2},
    );

    expect(deterministicLastWriter(earlier, later).mutationId, 'mutation-b');
    expect(deterministicLastWriter(later, earlier).mutationId, 'mutation-b');
    expect(
      classifyEnvelopeConflict(local: earlier, remote: later).decision,
      SyncEnvelopeDecision.acceptRemote,
    );
  });

  test('different object identities cannot be classified together', () {
    expect(
      () => classifyEnvelopeConflict(
        local: _envelope(
          mutationId: 'a',
          vector: <String, int>{'device-a': 1},
        ),
        remote: _envelope(
          mutationId: 'b',
          objectId: 'another-object',
          vector: <String, int>{'device-a': 2},
        ),
      ),
      throwsArgumentError,
    );
  });
}

EncryptedSyncEnvelope _envelope({
  required String mutationId,
  required Map<String, int> vector,
  String deviceId = 'device-a',
  String objectId = 'object-1',
  SyncObjectKind objectKind = SyncObjectKind.articleState,
  SyncPayloadKind payloadKind = SyncPayloadKind.upsert,
}) =>
    EncryptedSyncEnvelope(
      mutationId: mutationId,
      accountId: 'account-1',
      objectKind: objectKind,
      objectId: objectId,
      payloadKind: payloadKind,
      dataKeyId: 'data-key-1',
      authorDeviceId: deviceId,
      versionVector: VersionVector(vector),
      occurredAt: DateTime.utc(2026, 7, 26, 12),
      nonceBase64: _bytes(12),
      ciphertextBase64: _bytes(32),
      authenticationTagBase64: _bytes(16),
    );

String _bytes(int count) => base64.encode(List<int>.filled(count, 7));
