import 'dart:async';
import 'dart:convert';

enum CloudCapability {
  managedAi,
  cloudExtraction,
  cloudTts,
  podcastTranscription,
}

enum CloudSpanOutcome {
  success,
  rejected,
  providerFailure,
  timeout,
  cancelled,
  qualityRejected,
}

final class CloudOperationSpan {
  CloudOperationSpan({
    required this.spanId,
    required this.operationHash,
    required this.capability,
    required this.routeId,
    required this.modelId,
    required this.startedAt,
    required this.endedAt,
    required this.outcome,
    required this.costMicros,
    this.inputUnits = 0,
    this.outputUnits = 0,
  }) {
    if (!_safeId.hasMatch(spanId) ||
        !_hash.hasMatch(operationHash) ||
        !_safeProviderId.hasMatch(routeId) ||
        !_safeProviderId.hasMatch(modelId) ||
        !startedAt.isUtc ||
        !endedAt.isUtc ||
        endedAt.isBefore(startedAt) ||
        costMicros < 0 ||
        costMicros > 1000000000000 ||
        inputUnits < 0 ||
        outputUnits < 0) {
      throw ArgumentError('Invalid privacy-safe cloud span');
    }
  }

  final String spanId;
  final String operationHash;
  final CloudCapability capability;
  final String routeId;
  final String modelId;
  final DateTime startedAt;
  final DateTime endedAt;
  final CloudSpanOutcome outcome;
  final int costMicros;
  final int inputUnits;
  final int outputUnits;

  Duration get duration => endedAt.difference(startedAt);

  @override
  String toString() => 'CloudOperationSpan('
      'span: $spanId, operation: ${operationHash.substring(0, 12)}, '
      'capability: ${capability.name}, route: $routeId, model: $modelId, '
      'outcome: ${outcome.name}, durationMs: ${duration.inMilliseconds}, '
      'costMicros: $costMicros, inputUnits: $inputUnits, '
      'outputUnits: $outputUnits'
      ')';
}

abstract interface class CloudSpanStore {
  Future<void> recordOnce(CloudOperationSpan span);
  Future<List<CloudOperationSpan>> listSince(DateTime since);
}

final class MemoryCloudSpanStore implements CloudSpanStore {
  final Map<String, CloudOperationSpan> _spans = <String, CloudOperationSpan>{};

  List<CloudOperationSpan> get spans =>
      List<CloudOperationSpan>.unmodifiable(_spans.values);

  @override
  Future<List<CloudOperationSpan>> listSince(DateTime since) async =>
      _spans.values
          .where((span) => !span.endedAt.isBefore(since))
          .toList(growable: false);

  @override
  Future<void> recordOnce(CloudOperationSpan span) async {
    final existing = _spans[span.spanId];
    if (existing == null) {
      _spans[span.spanId] = span;
      return;
    }
    if (!_sameSpan(existing, span)) {
      throw StateError('Cloud span idempotency conflict');
    }
  }
}

final class CloudCostLimit {
  CloudCostLimit({
    required this.capability,
    required this.window,
    required this.maximumWindowCostMicros,
    required this.maximumOperationCostMicros,
  })  : assert(window > Duration.zero),
        assert(maximumWindowCostMicros >= 0),
        assert(maximumOperationCostMicros >= 0),
        assert(maximumOperationCostMicros <= maximumWindowCostMicros);

  final CloudCapability capability;
  final Duration window;
  final int maximumWindowCostMicros;
  final int maximumOperationCostMicros;
}

enum CloudCostTripReason { singleOperation, windowTotal }

final class CloudCostTrip {
  const CloudCostTrip({
    required this.capability,
    required this.reason,
    required this.observedCostMicros,
    required this.trippedAt,
  });

  final CloudCapability capability;
  final CloudCostTripReason reason;
  final int observedCostMicros;
  final DateTime trippedAt;
}

