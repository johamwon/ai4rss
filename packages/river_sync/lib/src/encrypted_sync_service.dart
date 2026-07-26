import 'dart:async';
import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import 'incremental_sync.dart';
import 'sync_auth.dart';
import 'sync_protocol.dart';
import 'sync_wire_codec.dart';

enum EncryptedSyncServiceFailureCode {
  unauthorized,
  rateLimited,
  quotaExceeded,
  mutationCollision,
  backupCorrupt,
  restoreTargetNotEmpty,
}

final class EncryptedSyncServiceException implements Exception {
  const EncryptedSyncServiceException({
    required this.code,
    this.retryAfter,
  });

  final EncryptedSyncServiceFailureCode code;
  final Duration? retryAfter;

  @override
  String toString() => 'EncryptedSyncServiceException(${code.name})';
}

final class SyncServicePrincipal {
  SyncServicePrincipal({
    required this.accountId,
    required this.deviceId,
    required this.deviceStatus,
  }) {
    _requireIdentifier(accountId, 'accountId');
    _requireIdentifier(deviceId, 'deviceId');
  }

  final String accountId;
  final String deviceId;
  final SyncDeviceStatus deviceStatus;
}

final class EncryptedSyncServiceLimits {
  const EncryptedSyncServiceLimits({
    this.maximumStoredBytes = 64 * 1024 * 1024,
    this.maximumStoredMutations = 100000,
    this.maximumRequestsPerWindow = 120,
    this.rateLimitWindow = const Duration(minutes: 1),
  });

  final int maximumStoredBytes;
  final int maximumStoredMutations;
  final int maximumRequestsPerWindow;
  final Duration rateLimitWindow;

  void validate() {
    if (maximumStoredBytes <= 0 ||
        maximumStoredMutations <= 0 ||
        maximumRequestsPerWindow <= 0 ||
        rateLimitWindow <= Duration.zero) {
      throw StateError('Encrypted sync service limits must be positive.');
    }
  }
}

abstract interface class SyncServiceClock {
  DateTime now();
}

enum SyncServiceAuditOperation { push, pull, delete, backup, restore }

enum SyncServiceAuditOutcome {
  succeeded,
  unauthorized,
  rateLimited,
  quotaRejected,
  rejected,
}

final class SyncServiceAuditEvent {
  SyncServiceAuditEvent({
    required this.accountId,
    required this.deviceId,
    required this.operation,
    required this.outcome,
    required this.itemCount,
    required this.occurredAt,
  }) {
    if (!occurredAt.isUtc || itemCount < 0) {
      throw ArgumentError('Invalid sync service audit event.');
    }
  }

  final String accountId;
  final String deviceId;
  final SyncServiceAuditOperation operation;
  final SyncServiceAuditOutcome outcome;
  final int itemCount;
  final DateTime occurredAt;
}

abstract interface class SyncServiceAuditSink {
  void record(SyncServiceAuditEvent event);
}

final class SyncServiceAccountMetrics {
  const SyncServiceAccountMetrics({
    required this.storedMutations,
    required this.storedBytes,
    required this.latestSequence,
  });

  final int storedMutations;
  final int storedBytes;
  final int latestSequence;
}

final class EncryptedSyncBackup {
  EncryptedSyncBackup({
    required this.accountId,
    required this.createdAt,
    required List<String> envelopeJson,
    required this.checksumBase64,
  }) : envelopeJson = List<String>.unmodifiable(envelopeJson) {
    _requireIdentifier(accountId, 'accountId');
    if (!createdAt.isUtc || checksumBase64.isEmpty) {
      throw ArgumentError('Invalid encrypted sync backup metadata.');
    }
  }

  final String accountId;
  final DateTime createdAt;
  final List<String> envelopeJson;
  final String checksumBase64;
}

