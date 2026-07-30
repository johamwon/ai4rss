import 'package:drift/drift.dart';
import 'package:river_domain/river_domain.dart' as domain;

import 'database.dart';

final class DriftReadingEventRepository
    implements domain.ReadingEventRepository {
  const DriftReadingEventRepository(this.database);

  final RiverDatabase database;

  @override
  Future<domain.ReadingEventRecordResult> record(domain.ReadingEvent event) {
    event.validate();
    return database.transaction(() async {
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
