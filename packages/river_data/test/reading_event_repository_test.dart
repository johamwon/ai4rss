import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:river_data/river_data.dart';
import 'package:river_domain/river_domain.dart' as domain;
import 'package:test/test.dart';

void main() {
  late RiverDatabase database;
  late DriftReadingEventRepository repository;
  Directory? directoryToDelete;

  setUp(() async {
    directoryToDelete = null;
    database = RiverDatabase(NativeDatabase.memory());
    repository = DriftReadingEventRepository(database);
    await _seedArticle(database);
  });

  tearDown(() async {
    await database.close();
    final directory = directoryToDelete;
    if (directory != null && directory.existsSync()) {
      directory.deleteSync(recursive: true);
    }
  });

  test('replaying an identical event is idempotent', () async {
    final event = domain.ReadingEvent(
      eventId: 'device-1:1',
      articleId: 'article-1',
      type: domain.ReadingEventType.activeRead,
      occurredAt: DateTime.utc(2026, 7, 30, 12),
      activeSeconds: 30,
      completionRatio: 0.4,
    );

    expect(
      await repository.record(event),
      domain.ReadingEventRecordResult.inserted,
    );
    expect(
      await repository.record(event),
      domain.ReadingEventRecordResult.duplicate,
    );
    final concurrent = await Future.wait(
      List<Future<domain.ReadingEventRecordResult>>.generate(
        4,
        (_) => repository.record(event),
      ),
    );

    expect(concurrent, everyElement(domain.ReadingEventRecordResult.duplicate));
    expect(await database.select(database.readingEvents).get(), hasLength(1));
  });

  test('reusing an event ID for different content is rejected', () async {
    final at = DateTime.utc(2026, 7, 30, 12);
    await repository.record(
      domain.ReadingEvent(
        eventId: 'device-1:2',
        articleId: 'article-1',
        type: domain.ReadingEventType.open,
        occurredAt: at,
      ),
    );

    expect(
      () => repository.record(
        domain.ReadingEvent(
          eventId: 'device-1:2',
          articleId: 'article-1',
          type: domain.ReadingEventType.starred,
          occurredAt: at,
        ),
      ),
      throwsA(isA<domain.ReadingEventIdentityConflict>()),
    );
    expect(await database.select(database.readingEvents).get(), hasLength(1));
  });

  test(
    'capture is local by default and disabling it blocks new rows',
    () async {
      expect(
        await repository.readSettings(),
        const domain.ReadingBehaviorSettings(),
      );
      expect(
        await repository.watchSettings().first,
        const domain.ReadingBehaviorSettings(),
      );
      await repository.saveSettings(
        const domain.ReadingBehaviorSettings(
          captureEnabled: false,
          retentionDays: 30,
        ),
        updatedAt: DateTime.utc(2026, 7, 30),
      );

      expect(
        await repository.record(_openEvent('disabled-event')),
        domain.ReadingEventRecordResult.captureDisabled,
      );
      expect(await database.select(database.readingEvents).get(), isEmpty);
      expect(
        await repository.readSettings(),
        const domain.ReadingBehaviorSettings(
          captureEnabled: false,
          retentionDays: 30,
        ),
      );
    },
  );

  test(
    'retention purges only events older than the configured boundary',
    () async {
      final now = DateTime.utc(2026, 7, 30, 12);
      await repository.record(
        _openEvent('old', at: now.subtract(const Duration(days: 91))),
      );
      await repository.record(
        _openEvent('boundary', at: now.subtract(const Duration(days: 90))),
      );
      await repository.record(
        _openEvent('recent', at: now.subtract(const Duration(days: 1))),
      );

      expect(await repository.purgeExpired(now: now), 1);
      expect(
        (await repository.readEvents()).map((event) => event.eventId),
        <String>['boundary', 'recent'],
      );
    },
  );

  test('export is stable and excludes article content', () async {
    await repository.record(
      _openEvent('later', at: DateTime.utc(2026, 7, 30, 13)),
    );
    await repository.record(
      _openEvent('earlier', at: DateTime.utc(2026, 7, 30, 12)),
    );

    final export =
        jsonDecode(
              await repository.exportJson(
                exportedAt: DateTime.utc(2026, 7, 31),
              ),
            )
            as Map<String, Object?>;
    final events = (export['events'] as List).cast<Map<String, Object?>>();

    expect(events.map((event) => event['eventId']), <String>[
      'earlier',
      'later',
    ]);
    expect(export.toString(), isNot(contains('Article')));
    expect(export.toString(), isNot(contains('https://example.test')));
  });

  test(
    'clear uses secure deletion and leaves no event identity on disk',
    () async {
      await database.close();
      final directory = Directory.systemTemp.createTempSync('river-events-');
      directoryToDelete = directory;
      final file = File('${directory.path}${Platform.pathSeparator}river.db');
      database = RiverDatabase(NativeDatabase(file));
      repository = DriftReadingEventRepository(database);
      await _seedArticle(database);
      await repository.record(_openEvent('private-event-identity'));

      expect(_databaseBytes(directory), contains('private-event-identity'));
      final secureDelete = await database
          .customSelect('PRAGMA secure_delete')
          .getSingle();
      expect(secureDelete.read<int>('secure_delete'), 1);
      expect(await repository.clearEvents(), 1);

      expect(
        _databaseBytes(directory),
        isNot(contains('private-event-identity')),
      );
    },
  );
}

domain.ReadingEvent _openEvent(String id, {DateTime? at}) =>
    domain.ReadingEvent(
      eventId: id,
      articleId: 'article-1',
      type: domain.ReadingEventType.open,
      occurredAt: at ?? DateTime.utc(2026, 7, 30, 12),
    );

String _databaseBytes(Directory directory) => directory
    .listSync()
    .whereType<File>()
    .map((file) => latin1.decode(file.readAsBytesSync()))
    .join();

Future<void> _seedArticle(RiverDatabase database) async {
  final now = DateTime.utc(2026, 7, 30);
  await database
      .into(database.feedSubscriptions)
      .insert(
        FeedSubscriptionsCompanion.insert(
          id: 'feed-1',
          canonicalUrl: 'https://example.test/feed.xml',
          title: 'Example',
          feedKind: 'rss',
          createdAt: now,
          updatedAt: now,
        ),
      );
  await database
      .into(database.articles)
      .insert(
        ArticlesCompanion.insert(
          id: 'article-1',
          feedId: 'feed-1',
          canonicalUrl: 'https://example.test/article-1',
          title: 'Article',
          createdAt: now,
          updatedAt: now,
        ),
      );
}
