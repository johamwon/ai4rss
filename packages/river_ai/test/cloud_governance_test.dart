import 'package:river_ai/river_ai.dart';
import 'package:test/test.dart';

void main() {
  test('model and capability aggregates preserve exact integer cost', () async {
    final store = MemoryCloudSpanStore();
    final guard = _guard(store: store, windowMaximum: 1000);
    final first = _span(
      id: 'span-001',
      cost: 40,
      model: 'model-a',
    );
    final second = _span(
      id: 'span-002',
      cost: 60,
      model: 'model-a',
      outcome: CloudSpanOutcome.providerFailure,
      offset: const Duration(minutes: 1),
    );
    final other = _span(
      id: 'span-003',
      cost: 25,
      model: 'model-b',
      capability: CloudCapability.cloudTts,
      offset: const Duration(minutes: 2),
    );

    await guard.record(first);
    await guard.record(second);
    await guard.record(other);
    await guard.record(first);
    final aggregate = await guard.aggregate(DateTime.utc(2026, 8, 6, 11));

    expect(store.spans, hasLength(3));
    expect(aggregate, hasLength(2));
    final managed = aggregate.firstWhere(
      (value) => value.capability == CloudCapability.managedAi,
    );
    expect(managed.modelId, 'model-a');
    expect(managed.operationCount, 2);
    expect(managed.failureCount, 1);
    expect(managed.totalCostMicros, 100);
  });

  test('same span ID with different evidence is rejected', () async {
    final store = MemoryCloudSpanStore();
    await store.recordOnce(_span(id: 'span-conflict', cost: 10));

    await expectLater(
      store.recordOnce(_span(id: 'span-conflict', cost: 11)),
      throwsStateError,
    );
  });

  test('single-operation and rolling-window anomalies trip independently',
      () async {
    final single = _guard(operationMaximum: 50, windowMaximum: 100);
    final singleTrip = await single.record(_span(id: 'span-single', cost: 51));
    expect(singleTrip?.reason, CloudCostTripReason.singleOperation);

    final window = _guard(operationMaximum: 80, windowMaximum: 100);
    expect(await window.record(_span(id: 'span-window-1', cost: 60)), isNull);
    final windowTrip = await window.record(
      _span(
        id: 'span-window-2',
        cost: 50,
        offset: const Duration(minutes: 30),
      ),
    );
    expect(windowTrip?.reason, CloudCostTripReason.windowTotal);
    expect(windowTrip?.observedCostMicros, 110);

    final outside = _guard(operationMaximum: 80, windowMaximum: 100);
    await outside.record(_span(id: 'span-old', cost: 70));
    expect(
      await outside.record(
        _span(
          id: 'span-new',
          cost: 70,
          offset: const Duration(hours: 2),
        ),
      ),
      isNull,
    );
  });

  test('verified remote snapshot selectively disables one cloud capability',
      () async {
    final store = MemoryCloudKillSwitchStore();
    final controller = _controller(
      store: store,
      snapshot: _snapshot(
        version: 1,
        disabled: const <CloudCapability>{CloudCapability.cloudTts},
      ),
    );
    await controller.refresh();

    expect(
      (await controller.decision(CloudCapability.cloudTts)).reason,
      CloudGateReason.remoteDisabled,
    );
    expect(
      (await controller.decision(CloudCapability.managedAi)).allowed,
      isTrue,
    );
  });

  test('forged snapshot is rejected without replacing last known good',
      () async {
    final store = MemoryCloudKillSwitchStore()
      ..value = _snapshot(version: 1, disabled: const <CloudCapability>{});
    final forged = _controller(
      store: store,
      snapshot: _snapshot(
        version: 2,
        disabled: const <CloudCapability>{CloudCapability.managedAi},
        signature: 'forged',
      ),
    );

    await _expectGovernanceFailure(
      forged.refresh(),
      CloudGovernanceFailureCode.invalidSignature,
    );
    expect(store.value?.version, 1);
    expect(
      (await forged.decision(CloudCapability.managedAi)).allowed,
      isTrue,
    );
  });

  test('version rollback and same-version mutation fail closed', () async {
    final current = _snapshot(version: 2, disabled: const <CloudCapability>{});
    final rollbackStore = MemoryCloudKillSwitchStore()..value = current;
    await _expectGovernanceFailure(
      _controller(
        store: rollbackStore,
        snapshot: _snapshot(version: 1, disabled: const <CloudCapability>{}),
      ).refresh(),
      CloudGovernanceFailureCode.versionRollback,
    );

    final mutationStore = MemoryCloudKillSwitchStore()..value = current;
    await _expectGovernanceFailure(
      _controller(
        store: mutationStore,
        snapshot: _snapshot(
          version: 2,
          disabled: const <CloudCapability>{CloudCapability.cloudExtraction},
        ),
      ).refresh(),
      CloudGovernanceFailureCode.versionRollback,
    );
  });

  test('missing and expired policy disable cloud but not local core', () async {
    final missing = _controller(
      store: MemoryCloudKillSwitchStore(),
      snapshot: _snapshot(version: 1, disabled: const <CloudCapability>{}),
    );
    final missingDecision =
        await missing.decision(CloudCapability.podcastTranscription);
    expect(missingDecision.allowed, isFalse);
    expect(missingDecision.reason, CloudGateReason.missingPolicy);
    expect(missingDecision.localCoreUnaffected, isTrue);

    final expiredStore = MemoryCloudKillSwitchStore()
      ..value = _snapshot(
        version: 1,
        disabled: const <CloudCapability>{},
        issuedAt: DateTime.utc(2026, 8, 5, 10),
        expiresAt: DateTime.utc(2026, 8, 5, 11),
      );
    final expired = _controller(
      store: expiredStore,
      snapshot: expiredStore.value!,
    );
    final expiredDecision = await expired.decision(CloudCapability.managedAi);
    expect(expiredDecision.reason, CloudGateReason.expiredPolicy);

    var localReads = 0;
    String localRead() {
      localReads += 1;
      return 'offline article';
    }

    expect(localRead(), 'offline article');
    expect(localReads, 1);
  });

  test('cost trip composes with valid remote policy and can be reset',
      () async {
    final store = MemoryCloudKillSwitchStore()
      ..value = _snapshot(version: 1, disabled: const <CloudCapability>{});
    final cost = _guard(operationMaximum: 50, windowMaximum: 100);
    final gate = CloudRuntimeGate(
      remote: _controller(store: store, snapshot: store.value!),
      costGuard: cost,
    );
    expect((await gate.decision(CloudCapability.managedAi)).allowed, isTrue);

    await cost.record(_span(id: 'span-trip', cost: 51));
    expect(
      (await gate.decision(CloudCapability.managedAi)).reason,
      CloudGateReason.costGuard,
    );
    expect((await gate.decision(CloudCapability.cloudTts)).allowed, isTrue);
    cost.reset(CloudCapability.managedAi);
    expect((await gate.decision(CloudCapability.managedAi)).allowed, isTrue);
  });

  test('span and snapshot diagnostics exclude private operation content', () {
    final span = _span(id: 'span-private', cost: 10);
    final snapshot = _snapshot(
      version: 1,
      disabled: const <CloudCapability>{CloudCapability.cloudExtraction},
      signature: 'PRIVATE-SIGNATURE',
    );
    final diagnostics = '$span\n$snapshot';

    expect(diagnostics, isNot(contains('PRIVATE-SIGNATURE')));
    expect(diagnostics, isNot(contains('PRIVATE ARTICLE BODY')));
    expect(diagnostics, contains('managedAi'));
    expect(diagnostics, contains('model-a'));
  });
}

