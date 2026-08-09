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

  test('behavior settings validate retention and preserve immutable updates',
      () {
    const defaults = ReadingBehaviorSettings();
    final enabled = defaults.copyWith(
      captureEnabled: true,
      retentionDays: 30,
    );

    expect(defaults.captureEnabled, isFalse);
    expect(defaults.retentionDays, 90);
    expect(
      enabled,
      const ReadingBehaviorSettings(
        captureEnabled: true,
        retentionDays: 30,
      ),
    );
    expect(
      () => const ReadingBehaviorSettings(retentionDays: 0).validate(),
      throwsFormatException,
    );
  });

  test('preference controls are bounded, comparable, and normalized', () {
    const controls = ReadingPreferenceControls(
      sourceScoreAdjustments: <String, double>{'feed-1': 2},
      topicScoreAdjustments: <String, double>{'flutter': -2},
      blockedSourceIds: <String>{'feed-2'},
      blockedTopics: <String>{'spoilers'},
    );
    controls.validate();

    expect(
      controls,
      const ReadingPreferenceControls(
        sourceScoreAdjustments: <String, double>{'feed-1': 2},
        topicScoreAdjustments: <String, double>{'flutter': -2},
        blockedSourceIds: <String>{'feed-2'},
        blockedTopics: <String>{'spoilers'},
      ),
    );
    expect(
      () => const ReadingPreferenceControls(
        topicScoreAdjustments: <String, double>{' Flutter ': 1},
      ).validate(),
      throwsFormatException,
    );
    expect(
      () => const ReadingPreferenceControls(
        sourceScoreAdjustments: <String, double>{'feed-1': 4.1},
      ).validate(),
      throwsFormatException,
    );
  });

  test('behavior export is ordered and contains only bounded event fields', () {
    final later = ReadingEvent(
      eventId: 'event-later',
      articleId: 'article-1',
      type: ReadingEventType.starred,
      occurredAt: DateTime.utc(2026, 7, 30, 13),
    );
    final earlier = ReadingEvent(
      eventId: 'event-earlier',
      articleId: 'article-1',
      type: ReadingEventType.open,
      occurredAt: DateTime.utc(2026, 7, 30, 12),
    );

    final export = jsonDecode(
      ReadingBehaviorExportCodec.encode(
        settings: const ReadingBehaviorSettings(),
        events: <ReadingEvent>[later, earlier],
        exportedAt: DateTime.utc(2026, 7, 31),
      ),
    ) as Map<String, Object?>;
    final events = (export['events'] as List).cast<Map<String, Object?>>();

    expect(export['schema'], readingBehaviorExportSchema);
    expect(export['version'], readingBehaviorExportSchemaVersion);
    final settings = export['settings']! as Map<String, Object?>;
    expect(
      settings['preferenceControls'],
      <String, Object>{
        'sourceScoreAdjustments': <String, double>{},
        'topicScoreAdjustments': <String, double>{},
        'blockedSourceIds': <String>[],
        'blockedTopics': <String>[],
      },
    );
    expect(events.map((event) => event['eventId']), <String>[
      'event-earlier',
      'event-later',
    ]);
    expect(export.toString(), isNot(contains('article body')));
    expect(
      events.first.keys,
      unorderedEquals(<String>[
        'schema',
        'version',
        'eventId',
        'articleId',
        'type',
        'occurredAt',
        'payload',
      ]),
    );
  });
}
