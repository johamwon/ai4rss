import 'package:drift/drift.dart';
import 'package:river_domain/river_domain.dart' as domain;

import 'database.dart';

final class DriftReadingEventRepository
    implements domain.ReadingBehaviorRepository {
  const DriftReadingEventRepository(this.database);

  final RiverDatabase database;

  static const _settingsId = 'reading-behavior';

  @override
  Future<bool> needsIntroduction() async => await _readSettingsRow() == null;

  @override
  Future<domain.ReadingEventRecordResult> record(domain.ReadingEvent event) {
    event.validate();
    return database.transaction(() async {
      final settings = await _readSettings();
      if (!settings.captureEnabled) {
        return domain.ReadingEventRecordResult.captureDisabled;
      }
      final existing = await _find(event);
      if (existing != null) {
        return _classifyExisting(existing, event);
      }

      final inserted = await database
          .into(database.readingEvents)
          .insertReturningOrNull(
            ReadingEventsCompanion.insert(
              id: event.eventId,
              articleId: event.articleId,
              eventKey: event.idempotencyKey,
              eventType: event.type.wireName,
              occurredAt: event.occurredAt.toUtc(),
              activeSeconds: Value<int>(event.activeSeconds),
              completionRatio: Value<double>(event.completionRatio),
            ),
            mode: InsertMode.insertOrIgnore,
          );
      if (inserted != null) {
        return domain.ReadingEventRecordResult.inserted;
      }

      final concurrent = await _find(event);
      if (concurrent == null) {
        throw StateError(
          'Reading event insert was ignored without a conflict.',
        );
      }
      return _classifyExisting(concurrent, event);
    });
  }

  @override
  Stream<domain.ReadingBehaviorSettings> watchSettings() {
    final query = database.select(database.readingBehaviorSettingsRows)
      ..where((row) => row.id.equals(_settingsId))
      ..limit(1);
    return query.watchSingleOrNull().map(_settingsFromRow);
  }

  @override
  Future<domain.ReadingBehaviorSettings> readSettings() => _readSettings();

  @override
  Future<void> saveSettings(
    domain.ReadingBehaviorSettings settings, {
    required DateTime updatedAt,
  }) async {
    settings.validate();
    await database
        .into(database.readingBehaviorSettingsRows)
        .insertOnConflictUpdate(
          ReadingBehaviorSettingsRowsCompanion.insert(
            id: _settingsId,
            captureEnabled: Value<bool>(settings.captureEnabled),
            retentionDays: Value<int>(settings.retentionDays),
            updatedAt: updatedAt.toUtc(),
          ),
        );
  }

  @override
  Future<List<domain.ReadingEvent>> readEvents() async {
    final query = database.select(database.readingEvents)
      ..orderBy([
        (row) => OrderingTerm.asc(row.occurredAt),
        (row) => OrderingTerm.asc(row.id),
      ]);
    final rows = await query.get();
    return List<domain.ReadingEvent>.unmodifiable(rows.map(_eventFromRow));
  }

  @override
  Future<int> purgeExpired({required DateTime now}) async {
    final settings = await _readSettings();
    final cutoff = now.toUtc().subtract(Duration(days: settings.retentionDays));
    final deleted = await (database.delete(
      database.readingEvents,
    )..where((row) => row.occurredAt.isSmallerThanValue(cutoff))).go();
    if (deleted > 0) {
      await _checkpointSecureDeletion();
    }
    return deleted;
  }

  @override
  Future<int> clearEvents() async {
    final deleted = await database.delete(database.readingEvents).go();
    if (deleted > 0) {
      await _checkpointSecureDeletion();
    }
    return deleted;
  }

  @override
  Future<String> exportJson({required DateTime exportedAt}) =>
      database.transaction(() async {
        final settings = await _readSettings();
        final events = await readEvents();
        return domain.ReadingBehaviorExportCodec.encode(
          settings: settings,
          events: events,
          exportedAt: exportedAt,
        );
      });

  Future<ReadingEvent?> _find(domain.ReadingEvent event) {
    final query = database.select(database.readingEvents)
      ..where(
        (row) =>
            row.id.equals(event.eventId) |
            row.eventKey.equals(event.idempotencyKey),
      )
      ..limit(1);
    return query.getSingleOrNull();
  }

  Future<domain.ReadingBehaviorSettings> _readSettings() async {
    return _settingsFromRow(await _readSettingsRow());
  }

  Future<ReadingBehaviorSettingsRow?> _readSettingsRow() {
    final query = database.select(database.readingBehaviorSettingsRows)
      ..where((row) => row.id.equals(_settingsId))
      ..limit(1);
    return query.getSingleOrNull();
  }

  Future<void> _checkpointSecureDeletion() =>
      database.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
}

domain.ReadingBehaviorSettings _settingsFromRow(
  ReadingBehaviorSettingsRow? row,
) {
  if (row == null) return const domain.ReadingBehaviorSettings();
  final settings = domain.ReadingBehaviorSettings(
    captureEnabled: row.captureEnabled,
    retentionDays: row.retentionDays,
  );
  settings.validate();
  return settings;
}

domain.ReadingEvent _eventFromRow(ReadingEvent row) {
  final expectedKey =
      '${domain.readingEventSchema}/${domain.readingEventSchemaVersion}/'
      '${row.id}';
  if (row.eventKey != expectedKey) {
    throw const FormatException('Unsupported stored reading event identity.');
  }
  final event = domain.ReadingEvent(
    eventId: row.id,
    articleId: row.articleId,
    type: domain.ReadingEventType.fromWireName(row.eventType),
    occurredAt: row.occurredAt.toUtc(),
    activeSeconds: row.activeSeconds,
    completionRatio: row.completionRatio,
  );
  event.validate();
  return event;
}

domain.ReadingEventRecordResult _classifyExisting(
  ReadingEvent row,
  domain.ReadingEvent event,
) {
  final sameEvent =
      row.id == event.eventId &&
      row.articleId == event.articleId &&
      row.eventKey == event.idempotencyKey &&
      row.eventType == event.type.wireName &&
      row.occurredAt.toUtc() == event.occurredAt.toUtc() &&
      row.activeSeconds == event.activeSeconds &&
      row.completionRatio == event.completionRatio;
  if (!sameEvent) {
    throw domain.ReadingEventIdentityConflict(event.eventId);
  }
  return domain.ReadingEventRecordResult.duplicate;
}