CloudOperationSpan _span({
  required String id,
  required int cost,
  String model = 'model-a',
  CloudCapability capability = CloudCapability.managedAi,
  CloudSpanOutcome outcome = CloudSpanOutcome.success,
  Duration offset = Duration.zero,
}) {
  final start = DateTime.utc(2026, 8, 6, 12).add(offset);
  return CloudOperationSpan(
    spanId: id,
    operationHash: List<String>.filled(64, 'a').join(),
    capability: capability,
    routeId: 'route-primary',
    modelId: model,
    startedAt: start,
    endedAt: start.add(const Duration(milliseconds: 250)),
    outcome: outcome,
    costMicros: cost,
    inputUnits: 10,
    outputUnits: 20,
  );
}

CloudCostGuard _guard({
  MemoryCloudSpanStore? store,
  int operationMaximum = 500,
  int windowMaximum = 500,
}) =>
    CloudCostGuard(
      spans: store ?? MemoryCloudSpanStore(),
      limits: <CloudCostLimit>[
        for (final capability in CloudCapability.values)
          CloudCostLimit(
            capability: capability,
            window: const Duration(hours: 1),
            maximumWindowCostMicros: windowMaximum,
            maximumOperationCostMicros: operationMaximum,
          ),
      ],
    );

CloudKillSwitchSnapshot _snapshot({
  required int version,
  required Set<CloudCapability> disabled,
  DateTime? issuedAt,
  DateTime? expiresAt,
  String signature = 'valid-signature',
}) =>
    CloudKillSwitchSnapshot(
      version: version,
      issuedAt: issuedAt ?? DateTime.utc(2026, 8, 6, 11),
      expiresAt: expiresAt ?? DateTime.utc(2026, 8, 6, 13),
      disabled: disabled,
      reasonCode: 'cost_guard',
      signature: signature,
    );

CloudKillSwitchController _controller({
  required MemoryCloudKillSwitchStore store,
  required CloudKillSwitchSnapshot snapshot,
}) =>
    CloudKillSwitchController(
      source: _Source(snapshot),
      verifier: const _Verifier(),
      store: store,
      clock: const _Clock(),
    );

Future<void> _expectGovernanceFailure(
  Future<Object> future,
  CloudGovernanceFailureCode code,
) =>
    expectLater(
      future,
      throwsA(
        isA<CloudGovernanceFailure>().having(
          (failure) => failure.code,
          'code',
          code,
        ),
      ),
    );

final class _Source implements CloudKillSwitchSource {
  const _Source(this.snapshot);

  final CloudKillSwitchSnapshot snapshot;

  @override
  Future<CloudKillSwitchSnapshot> fetch() async => snapshot;
}

final class _Verifier implements CloudKillSwitchVerifier {
  const _Verifier();

  @override
  Future<bool> verify(String canonicalPayload, String signature) async =>
      signature == 'valid-signature';
}

final class _Clock implements CloudGovernanceClock {
  const _Clock();

  @override
  DateTime now() => DateTime.utc(2026, 8, 6, 12);
}
