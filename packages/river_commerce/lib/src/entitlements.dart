import 'dart:async';
import 'dart:convert';

enum EntitlementKey {
  subscriptions,
  localReading,
  fullTextExtraction,
  offlineReading,
  systemTts,
  podcastPlayback,
  localKnowledge,
  portableExport,
  bringYourOwnKey,
  managedAi,
  encryptedSync,
  cloudExtraction,
  cloudTts,
  podcastTranscription,
  semanticKnowledge,
  automaticConnectors,
}

enum EntitlementTier { free, pro }

const Map<EntitlementKey, EntitlementTier> entitlementTierMatrix =
    <EntitlementKey, EntitlementTier>{
  EntitlementKey.subscriptions: EntitlementTier.free,
  EntitlementKey.localReading: EntitlementTier.free,
  EntitlementKey.fullTextExtraction: EntitlementTier.free,
  EntitlementKey.offlineReading: EntitlementTier.free,
  EntitlementKey.systemTts: EntitlementTier.free,
  EntitlementKey.podcastPlayback: EntitlementTier.free,
  EntitlementKey.localKnowledge: EntitlementTier.free,
  EntitlementKey.portableExport: EntitlementTier.free,
  EntitlementKey.bringYourOwnKey: EntitlementTier.free,
  EntitlementKey.managedAi: EntitlementTier.pro,
  EntitlementKey.encryptedSync: EntitlementTier.pro,
  EntitlementKey.cloudExtraction: EntitlementTier.pro,
  EntitlementKey.cloudTts: EntitlementTier.pro,
  EntitlementKey.podcastTranscription: EntitlementTier.pro,
  EntitlementKey.semanticKnowledge: EntitlementTier.pro,
  EntitlementKey.automaticConnectors: EntitlementTier.pro,
};

Set<EntitlementKey> get freeEntitlements => Set<EntitlementKey>.unmodifiable(
      entitlementTierMatrix.entries
          .where((entry) => entry.value == EntitlementTier.free)
          .map((entry) => entry.key),
    );

bool isFreeEntitlement(EntitlementKey key) =>
    entitlementTierMatrix[key] == EntitlementTier.free;

enum EntitlementPlan { free, pro, trial, founding }

final class EntitlementSnapshot {
  EntitlementSnapshot({
    required this.revision,
    required this.subjectHash,
    required this.plan,
    required Iterable<EntitlementKey> granted,
    required this.issuedAt,
    required this.refreshAfter,
    required this.validUntil,
    required this.signature,
  }) : granted = Set<EntitlementKey>.unmodifiable(granted) {
    if (revision < 1 ||
        !_subjectHash.hasMatch(subjectHash) ||
        !issuedAt.isUtc ||
        !refreshAfter.isUtc ||
        !validUntil.isUtc ||
        !refreshAfter.isAfter(issuedAt) ||
        validUntil.isBefore(refreshAfter) ||
        validUntil.difference(issuedAt) > maximumSnapshotLifetime ||
        signature.isEmpty ||
        signature.length > 4096 ||
        (plan == EntitlementPlan.free &&
            this.granted.any((key) => !isFreeEntitlement(key)))) {
      throw ArgumentError('Invalid entitlement snapshot');
    }
  }

  static const Duration maximumSnapshotLifetime = Duration(days: 7);

  final int revision;
  final String subjectHash;
  final EntitlementPlan plan;
  final Set<EntitlementKey> granted;
  final DateTime issuedAt;
  final DateTime refreshAfter;
  final DateTime validUntil;
  final String signature;

  String get canonicalPayload => jsonEncode(<String, Object>{
        'schema': 'river.entitlements.v1',
        'revision': revision,
        'subjectHash': subjectHash,
        'plan': plan.name,
        'granted': granted.map((key) => key.name).toList()..sort(),
        'issuedAt': issuedAt.toIso8601String(),
        'refreshAfter': refreshAfter.toIso8601String(),
        'validUntil': validUntil.toIso8601String(),
      });