final class SyncRecoveryDrillReport {
  SyncRecoveryDrillReport({
    required this.accountId,
    required this.restoredMutations,
    required this.restoredBytes,
    required this.latestSequence,
    required this.completedAt,
  }) {
    if (!completedAt.isUtc ||
        restoredMutations < 0 ||
        restoredBytes < 0 ||
        latestSequence < 0) {
      throw ArgumentError('Invalid sync recovery drill report.');
    }
  }

  final String accountId;
  final int restoredMutations;
  final int restoredBytes;
  final int latestSequence;
  final DateTime completedAt;
}

abstract interface class EncryptedSyncStorage {
  Future<SyncPushReceipt> append({
    required String accountId,
    required List<EncryptedSyncEnvelope> envelopes,
    required EncryptedSyncServiceLimits limits,
  });

  Future<SyncPullPage> readPage(SyncPullRequest request);

  Future<SyncServiceAccountMetrics> readMetrics(String accountId);

  Future<EncryptedSyncBackup> createBackup({
    required String accountId,
    required DateTime createdAt,
  });

  Future<void> restoreBackup(
    EncryptedSyncBackup backup, {
    required bool allowReplace,
  });

  Future<void> deleteAccount(String accountId);
}

final class InMemoryEncryptedSyncStorage implements EncryptedSyncStorage {
  final Map<String, List<EncryptedSyncEnvelope>> _accounts =
      <String, List<EncryptedSyncEnvelope>>{};
  Future<void> _tail = Future<void>.value();

  @override
  Future<SyncPushReceipt> append({
    required String accountId,
    required List<EncryptedSyncEnvelope> envelopes,
    required EncryptedSyncServiceLimits limits,
  }) =>
      _serialized(() {
        final records =
            _accounts.putIfAbsent(accountId, () => <EncryptedSyncEnvelope>[]);
        final byMutation = <String, EncryptedSyncEnvelope>{
          for (final record in records) record.mutationId: record,
        };
        final additions = <EncryptedSyncEnvelope>[];
        for (final envelope in envelopes) {
          final existing = byMutation[envelope.mutationId];
          if (existing != null) {
            if (!_sameEnvelope(existing, envelope)) {
              throw const EncryptedSyncServiceException(
                code: EncryptedSyncServiceFailureCode.mutationCollision,
              );
            }
            continue;
          }
          byMutation[envelope.mutationId] = envelope;
          additions.add(envelope);
        }
        final storedCount = records.length + additions.length;
        final storedBytes = records.fold<int>(
              0,
              (sum, item) => sum + _wireSize(item),
            ) +
            additions.fold<int>(
              0,
              (sum, item) => sum + _wireSize(item),
            );
        if (storedCount > limits.maximumStoredMutations ||
            storedBytes > limits.maximumStoredBytes) {
          throw const EncryptedSyncServiceException(
            code: EncryptedSyncServiceFailureCode.quotaExceeded,
          );
        }
        records.addAll(additions);
        return SyncPushReceipt(
          acceptedMutationIds: envelopes.map((item) => item.mutationId).toSet(),
        );
      });

  @override
  Future<SyncPullPage> readPage(SyncPullRequest request) => _serialized(() {
        final records =
            _accounts[request.accountId] ?? const <EncryptedSyncEnvelope>[];
        final start = request.cursor.serverSequence;
        if (start > records.length) {
          throw const EncryptedSyncServiceException(
            code: EncryptedSyncServiceFailureCode.backupCorrupt,
          );
        }
        final selected = records.skip(start).take(request.limit).toList();
        final nextSequence = start + selected.length;
        return SyncPullPage(
          previousCursor: request.cursor,
          nextCursor: selected.isEmpty
              ? request.cursor
              : SyncCursor(
                  serverSequence: nextSequence,
                  opaqueToken: 'sequence-$nextSequence',
                ),
          envelopes: selected,
          hasMore: nextSequence < records.length,
        );
      });

