import 'package:river_commerce/river_commerce.dart';
import 'package:test/test.dart';

void main() {
  test('free matrix is permanently available without an account', () async {
    final gate = _gate(
      store: MemoryEntitlementSnapshotStore(),
      subjectHash: null,
    );

    for (final key in freeEntitlements) {
      final decision = await gate.decision(key, networkAvailable: false);
      expect(decision.allowed, isTrue, reason: key.name);
      expect(decision.reason, EntitlementGateReason.freeBaseline);
    }
    expect(
      freeEntitlements,
      containsAll(<EntitlementKey>{
        EntitlementKey.fullTextExtraction,
        EntitlementKey.offlineReading,
        EntitlementKey.systemTts,
        EntitlementKey.podcastPlayback,
        EntitlementKey.localKnowledge,
        EntitlementKey.portableExport,
        EntitlementKey.bringYourOwnKey,
      }),
    );
    expect(
      (await gate.decision(
        EntitlementKey.managedAi,
        networkAvailable: false,
      ))
          .allowed,
      isFalse,
    );
    await _expectFailure(
      gate.refresh(),
      EntitlementFailureCode.accountRequired,
    );
  });

  test('verified Pro snapshot grants only listed Pro capabilities', () async {
    final snapshot = _snapshot(
      revision: 1,
      granted: const <EntitlementKey>{
        EntitlementKey.managedAi,
        EntitlementKey.cloudTts,
      },
    );
    final store = MemoryEntitlementSnapshotStore();
    final gate = _gate(store: store, snapshot: snapshot);

    expect((await gate.refresh()).revision, 1);
    final managed = await gate.decision(
      EntitlementKey.managedAi,
      networkAvailable: true,
    );
    expect(managed.allowed, isTrue);
    expect(managed.reason, EntitlementGateReason.verifiedSnapshot);
    expect(managed.plan, EntitlementPlan.pro);
    expect(
      (await gate.decision(
        EntitlementKey.cloudExtraction,
        networkAvailable: true,
      ))
          .reason,
      EntitlementGateReason.notEntitled,
    );
  });

  test('canonical payload is deterministic and diagnostics are redacted', () {
    final first = _snapshot(
      revision: 1,
      signature: 'PRIVATE-SIGNATURE',
      granted: const <EntitlementKey>{
        EntitlementKey.cloudTts,
        EntitlementKey.managedAi,
      },
    );
    final second = _snapshot(
      revision: 1,
      signature: 'another-signature',
      granted: const <EntitlementKey>{
        EntitlementKey.managedAi,
        EntitlementKey.cloudTts,
      },
    );

    expect(first.canonicalPayload, second.canonicalPayload);
    expect(first.canonicalPayload, isNot(contains('PRIVATE-SIGNATURE')));
    expect('$first', isNot(contains(_subject)));
    expect('$first', isNot(contains('PRIVATE-SIGNATURE')));
  });

  test('forged snapshot is rejected without replacing trusted cache', () async {
    final trusted = _snapshot(revision: 1);
    final store = MemoryEntitlementSnapshotStore()..value = trusted;
    final gate = _gate(
      store: store,
      snapshot: _snapshot(revision: 2, signature: 'forged'),
    );

    await _expectFailure(
      gate.refresh(),
      EntitlementFailureCode.invalidSignature,
    );
    expect(store.value?.revision, 1);
  });

  test('snapshot is bound to the expected account subject', () async {
    final gate = _gate(
      store: MemoryEntitlementSnapshotStore(),
      snapshot: _snapshot(revision: 1, subjectHash: _otherSubject),
    );

    await _expectFailure(
      gate.refresh(),
      EntitlementFailureCode.subjectMismatch,
    );
  });

  test('revision rollback and same-revision mutation are rejected', () async {
    final current = _snapshot(revision: 2);
    final rollbackStore = MemoryEntitlementSnapshotStore()..value = current;
    await _expectFailure(
      _gate(
        store: rollbackStore,
        snapshot: _snapshot(revision: 1),
      ).refresh(),
      EntitlementFailureCode.revisionRollback,
    );

    final mutationStore = MemoryEntitlementSnapshotStore()..value = current;
    await _expectFailure(
      _gate(
        store: mutationStore,
        snapshot: _snapshot(
          revision: 2,
          granted: const <EntitlementKey>{EntitlementKey.cloudTts},
        ),
      ).refresh(),
      EntitlementFailureCode.revisionRollback,
    );
  });

  test('expired and excessively future snapshots cannot be refreshed',
      () async {
    final expired = _snapshot(
      revision: 1,
      issuedAt: DateTime.utc(2026, 8, 4, 12),
      refreshAfter: DateTime.utc(2026, 8, 4, 13),
      validUntil: DateTime.utc(2026, 8, 5, 12),
    );
    await _expectFailure(
      _gate(
        store: MemoryEntitlementSnapshotStore(),
        snapshot: expired,
      ).refresh(),
      EntitlementFailureCode.expiredSnapshot,
    );

    final future = _snapshot(
      revision: 1,
      issuedAt: DateTime.utc(2026, 8, 6, 13),
      refreshAfter: DateTime.utc(2026, 8, 6, 14),
      validUntil: DateTime.utc(2026, 8, 7, 13),
    );
    await _expectFailure(
      _gate(
        store: MemoryEntitlementSnapshotStore(),
        snapshot: future,
      ).refresh(),
      EntitlementFailureCode.futureSnapshot,
    );
  });

  test('stale verified snapshot supports bounded offline access', () async {
    final store = MemoryEntitlementSnapshotStore()
      ..value = _snapshot(
        revision: 1,
        refreshAfter: DateTime.utc(2026, 8, 6, 11),
        validUntil: DateTime.utc(2026, 8, 7, 12),
      );
    final decision = await _gate(store: store).decision(
      EntitlementKey.managedAi,
      networkAvailable: false,
    );

    expect(decision.allowed, isTrue);
    expect(decision.reason, EntitlementGateReason.offlineCache);
    expect(decision.usesOfflineCache, isTrue);
  });

  test('stale online snapshot requires refresh before paid work', () async {
    final store = MemoryEntitlementSnapshotStore()
      ..value = _snapshot(
        revision: 1,
        refreshAfter: DateTime.utc(2026, 8, 6, 11),
        validUntil: DateTime.utc(2026, 8, 7, 12),
      );
    final decision = await _gate(store: store).decision(
      EntitlementKey.managedAi,
      networkAvailable: true,
    );

    expect(decision.allowed, isFalse);
    expect(decision.reason, EntitlementGateReason.refreshRequired);
  });

  test('trial expiry and Pro downgrade preserve every Free feature', () async {
    final store = MemoryEntitlementSnapshotStore()
      ..value = _snapshot(
        revision: 1,
        plan: EntitlementPlan.trial,
        issuedAt: DateTime.utc(2026, 8, 4, 12),
        refreshAfter: DateTime.utc(2026, 8, 4, 13),
        validUntil: DateTime.utc(2026, 8, 5, 12),
      );
    final gate = _gate(store: store);

    expect(
      (await gate.decision(
        EntitlementKey.managedAi,
        networkAvailable: false,
      ))
          .allowed,
      isFalse,
    );
    for (final key in freeEntitlements) {
      expect(
        (await gate.decision(key, networkAvailable: false)).allowed,
        isTrue,
        reason: key.name,
      );
    }
  });

  test('corrupt cached signature fails paid access closed', () async {
    final store = MemoryEntitlementSnapshotStore()
      ..value = _snapshot(revision: 1, signature: 'forged');
    final decision = await _gate(store: store).decision(
      EntitlementKey.managedAi,
      networkAvailable: false,
    );

    expect(decision.allowed, isFalse);
    expect(decision.reason, EntitlementGateReason.invalidSnapshot);
  });

  test('Free plan cannot encode a premium grant', () {
    expect(
      () => _snapshot(
        revision: 1,
        plan: EntitlementPlan.free,
        granted: const <EntitlementKey>{EntitlementKey.managedAi},
      ),
      throwsArgumentError,
    );
  });
}

