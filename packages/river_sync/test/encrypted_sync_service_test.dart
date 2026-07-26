import 'dart:convert';

import 'package:river_sync/river_sync.dart';
import 'package:test/test.dart';

void main() {
  test('active devices exchange only their account ciphertext', () async {
    final fixture = _Fixture();
    final first = _envelope('account-1', 'device-a', 'mutation-a-1', 1);
    final other = _envelope('account-2', 'device-z', 'mutation-z-1', 1);
    await fixture.service.push(
      principal: _principal('account-1', 'device-a'),
      batch: _batch(first),
    );
    await fixture.service.push(
      principal: _principal('account-2', 'device-z'),
      batch: _batch(other),
    );

    final page = await fixture.service.pull(
      principal: _principal('account-1', 'device-b'),
      request: SyncPullRequest(
        accountId: 'account-1',
        deviceId: 'device-b',
        cursor: SyncCursor.initial(),
      ),
    );
    final metrics = await fixture.service.readAdminMetrics('account-1');

    expect(page.envelopes.map((item) => item.mutationId), <String>[
      'mutation-a-1',
    ]);
    expect(page.envelopes.single.ciphertextBase64, first.ciphertextBase64);
    expect(metrics.storedMutations, 1);
    expect(metrics.latestSequence, 1);
    expect(fixture.audit.events, hasLength(3));
    expect(
      fixture.audit.events.every((event) => event.itemCount >= 0),
      isTrue,
    );
  });

  test('revoked devices and cross-account principals fail closed', () async {
    final fixture = _Fixture();
    final envelope = _envelope(
      'account-1',
      'device-a',
      'mutation-a-1',
      1,
    );

    await expectLater(
      fixture.service.push(
        principal: _principal(
          'account-1',
          'device-a',
          status: SyncDeviceStatus.revoked,
        ),
        batch: _batch(envelope),
      ),
      _failure(EncryptedSyncServiceFailureCode.unauthorized),
    );
    await expectLater(
      fixture.service.push(
        principal: _principal('account-2', 'device-a'),
        batch: _batch(envelope),
      ),
      _failure(EncryptedSyncServiceFailureCode.unauthorized),
    );
    expect(
      (await fixture.service.readAdminMetrics('account-1')).storedMutations,
      0,
    );
  });

  test('exact replay is idempotent and mutation collision is rejected',
      () async {
    final fixture = _Fixture();
    final original = _envelope(
      'account-1',
      'device-a',
      'mutation-a-1',
      1,
    );
    final altered = _envelope(
      'account-1',
      'device-a',
      'mutation-a-1',
      2,
    );
    final principal = _principal('account-1', 'device-a');
    await fixture.service.push(
      principal: principal,
      batch: _batch(original),
    );

    final replay = await fixture.service.push(
      principal: principal,
      batch: _batch(original),
    );
    await expectLater(
      fixture.service.push(
        principal: principal,
        batch: _batch(altered),
      ),
      _failure(EncryptedSyncServiceFailureCode.mutationCollision),
    );

    expect(replay.acceptedMutationIds, <String>{'mutation-a-1'});
    expect(
      (await fixture.service.readAdminMetrics('account-1')).storedMutations,
      1,
    );
  });

  test('quota rejection is atomic', () async {
    final fixture = _Fixture(
      limits: const EncryptedSyncServiceLimits(
        maximumStoredMutations: 1,
        maximumStoredBytes: 1024 * 1024,
      ),
    );
    final first = _envelope('account-1', 'device-a', 'mutation-a-1', 1);
    final second = _envelope('account-1', 'device-a', 'mutation-a-2', 2);

    await expectLater(
      fixture.service.push(
        principal: _principal('account-1', 'device-a'),
        batch: SyncPushBatch(
          accountId: 'account-1',
          deviceId: 'device-a',
          baseCursor: SyncCursor.initial(),
          envelopes: <EncryptedSyncEnvelope>[first, second],
        ),
      ),
      _failure(EncryptedSyncServiceFailureCode.quotaExceeded),
    );

    expect(
      (await fixture.service.readAdminMetrics('account-1')).storedMutations,
      0,
    );
    expect(
      fixture.audit.events.last.outcome,
      SyncServiceAuditOutcome.quotaRejected,
    );
  });

  test('per-device rate limit resets after its UTC window', () async {
    final fixture = _Fixture(
      limits: const EncryptedSyncServiceLimits(
        maximumRequestsPerWindow: 1,
        rateLimitWindow: Duration(minutes: 1),
      ),
    );
    final principal = _principal('account-1', 'device-a');
    final request = SyncPullRequest(
      accountId: 'account-1',
      deviceId: 'device-a',
      cursor: SyncCursor.initial(),
    );
    await fixture.service.pull(principal: principal, request: request);

    await expectLater(
      fixture.service.pull(principal: principal, request: request),
      throwsA(
        isA<EncryptedSyncServiceException>()
            .having(
              (error) => error.code,
              'code',
              EncryptedSyncServiceFailureCode.rateLimited,
            )
            .having((error) => error.retryAfter, 'retryAfter', isNotNull),
      ),
    );
    fixture.clock.value = fixture.clock.value.add(const Duration(minutes: 1));
    final recovered = await fixture.service.pull(
      principal: principal,
      request: request,
    );
    expect(recovered.envelopes, isEmpty);
  });

  test('backup, deletion, and restore preserve ciphertext and sequence',
      () async {
    final fixture = _Fixture();
    final principal = _principal('account-1', 'device-a');
    final records = <EncryptedSyncEnvelope>[
      _envelope('account-1', 'device-a', 'mutation-a-1', 1),
      _envelope('account-1', 'device-a', 'mutation-a-2', 2),
    ];
    await fixture.service.push(
      principal: principal,
      batch: SyncPushBatch(
        accountId: 'account-1',
        deviceId: 'device-a',
        baseCursor: SyncCursor.initial(),
        envelopes: records,
      ),
    );
    final backup = await fixture.service.createBackup('account-1');
    final drill = await fixture.service.verifyBackup(backup);
    expect(drill.restoredMutations, 2);
    expect(drill.latestSequence, 2);
    expect(drill.restoredBytes, greaterThan(0));

    final receipt = await fixture.service.deleteCloudData(
      principal: principal,
      requestId: 'delete-1',
    );
    expect(receipt.accountId, 'account-1');
    expect(
      (await fixture.service.readAdminMetrics('account-1')).storedMutations,
      0,
    );

    await fixture.service.restoreBackup(backup);
    final restored = await fixture.service.pull(
      principal: _principal('account-1', 'device-b'),
      request: SyncPullRequest(
        accountId: 'account-1',
        deviceId: 'device-b',
        cursor: SyncCursor.initial(),
      ),
    );
    expect(
      restored.envelopes.map(SyncWireCodec.encodeEnvelope),
      backup.envelopeJson,
    );
    expect(restored.nextCursor.serverSequence, 2);
  });

  test('corrupt backup cannot replace a healthy target', () async {
    final fixture = _Fixture();
    final original = _envelope(
      'account-1',
      'device-a',
      'mutation-a-1',
      1,
    );
    await fixture.service.push(
      principal: _principal('account-1', 'device-a'),
      batch: _batch(original),
    );
    final backup = await fixture.service.createBackup('account-1');
    final corrupt = EncryptedSyncBackup(
      accountId: backup.accountId,
      createdAt: backup.createdAt,
      envelopeJson: <String>[...backup.envelopeJson, '{}'],
      checksumBase64: backup.checksumBase64,
    );

    await expectLater(
      fixture.service.restoreBackup(corrupt, allowReplace: true),
      _failure(EncryptedSyncServiceFailureCode.backupCorrupt),
    );

    final page = await fixture.service.pull(
      principal: _principal('account-1', 'device-b'),
      request: SyncPullRequest(
        accountId: 'account-1',
        deviceId: 'device-b',
        cursor: SyncCursor.initial(),
      ),
    );
    expect(page.envelopes.single.mutationId, original.mutationId);
  });
}

