import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:river_sync/river_sync.dart';

import 'database.dart';

final class DriftSyncReplicaStore implements SyncReplicaStore {
  DriftSyncReplicaStore({
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
  Future<SyncCursor> readCursor() async {
    final row =
        await (_database.select(_database.syncCursorRows)..where(
              (table) =>
                  table.accountId.equals(accountId) &
                  table.deviceId.equals(deviceId),
            ))
            .getSingleOrNull();
    if (row == null) return SyncCursor.initial();
    return SyncCursor(
      protocolVersion: row.protocolVersion,
      serverSequence: row.serverSequence,
      opaqueToken: row.opaqueToken,
    );
  }

  @override
  Future<SyncReplicaRecord?> readRecord(
    SyncObjectKind objectKind,
    String objectId,
  ) async {
    final row =
        await (_database.select(_database.syncReplicaEntries)..where(
              (table) =>
                  table.accountId.equals(accountId) &
                  table.objectKind.equals(objectKind.name) &
                  table.objectId.equals(objectId),
            ))
            .getSingleOrNull();
    return row == null
        ? null
        : _decodeRecord(
            envelopeJson: row.envelopeJson,
            clearPayloadJson: row.clearPayloadJson,
          );
  }

  @override
  Future<void> commitLocal(SyncReplicaRecord record) =>
      _database.transaction(() async {
        _requireLocalRecordScope(record);
        final envelopeJson = SyncWireCodec.encodeEnvelope(record.envelope);
        final payloadJson = _encodePayload(record.decodedPayload);
        final existing =
            await (_database.select(_database.syncOutboxRows)..where(
                  (table) =>
                      table.mutationId.equals(record.envelope.mutationId),
                ))
                .getSingleOrNull();
        if (existing != null && existing.envelopeJson != envelopeJson) {
          throw StateError('Mutation ID collision in sync outbox.');
        }
        await _database
            .into(_database.syncReplicaEntries)
            .insert(
              SyncReplicaEntriesCompanion.insert(
                accountId: accountId,
                objectKind: record.envelope.objectKind.name,
                objectId: record.envelope.objectId,
                envelopeJson: envelopeJson,
                clearPayloadJson: payloadJson,
                updatedAt: record.envelope.occurredAt,
              ),
              mode: InsertMode.insertOrReplace,
            );
        if (existing == null) {
          await _database
              .into(_database.syncOutboxRows)
              .insert(
                SyncOutboxRowsCompanion.insert(
                  mutationId: record.envelope.mutationId,
                  accountId: accountId,
                  deviceId: deviceId,
                  envelopeJson: envelopeJson,
                  queuedAt: _now(),
                ),
              );
        }
      });

  @override
  Future<List<EncryptedSyncEnvelope>> readOutbox({required int limit}) async {
    if (limit <= 0 || limit > SyncProtocol.maximumBatchItems) {
      throw ArgumentError.value(limit, 'limit');
    }
    final rows =
        await (_database.select(_database.syncOutboxRows)
              ..where(
                (table) =>
                    table.accountId.equals(accountId) &
                    table.deviceId.equals(deviceId),
              )
              ..orderBy([
                (table) => OrderingTerm.asc(table.queuedAt),
                (table) => OrderingTerm.asc(table.mutationId),
              ])
              ..limit(limit))
            .get();
    return List<EncryptedSyncEnvelope>.unmodifiable(
      rows.map((row) => SyncWireCodec.decodeEnvelope(row.envelopeJson)),
    );
  }

  @override
  Future<void> acknowledgeOutbox(Set<String> mutationIds) async {
    if (mutationIds.isEmpty) return;
    if (mutationIds.length > SyncProtocol.maximumBatchItems) {
      throw ArgumentError.value(mutationIds.length, 'mutationIds');
    }
    await (_database.delete(_database.syncOutboxRows)..where(
          (table) =>
              table.accountId.equals(accountId) &
              table.deviceId.equals(deviceId) &
              table.mutationId.isIn(mutationIds),
        ))
        .go();
  }

  @override
  Future<void> commitRemotePage({
    required SyncCursor expectedCursor,
    required SyncCursor nextCursor,
    required List<SyncIncomingRecord> records,
  }) => _database.transaction(() async {
    final current = await readCursor();
    if (!_sameCursor(current, expectedCursor) ||
        !expectedCursor.canAdvanceTo(nextCursor)) {
      throw StateError('Sync cursor compare-and-swap failed.');
    }
    for (final incoming in records) {
      final record = incoming.record;
      if (record.envelope.accountId != accountId) {
        throw StateError('Remote sync record belongs to another account.');
      }
      switch (incoming.action) {
        case SyncIncomingAction.accept:
          await _writeReplicaRecord(record);
        case SyncIncomingAction.ignore:
          break;
        case SyncIncomingAction.conflict:
          await _database
              .into(_database.syncConflictRows)
              .insert(
                SyncConflictRowsCompanion.insert(
                  mutationId: record.envelope.mutationId,
                  accountId: accountId,
                  objectKind: record.envelope.objectKind.name,
                  objectId: record.envelope.objectId,
                  envelopeJson: SyncWireCodec.encodeEnvelope(record.envelope),
                  clearPayloadJson: _encodePayload(record.decodedPayload),
                  detectedAt: _now(),
                ),
                mode: InsertMode.insertOrIgnore,
              );
      }
    }
    await _database
        .into(_database.syncCursorRows)
        .insert(
          SyncCursorRowsCompanion.insert(
            accountId: accountId,
            deviceId: deviceId,
            protocolVersion: nextCursor.protocolVersion,
            serverSequence: nextCursor.serverSequence,
            opaqueToken: nextCursor.opaqueToken,
            updatedAt: _now(),
          ),
          mode: InsertMode.insertOrReplace,
        );
  });

  Future<void> _writeReplicaRecord(SyncReplicaRecord record) => _database
      .into(_database.syncReplicaEntries)
      .insert(
        SyncReplicaEntriesCompanion.insert(
          accountId: accountId,
          objectKind: record.envelope.objectKind.name,
          objectId: record.envelope.objectId,
          envelopeJson: SyncWireCodec.encodeEnvelope(record.envelope),
          clearPayloadJson: _encodePayload(record.decodedPayload),
          updatedAt: record.envelope.occurredAt,
        ),
        mode: InsertMode.insertOrReplace,
      );

  void _requireLocalRecordScope(SyncReplicaRecord record) {
    if (record.envelope.accountId != accountId ||
        record.envelope.authorDeviceId != deviceId) {
      throw ArgumentError('Local sync record scope does not match this store.');
    }
  }

  DateTime _now() {
    final value = _clock();
    if (!value.isUtc) throw StateError('Sync store clock must return UTC.');
    return value;
  }
}

String _encodePayload(DecodedSyncPayload payload) => utf8.decode(
  switch (payload) {
    DecodedSyncUpsert(:final payload) => SyncPayloadCodec.encodeUpsert(payload),
    DecodedSyncTombstone(:final tombstone) => SyncPayloadCodec.encodeTombstone(
      tombstone,
    ),
  },
);

SyncReplicaRecord _decodeRecord({
  required String envelopeJson,
  required String clearPayloadJson,
}) => SyncReplicaRecord(
  envelope: SyncWireCodec.decodeEnvelope(envelopeJson),
  decodedPayload: SyncPayloadCodec.decode(utf8.encode(clearPayloadJson)),
);

bool _sameCursor(SyncCursor left, SyncCursor right) =>
    left.protocolVersion == right.protocolVersion &&
    left.serverSequence == right.serverSequence &&
    left.opaqueToken == right.opaqueToken;

void _requireIdentifier(String value, String name) {
  if (value.isEmpty || value.trim() != value || value.length > 256) {
    throw ArgumentError.value(value, name, 'Invalid identifier.');
  }
}

DateTime _utcNow() => DateTime.now().toUtc();