final class CloudCostGuard {
  CloudCostGuard({
    required CloudSpanStore spans,
    required Iterable<CloudCostLimit> limits,
  }) : _spans = spans {
    for (final limit in limits) {
      if (_limits.containsKey(limit.capability)) {
        throw ArgumentError('Duplicate cloud cost limit');
      }
      _limits[limit.capability] = limit;
    }
    if (_limits.length != CloudCapability.values.length) {
      throw ArgumentError('Every cloud capability requires a cost limit');
    }
  }

  final CloudSpanStore _spans;
  final Map<CloudCapability, CloudCostLimit> _limits =
      <CloudCapability, CloudCostLimit>{};
  final Map<CloudCapability, CloudCostTrip> _trips =
      <CloudCapability, CloudCostTrip>{};

  CloudCostTrip? tripFor(CloudCapability capability) => _trips[capability];

  Future<CloudCostTrip?> record(CloudOperationSpan span) async {
    await _spans.recordOnce(span);
    final existing = _trips[span.capability];
    if (existing != null) return existing;
    final limit = _limits[span.capability]!;
    if (span.costMicros > limit.maximumOperationCostMicros) {
      return _trips[span.capability] = CloudCostTrip(
        capability: span.capability,
        reason: CloudCostTripReason.singleOperation,
        observedCostMicros: span.costMicros,
        trippedAt: span.endedAt,
      );
    }
    final window = await _spans.listSince(span.endedAt.subtract(limit.window));
    final total = window
        .where((candidate) => candidate.capability == span.capability)
        .fold<int>(0, (sum, candidate) => sum + candidate.costMicros);
    if (total > limit.maximumWindowCostMicros) {
      return _trips[span.capability] = CloudCostTrip(
        capability: span.capability,
        reason: CloudCostTripReason.windowTotal,
        observedCostMicros: total,
        trippedAt: span.endedAt,
      );
    }
    return null;
  }

  void reset(CloudCapability capability) => _trips.remove(capability);

  Future<List<CloudCostAggregate>> aggregate(DateTime since) async {
    if (!since.isUtc) throw ArgumentError.value(since, 'since');
    final spans = await _spans.listSince(since);
    final groups = <(CloudCapability, String), List<CloudOperationSpan>>{};
    for (final span in spans) {
      groups.putIfAbsent((span.capability, span.modelId), () => []).add(span);
    }
    final values = groups.entries.map((entry) {
      final items = entry.value;
      return CloudCostAggregate(
        capability: entry.key.$1,
        modelId: entry.key.$2,
        operationCount: items.length,
        failureCount: items
            .where((span) => span.outcome != CloudSpanOutcome.success)
            .length,
        totalCostMicros:
            items.fold<int>(0, (sum, span) => sum + span.costMicros),
        totalDuration: items.fold<Duration>(
          Duration.zero,
          (sum, span) => sum + span.duration,
        ),
      );
    }).toList(growable: false)
      ..sort((left, right) {
        final capability =
            left.capability.index.compareTo(right.capability.index);
        if (capability != 0) return capability;
        return left.modelId.compareTo(right.modelId);
      });
    return List<CloudCostAggregate>.unmodifiable(values);
  }
}

final class CloudCostAggregate {
  const CloudCostAggregate({
    required this.capability,
    required this.modelId,
    required this.operationCount,
    required this.failureCount,
    required this.totalCostMicros,
    required this.totalDuration,
  });

  final CloudCapability capability;
  final String modelId;
  final int operationCount;
  final int failureCount;
  final int totalCostMicros;
  final Duration totalDuration;
}

final class CloudKillSwitchSnapshot {
  CloudKillSwitchSnapshot({
    required this.version,
    required this.issuedAt,
    required this.expiresAt,
    required Iterable<CloudCapability> disabled,
    required this.reasonCode,
    required this.signature,
  }) : disabled = Set<CloudCapability>.unmodifiable(disabled) {
    if (version < 1 ||
        !issuedAt.isUtc ||
        !expiresAt.isUtc ||
        !expiresAt.isAfter(issuedAt) ||
        expiresAt.difference(issuedAt) > const Duration(days: 7) ||
        !_safeReason.hasMatch(reasonCode) ||
        signature.isEmpty ||
        signature.length > 4096) {
      throw ArgumentError('Invalid cloud kill-switch snapshot');
    }
  }