final class _Fixture {
  _Fixture({
    EncryptedSyncServiceLimits limits = const EncryptedSyncServiceLimits(),
  })  : clock = _Clock(),
        audit = _Audit() {
    service = EncryptedSyncService(
      storage: InMemoryEncryptedSyncStorage(),
      clock: clock,
      audit: audit,
      limits: limits,
    );
  }

  final _Clock clock;
  final _Audit audit;
  late final EncryptedSyncService service;
}

final class _Clock implements SyncServiceClock {
  DateTime value = DateTime.utc(2026, 7, 27);

  @override
  DateTime now() => value;
}

final class _Audit implements SyncServiceAuditSink {
  final List<SyncServiceAuditEvent> events = <SyncServiceAuditEvent>[];

  @override
  void record(SyncServiceAuditEvent event) => events.add(event);
}

SyncServicePrincipal _principal(
  String accountId,
  String deviceId, {
  SyncDeviceStatus status = SyncDeviceStatus.active,
}) =>
    SyncServicePrincipal(
      accountId: accountId,
      deviceId: deviceId,
      deviceStatus: status,
    );

SyncPushBatch _batch(EncryptedSyncEnvelope envelope) => SyncPushBatch(
      accountId: envelope.accountId,
      deviceId: envelope.authorDeviceId,
      baseCursor: SyncCursor.initial(),
      envelopes: <EncryptedSyncEnvelope>[envelope],
    );

EncryptedSyncEnvelope _envelope(
  String accountId,
  String deviceId,
  String mutationId,
  int counter,
) =>
    EncryptedSyncEnvelope(
      mutationId: mutationId,
      accountId: accountId,
      objectKind: SyncObjectKind.subscription,
      objectId: 'subscription-1',
      payloadKind: SyncPayloadKind.upsert,
      dataKeyId: 'data-key-1',
      authorDeviceId: deviceId,
      versionVector: VersionVector(<String, int>{deviceId: counter}),
      occurredAt: DateTime.utc(2026, 7, 27, 0, counter),
      nonceBase64: _bytes(12, counter),
      ciphertextBase64: _bytes(48, counter + 1),
      authenticationTagBase64: _bytes(16, counter + 2),
    );

Matcher _failure(EncryptedSyncServiceFailureCode code) => throwsA(
      isA<EncryptedSyncServiceException>().having(
        (error) => error.code,
        'code',
        code,
      ),
    );

String _bytes(int count, int seed) =>
    base64.encode(List<int>.generate(count, (index) => (index + seed) % 251));
