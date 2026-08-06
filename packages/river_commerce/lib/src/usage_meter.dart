import 'dart:async';

import 'entitlements.dart';

final class UsageBalance {
  const UsageBalance({required this.capability, required this.remaining});

  final String capability;
  final int remaining;
}

final class UsageMeter {
  UsageMeter(Map<String, int> initialBalances)
      : _balances = Map<String, int>.from(initialBalances);

  final Map<String, int> _balances;
  final Map<String, UsageBalance> _completed = <String, UsageBalance>{};

  UsageBalance consume({
    required String idempotencyKey,
    required String capability,
    required int amount,
    required bool producedUsableResult,
  }) {
    if (amount <= 0) throw ArgumentError.value(amount, 'amount');
    final existing = _completed[idempotencyKey];
    if (existing != null) return existing;

    final current = _balances[capability] ?? 0;
    if (!producedUsableResult) {
      return UsageBalance(capability: capability, remaining: current);
    }
    if (current < amount) {
      throw StateError('Insufficient $capability balance');
    }
    final result = UsageBalance(
      capability: capability,
      remaining: current - amount,
    );
    _balances[capability] = result.remaining;
    _completed[idempotencyKey] = result;
    return result;
  }

  int remaining(String capability) => _balances[capability] ?? 0;
}

enum UsageLedgerStatus { reserved, committed, released, refunded }

enum UsageThreshold { eightyPercent, exhausted }

final class UsageGrant {
  UsageGrant({
    required this.grantId,
    required this.capability,
    required this.limit,
    required this.validFrom,
    required this.validUntil,
  }) {
    if (!_usageId.hasMatch(grantId) ||
        isFreeEntitlement(capability) ||
        limit < 1 ||
        limit > 1000000000 ||
        !validFrom.isUtc ||
        !validUntil.isUtc ||
        !validUntil.isAfter(validFrom)) {
      throw ArgumentError('Invalid usage grant');
    }
  }

  final String grantId;
  final EntitlementKey capability;
  final int limit;
  final DateTime validFrom;
  final DateTime validUntil;

  bool isActiveAt(DateTime at) =>
      !at.isBefore(validFrom) && at.isBefore(validUntil);
}

final class UsageLedgerEntry {
  UsageLedgerEntry({
    required this.operationId,
    required this.requestHash,
    required this.grantId,
    required this.capability,
    required this.units,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  }) {
    if (!_usageId.hasMatch(operationId) ||
        !_usageHash.hasMatch(requestHash) ||
        !_usageId.hasMatch(grantId) ||
        units < 1 ||
        units > 1000000000 ||
        !createdAt.isUtc ||
        !updatedAt.isUtc ||
        updatedAt.isBefore(createdAt)) {
      throw ArgumentError('Invalid usage ledger entry');
    }
  }

  final String operationId;
  final String requestHash;
  final String grantId;
  final EntitlementKey capability;
  final int units;
  final UsageLedgerStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  UsageLedgerEntry withStatus(UsageLedgerStatus next, DateTime at) =>
      UsageLedgerEntry(
        operationId: operationId,
        requestHash: requestHash,
        grantId: grantId,
        capability: capability,
        units: units,
        status: next,
        createdAt: createdAt,
        updatedAt: at,
      );

  bool sameRequest({
    required String requestHash,
    required String grantId,
    required EntitlementKey capability,
    required int units,
  }) =>
      this.requestHash == requestHash &&
      this.grantId == grantId &&
      this.capability == capability &&
      this.units == units;
}

final class UsageThresholdNotice {
  const UsageThresholdNotice({
    required this.grantId,
    required this.capability,
    required this.threshold,
    required this.used,
    required this.limit,
    required this.emittedAt,
  });

  final String grantId;
  final EntitlementKey capability;
  final UsageThreshold threshold;
  final int used;
  final int limit;
  final DateTime emittedAt;
}

final class UsageLedgerSnapshot {
  const UsageLedgerSnapshot({
    required this.grant,
    required this.used,
    required this.reserved,
    required this.entries,
    required this.notices,
  });

  final UsageGrant grant;
  final int used;
  final int reserved;
  final List<UsageLedgerEntry> entries;
  final List<UsageThresholdNotice> notices;

  int get remaining => grant.limit - used;
  int get available => grant.limit - used - reserved;
}

enum UsageLedgerFailureCode {
  grantNotFound,
  grantInactive,
  capabilityMismatch,
  exhausted,
  idempotencyConflict,
  settlementConflict,
  operationNotFound,
}

final class UsageLedgerFailure implements Exception {
  const UsageLedgerFailure(this.code);

  final UsageLedgerFailureCode code;

  @override
  String toString() => 'UsageLedgerFailure(${code.name})';
}

final class UsageLedger {
  UsageLedger(Iterable<UsageGrant> grants) {
    for (final grant in grants) {
      if (_grants.containsKey(grant.grantId)) {
        throw ArgumentError('Duplicate usage grant');
      }
      _grants[grant.grantId] = grant;
    }
  }

  final Map<String, UsageGrant> _grants = <String, UsageGrant>{};
  final Map<String, UsageLedgerEntry> _entries = <String, UsageLedgerEntry>{};
  final Map<String, UsageThresholdNotice> _notices =
      <String, UsageThresholdNotice>{};
  Future<void> _tail = Future<void>.value();

