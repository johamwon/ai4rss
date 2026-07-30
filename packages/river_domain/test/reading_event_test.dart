import 'dart:convert';

import 'package:river_domain/river_domain.dart';
import 'package:test/test.dart';

void main() {
  test('v1 round-trips every stable event wire name', () {
    final at = DateTime.utc(2026, 7, 30, 12, 34, 56);
    final events = <ReadingEvent>[
      for (final type in ReadingEventType.values)
        ReadingEvent(
          eventId: 'event-${type.name}',
          articleId: 'article-1',
          type: type,
          occurredAt: at,
          activeSeconds: type == ReadingEventType.activeRead ? 45 : 0,
          completionRatio: type == ReadingEventType.completed ? 0.95 : 0,
        ),
    ];

    expect(
      events.map((event) => event.type.wireName),
      <String>[
        'impression',
        'open',
        'active_read',
        'completed',
        'starred',
        'saved_to_knowledge',
        'not_interested',
      ],
    );
    for (final event in events) {
      final json = event.toJson();
      final wire = jsonDecode(jsonEncode(json)) as Map<String, Object?>;
      final decoded = ReadingEvent.fromJson(wire);

      expect(json['schema'], readingEventSchema);
      expect(json['version'], readingEventSchemaVersion);
      expect(decoded.eventId, event.eventId);
      expect(decoded.articleId, event.articleId);
      expect(decoded.type, event.type);
      expect(decoded.occurredAt, at);
      expect(decoded.activeSeconds, event.activeSeconds);
      expect(decoded.completionRatio, event.completionRatio);
    }
  });

  test('future versions and unknown event types fail closed', () {
    final valid = ReadingEvent(
      eventId: 'event-1',
      articleId: 'article-1',
      type: ReadingEventType.open,
      occurredAt: DateTime.utc(2026, 7, 30),
    ).toJson();

    expect(
      () => ReadingEvent.fromJson(<String, Object?>{
        ...valid,
        'version': readingEventSchemaVersion + 1,
      }),
      throwsFormatException,
    );
    expect(
      () => ReadingEvent.fromJson(<String, Object?>{
        ...valid,
        'type': 'hovered',
      }),
      throwsFormatException,
    );
    expect(
      () => ReadingEvent.fromJson(<String, Object?>{
        ...valid,
        'articleTitle': 'Private title must not enter the schema',
      }),
      throwsFormatException,
    );
    expect(
      () => ReadingEvent.fromJson(<String, Object?>{
        ...valid,
        'occurredAt': '2026-07-30T12:00:00',
      }),
      throwsFormatException,
    );
  });

  test('event-specific progress payloads are validated', () {
    expect(
      () => ReadingEvent(
        eventId: 'active-without-time',
        articleId: 'article-1',
        type: ReadingEventType.activeRead,
        occurredAt: DateTime.utc(2026, 7, 30),
      ).toJson(),
      throwsFormatException,
    );
    expect(
      () => ReadingEvent(
        eventId: 'open-with-progress',
        articleId: 'article-1',
        type: ReadingEventType.open,
        occurredAt: DateTime.utc(2026, 7, 30),
        completionRatio: 0.5,
      ).toJson(),
      throwsFormatException,
    );
    expect(
      () => ReadingEvent(
        eventId: 'completed-without-progress',
        articleId: 'article-1',
        type: ReadingEventType.completed,
        occurredAt: DateTime.utc(2026, 7, 30),
      ).toJson(),
      throwsFormatException,
    );
  });

  test('idempotency key is stable and excludes mutable event payload', () {
    final first = ReadingEvent(
      eventId: 'device-1:42',
      articleId: 'article-1',
      type: ReadingEventType.open,
      occurredAt: DateTime.utc(2026, 7, 30),
    );
    final conflicting = ReadingEvent(
      eventId: 'device-1:42',
      articleId: 'article-2',
      type: ReadingEventType.starred,
      occurredAt: DateTime.utc(2026, 7, 31),
    );

    expect(first.idempotencyKey, 'river.reading-event/1/device-1:42');
    expect(conflicting.idempotencyKey, first.idempotencyKey);
  });
}