  @override
  Future<SyncServiceAccountMetrics> readMetrics(String accountId) =>
      _serialized(() {
        final records = _accounts[accountId] ?? const <EncryptedSyncEnvelope>[];
        return SyncServiceAccountMetrics(
          storedMutations: records.length,
          storedBytes: records.fold<int>(
            0,
            (sum, item) => sum + _wireSize(item),
          ),
          latestSequence: records.length,
        );
      });

  @override
  Future<EncryptedSyncBackup> createBackup({
    required String accountId,
    required DateTime createdAt,
  }) =>
      _serialized(() async {
        final encoded = List<String>.unmodifiable(
          (_accounts[accountId] ?? const <EncryptedSyncEnvelope>[])
              .map(SyncWireCodec.encodeEnvelope),
        );
        return EncryptedSyncBackup(
          accountId: accountId,
          createdAt: createdAt,
          envelopeJson: encoded,
          checksumBase64: await _backupChecksum(accountId, encoded),
        );
      });

  @override
  Future<void> restoreBackup(
    EncryptedSyncBackup backup, {
    required bool allowReplace,
  }) =>
      _serialized(() async {
        final expected = await _backupChecksum(
          backup.accountId,
          backup.envelopeJson,
        );
        if (expected != backup.checksumBase64) {
          throw const EncryptedSyncServiceException(
            code: EncryptedSyncServiceFailureCode.backupCorrupt,
          );
        }
        final existing = _accounts[backup.accountId];
        if (!allowReplace && existing != null && existing.isNotEmpty) {
          throw const EncryptedSyncServiceException(
            code: EncryptedSyncServiceFailureCode.restoreTargetNotEmpty,
          );
        }
        final records = backup.envelopeJson
            .map(SyncWireCodec.decodeEnvelope)
            .toList(growable: false);
        if (records.any((item) => item.accountId != backup.accountId) ||
            records.map((item) => item.mutationId).toSet().length !=
                records.length) {
          throw const EncryptedSyncServiceException(
            code: EncryptedSyncServiceFailureCode.backupCorrupt,
          );
        }
        _accounts[backup.accountId] = List<EncryptedSyncEnvelope>.of(records);
      });

  @override
  Future<void> deleteAccount(String accountId) =>
      _serialized(() => _accounts.remove(accountId));

  Future<T> _serialized<T>(FutureOr<T> Function() operation) {
    final completer = Completer<T>();
    final previous = _tail;
    _tail = () async {
      await previous;
      try {
        completer.complete(await operation());
      } on Object catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    }();
    return completer.future;
  }
}

final class EncryptedSyncService {
  EncryptedSyncService({
    required EncryptedSyncStorage storage,
    required SyncServiceClock clock,
    required SyncServiceAuditSink audit,
    this.limits = const EncryptedSyncServiceLimits(),
  })  : _storage = storage,
        _clock = clock,
        _audit = audit {
    limits.validate();
  }

  final EncryptedSyncStorage _storage;
  final SyncServiceClock _clock;
  final SyncServiceAuditSink _audit;
  final EncryptedSyncServiceLimits limits;
  final Map<String, _RateWindow> _rateWindows = <String, _RateWindow>{};

  Future<SyncPushReceipt> push({
    required SyncServicePrincipal principal,
    required SyncPushBatch batch,
  }) async {
    _authorize(
      principal,
      operation: SyncServiceAuditOperation.push,
      itemCount: batch.envelopes.length,
    );
    _rateLimit(
      principal,
      operation: SyncServiceAuditOperation.push,
      itemCount: batch.envelopes.length,
    );
    if (batch.accountId != principal.accountId ||
        batch.deviceId != principal.deviceId ||
        batch.envelopes.any(
          (item) =>
              item.accountId != principal.accountId ||
              item.authorDeviceId != principal.deviceId,
        )) {
      _record(
        principal,
        SyncServiceAuditOperation.push,
        SyncServiceAuditOutcome.unauthorized,
        batch.envelopes.length,
      );
      throw const EncryptedSyncServiceException(
        code: EncryptedSyncServiceFailureCode.unauthorized,
      );
    }
    try {
      final receipt = await _storage.append(
        accountId: principal.accountId,
        envelopes: batch.envelopes,
        limits: limits,
      );
      _record(
        principal,
        SyncServiceAuditOperation.push,
        SyncServiceAuditOutcome.succeeded,
        batch.envelopes.length,
      );
      return receipt;
    } on EncryptedSyncServiceException catch (error) {
      _record(
        principal,
        SyncServiceAuditOperation.push,
        error.code == EncryptedSyncServiceFailureCode.quotaExceeded
            ? SyncServiceAuditOutcome.quotaRejected
            : SyncServiceAuditOutcome.rejected,
        batch.envelopes.length,
      );
      rethrow;
    }
  }