const _subject =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _otherSubject =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

EntitlementSnapshot _snapshot({
  required int revision,
  String subjectHash = _subject,
  EntitlementPlan plan = EntitlementPlan.pro,
  Set<EntitlementKey> granted = const <EntitlementKey>{
    EntitlementKey.managedAi,
  },
  DateTime? issuedAt,
  DateTime? refreshAfter,
  DateTime? validUntil,
  String signature = 'valid',
}) =>
    EntitlementSnapshot(
      revision: revision,
      subjectHash: subjectHash,
      plan: plan,
      granted: granted,
      issuedAt: issuedAt ?? DateTime.utc(2026, 8, 6, 10),
      refreshAfter: refreshAfter ?? DateTime.utc(2026, 8, 6, 18),
      validUntil: validUntil ?? DateTime.utc(2026, 8, 7, 10),
      signature: signature,
    );

EntitlementGate _gate({
  required MemoryEntitlementSnapshotStore store,
  EntitlementSnapshot? snapshot,
  String? subjectHash = _subject,
}) =>
    EntitlementGate(
      subjectHash: subjectHash,
      source: _Source(snapshot ?? _snapshot(revision: 1)),
      verifier: const _Verifier(),
      store: store,
      clock: const _Clock(),
    );

Future<void> _expectFailure(
  Future<Object?> future,
  EntitlementFailureCode code,
) async {
  try {
    await future;
    fail('Expected ${code.name}');
  } on EntitlementFailure catch (error) {
    expect(error.code, code);
  }
}

final class _Source implements EntitlementSnapshotSource {
  const _Source(this.snapshot);

  final EntitlementSnapshot snapshot;

  @override
  Future<EntitlementSnapshot> fetch(String subjectHash) async => snapshot;
}

final class _Verifier implements EntitlementSnapshotVerifier {
  const _Verifier();

  @override
  Future<bool> verify(String canonicalPayload, String signature) async =>
      signature == 'valid' || signature == 'another-signature';
}

final class _Clock implements EntitlementClock {
  const _Clock();

  @override
  DateTime now() => DateTime.utc(2026, 8, 6, 12);
}
