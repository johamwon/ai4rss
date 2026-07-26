import 'dart:convert';

import 'package:river_sync/river_sync.dart';
import 'package:test/test.dart';

void main() {
  test('account, device and key descriptors contain no secret key material',
      () {
    final account = SyncAccount(
      id: 'account-1',
      createdAt: DateTime.utc(2026, 7, 26),
      currentKeyId: 'data-key-2',
    );
    final device = SyncDevice(
      id: 'device-a',
      accountId: account.id,
      displayName: 'Windows',
      registeredAt: DateTime.utc(2026, 7, 26),
      publicKeyId: 'device-key-a',
      publicKeyBase64: _bytes(32),
    );
    final key = SyncDataKeyDescriptor(
      id: account.currentKeyId,
      accountId: account.id,
      version: 2,
      createdAt: DateTime.utc(2026, 7, 26),
    );
    final wrapped = WrappedSyncDataKey(
      accountId: account.id,
      dataKeyId: key.id,
      recipientDeviceId: device.id,
      senderDeviceId: 'device-b',
      ephemeralPublicKeyBase64: _bytes(32),
      nonceBase64: _bytes(12),
      ciphertextBase64: _filledBytes(32, 99),
      authenticationTagBase64: _bytes(16),
    );

    expect(device.canSync, isTrue);
    expect(device.publicKeyBase64, _bytes(32));
    expect(key.algorithm, SyncDataKeyAlgorithm.aes256Gcm);
    expect(wrapped.associatedData, isNot(contains(wrapped.ciphertextBase64)));
    expect(
      wrapped.associatedData,
      contains('account-1|data-key-2|device-a|device-b'),
    );
  });

  test('revoked devices require a consistent UTC revocation time', () {
    expect(
      () => SyncDevice(
        id: 'device-a',
        accountId: 'account-1',
        displayName: 'Phone',
        registeredAt: DateTime.utc(2026, 7, 26),
        publicKeyId: 'device-key-a',
        publicKeyBase64: _bytes(32),
        status: SyncDeviceStatus.revoked,
      ),
      throwsArgumentError,
    );
    expect(
      () => SyncDevice(
        id: 'device-a',
        accountId: 'account-1',
        displayName: 'Phone',
        registeredAt: DateTime.utc(2026, 7, 26),
        publicKeyId: 'device-key-a',
        publicKeyBase64: _bytes(32),
        status: SyncDeviceStatus.revoked,
        revokedAt: DateTime(2026, 7, 27),
      ),
      throwsArgumentError,
    );
  });

  test('encrypted envelope binds routing metadata as associated data', () {
    final envelope = _envelope();

    expect(
      envelope.associatedData,
      'river-sync-v1|account-1|articleState|article-1|upsert|data-key-1|'
      'device-a|ZGV2aWNlLWE:1|2026-07-26T12:00:00.000Z|mutation-1',
    );
    expect(envelope.associatedData, isNot(contains(envelope.ciphertextBase64)));
    expect(envelope.estimatedEncodedBytes, lessThan(1024));
  });

  test('envelope rejects invalid crypto shape and absent author counter', () {
    expect(
      () => _envelope(
        nonceBase64: _bytes(11),
      ),
      throwsArgumentError,
    );
    expect(
      () => _envelope(
        versionVector: VersionVector(<String, int>{'device-b': 1}),
      ),
      throwsArgumentError,
    );
    expect(
      () => _envelope(protocolVersion: 99),
      throwsArgumentError,
    );
  });

  test('push batches are scoped, deduplicated and bounded', () {
    final envelope = _envelope();
    final batch = SyncPushBatch(
      accountId: 'account-1',
      deviceId: 'device-a',
      baseCursor: SyncCursor.initial(),
      envelopes: <EncryptedSyncEnvelope>[envelope],
    );

    expect(batch.envelopes, hasLength(1));
    expect(
      () => SyncPushBatch(
        accountId: 'account-1',
        deviceId: 'device-a',
        baseCursor: SyncCursor.initial(),
        envelopes: <EncryptedSyncEnvelope>[envelope, envelope],
      ),
      throwsArgumentError,
    );
    expect(
      () => SyncPushBatch(
        accountId: 'another-account',
        deviceId: 'device-a',
        baseCursor: SyncCursor.initial(),
        envelopes: <EncryptedSyncEnvelope>[envelope],
      ),
      throwsArgumentError,
    );
  });

  test('pull cursors advance monotonically', () {
    final initial = SyncCursor.initial();
    final next = SyncCursor(serverSequence: 4, opaqueToken: 'cursor-4');

    expect(initial.canAdvanceTo(next), isTrue);
    expect(next.canAdvanceTo(initial), isFalse);
    expect(
      () => SyncPullPage(
        previousCursor: next,
        nextCursor: initial,
        envelopes: const <EncryptedSyncEnvelope>[],
        hasMore: false,
      ),
      throwsArgumentError,
    );
  });

  test('tombstone carries a causal delete clock', () {
    final tombstone = SyncTombstone(
      objectKind: SyncObjectKind.subscription,
      objectId: 'subscription-1',
      deletedAt: DateTime.utc(2026, 7, 26),
      deletedByDeviceId: 'device-a',
      versionVector: VersionVector(<String, int>{'device-a': 3}),
    );

    expect(tombstone.versionVector.counterFor('device-a'), 3);
  });
}

EncryptedSyncEnvelope _envelope({
  int protocolVersion = SyncProtocol.currentVersion,
  String mutationId = 'mutation-1',
  SyncPayloadKind payloadKind = SyncPayloadKind.upsert,
  VersionVector? versionVector,
  String? nonceBase64,
}) =>
    EncryptedSyncEnvelope(
      protocolVersion: protocolVersion,
      mutationId: mutationId,
      accountId: 'account-1',
      objectKind: SyncObjectKind.articleState,
      objectId: 'article-1',
      payloadKind: payloadKind,
      dataKeyId: 'data-key-1',
      authorDeviceId: 'device-a',
      versionVector:
          versionVector ?? VersionVector(<String, int>{'device-a': 1}),
      occurredAt: DateTime.utc(2026, 7, 26, 12),
      nonceBase64: nonceBase64 ?? _bytes(12),
      ciphertextBase64: _bytes(48),
      authenticationTagBase64: _bytes(16),
    );

String _bytes(int count) =>
    base64.encode(List<int>.generate(count, (index) => index % 251));

String _filledBytes(int count, int value) =>
    base64.encode(List<int>.filled(count, value));
