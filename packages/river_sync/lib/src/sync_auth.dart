import 'sync_protocol.dart';

abstract interface class SyncAuthClock {
  DateTime now();
}

abstract interface class SyncConnectivity {
  Future<bool> isOnline();
}

final class PasswordlessEmail {
  factory PasswordlessEmail(String value) {
    final trimmed = value.trim();
    final separator = trimmed.lastIndexOf('@');
    if (trimmed.length < 3 ||
        trimmed.length > 320 ||
        separator <= 0 ||
        separator == trimmed.length - 1 ||
        trimmed.contains(RegExp(r'\s'))) {
      throw ArgumentError.value(value, 'value', 'Invalid email address.');
    }
    final local = trimmed.substring(0, separator);
    final domain = trimmed.substring(separator + 1).toLowerCase();
    if (!domain.contains('.') ||
        domain.startsWith('.') ||
        domain.endsWith('.')) {
      throw ArgumentError.value(value, 'value', 'Invalid email domain.');
    }
    return PasswordlessEmail._('$local@$domain');
  }

  const PasswordlessEmail._(this.value);

  final String value;

  @override
  String toString() => '[REDACTED_EMAIL]';
}

final class OpaqueSyncToken {
  OpaqueSyncToken(String value) : _value = value {
    if (value.isEmpty || value.length > 8192) {
      throw ArgumentError.value(value, 'value', 'Invalid opaque token.');
    }
  }

  final String _value;

  String reveal() => _value;

  @override
  String toString() => '[REDACTED_TOKEN]';
}

final class PasswordlessProof {
  PasswordlessProof(String value) : _value = value {
    if (value.isEmpty || value.length > 4096) {
      throw ArgumentError.value(value, 'value', 'Invalid proof.');
    }
  }

  final String _value;

  String reveal() => _value;

  @override
  String toString() => '[REDACTED_PROOF]';
}

final class PasswordlessChallenge {
  PasswordlessChallenge({
    required this.id,
    required this.deliveryHint,
    required this.requestedAt,
    required this.expiresAt,
  }) {
    _requireId(id, 'id');
    if (deliveryHint.isEmpty || deliveryHint.length > 160) {
      throw ArgumentError.value(deliveryHint, 'deliveryHint');
    }
    _requireUtc(requestedAt, 'requestedAt');
    _requireUtc(expiresAt, 'expiresAt');
    if (!expiresAt.isAfter(requestedAt)) {
      throw ArgumentError('Challenge expiry must follow its request time.');
    }
  }

  final String id;
  final String deliveryHint;
  final DateTime requestedAt;
  final DateTime expiresAt;

  bool isExpiredAt(DateTime now) => !now.isBefore(expiresAt);
}

final class SyncSession {
  SyncSession({
    required this.id,
    required this.accountId,
    required this.deviceId,
    required this.accessToken,
    required this.refreshToken,
    required this.issuedAt,
    required this.expiresAt,
    required this.deviceStatus,
  }) {
    _requireId(id, 'id');
    _requireId(accountId, 'accountId');
    _requireId(deviceId, 'deviceId');
    _requireUtc(issuedAt, 'issuedAt');
    _requireUtc(expiresAt, 'expiresAt');
    if (!expiresAt.isAfter(issuedAt)) {
      throw ArgumentError('Session expiry must follow its issue time.');
    }
  }

  final String id;
  final String accountId;
  final String deviceId;
  final OpaqueSyncToken accessToken;
  final OpaqueSyncToken refreshToken;
  final DateTime issuedAt;
  final DateTime expiresAt;
  final SyncDeviceStatus deviceStatus;

  bool isExpiredAt(DateTime now) => !now.isBefore(expiresAt);

  bool canSyncAt(DateTime now) =>
      deviceStatus == SyncDeviceStatus.active && !isExpiredAt(now);

  @override
  String toString() =>
      'SyncSession(id: $id, accountId: $accountId, deviceId: $deviceId, '
      'accessToken: [REDACTED], refreshToken: [REDACTED], '
      'expiresAt: $expiresAt, deviceStatus: ${deviceStatus.name})';
}

enum DeviceJoinStatus { pending, approved, rejected, expired }

