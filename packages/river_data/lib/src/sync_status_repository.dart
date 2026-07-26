import 'package:drift/drift.dart';
import 'package:river_sync/river_sync.dart';

import 'database.dart';

final class DriftSyncStatusRepository implements SyncStatusRepository {
  DriftSyncStatusRepository({
    required RiverDatabase database,
    required this.accountId,
    required this.deviceId,
    DateTime Function()? clock,
  }) : _database = database,
       _clock = clock ?? _utcNow {
    _requireIdentifier(accountId, 'accountId');
    _requireIdentifier(deviceId, 'deviceId');
  }

  final RiverDatabase _database;
  final String accountId;
  final String deviceId;
  final DateTime Function() _clock;

  @override
  Future<SyncStorageStatus> readStatus() async {
    final pendingExpression = _database.syncOutboxRows.mutationId.count();
    final pendingQuery = _database.selectOnly(_database.syncOutboxRows)
      ..addColumns(<Expression<Object>>[pendingExpression])
      ..where(
        _database.syncOutboxRows.accountId.equals(accountId) &
            _database.syncOutboxRows.deviceId.equals(deviceId),
      );
    final conflictExpression = _database.syncConflictRows.mutationId.count();
    final conflictQuery = _database.selectOnly(_database.syncConflictRows)
      ..addColumns(<Expression<Object>>[conflictExpression])
      ..where(
        _database.syncConflictRows.accountId.equals(accountId) &
            _database.syncConflictRows.resolutionKind.equals('unresolved'),
      );
    final cursor =
        await (_database.select(_database.syncCursorRows)..where(
              (table) =>
                  table.accountId.equals(accountId) &
                  table.deviceId.equals(deviceId),
            ))
            .getSingleOrNull();
    final pending =
        (await pendingQuery.getSingle()).read(pendingExpression) ?? 0;
    final conflicts =
        (await conflictQuery.getSingle()).read(conflictExpression) ?? 0;
    return SyncStorageStatus(
      pendingMutations: pending,
      unresolvedConflicts: conflicts,
      serverSequence: cursor?.serverSequence ?? 0,
      updatedAt: cursor?.updatedAt.toUtc() ?? _now(),
    );
  }

  @override
  Future<List<SyncConflictHistoryEntry>> readConflictHistory({
    int limit = 100,
  }) async {
    if (limit <= 0 || limit > 500) {
      throw ArgumentError.value(limit, 'limit');
    }
    final rows =
        await (_database.select(_database.syncConflictRows)
              ..where((table) => table.accountId.equals(accountId))
              ..orderBy([
                (table) => OrderingTerm.desc(table.detectedAt),
                (table) => OrderingTerm.desc(table.mutationId),
              ])
              ..limit(limit))
            .get();
    return List<SyncConflictHistoryEntry>.unmodifiable(
      rows.map(
        (row) => SyncConflictHistoryEntry(
          mutationId: row.mutationId,
          objectKind: SyncObjectKind.values.byName(row.objectKind),
          objectId: row.objectId,
          detectedAt: row.detectedAt.toUtc(),
          resolutionKind: row.resolutionKind,
          resolutionMutationId: row.resolutionMutationId,
          resolvedAt: row.resolvedAt?.toUtc(),
        ),
      ),
    );
  }

  DateTime _now() {
    final value = _clock();
    if (!value.isUtc) {
      throw StateError('Sync status clock must return UTC.');
    }
    return value;
  }
}

void _requireIdentifier(String value, String name) {
  if (value.isEmpty || value.trim() != value || value.length > 256) {
    throw ArgumentError.value(value, name);
  }
}

DateTime _utcNow() => DateTime.now().toUtc();
