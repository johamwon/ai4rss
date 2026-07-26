import 'package:drift/drift.dart';
import 'package:river_data/river_data.dart';
import 'package:river_sync/river_sync.dart';
import 'package:test/test.dart';

void main() {
  test('status and conflict history are account and device scoped', () async {
    final database = RiverDatabase.inMemory();
    addTearDown(database.close);
    final now = DateTime.utc(2026, 7, 27, 6);
    final repository = DriftSyncStatusRepository(
      database: database,
      accountId: 'account-1',
      deviceId: 'device-a',
      clock: () => now,
    );
    await database.batch((batch) {
      batch.insertAll(database.syncOutboxRows, <SyncOutboxRowsCompanion>[
        _outbox('mutation-a', 'account-1', 'device-a', now),
        _outbox('mutation-b', 'account-1', 'device-b', now),
        _outbox('mutation-c', 'account-2', 'device-a', now),
      ]);
      batch.insert(
        database.syncCursorRows,
        SyncCursorRowsCompanion.insert(
          accountId: 'account-1',
          deviceId: 'device-a',
          protocolVersion: 1,
          serverSequence: 42,
          opaqueToken: 'cursor-42',
          updatedAt: now,
        ),
      );
      batch.insertAll(database.syncConflictRows, <SyncConflictRowsCompanion>[
        _conflict(
          'remote-1',
          'account-1',
          now.subtract(const Duration(minutes: 1)),
          'unresolved',
        ),
        _conflict('remote-2', 'account-1', now, 'merged'),
        _conflict('remote-3', 'account-2', now, 'unresolved'),
      ]);
    });

    final status = await repository.readStatus();
    final history = await repository.readConflictHistory();

    expect(status.pendingMutations, 1);
    expect(status.unresolvedConflicts, 1);
    expect(status.serverSequence, 42);
    expect(status.updatedAt, now);
    expect(history.map((item) => item.mutationId), <String>[
      'remote-2',
      'remote-1',
    ]);
    expect(history.first.isResolved, isTrue);
    expect(history.last.objectKind, SyncObjectKind.subscription);
  });

  test('empty replica reports a stable zero status', () async {
    final database = RiverDatabase.inMemory();
    addTearDown(database.close);
    final now = DateTime.utc(2026, 7, 27, 6);
    final repository = DriftSyncStatusRepository(
      database: database,
      accountId: 'account-1',
      deviceId: 'device-a',
      clock: () => now,
    );

    final status = await repository.readStatus();

    expect(status.pendingMutations, 0);
    expect(status.unresolvedConflicts, 0);
    expect(status.serverSequence, 0);
    expect(status.updatedAt, now);
    expect(await repository.readConflictHistory(), isEmpty);
  });
}

SyncOutboxRowsCompanion _outbox(
  String mutationId,
  String accountId,
  String deviceId,
  DateTime queuedAt,
) => SyncOutboxRowsCompanion.insert(
  mutationId: mutationId,
  accountId: accountId,
  deviceId: deviceId,
  envelopeJson: '{}',
  queuedAt: queuedAt,
);

SyncConflictRowsCompanion _conflict(
  String mutationId,
  String accountId,
  DateTime detectedAt,
  String resolutionKind,
) => SyncConflictRowsCompanion.insert(
  mutationId: mutationId,
  accountId: accountId,
  objectKind: SyncObjectKind.subscription.name,
  objectId: 'subscription-$mutationId',
  envelopeJson: '{}',
  clearPayloadJson: '{}',
  detectedAt: detectedAt,
  resolutionKind: Value<String>(resolutionKind),
  resolutionMutationId: resolutionKind == 'unresolved'
      ? const Value<String?>.absent()
      : Value<String?>('resolution-$mutationId'),
  resolvedAt: resolutionKind == 'unresolved'
      ? const Value<DateTime?>.absent()
      : Value<DateTime?>(detectedAt),
);
