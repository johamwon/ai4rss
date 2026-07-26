import 'dart:convert';

import 'package:river_sync/river_sync.dart';
import 'package:test/test.dart';

void main() {
  late _MutableClock clock;
  late _FakeConnectivity connectivity;
  late _FakeIdentityGateway gateway;

  setUp(() {
    clock = _MutableClock(DateTime.utc(2026, 7, 27, 1));
    connectivity = _FakeConnectivity();
    gateway = _FakeIdentityGateway(clock);
  });

  test('passwordless first-device login saves a redacted active session',
      () async {
    final vault = _MemorySessionVault();
    final controller = _controller(
      gateway: gateway,
      vault: vault,
      connectivity: connectivity,
      clock: clock,
    );
    final email = PasswordlessEmail('Reader@Example.COM');
    final challengeResult = await controller.startPasswordless(email);
    final challenge =
        (challengeResult as SyncAuthSuccess<PasswordlessChallenge>).value;

    final result = await controller.completePasswordless(
      challenge: challenge,
      proof: PasswordlessProof('proof-1'),
      registration: _registration('device-a', 'Windows'),
      idempotencyKey: 'login-attempt-1',
    );

    final session = (result as SyncAuthSuccess<SyncSession>).value;
    expect(session.deviceStatus, SyncDeviceStatus.active);
    expect(vault.session?.deviceId, 'device-a');
    expect(email.value, 'Reader@example.com');
    expect(email.toString(), isNot(contains('Reader')));
    expect(session.toString(), isNot(contains('access-')));
    expect(session.toString(), isNot(contains('refresh-')));
  });

  test('repeated completion with one idempotency key reuses one device',
      () async {
    final firstVault = _MemorySessionVault();
    final secondVault = _MemorySessionVault();
    final challenge = await _challenge(gateway);
    final registration = _registration('device-a', 'Windows');

    final first = await _controller(
      gateway: gateway,
      vault: firstVault,
      connectivity: connectivity,
      clock: clock,
    ).completePasswordless(
      challenge: challenge,
      proof: PasswordlessProof('proof-1'),
      registration: registration,
      idempotencyKey: 'same-attempt',
    );
    final second = await _controller(
      gateway: gateway,
      vault: secondVault,
      connectivity: connectivity,
      clock: clock,
    ).completePasswordless(
      challenge: challenge,
      proof: PasswordlessProof('proof-1'),
      registration: registration,
      idempotencyKey: 'same-attempt',
    );

    expect(
      (first as SyncAuthSuccess<SyncSession>).value.deviceId,
      (second as SyncAuthSuccess<SyncSession>).value.deviceId,
    );
    expect(gateway.registrationWrites, 1);
    expect(gateway.devices, hasLength(1));
  });

  test('expired passwordless challenge never reaches the gateway', () async {
    final challenge = await _challenge(gateway);
    clock.value = challenge.expiresAt;
    final controller = _controller(
      gateway: gateway,
      vault: _MemorySessionVault(),
      connectivity: connectivity,
      clock: clock,
    );

    final result = await controller.completePasswordless(
      challenge: challenge,
      proof: PasswordlessProof('proof-1'),
      registration: _registration('device-a', 'Windows'),
      idempotencyKey: 'expired-attempt',
    );

    expect(
      (result as SyncAuthFailure).code,
      SyncAuthFailureCode.challengeExpired,
    );
    expect(gateway.registrationWrites, 0);
  });

  test('offline login and refresh never call the gateway or erase session',
      () async {
    connectivity.online = false;
    final existing = gateway.seedActiveDevice('device-a', 'Windows');
    final vault = _MemorySessionVault()..session = existing;
    final controller = _controller(
      gateway: gateway,
      vault: vault,
      connectivity: connectivity,
      clock: clock,
    );

    final start = await controller.startPasswordless(
      PasswordlessEmail('reader@example.com'),
    );
    final authorization = await controller.authorizeSync();

    expect((start as SyncAuthFailure).code, SyncAuthFailureCode.offline);
    expect(
      (authorization as SyncAuthFailure).code,
      SyncAuthFailureCode.offline,
    );
    expect(gateway.refreshCalls, 0);
    expect(vault.session, same(existing));
  });

  test('expired local session is reported and refreshed when online', () async {
    final expired = gateway.seedActiveDevice(
      'device-a',
      'Windows',
      expiresAt: clock.now().subtract(const Duration(minutes: 1)),
    );
    final vault = _MemorySessionVault()..session = expired;
    final controller = _controller(
      gateway: gateway,
      vault: vault,
      connectivity: connectivity,
      clock: clock,
    );

    final local = await controller.restoreLocalSession();
    final refreshed = await controller.authorizeSync();

    expect(
      (local as SyncAuthFailure).code,
      SyncAuthFailureCode.sessionExpired,
    );
    final session = (refreshed as SyncAuthSuccess<SyncSession>).value;
    expect(session.expiresAt, clock.now().add(const Duration(hours: 1)));
    expect(vault.session, same(session));
  });

  test('server-expired session is cleared without touching remote devices',
      () async {
    final session = gateway.seedActiveDevice('device-a', 'Windows');
    gateway.refreshFailure = SyncAuthFailureCode.sessionExpired;
    final vault = _MemorySessionVault()..session = session;
    final controller = _controller(
      gateway: gateway,
      vault: vault,
      connectivity: connectivity,
      clock: clock,
    );

    final result = await controller.authorizeSync();

    expect(
      (result as SyncAuthFailure).code,
      SyncAuthFailureCode.sessionExpired,
    );
    expect(vault.session, isNull);
    expect(gateway.devices, hasLength(1));
  });

  test('a second device remains blocked until an active device approves it',
      () async {
    final firstVault = _MemorySessionVault();
    final firstSession = gateway.seedActiveDevice('device-a', 'Windows');
    firstVault.session = firstSession;
    final secondVault = _MemorySessionVault();
    final challenge = await _challenge(gateway);
    final secondController = _controller(
      gateway: gateway,
      vault: secondVault,
      connectivity: connectivity,
      clock: clock,
    );
    final login = await secondController.completePasswordless(
      challenge: challenge,
      proof: PasswordlessProof('proof-2'),
      registration: _registration('device-b', 'Phone'),
      idempotencyKey: 'phone-login',
    );
    expect(
      (login as SyncAuthSuccess<SyncSession>).value.deviceStatus,
      SyncDeviceStatus.pendingApproval,
    );

    final blocked = await secondController.authorizeSync();
    expect(
      (blocked as SyncAuthFailure).code,
      SyncAuthFailureCode.devicePendingApproval,
    );

    final firstController = _controller(
      gateway: gateway,
      vault: firstVault,
      connectivity: connectivity,
      clock: clock,
    );
    final joins = (await firstController.pendingDeviceJoins()
            as SyncAuthSuccess<List<DeviceJoinRequest>>)
        .value;
    expect(joins.single.registration.requestedDeviceId, 'device-b');
    final approved = await firstController.approveDeviceJoin(
      joinRequest: joins.single,
      wrappedDataKey: _wrappedKey(
        recipientDeviceId: 'device-b',
        senderDeviceId: 'device-a',
      ),
    );
    expect(
      (approved as SyncAuthSuccess<DeviceJoinRequest>).value.status,
      DeviceJoinStatus.approved,
    );

    final authorized = await secondController.authorizeSync();
    expect(
      (authorized as SyncAuthSuccess<SyncSession>).value.deviceStatus,
      SyncDeviceStatus.active,
    );
  });

  test('revocation requires rotation and revoked device loses its session',
      () async {
    final firstSession = gateway.seedActiveDevice('device-a', 'Windows');
    final secondSession = gateway.seedActiveDevice('device-b', 'Phone');
    final firstVault = _MemorySessionVault()..session = firstSession;
    final secondVault = _MemorySessionVault()..session = secondSession;
    final firstController = _controller(
      gateway: gateway,
      vault: firstVault,
      connectivity: connectivity,
      clock: clock,
    );
    final secondController = _controller(
      gateway: gateway,
      vault: secondVault,
      connectivity: connectivity,
      clock: clock,
    );

    final revoked = await firstController.revokeDevice('device-b');

    final revocation = (revoked as SyncAuthSuccess<DeviceRevocation>).value;
    expect(revocation.requiresDataKeyRotation, isTrue);
    expect(revocation.remainingActiveDevices, 1);
    final denied = await secondController.authorizeSync();
    expect(
      (denied as SyncAuthFailure).code,
      SyncAuthFailureCode.deviceRevoked,
    );
    expect(secondVault.session, isNull);
    expect(firstVault.session, isNotNull);
  });

  test('device approval rejects a wrapped key for another recipient', () async {
    final firstVault = _MemorySessionVault()
      ..session = gateway.seedActiveDevice('device-a', 'Windows');
    final secondController = _controller(
      gateway: gateway,
      vault: _MemorySessionVault(),
      connectivity: connectivity,
      clock: clock,
    );
    final challenge = await _challenge(gateway);
    await secondController.completePasswordless(
      challenge: challenge,
      proof: PasswordlessProof('proof-2'),
      registration: _registration('device-b', 'Phone'),
      idempotencyKey: 'phone-login',
    );
    final firstController = _controller(
      gateway: gateway,
      vault: firstVault,
      connectivity: connectivity,
      clock: clock,
    );
    final join = (await firstController.pendingDeviceJoins()
            as SyncAuthSuccess<List<DeviceJoinRequest>>)
        .value
        .single;

    await expectLater(
      firstController.approveDeviceJoin(
        joinRequest: join,
        wrappedDataKey: _wrappedKey(
          recipientDeviceId: 'device-c',
          senderDeviceId: 'device-a',
        ),
      ),
      throwsArgumentError,
    );
    expect(gateway.approvalCalls, 0);
  });

  test('last active device cannot be revoked', () async {
    final session = gateway.seedActiveDevice('device-a', 'Windows');
    final vault = _MemorySessionVault()..session = session;
    final controller = _controller(
      gateway: gateway,
      vault: vault,
      connectivity: connectivity,
      clock: clock,
    );

    final result = await controller.revokeDevice('device-a');

    expect(
      (result as SyncAuthFailure).code,
      SyncAuthFailureCode.cannotRevokeLastDevice,
    );
    expect(vault.session?.deviceId, session.deviceId);
    expect(vault.session?.deviceStatus, SyncDeviceStatus.active);
  });

  test('sign out clears only secure session state', () async {
    final vault = _MemorySessionVault()
      ..session = gateway.seedActiveDevice('device-a', 'Windows');
    final controller = _controller(
      gateway: gateway,
      vault: vault,
      connectivity: connectivity,
      clock: clock,
    );

    await controller.signOut();

    expect(vault.session, isNull);
    expect(gateway.devices, hasLength(1));
  });

  test('cloud deletion clears session only after scoped remote success',
      () async {
    final vault = _MemorySessionVault()
      ..session = gateway.seedActiveDevice('device-a', 'Windows');
    final controller = _controller(
      gateway: gateway,
      vault: vault,
      connectivity: connectivity,
      clock: clock,
    );
    final localArticles = <String>['article-local'];

    final result = await controller.deleteCloudData();

    expect(result, isA<SyncAuthSuccess<CloudDataDeletionReceipt>>());
    expect(vault.session, isNull);
    expect(gateway.devices, isEmpty);
    expect(localArticles, <String>['article-local']);
  });
}