final class DeviceJoinRequest {
  DeviceJoinRequest({
    required this.id,
    required this.accountId,
    required this.registration,
    required this.requestedAt,
    required this.expiresAt,
    required this.status,
    this.approvedByDeviceId,
  }) {
    _requireId(id, 'id');
    _requireId(accountId, 'accountId');
    _requireUtc(requestedAt, 'requestedAt');
    _requireUtc(expiresAt, 'expiresAt');
    if (!expiresAt.isAfter(requestedAt)) {
      throw ArgumentError('Join expiry must follow its request time.');
    }
    if (status == DeviceJoinStatus.approved && approvedByDeviceId == null) {
      throw ArgumentError('Approved joins require an approving device.');
    }
    if (approvedByDeviceId != null) {
      _requireId(approvedByDeviceId!, 'approvedByDeviceId');
    }
  }

  final String id;
  final String accountId;
  final SyncDeviceRegistration registration;
  final DateTime requestedAt;
  final DateTime expiresAt;
  final DeviceJoinStatus status;
  final String? approvedByDeviceId;
}

final class DeviceRevocation {
  DeviceRevocation({
    required this.revokedDeviceId,
    required this.revokedAt,
    required this.remainingActiveDevices,
    required this.requiresDataKeyRotation,
  }) {
    _requireId(revokedDeviceId, 'revokedDeviceId');
    _requireUtc(revokedAt, 'revokedAt');
    if (remainingActiveDevices < 0) {
      throw ArgumentError.value(
        remainingActiveDevices,
        'remainingActiveDevices',
      );
    }
  }

  final String revokedDeviceId;
  final DateTime revokedAt;
  final int remainingActiveDevices;
  final bool requiresDataKeyRotation;
}

enum SyncAuthFailureCode {
  offline,
  signedOut,
  invalidChallenge,
  challengeExpired,
  proofRejected,
  sessionExpired,
  devicePendingApproval,
  deviceRevoked,
  approvalExpired,
  cannotRevokeLastDevice,
  unauthorized,
  rateLimited,
  unavailable,
  unexpected,
}

sealed class SyncAuthResult<T> {
  const SyncAuthResult();
}

final class SyncAuthSuccess<T> extends SyncAuthResult<T> {
  const SyncAuthSuccess(this.value);

  final T value;
}

final class SyncAuthFailure<T> extends SyncAuthResult<T> {
  const SyncAuthFailure({
    required this.code,
    this.retryable = false,
    this.retryAfter,
  });

  final SyncAuthFailureCode code;
  final bool retryable;
  final Duration? retryAfter;
}

abstract interface class SyncSessionVault {
  Future<SyncSession?> read();
  Future<void> write(SyncSession session);
  Future<void> clear();
}

abstract interface class SyncAuthorizer {
  Future<SyncAuthResult<SyncSession>> authorizeSync();
}

abstract interface class SyncIdentityGateway {
  Future<SyncAuthResult<PasswordlessChallenge>> startPasswordless(
    PasswordlessEmail email,
  );

  Future<SyncAuthResult<SyncSession>> completePasswordless({
    required String challengeId,
    required PasswordlessProof proof,
    required SyncDeviceRegistration registration,
    required String idempotencyKey,
  });

  Future<SyncAuthResult<SyncSession>> refreshSession(SyncSession session);

  Future<SyncAuthResult<List<DeviceJoinRequest>>> pendingDeviceJoins(
    SyncSession session,
  );

  Future<SyncAuthResult<DeviceJoinRequest>> approveDeviceJoin({
    required SyncSession session,
    required DeviceJoinRequest joinRequest,
    required WrappedSyncDataKey wrappedDataKey,
  });

  Future<SyncAuthResult<List<SyncDevice>>> listDevices(SyncSession session);

  Future<SyncAuthResult<DeviceRevocation>> revokeDevice({
    required SyncSession session,
    required String deviceId,
  });
}

final class SyncAuthController implements SyncAuthorizer {
  SyncAuthController({
    required SyncIdentityGateway gateway,
    required SyncSessionVault vault,
    required SyncConnectivity connectivity,
    required SyncAuthClock clock,
  })  : _gateway = gateway,
        _vault = vault,
        _connectivity = connectivity,
        _clock = clock;

  final SyncIdentityGateway _gateway;
  final SyncSessionVault _vault;
  final SyncConnectivity _connectivity;
  final SyncAuthClock _clock;

  Future<SyncAuthResult<PasswordlessChallenge>> startPasswordless(
    PasswordlessEmail email,
  ) async {
    if (!await _connectivity.isOnline()) {
      return const SyncAuthFailure<PasswordlessChallenge>(
        code: SyncAuthFailureCode.offline,
        retryable: true,
      );
    }
    try {
      return await _gateway.startPasswordless(email);
    } on Object {
      return const SyncAuthFailure<PasswordlessChallenge>(
        code: SyncAuthFailureCode.unexpected,
        retryable: true,
      );
    }
  }

