import 'package:river_commerce/river_commerce.dart';
import 'package:test/test.dart';

void main() {
  test('retry reserves and commits an operation exactly once', () async {
    final ledger = _ledger(limit: 10);
    final first = await _reserve(ledger, 'operation-1', 3);
    final retry = await _reserve(ledger, 'operation-1', 3);
    await ledger.settle(
      operationId: first.operationId,
      producedUsableResult: true,
      at: _now.add(const Duration(seconds: 1)),
    );
    await ledger.settle(
      operationId: retry.operationId,
      producedUsableResult: true,
      at: _now.add(const Duration(seconds: 2)),
    );

    final snapshot = await ledger.snapshot('grant-summary');
    expect(snapshot.used, 3);
    expect(snapshot.reserved, 0);
    expect(snapshot.remaining, 7);
  });

  test('same operation ID with different evidence fails closed', () async {
    final ledger = _ledger(limit: 10);
    await _reserve(ledger, 'operation-conflict', 2);

    await expectLater(
      _reserve(ledger, 'operation-conflict', 3),
      throwsA(_failure(UsageLedgerFailureCode.idempotencyConflict)),
    );
  });

  test('failure and cancellation release reservations without charging',
      () async {
    final ledger = _ledger(limit: 10);
    await _reserve(ledger, 'operation-failed', 4);
    await ledger.settle(
      operationId: 'operation-failed',
      producedUsableResult: false,
      at: _now.add(const Duration(seconds: 1)),
    );
    await _reserve(ledger, 'operation-cancelled', 5);
    await ledger.refund(
      operationId: 'operation-cancelled',
      at: _now.add(const Duration(seconds: 2)),
    );

    final snapshot = await ledger.snapshot('grant-summary');
    expect(snapshot.used, 0);
    expect(snapshot.reserved, 0);
    expect(snapshot.remaining, 10);
  });

  test('committed usage can be refunded only once', () async {
    final ledger = _ledger(limit: 10);
    await _reserve(ledger, 'operation-refund', 6);
    await ledger.settle(
      operationId: 'operation-refund',
      producedUsableResult: true,
      at: _now.add(const Duration(seconds: 1)),
    );
    await ledger.refund(
      operationId: 'operation-refund',
      at: _now.add(const Duration(seconds: 2)),
    );
    await ledger.refund(
      operationId: 'operation-refund',
      at: _now.add(const Duration(seconds: 3)),
    );

    final snapshot = await ledger.snapshot('grant-summary');
    expect(snapshot.used, 0);
    expect(snapshot.entries.single.status, UsageLedgerStatus.refunded);
  });

  test('concurrent reservations cannot overdraw a grant', () async {
    final ledger = _ledger(limit: 10);
    final results = await Future.wait<Object>(
      <Future<Object>>[
        _reserve(ledger, 'operation-concurrent-a', 6),
        _reserve(ledger, 'operation-concurrent-b', 6),
      ].map((future) async {
        try {
          return await future;
        } on Object catch (error) {
          return error;
        }
      }),
    );

    expect(results.whereType<UsageLedgerEntry>(), hasLength(1));
    expect(
      results.whereType<UsageLedgerFailure>().single.code,
      UsageLedgerFailureCode.exhausted,
    );
    expect((await ledger.snapshot('grant-summary')).reserved, 6);
  });

  test('80 and 100 percent notices emit exactly once', () async {
    final ledger = _ledger(limit: 10);
    await _commit(ledger, 'operation-threshold-a', 7);
    expect((await ledger.snapshot('grant-summary')).notices, isEmpty);
    await _commit(ledger, 'operation-threshold-b', 1);
    await _commit(ledger, 'operation-threshold-c', 2);
    await ledger.settle(
      operationId: 'operation-threshold-c',
      producedUsableResult: true,
      at: _now.add(const Duration(seconds: 9)),
    );

    final notices = (await ledger.snapshot('grant-summary')).notices;
    expect(notices.map((notice) => notice.threshold), <UsageThreshold>[
      UsageThreshold.eightyPercent,
      UsageThreshold.exhausted,
    ]);
  });

  test('one commit can cross both thresholds without duplicate notices',
      () async {
    final ledger = _ledger(limit: 10);
    await _commit(ledger, 'operation-jump', 10);
    await ledger.settle(
      operationId: 'operation-jump',
      producedUsableResult: true,
      at: _now.add(const Duration(seconds: 4)),
    );

    expect((await ledger.snapshot('grant-summary')).notices, hasLength(2));
  });

  test('grant capability and validity boundaries are enforced', () async {
    final ledger = _ledger(limit: 10);
    await expectLater(
      ledger.reserve(
        operationId: 'operation-wrong-capability',
        requestHash: _hash,
        grantId: 'grant-summary',
        capability: EntitlementKey.cloudTts,
        units: 1,
        at: _now,
      ),
      throwsA(_failure(UsageLedgerFailureCode.capabilityMismatch)),
    );
    await expectLater(
      ledger.reserve(
        operationId: 'operation-expired',
        requestHash: _hash,
        grantId: 'grant-summary',
        capability: EntitlementKey.managedAi,
        units: 1,
        at: DateTime.utc(2026, 9, 1),
      ),
      throwsA(_failure(UsageLedgerFailureCode.grantInactive)),
    );
  });
}

const _hash =
    'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';
final _now = DateTime.utc(2026, 8, 6, 12);

UsageLedger _ledger({required int limit}) => UsageLedger(<UsageGrant>[
      UsageGrant(
        grantId: 'grant-summary',
        capability: EntitlementKey.managedAi,
        limit: limit,
        validFrom: DateTime.utc(2026, 8, 1),
        validUntil: DateTime.utc(2026, 9, 1),
      ),
    ]);

Future<UsageLedgerEntry> _reserve(
  UsageLedger ledger,
  String operationId,
  int units,
) =>
    ledger.reserve(
      operationId: operationId,
      requestHash: _hash,
      grantId: 'grant-summary',
      capability: EntitlementKey.managedAi,
      units: units,
      at: _now,
    );

Future<void> _commit(UsageLedger ledger, String operationId, int units) async {
  await _reserve(ledger, operationId, units);
  await ledger.settle(
    operationId: operationId,
    producedUsableResult: true,
    at: _now.add(const Duration(seconds: 1)),
  );
}

Matcher _failure(UsageLedgerFailureCode code) =>
    isA<UsageLedgerFailure>().having((failure) => failure.code, 'code', code);