SyncAuthController _controller({
  required _FakeIdentityGateway gateway,
  required _MemorySessionVault vault,
  required _FakeConnectivity connectivity,
  required _MutableClock clock,
}) =>
    SyncAuthController(
      gateway: gateway,
      vault: vault,
      connectivity: connectivity,
      clock: clock,
    );

Future<PasswordlessChallenge> _challenge(
  _FakeIdentityGateway gateway,
) async =>
    (await gateway.startPasswordless(PasswordlessEmail('reader@example.com'))
            as SyncAuthSuccess<PasswordlessChallenge>)
        .value;

SyncDeviceRegistration _registration(String id, String name) =>
    SyncDeviceRegistration(
      requestedDeviceId: id,
      displayName: name,
      publicKeyId: 'key-$id',
      publicKeyBase64: _bytes(32, 3),
    );

WrappedSyncDataKey _wrappedKey({
  required String recipientDeviceId,
  required String senderDeviceId,
}) =>
    WrappedSyncDataKey(
      accountId: 'account-1',
      dataKeyId: 'data-key-1',
      recipientDeviceId: recipientDeviceId,
      senderDeviceId: senderDeviceId,
      ephemeralPublicKeyBase64: _bytes(32, 4),
      kdfSaltBase64: _bytes(32, 8),
      nonceBase64: _bytes(12, 5),
      ciphertextBase64: _bytes(32, 6),
      authenticationTagBase64: _bytes(16, 7),
    );