  Future<SyncPullPage> pull({
    required SyncServicePrincipal principal,
    required SyncPullRequest request,
  }) async {
    _authorize(
      principal,
      operation: SyncServiceAuditOperation.pull,
      itemCount: request.limit,
    );
    _rateLimit(
      principal,
      operation: SyncServiceAuditOperation.pull,
      itemCount: request.limit,
    );
    if (request.accountId != principal.accountId ||
        request.deviceId != principal.deviceId) {
      _record(
        principal,
        SyncServiceAuditOperation.pull,
        SyncServiceAuditOutcome.unauthorized,
        0,
      );
      throw const EncryptedSyncServiceException(
        code: EncryptedSyncServiceFailureCode.unauthorized,
      );
    }
    final page = await _storage.readPage(request);
    _record(
      principal,
      SyncServiceAuditOperation.pull,
      SyncServiceAuditOutcome.succeeded,
      page.envelopes.length,
    );
    return page;
  }

  Future<CloudDataDeletionReceipt> deleteCloudData({
    required SyncServicePrincipal principal,
    required String requestId,
  }) async {
    _authorize(
      principal,
      operation: SyncServiceAuditOperation.delete,
      itemCount: 0,
    );
    _rateLimit(
      principal,
      operation: SyncServiceAuditOperation.delete,
      itemCount: 0,
    );
    _requireIdentifier(requestId, 'requestId');
    await _storage.deleteAccount(principal.accountId);
    final completedAt = _now();
    _record(
      principal,
      SyncServiceAuditOperation.delete,
      SyncServiceAuditOutcome.succeeded,
      0,
    );
    return CloudDataDeletionReceipt(
      requestId: requestId,
      accountId: principal.accountId,
      completedAt: completedAt,
    );
  }

  Future<SyncRecoveryDrillReport> verifyBackup(
    EncryptedSyncBackup backup,
  ) async {
    final isolated = InMemoryEncryptedSyncStorage();
    await isolated.restoreBackup(backup, allowReplace: false);
    final metrics = await isolated.readMetrics(backup.accountId);
    final completedAt = _now();
    _audit.record(
      SyncServiceAuditEvent(
        accountId: backup.accountId,
        deviceId: 'service-recovery-drill',
        operation: SyncServiceAuditOperation.restore,
        outcome: SyncServiceAuditOutcome.succeeded,
        itemCount: metrics.storedMutations,
        occurredAt: completedAt,
      ),
    );
    return SyncRecoveryDrillReport(
      accountId: backup.accountId,
      restoredMutations: metrics.storedMutations,
      restoredBytes: metrics.storedBytes,
      latestSequence: metrics.latestSequence,
      completedAt: completedAt,
    );
  }

  Future<SyncServiceAccountMetrics> readAdminMetrics(String accountId) {
    _requireIdentifier(accountId, 'accountId');
    return _storage.readMetrics(accountId);
  }

  Future<EncryptedSyncBackup> createBackup(String accountId) async {
    _requireIdentifier(accountId, 'accountId');
    final backup = await _storage.createBackup(
      accountId: accountId,
      createdAt: _now(),
    );
    _audit.record(
      SyncServiceAuditEvent(
        accountId: accountId,
        deviceId: 'service-backup',
        operation: SyncServiceAuditOperation.backup,
        outcome: SyncServiceAuditOutcome.succeeded,
        itemCount: backup.envelopeJson.length,
        occurredAt: _now(),
      ),
    );
    return backup;
  }