  @override
  String toString() => 'EntitlementSnapshot('
      'revision: $revision, plan: ${plan.name}, '
      'issuedAt: $issuedAt, refreshAfter: $refreshAfter, '
      'validUntil: $validUntil, granted: '
      '${granted.map((key) => key.name).join(',')}, '
      'subjectHash: [REDACTED], signature: [REDACTED]'
      ')';
}

abstract interface class EntitlementSnapshotVerifier {
  Future<bool> verify(String canonicalPayload, String signature);
}

abstract interface class EntitlementSnapshotSource {
  Future<EntitlementSnapshot> fetch(String subjectHash);
}

abstract interface class EntitlementSnapshotStore {
  Future<EntitlementSnapshot?> read();
  Future<void> write(EntitlementSnapshot snapshot);
  Future<void> clear();
}

final class MemoryEntitlementSnapshotStore implements EntitlementSnapshotStore {
  EntitlementSnapshot? value;

  @override
  Future<void> clear() async => value = null;

  @override
  Future<EntitlementSnapshot?> read() async => value;

  @override
  Future<void> write(EntitlementSnapshot snapshot) async => value = snapshot;
}

abstract interface class EntitlementClock {
  DateTime now();
}

final class SystemEntitlementClock implements EntitlementClock {
  const SystemEntitlementClock();

  @override
  DateTime now() => DateTime.now().toUtc();
}

enum EntitlementFailureCode {
  accountRequired,
  fetchFailed,
  invalidSignature,
  subjectMismatch,
  futureSnapshot,
  expiredSnapshot,
  revisionRollback,
  invalidCachedSnapshot,
  persistenceFailed,
}

final class EntitlementFailure implements Exception {
  const EntitlementFailure({required this.code, required this.retryable});

  final EntitlementFailureCode code;
  final bool retryable;

  @override
  String toString() => 'EntitlementFailure('
      'code: ${code.name}, retryable: $retryable'
      ')';
}

enum EntitlementGateReason {
  freeBaseline,
  verifiedSnapshot,
  offlineCache,
  notEntitled,
  missingSnapshot,
  refreshRequired,
  expiredSnapshot,
  invalidSnapshot,
}

final class EntitlementGateDecision {
  const EntitlementGateDecision({
    required this.allowed,
    required this.reason,
    required this.key,
    required this.plan,
    required this.usesOfflineCache,
  });

  final bool allowed;
  final EntitlementGateReason reason;
  final EntitlementKey key;
  final EntitlementPlan plan;
  final bool usesOfflineCache;

  bool get freeCoreUnaffected => true;
}

final class EntitlementGate {
  EntitlementGate({
    required this.subjectHash,
    required EntitlementSnapshotSource source,
    required EntitlementSnapshotVerifier verifier,
    required EntitlementSnapshotStore store,
    EntitlementClock clock = const SystemEntitlementClock(),
    this.fetchTimeout = const Duration(seconds: 10),
    this.maximumFutureSkew = const Duration(minutes: 5),
  })  : _source = source,
        _verifier = verifier,
        _store = store,
        _clock = clock {
    if (this.subjectHash != null && !_subjectHash.hasMatch(this.subjectHash!)) {
      throw ArgumentError.value(this.subjectHash, 'subjectHash');
    }
  }

  final String? subjectHash;
  final EntitlementSnapshotSource _source;
  final EntitlementSnapshotVerifier _verifier;
  final EntitlementSnapshotStore _store;
  final EntitlementClock _clock;
  final Duration fetchTimeout;
  final Duration maximumFutureSkew;

  Future<EntitlementSnapshot> refresh() async {
    final expectedSubject = subjectHash;
    if (expectedSubject == null) {
      throw const EntitlementFailure(
        code: EntitlementFailureCode.accountRequired,
        retryable: false,
      );
    }
    EntitlementSnapshot candidate;
    try {
      candidate = await _source.fetch(expectedSubject).timeout(fetchTimeout);
    } on Object {
      throw const EntitlementFailure(
        code: EntitlementFailureCode.fetchFailed,
        retryable: true,
      );
    }
    await _verifyCandidate(candidate, allowExpired: false);

    EntitlementSnapshot? current;
    try {
      current = await _store.read();
    } on Object {
      throw const EntitlementFailure(
        code: EntitlementFailureCode.invalidCachedSnapshot,
        retryable: false,
      );
    }
    if (current != null) {
      await _verifyCached(current);
      if (candidate.revision < current.revision ||
          (candidate.revision == current.revision &&
              candidate.canonicalPayload != current.canonicalPayload)) {
        throw const EntitlementFailure(
          code: EntitlementFailureCode.revisionRollback,
          retryable: false,
        );
      }
    }
    try {
      await _store.write(candidate);
    } on Object {
      throw const EntitlementFailure(
        code: EntitlementFailureCode.persistenceFailed,
        retryable: true,
      );
    }
    return candidate;
  }