String _bytes(int count, int value) =>
    base64.encode(List<int>.filled(count, value));

final class _MutableClock implements SyncAuthClock {
  _MutableClock(this.value);

  DateTime value;

  @override
  DateTime now() => value;
}

final class _FakeConnectivity implements SyncConnectivity {
  var online = true;

  @override
  Future<bool> isOnline() async => online;
}

final class _MemorySessionVault implements SyncSessionVault {
  SyncSession? session;

  @override
  Future<void> clear() async {
    session = null;
  }

  @override
  Future<SyncSession?> read() async => session;

  @override
  Future<void> write(SyncSession session) async {
    this.session = session;
  }
}

final class _FakeIdentityGateway implements SyncIdentityGateway {
  _FakeIdentityGateway(this.clock);

  final _MutableClock clock;
  final Map<String, SyncDevice> devices = <String, SyncDevice>{};
  final Map<String, SyncSession> sessions = <String, SyncSession>{};
  final Map<String, SyncSession> idempotentLogins = <String, SyncSession>{};
  final Map<String, DeviceJoinRequest> joins = <String, DeviceJoinRequest>{};
  var registrationWrites = 0;
  var refreshCalls = 0;
  var approvalCalls = 0;
  var deletionCalls = 0;
  SyncAuthFailureCode? refreshFailure;
  var _challengeSequence = 0;
  var _sessionSequence = 0;
  var _joinSequence = 0;