  Future<SyncAuthResult<SyncSession>> completePasswordless({
    required PasswordlessChallenge challenge,
    required PasswordlessProof proof,
    required SyncDeviceRegistration registration,
    required String idempotencyKey,
  }) async {
    if (challenge.isExpiredAt(_clock.now())) {
      return const SyncAuthFailure<SyncSession>(
        code: SyncAuthFailureCode.challengeExpired,
      );
    }
    _requireId(idempotencyKey, 'idempotencyKey');
    if (!await _connectivity.isOnline()) {
      return const SyncAuthFailure<SyncSession>(
        code: SyncAuthFailureCode.offline,
        retryable: true,
      );
    }
    try {
      final result = await _gateway.completePasswordless(
        challengeId: challenge.id,
        proof: proof,
        registration: registration,
        idempotencyKey: idempotencyKey,
      );
      if (result case SyncAuthSuccess<SyncSession>(:final value)) {
        if (value.deviceId != registration.requestedDeviceId) {
          return const SyncAuthFailure<SyncSession>(
            code: SyncAuthFailureCode.unexpected,
          );
        }
        await _vault.write(value);
      }
      return result;
    } on Object {
      return const SyncAuthFailure<SyncSession>(
        code: SyncAuthFailureCode.unexpected,
        retryable: true,
      );
    }
  }

  Future<SyncAuthResult<SyncSession>> restoreLocalSession() async {
    final session = await _vault.read();
    if (session == null) {
      return const SyncAuthFailure<SyncSession>(
        code: SyncAuthFailureCode.signedOut,
      );
    }
    if (session.deviceStatus == SyncDeviceStatus.revoked) {
      await _vault.clear();
      return const SyncAuthFailure<SyncSession>(
        code: SyncAuthFailureCode.deviceRevoked,
      );
    }
    if (session.isExpiredAt(_clock.now())) {
      return const SyncAuthFailure<SyncSession>(
        code: SyncAuthFailureCode.sessionExpired,
        retryable: true,
      );
    }
    return SyncAuthSuccess<SyncSession>(session);
  }

  Future<SyncAuthResult<SyncSession>> refreshDeviceStatus() async {
    final session = await _vault.read();
    if (session == null) {
      return const SyncAuthFailure<SyncSession>(
        code: SyncAuthFailureCode.signedOut,
      );
    }
    if (!await _connectivity.isOnline()) {
      return const SyncAuthFailure<SyncSession>(
        code: SyncAuthFailureCode.offline,
        retryable: true,
      );
    }
    try {
      final result = await _gateway.refreshSession(session);
      if (result case SyncAuthSuccess<SyncSession>(:final value)) {
        if (value.accountId != session.accountId ||
            value.deviceId != session.deviceId) {
          await _vault.clear();
          return const SyncAuthFailure<SyncSession>(
            code: SyncAuthFailureCode.unexpected,
          );
        }
        await _vault.write(value);
      } else if (result
          case SyncAuthFailure<SyncSession>(
            code: SyncAuthFailureCode.deviceRevoked ||
                SyncAuthFailureCode.sessionExpired
          )) {
        await _vault.clear();
      }
      return result;
    } on Object {
      return const SyncAuthFailure<SyncSession>(
        code: SyncAuthFailureCode.unexpected,
        retryable: true,
      );
    }
  }

  @override
  Future<SyncAuthResult<SyncSession>> authorizeSync() async {
    final refreshed = await refreshDeviceStatus();
    if (refreshed case SyncAuthSuccess<SyncSession>(:final value)) {
      if (value.deviceStatus == SyncDeviceStatus.revoked) {
        await _vault.clear();
        return const SyncAuthFailure<SyncSession>(
          code: SyncAuthFailureCode.deviceRevoked,
        );
      }
      if (value.deviceStatus != SyncDeviceStatus.active) {
        return const SyncAuthFailure<SyncSession>(
          code: SyncAuthFailureCode.devicePendingApproval,
          retryable: true,
        );
      }
      if (value.isExpiredAt(_clock.now())) {
        await _vault.clear();
        return const SyncAuthFailure<SyncSession>(
          code: SyncAuthFailureCode.sessionExpired,
        );
      }
    }
    return refreshed;
  }

