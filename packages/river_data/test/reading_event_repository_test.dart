import 'package:drift/native.dart';
import 'package:river_data/river_data.dart';
import 'package:river_domain/river_domain.dart' as domain;
import 'package:test/test.dart';

void main() {
  late RiverDatabase database;
  late DriftReadingEventRepository repository;

  setUp(() async {
    database = RiverDatabase(NativeDatabase.memory());
    repository = DriftReadingEventRepository(database);
    await _seedArticle(database);
  });

  tearDown(() => database.close());

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
}

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