  SyncSession seedActiveDevice(
    String deviceId,
    String displayName, {
    DateTime? expiresAt,
  }) {
    devices[deviceId] = SyncDevice(
      id: deviceId,
      accountId: 'account-1',
      displayName: displayName,
      registeredAt: clock.now(),
      publicKeyId: 'key-$deviceId',
      publicKeyBase64: _bytes(32, 3),
    );
    final session = _session(
      deviceId,
      status: SyncDeviceStatus.active,
      expiresAt: expiresAt,
    );
    sessions[deviceId] = session;
    return session;
  }

  @override
  Future<SyncAuthResult<PasswordlessChallenge>> startPasswordless(
    PasswordlessEmail email,
  ) async {
    _challengeSequence += 1;
    return SyncAuthSuccess<PasswordlessChallenge>(
      PasswordlessChallenge(
        id: 'challenge-$_challengeSequence',
        deliveryHint: 'r***@example.com',
        requestedAt: clock.now(),
        expiresAt: clock.now().add(const Duration(minutes: 10)),
      ),
    );
  }

  @override
  Future<SyncAuthResult<SyncSession>> completePasswordless({
    required String challengeId,
    required PasswordlessProof proof,
    required SyncDeviceRegistration registration,
    required String idempotencyKey,
  }) async {
    final existing = idempotentLogins[idempotencyKey];
    if (existing != null) return SyncAuthSuccess<SyncSession>(existing);
    registrationWrites += 1;
    final hasActiveDevice = devices.values.any((device) => device.canSync);
    final status = hasActiveDevice
        ? SyncDeviceStatus.pendingApproval
        : SyncDeviceStatus.active;
    devices[registration.requestedDeviceId] = SyncDevice(
      id: registration.requestedDeviceId,
      accountId: 'account-1',
      displayName: registration.displayName,
      registeredAt: clock.now(),
      publicKeyId: registration.publicKeyId,
      publicKeyBase64: registration.publicKeyBase64,
      status: status,
    );
    final session = _session(
      registration.requestedDeviceId,
      status: status,
    );
    sessions[registration.requestedDeviceId] = session;
    idempotentLogins[idempotencyKey] = session;
    if (hasActiveDevice) {
      _joinSequence += 1;
      joins['join-$_joinSequence'] = DeviceJoinRequest(
        id: 'join-$_joinSequence',
        accountId: 'account-1',
        registration: registration,
        requestedAt: clock.now(),
        expiresAt: clock.now().add(const Duration(hours: 24)),
        status: DeviceJoinStatus.pending,
      );
    }
    return SyncAuthSuccess<SyncSession>(session);
  }

  @override
  Future<SyncAuthResult<SyncSession>> refreshSession(
    SyncSession session,
  ) async {
    refreshCalls += 1;
    final configuredFailure = refreshFailure;
    if (configuredFailure != null) {
      return SyncAuthFailure<SyncSession>(code: configuredFailure);
    }
    final device = devices[session.deviceId];
    if (device == null || device.status == SyncDeviceStatus.revoked) {
      return const SyncAuthFailure<SyncSession>(
        code: SyncAuthFailureCode.deviceRevoked,
      );
    }
    if (device.status == SyncDeviceStatus.pendingApproval) {
      return SyncAuthSuccess<SyncSession>(
        _session(
          session.deviceId,
          status: SyncDeviceStatus.pendingApproval,
        ),
      );
    }
    final refreshed = _session(
      session.deviceId,
      status: SyncDeviceStatus.active,
    );
    sessions[session.deviceId] = refreshed;
    return SyncAuthSuccess<SyncSession>(refreshed);
  }