  Future<EntitlementGateDecision> decision(
    EntitlementKey key, {
    required bool networkAvailable,
  }) async {
    if (isFreeEntitlement(key)) {
      return EntitlementGateDecision(
        allowed: true,
        reason: EntitlementGateReason.freeBaseline,
        key: key,
        plan: EntitlementPlan.free,
        usesOfflineCache: false,
      );
    }

    EntitlementSnapshot? snapshot;
    try {
      snapshot = await _store.read();
      if (snapshot != null) await _verifyCached(snapshot);
    } on Object {
      return _denied(key, EntitlementGateReason.invalidSnapshot);
    }
    if (snapshot == null) {
      return _denied(key, EntitlementGateReason.missingSnapshot);
    }

    final now = _utcNow();
    if (!snapshot.validUntil.isAfter(now)) {
      return _denied(key, EntitlementGateReason.expiredSnapshot);
    }
    if (!snapshot.granted.contains(key)) {
      return _denied(key, EntitlementGateReason.notEntitled);
    }
    if (now.isAfter(snapshot.refreshAfter)) {
      if (networkAvailable) {
        return _denied(key, EntitlementGateReason.refreshRequired);
      }
      return EntitlementGateDecision(
        allowed: true,
        reason: EntitlementGateReason.offlineCache,
        key: key,
        plan: snapshot.plan,
        usesOfflineCache: true,
      );
    }
    return EntitlementGateDecision(
      allowed: true,
      reason: EntitlementGateReason.verifiedSnapshot,
      key: key,
      plan: snapshot.plan,
      usesOfflineCache: false,
    );
  }

  Future<void> _verifyCandidate(
    EntitlementSnapshot snapshot, {
    required bool allowExpired,
  }) async {
    if (subjectHash == null || snapshot.subjectHash != subjectHash) {
      throw const EntitlementFailure(
        code: EntitlementFailureCode.subjectMismatch,
        retryable: false,
      );
    }
    final now = _utcNow();
    if (snapshot.issuedAt.isAfter(now.add(maximumFutureSkew))) {
      throw const EntitlementFailure(
        code: EntitlementFailureCode.futureSnapshot,
        retryable: false,
      );
    }
    if (!allowExpired && !snapshot.validUntil.isAfter(now)) {
      throw const EntitlementFailure(
        code: EntitlementFailureCode.expiredSnapshot,
        retryable: true,
      );
    }
    if (!await _verifier.verify(
      snapshot.canonicalPayload,
      snapshot.signature,
    )) {
      throw const EntitlementFailure(
        code: EntitlementFailureCode.invalidSignature,
        retryable: false,
      );
    }
  }

  Future<void> _verifyCached(EntitlementSnapshot snapshot) async {
    try {
      await _verifyCandidate(snapshot, allowExpired: true);
    } on Object {
      throw const EntitlementFailure(
        code: EntitlementFailureCode.invalidCachedSnapshot,
        retryable: false,
      );
    }
  }

  EntitlementGateDecision _denied(
    EntitlementKey key,
    EntitlementGateReason reason,
  ) =>
      EntitlementGateDecision(
        allowed: false,
        reason: reason,
        key: key,
        plan: EntitlementPlan.free,
        usesOfflineCache: false,
      );

  DateTime _utcNow() {
    final value = _clock.now();
    if (!value.isUtc) throw StateError('Entitlement clock must return UTC');
    return value;
  }
}

final _subjectHash = RegExp(r'^[a-f0-9]{64}$');