  Future<UsageLedgerEntry> reserve({
    required String operationId,
    required String requestHash,
    required String grantId,
    required EntitlementKey capability,
    required int units,
    required DateTime at,
  }) =>
      _serialized(() {
        final existing = _entries[operationId];
        if (existing != null) {
          if (!existing.sameRequest(
            requestHash: requestHash,
            grantId: grantId,
            capability: capability,
            units: units,
          )) {
            throw const UsageLedgerFailure(
              UsageLedgerFailureCode.idempotencyConflict,
            );
          }
          return existing;
        }
        if (!_usageId.hasMatch(operationId) ||
            !_usageHash.hasMatch(requestHash) ||
            units < 1 ||
            units > 1000000000 ||
            !at.isUtc) {
          throw ArgumentError('Invalid usage reservation');
        }
        final grant = _grants[grantId];
        if (grant == null) {
          throw const UsageLedgerFailure(UsageLedgerFailureCode.grantNotFound);
        }
        if (grant.capability != capability) {
          throw const UsageLedgerFailure(
            UsageLedgerFailureCode.capabilityMismatch,
          );
        }
        if (!grant.isActiveAt(at)) {
          throw const UsageLedgerFailure(UsageLedgerFailureCode.grantInactive);
        }
        if (_snapshot(grant).available < units) {
          throw const UsageLedgerFailure(UsageLedgerFailureCode.exhausted);
        }
        return _entries[operationId] = UsageLedgerEntry(
          operationId: operationId,
          requestHash: requestHash,
          grantId: grantId,
          capability: capability,
          units: units,
          status: UsageLedgerStatus.reserved,
          createdAt: at,
          updatedAt: at,
        );
      });

  Future<UsageLedgerEntry> settle({
    required String operationId,
    required bool producedUsableResult,
    required DateTime at,
  }) =>
      _serialized(() {
        final entry = _requireEntry(operationId);
        final expected = producedUsableResult
            ? UsageLedgerStatus.committed
            : UsageLedgerStatus.released;
        if (entry.status == expected) return entry;
        if (entry.status != UsageLedgerStatus.reserved) {
          throw const UsageLedgerFailure(
            UsageLedgerFailureCode.settlementConflict,
          );
        }
        final updated = entry.withStatus(expected, _requireUtc(at));
        _entries[operationId] = updated;
        if (expected == UsageLedgerStatus.committed) {
          _emitThresholds(_grants[entry.grantId]!, at);
        }
        return updated;
      });

  Future<UsageLedgerEntry> refund({
    required String operationId,
    required DateTime at,
  }) =>
      _serialized(() {
        final entry = _requireEntry(operationId);
        if (entry.status == UsageLedgerStatus.refunded ||
            entry.status == UsageLedgerStatus.released) {
          return entry;
        }
        final next = entry.status == UsageLedgerStatus.reserved
            ? UsageLedgerStatus.released
            : UsageLedgerStatus.refunded;
        final updated = entry.withStatus(next, _requireUtc(at));
        _entries[operationId] = updated;
        return updated;
      });

  Future<UsageLedgerSnapshot> snapshot(String grantId) => _serialized(() {
        final grant = _grants[grantId];
        if (grant == null) {
          throw const UsageLedgerFailure(UsageLedgerFailureCode.grantNotFound);
        }
        return _snapshot(grant);
      });

  UsageLedgerEntry _requireEntry(String operationId) {
    final entry = _entries[operationId];
    if (entry == null) {
      throw const UsageLedgerFailure(UsageLedgerFailureCode.operationNotFound);
    }
    return entry;
  }

  UsageLedgerSnapshot _snapshot(UsageGrant grant) {
    final entries = _entries.values
        .where((entry) => entry.grantId == grant.grantId)
        .toList(growable: false)
      ..sort((left, right) => left.operationId.compareTo(right.operationId));
    final used = entries
        .where((entry) => entry.status == UsageLedgerStatus.committed)
        .fold<int>(0, (sum, entry) => sum + entry.units);
    final reserved = entries
        .where((entry) => entry.status == UsageLedgerStatus.reserved)
        .fold<int>(0, (sum, entry) => sum + entry.units);
    final notices = _notices.values
        .where((notice) => notice.grantId == grant.grantId)
        .toList(growable: false)
      ..sort(
        (left, right) => left.threshold.index.compareTo(right.threshold.index),
      );
    return UsageLedgerSnapshot(
      grant: grant,
      used: used,
      reserved: reserved,
      entries: List<UsageLedgerEntry>.unmodifiable(entries),
      notices: List<UsageThresholdNotice>.unmodifiable(notices),
    );
  }

  void _emitThresholds(UsageGrant grant, DateTime at) {
    final used = _snapshot(grant).used;
    final thresholds = <(UsageThreshold, int)>[
      (UsageThreshold.eightyPercent, (grant.limit * 8 + 9) ~/ 10),
      (UsageThreshold.exhausted, grant.limit),
    ];
    for (final threshold in thresholds) {
      final key = '${grant.grantId}:${threshold.$1.name}';
      if (used >= threshold.$2 && !_notices.containsKey(key)) {
        _notices[key] = UsageThresholdNotice(
          grantId: grant.grantId,
          capability: grant.capability,
          threshold: threshold.$1,
          used: used,
          limit: grant.limit,
          emittedAt: at,
        );
      }
    }
  }

  DateTime _requireUtc(DateTime value) {
    if (!value.isUtc) throw ArgumentError.value(value, 'at');
    return value;
  }

  Future<T> _serialized<T>(FutureOr<T> Function() operation) {
    final result = _tail.then<T>((_) => operation());
    _tail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return result;
  }
}

final _usageId = RegExp(r'^[A-Za-z0-9._:-]{3,200}$');
final _usageHash = RegExp(r'^[a-f0-9]{64}$');
