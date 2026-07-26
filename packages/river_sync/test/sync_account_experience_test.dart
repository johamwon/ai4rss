import 'package:river_sync/river_sync.dart';
import 'package:test/test.dart';

void main() {
  test('load, retry failure, and successful recovery expose stable state',
      () async {
    final session = _session();
    final vault = _Vault()..session = session;
    final status = _Status();
    final retry = _Retry();
    final controller = SyncAccountExperienceController(
      auth: _auth(vault),
      status: status,
      retry: retry,
    );
    addTearDown(controller.dispose);

    await controller.load();
    expect(controller.state.phase, SyncAccountPhase.ready);
    expect(controller.state.storage?.pendingMutations, 2);

    retry.result = const IncrementalSyncFailure(
      code: IncrementalSyncFailureCode.offline,
      retryable: true,
      pushed: 0,
      pulled: 0,
    );
    await controller.retryNow();
    expect(controller.state.phase, SyncAccountPhase.retryableFailure);
    expect(controller.state.canRetry, isTrue);

    status.pending = 0;
    retry.result = IncrementalSyncSuccess(
      pushed: 2,
      pulled: 1,
      applied: 1,
      conflicts: 0,
      hasMoreWork: false,
      cursor: SyncCursor(serverSequence: 4, opaqueToken: 'cursor-4'),
    );
    await controller.retryNow();
    expect(controller.state.phase, SyncAccountPhase.ready);
    expect(controller.state.storage?.pendingMutations, 0);
  });

  test('sign out changes account state without touching local status',
      () async {
    final vault = _Vault()..session = _session();
    final status = _Status();
    final controller = SyncAccountExperienceController(
      auth: _auth(vault),
      status: status,
      retry: _Retry(),
    );
    addTearDown(controller.dispose);
    await controller.load();

    await controller.signOut();

    expect(controller.state.phase, SyncAccountPhase.signedOut);
    expect(vault.session, isNull);
    expect(status.pending, 2);
  });
}

SyncAuthController _auth(_Vault vault) => SyncAuthController(
      gateway: _Gateway(),
      vault: vault,
      connectivity: const _Connectivity(),
      clock: const _Clock(),
    );

final class _Status implements SyncStatusRepository {
  var pending = 2;

  @override
  Future<List<SyncConflictHistoryEntry>> readConflictHistory({
    int limit = 100,
  }) async =>
      const <SyncConflictHistoryEntry>[];

  @override
  Future<SyncStorageStatus> readStatus() async => SyncStorageStatus(
        pendingMutations: pending,
        unresolvedConflicts: 1,
        serverSequence: 3,
        updatedAt: DateTime.utc(2026, 7, 27),
      );
}

final class _Retry implements SyncRetryRunner {
  IncrementalSyncResult result = IncrementalSyncSuccess(
    pushed: 0,
    pulled: 0,
    applied: 0,
    conflicts: 0,
    hasMoreWork: false,
    cursor: SyncCursor.initial(),
  );

  @override
  Future<IncrementalSyncResult> retry() async => result;
}

final class _Vault implements SyncSessionVault {
  SyncSession? session;

  @override
  Future<void> clear() async => session = null;

  @override
  Future<SyncSession?> read() async => session;

  @override
  Future<void> write(SyncSession session) async => this.session = session;
}

final class _Gateway implements SyncIdentityGateway {
  @override
  Future<SyncAuthResult<DeviceJoinRequest>> approveDeviceJoin({
    required SyncSession session,
    required DeviceJoinRequest joinRequest,
    required WrappedSyncDataKey wrappedDataKey,
  }) async =>
      const SyncAuthFailure<DeviceJoinRequest>(
        code: SyncAuthFailureCode.unavailable,
      );

  @override
  Future<SyncAuthResult<SyncSession>> completePasswordless({
    required String challengeId,
    required PasswordlessProof proof,
    required SyncDeviceRegistration registration,
    required String idempotencyKey,
  }) async =>
      const SyncAuthFailure<SyncSession>(
        code: SyncAuthFailureCode.unavailable,
      );

  @override
  Future<SyncAuthResult<CloudDataDeletionReceipt>> deleteCloudData(
    SyncSession session,
  ) async =>
      SyncAuthSuccess<CloudDataDeletionReceipt>(
        CloudDataDeletionReceipt(
          requestId: 'delete-1',
          accountId: session.accountId,
          completedAt: DateTime.utc(2026, 7, 27),
        ),
      );

  @override
  Future<SyncAuthResult<List<SyncDevice>>> listDevices(
    SyncSession session,
  ) async =>
      const SyncAuthSuccess<List<SyncDevice>>(<SyncDevice>[]);

  @override
  Future<SyncAuthResult<List<DeviceJoinRequest>>> pendingDeviceJoins(
    SyncSession session,
  ) async =>
      const SyncAuthSuccess<List<DeviceJoinRequest>>(<DeviceJoinRequest>[]);

  @override
  Future<SyncAuthResult<SyncSession>> refreshSession(
    SyncSession session,
  ) async =>
      SyncAuthSuccess<SyncSession>(session);

  @override
  Future<SyncAuthResult<DeviceRevocation>> revokeDevice({
    required SyncSession session,
    required String deviceId,
  }) async =>
      const SyncAuthFailure<DeviceRevocation>(
        code: SyncAuthFailureCode.unavailable,
      );

  @override
  Future<SyncAuthResult<PasswordlessChallenge>> startPasswordless(
    PasswordlessEmail email,
  ) async =>
      const SyncAuthFailure<PasswordlessChallenge>(
        code: SyncAuthFailureCode.unavailable,
      );
}

final class _Connectivity implements SyncConnectivity {
  const _Connectivity();

  @override
  Future<bool> isOnline() async => true;
}

final class _Clock implements SyncAuthClock {
  const _Clock();

  @override
  DateTime now() => DateTime.utc(2026, 7, 27);
}

SyncSession _session() => SyncSession(
      id: 'session-1',
      accountId: 'account-1',
      deviceId: 'device-a',
      accessToken: OpaqueSyncToken('access'),
      refreshToken: OpaqueSyncToken('refresh'),
      issuedAt: DateTime.utc(2026, 7, 26),
      expiresAt: DateTime.utc(2026, 7, 28),
      deviceStatus: SyncDeviceStatus.active,
    );