  Future<void> restoreBackup(
    EncryptedSyncBackup backup, {
    bool allowReplace = false,
  }) async {
    await _storage.restoreBackup(backup, allowReplace: allowReplace);
    _audit.record(
      SyncServiceAuditEvent(
        accountId: backup.accountId,
        deviceId: 'service-restore',
        operation: SyncServiceAuditOperation.restore,
        outcome: SyncServiceAuditOutcome.succeeded,
        itemCount: backup.envelopeJson.length,
        occurredAt: _now(),
      ),
    );
  }

  void _authorize(
    SyncServicePrincipal principal, {
    required SyncServiceAuditOperation operation,
    required int itemCount,
  }) {
    if (principal.deviceStatus == SyncDeviceStatus.active) return;
    _record(
      principal,
      operation,
      SyncServiceAuditOutcome.unauthorized,
      itemCount,
    );
    throw const EncryptedSyncServiceException(
      code: EncryptedSyncServiceFailureCode.unauthorized,
    );
  }

  void _rateLimit(
    SyncServicePrincipal principal, {
    required SyncServiceAuditOperation operation,
    required int itemCount,
  }) {
    final now = _now();
    final key = '${principal.accountId}:${principal.deviceId}';
    var window = _rateWindows[key];
    if (window == null ||
        now.difference(window.startedAt) >= limits.rateLimitWindow) {
      window = _RateWindow(startedAt: now);
      _rateWindows[key] = window;
    }
    if (window.requests >= limits.maximumRequestsPerWindow) {
      final retryAfter =
          limits.rateLimitWindow - now.difference(window.startedAt);
      _record(
        principal,
        operation,
        SyncServiceAuditOutcome.rateLimited,
        itemCount,
      );
      throw EncryptedSyncServiceException(
        code: EncryptedSyncServiceFailureCode.rateLimited,
        retryAfter: retryAfter,
      );
    }
    window.requests += 1;
  }

  void _record(
    SyncServicePrincipal principal,
    SyncServiceAuditOperation operation,
    SyncServiceAuditOutcome outcome,
    int itemCount,
  ) {
    _audit.record(
      SyncServiceAuditEvent(
        accountId: principal.accountId,
        deviceId: principal.deviceId,
        operation: operation,
        outcome: outcome,
        itemCount: itemCount,
        occurredAt: _now(),
      ),
    );
  }

  DateTime _now() {
    final value = _clock.now();
    if (!value.isUtc) {
      throw StateError('Encrypted sync service clock must return UTC.');
    }
    return value;
  }
}

final class _RateWindow {
  _RateWindow({required this.startedAt});

  final DateTime startedAt;
  var requests = 0;
}

Future<String> _backupChecksum(
  String accountId,
  List<String> envelopes,
) async {
  final clear = utf8.encode(
    jsonEncode(<String, Object?>{
      'accountId': accountId,
      'envelopes': envelopes,
    }),
  );
  final digest = await Sha256().hash(clear);
  return base64.encode(digest.bytes);
}

int _wireSize(EncryptedSyncEnvelope envelope) =>
    utf8.encode(SyncWireCodec.encodeEnvelope(envelope)).length;

bool _sameEnvelope(
  EncryptedSyncEnvelope left,
  EncryptedSyncEnvelope right,
) =>
    left.associatedData == right.associatedData &&
    left.nonceBase64 == right.nonceBase64 &&
    left.ciphertextBase64 == right.ciphertextBase64 &&
    left.authenticationTagBase64 == right.authenticationTagBase64;

void _requireIdentifier(String value, String name) {
  if (value.isEmpty || value.trim() != value || value.length > 256) {
    throw ArgumentError.value(value, name);
  }
}