  final int version;
  final DateTime issuedAt;
  final DateTime expiresAt;
  final Set<CloudCapability> disabled;
  final String reasonCode;
  final String signature;

  String get canonicalPayload => jsonEncode(<String, Object>{
        'schema': 'river.cloud-kill-switch.v1',
        'version': version,
        'issuedAt': issuedAt.toIso8601String(),
        'expiresAt': expiresAt.toIso8601String(),
        'disabled': disabled.map((value) => value.name).toList()..sort(),
        'reasonCode': reasonCode,
      });

  @override
  String toString() => 'CloudKillSwitchSnapshot('
      'version: $version, issuedAt: $issuedAt, expiresAt: $expiresAt, '
      'disabled: ${disabled.map((value) => value.name).join(',')}, '
      'reasonCode: $reasonCode, signature: [REDACTED]'
      ')';
}

abstract interface class CloudKillSwitchVerifier {
  Future<bool> verify(String canonicalPayload, String signature);
}

abstract interface class CloudKillSwitchSource {
  Future<CloudKillSwitchSnapshot> fetch();
}

abstract interface class CloudKillSwitchStore {
  Future<CloudKillSwitchSnapshot?> read();
  Future<void> write(CloudKillSwitchSnapshot snapshot);
}

final class MemoryCloudKillSwitchStore implements CloudKillSwitchStore {
  CloudKillSwitchSnapshot? value;

  @override
  Future<CloudKillSwitchSnapshot?> read() async => value;

  @override
  Future<void> write(CloudKillSwitchSnapshot snapshot) async =>
      value = snapshot;
}

abstract interface class CloudGovernanceClock {
  DateTime now();
}

final class SystemCloudGovernanceClock implements CloudGovernanceClock {
  const SystemCloudGovernanceClock();

  @override
  DateTime now() => DateTime.now().toUtc();
}

enum CloudGovernanceFailureCode {
  fetchFailed,
  invalidSignature,
  expiredSnapshot,
  futureSnapshot,
  versionRollback,
  persistenceFailed,
}

final class CloudGovernanceFailure implements Exception {
  const CloudGovernanceFailure({required this.code, required this.retryable});

  final CloudGovernanceFailureCode code;
  final bool retryable;

  @override
  String toString() => 'CloudGovernanceFailure('
      'code: ${code.name}, retryable: $retryable'
      ')';
}

enum CloudGateReason {
  allowed,
  remoteDisabled,
  costGuard,
  missingPolicy,
  expiredPolicy,
}

final class CloudGateDecision {
  const CloudGateDecision({
    required this.allowed,
    required this.reason,
    required this.localCoreUnaffected,
  });

  final bool allowed;
  final CloudGateReason reason;
  final bool localCoreUnaffected;
}

final class CloudKillSwitchController {
  CloudKillSwitchController({
    required CloudKillSwitchSource source,
    required CloudKillSwitchVerifier verifier,
    required CloudKillSwitchStore store,
    CloudGovernanceClock clock = const SystemCloudGovernanceClock(),
    this.fetchTimeout = const Duration(seconds: 10),
    this.maximumFutureSkew = const Duration(minutes: 5),
  })  : _source = source,
        _verifier = verifier,
        _store = store,
        _clock = clock;

  final CloudKillSwitchSource _source;
  final CloudKillSwitchVerifier _verifier;
  final CloudKillSwitchStore _store;
  final CloudGovernanceClock _clock;
  final Duration fetchTimeout;
  final Duration maximumFutureSkew;