  @override
  Future<SyncAuthResult<List<DeviceJoinRequest>>> pendingDeviceJoins(
    SyncSession session,
  ) async =>
      SyncAuthSuccess<List<DeviceJoinRequest>>(
        joins.values
            .where((join) => join.status == DeviceJoinStatus.pending)
            .toList(growable: false),
      );

  @override
  Future<SyncAuthResult<DeviceJoinRequest>> approveDeviceJoin({
    required SyncSession session,
    required DeviceJoinRequest joinRequest,
    required WrappedSyncDataKey wrappedDataKey,
  }) async {
    approvalCalls += 1;
    final join = joins[joinRequest.id];
    if (join == null || join.status != DeviceJoinStatus.pending) {
      return const SyncAuthFailure<DeviceJoinRequest>(
        code: SyncAuthFailureCode.approvalExpired,
      );
    }
    final deviceId = join.registration.requestedDeviceId;
    devices[deviceId] = SyncDevice(
      id: deviceId,
      accountId: join.accountId,
      displayName: join.registration.displayName,
      registeredAt: join.requestedAt,
      publicKeyId: join.registration.publicKeyId,
      publicKeyBase64: join.registration.publicKeyBase64,
    );
    final approved = DeviceJoinRequest(
      id: join.id,
      accountId: join.accountId,
      registration: join.registration,
      requestedAt: join.requestedAt,
      expiresAt: join.expiresAt,
      status: DeviceJoinStatus.approved,
      approvedByDeviceId: session.deviceId,
    );
    joins[join.id] = approved;
    return SyncAuthSuccess<DeviceJoinRequest>(approved);
  }

  @override
  Future<SyncAuthResult<List<SyncDevice>>> listDevices(
    SyncSession session,
  ) async =>
      SyncAuthSuccess<List<SyncDevice>>(
        devices.values.toList(growable: false),
      );

  @override
  Future<SyncAuthResult<DeviceRevocation>> revokeDevice({
    required SyncSession session,
    required String deviceId,
  }) async {
    final active = devices.values.where((device) => device.canSync).length;
    final target = devices[deviceId];
    if (target == null) {
      return const SyncAuthFailure<DeviceRevocation>(
        code: SyncAuthFailureCode.unauthorized,
      );
    }
    if (target.canSync && active == 1) {
      return const SyncAuthFailure<DeviceRevocation>(
        code: SyncAuthFailureCode.cannotRevokeLastDevice,
      );
    }
    devices[deviceId] = SyncDevice(
      id: target.id,
      accountId: target.accountId,
      displayName: target.displayName,
      registeredAt: target.registeredAt,
      publicKeyId: target.publicKeyId,
      publicKeyBase64: target.publicKeyBase64,
      status: SyncDeviceStatus.revoked,
      revokedAt: clock.now(),
    );
    return SyncAuthSuccess<DeviceRevocation>(
      DeviceRevocation(
        revokedDeviceId: deviceId,
        revokedAt: clock.now(),
        remainingActiveDevices:
            devices.values.where((device) => device.canSync).length,
        requiresDataKeyRotation: true,
      ),
    );
  }

  @override
  Future<SyncAuthResult<CloudDataDeletionReceipt>> deleteCloudData(
    SyncSession session,
  ) async {
    deletionCalls += 1;
    devices.clear();
    sessions.clear();
    return SyncAuthSuccess<CloudDataDeletionReceipt>(
      CloudDataDeletionReceipt(
        requestId: 'deletion-$deletionCalls',
        accountId: session.accountId,
        completedAt: clock.now(),
      ),
    );
  }

  SyncSession _session(
    String deviceId, {
    required SyncDeviceStatus status,
    DateTime? expiresAt,
  }) {
    _sessionSequence += 1;
    return SyncSession(
      id: 'session-$_sessionSequence',
      accountId: 'account-1',
      deviceId: deviceId,
      accessToken: OpaqueSyncToken('access-$_sessionSequence'),
      refreshToken: OpaqueSyncToken('refresh-$_sessionSequence'),
      issuedAt: clock.now().subtract(
            expiresAt != null && !expiresAt.isAfter(clock.now())
                ? const Duration(hours: 1)
                : Duration.zero,
          ),
      expiresAt: expiresAt ?? clock.now().add(const Duration(hours: 1)),
      deviceStatus: status,
    );
  }
}