  Future<SyncAuthResult<List<DeviceJoinRequest>>> pendingDeviceJoins() async {
    final authorization = await authorizeSync();
    if (authorization
        case SyncAuthFailure<SyncSession>(
          :final code,
          :final retryable,
          :final retryAfter,
        )) {
      return SyncAuthFailure<List<DeviceJoinRequest>>(
        code: code,
        retryable: retryable,
        retryAfter: retryAfter,
      );
    }
    final session = (authorization as SyncAuthSuccess<SyncSession>).value;
    try {
      return await _gateway.pendingDeviceJoins(session);
    } on Object {
      return const SyncAuthFailure<List<DeviceJoinRequest>>(
        code: SyncAuthFailureCode.unexpected,
        retryable: true,
      );
    }
  }

  Future<SyncAuthResult<DeviceJoinRequest>> approveDeviceJoin({
    required DeviceJoinRequest joinRequest,
    required WrappedSyncDataKey wrappedDataKey,
  }) async {
    final authorization = await authorizeSync();
    if (authorization
        case SyncAuthFailure<SyncSession>(
          :final code,
          :final retryable,
          :final retryAfter,
        )) {
      return SyncAuthFailure<DeviceJoinRequest>(
        code: code,
        retryable: retryable,
        retryAfter: retryAfter,
      );
    }
    final session = (authorization as SyncAuthSuccess<SyncSession>).value;
    if (joinRequest.status != DeviceJoinStatus.pending ||
        !_clock.now().isBefore(joinRequest.expiresAt)) {
      return const SyncAuthFailure<DeviceJoinRequest>(
        code: SyncAuthFailureCode.approvalExpired,
      );
    }
    if (joinRequest.accountId != session.accountId ||
        wrappedDataKey.accountId != session.accountId ||
        wrappedDataKey.senderDeviceId != session.deviceId ||
        wrappedDataKey.recipientDeviceId !=
            joinRequest.registration.requestedDeviceId) {
      throw ArgumentError(
        'Join request and wrapped key scope must match the approving session.',
      );
    }
    try {
      return await _gateway.approveDeviceJoin(
        session: session,
        joinRequest: joinRequest,
        wrappedDataKey: wrappedDataKey,
      );
    } on Object {
      return const SyncAuthFailure<DeviceJoinRequest>(
        code: SyncAuthFailureCode.unexpected,
        retryable: true,
      );
    }
  }

  Future<SyncAuthResult<List<SyncDevice>>> listDevices() async {
    final authorization = await authorizeSync();
    if (authorization
        case SyncAuthFailure<SyncSession>(
          :final code,
          :final retryable,
          :final retryAfter,
        )) {
      return SyncAuthFailure<List<SyncDevice>>(
        code: code,
        retryable: retryable,
        retryAfter: retryAfter,
      );
    }
    try {
      return await _gateway.listDevices(
        (authorization as SyncAuthSuccess<SyncSession>).value,
      );
    } on Object {
      return const SyncAuthFailure<List<SyncDevice>>(
        code: SyncAuthFailureCode.unexpected,
        retryable: true,
      );
    }
  }

  Future<SyncAuthResult<DeviceRevocation>> revokeDevice(
    String deviceId,
  ) async {
    _requireId(deviceId, 'deviceId');
    final authorization = await authorizeSync();
    if (authorization
        case SyncAuthFailure<SyncSession>(
          :final code,
          :final retryable,
          :final retryAfter,
        )) {
      return SyncAuthFailure<DeviceRevocation>(
        code: code,
        retryable: retryable,
        retryAfter: retryAfter,
      );
    }
    final session = (authorization as SyncAuthSuccess<SyncSession>).value;
    try {
      final result = await _gateway.revokeDevice(
        session: session,
        deviceId: deviceId,
      );
      if (result case SyncAuthSuccess<DeviceRevocation>(:final value)) {
        if (value.revokedDeviceId == session.deviceId) {
          await _vault.clear();
        }
      }
      return result;
    } on Object {
      return const SyncAuthFailure<DeviceRevocation>(
        code: SyncAuthFailureCode.unexpected,
        retryable: true,
      );
    }
  }

  Future<void> signOut() => _vault.clear();
}

void _requireId(String value, String name) {
  if (value.isEmpty || value.trim() != value || value.length > 256) {
    throw ArgumentError.value(value, name, 'Invalid identifier.');
  }
}

void _requireUtc(DateTime value, String name) {
  if (!value.isUtc) {
    throw ArgumentError.value(value, name, 'Timestamp must be UTC.');
  }
}