  Future<CloudKillSwitchSnapshot> refresh() async {
    CloudKillSwitchSnapshot candidate;
    try {
      candidate = await _source.fetch().timeout(fetchTimeout);
    } on Object {
      throw const CloudGovernanceFailure(
        code: CloudGovernanceFailureCode.fetchFailed,
        retryable: true,
      );
    }
    final now = _utcNow();
    if (candidate.issuedAt.isAfter(now.add(maximumFutureSkew))) {
      throw const CloudGovernanceFailure(
        code: CloudGovernanceFailureCode.futureSnapshot,
        retryable: false,
      );
    }
    if (!candidate.expiresAt.isAfter(now)) {
      throw const CloudGovernanceFailure(
        code: CloudGovernanceFailureCode.expiredSnapshot,
        retryable: true,
      );
    }
    if (!await _verifier.verify(
      candidate.canonicalPayload,
      candidate.signature,
    )) {
      throw const CloudGovernanceFailure(
        code: CloudGovernanceFailureCode.invalidSignature,
        retryable: false,
      );
    }
    final current = await _store.read();
    if (current != null && candidate.version < current.version) {
      throw const CloudGovernanceFailure(
        code: CloudGovernanceFailureCode.versionRollback,
        retryable: false,
      );
    }
    if (current != null &&
        candidate.version == current.version &&
        candidate.canonicalPayload != current.canonicalPayload) {
      throw const CloudGovernanceFailure(
        code: CloudGovernanceFailureCode.versionRollback,
        retryable: false,
      );
    }
    try {
      await _store.write(candidate);
    } on Object {
      throw const CloudGovernanceFailure(
        code: CloudGovernanceFailureCode.persistenceFailed,
        retryable: true,
      );
    }
    return candidate;
  }

  Future<CloudGateDecision> decision(CloudCapability capability) async {
    final snapshot = await _store.read();
    if (snapshot == null) {
      return const CloudGateDecision(
        allowed: false,
        reason: CloudGateReason.missingPolicy,
        localCoreUnaffected: true,
      );
    }
    if (!snapshot.expiresAt.isAfter(_utcNow())) {
      return const CloudGateDecision(
        allowed: false,
        reason: CloudGateReason.expiredPolicy,
        localCoreUnaffected: true,
      );
    }
    if (snapshot.disabled.contains(capability)) {
      return const CloudGateDecision(
        allowed: false,
        reason: CloudGateReason.remoteDisabled,
        localCoreUnaffected: true,
      );
    }
    return const CloudGateDecision(
      allowed: true,
      reason: CloudGateReason.allowed,
      localCoreUnaffected: true,
    );
  }

  DateTime _utcNow() {
    final value = _clock.now();
    if (!value.isUtc) throw StateError('Governance clock must return UTC');
    return value;
  }
}

final class CloudRuntimeGate {
  const CloudRuntimeGate({required this.remote, required this.costGuard});

  final CloudKillSwitchController remote;
  final CloudCostGuard costGuard;

  Future<CloudGateDecision> decision(CloudCapability capability) async {
    final remoteDecision = await remote.decision(capability);
    if (!remoteDecision.allowed) return remoteDecision;
    if (costGuard.tripFor(capability) != null) {
      return const CloudGateDecision(
        allowed: false,
        reason: CloudGateReason.costGuard,
        localCoreUnaffected: true,
      );
    }
    return remoteDecision;
  }
}

bool _sameSpan(CloudOperationSpan left, CloudOperationSpan right) =>
    left.spanId == right.spanId &&
    left.operationHash == right.operationHash &&
    left.capability == right.capability &&
    left.routeId == right.routeId &&
    left.modelId == right.modelId &&
    left.startedAt == right.startedAt &&
    left.endedAt == right.endedAt &&
    left.outcome == right.outcome &&
    left.costMicros == right.costMicros &&
    left.inputUnits == right.inputUnits &&
    left.outputUnits == right.outputUnits;

final _safeId = RegExp(r'^[A-Za-z0-9._:-]{3,256}$');
final _hash = RegExp(r'^[a-f0-9]{64}$');
final _safeProviderId = RegExp(r'^[A-Za-z0-9._:/-]{1,200}$');
final _safeReason = RegExp(r'^[a-z][a-z0-9_.-]{1,63}$');
