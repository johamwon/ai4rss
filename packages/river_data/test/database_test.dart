import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:river_data/river_data.dart';
import 'package:test/test.dart';

void main() {
  late RiverDatabase database;

  setUp(() {
    database = RiverDatabase(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  test('v1 schema enforces canonical feed uniqueness', () async {
    final now = DateTime.utc(2026, 7, 15);
    final feed = FeedSubscriptionsCompanion.insert(
      id: 'feed-1',
      canonicalUrl: 'https://example.test/feed.xml',
      title: 'Example',
      feedKind: 'rss',
      createdAt: now,
      updatedAt: now,
    );
    await database.into(database.feedSubscriptions).insert(feed);

    expect(
      () => database
          .into(database.feedSubscriptions)
          .insert(feed.copyWith(id: const Value<String>('feed-2'))),
      throwsA(isA<Exception>()),
    );
  });

  test('deleting a feed cascades article content', () async {
    final now = DateTime.utc(2026, 7, 15);
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
    await database
        .into(database.articleContents)
        .insert(
          ArticleContentsCompanion.insert(
            articleId: 'article-1',
            sanitizedHtml: '<p>Safe</p>',
            markdown: 'Safe',
            plainText: 'Safe',
            extractorName: 'test',
            extractorVersion: '1',
            extractedAt: now,
          ),
        );

    await (database.delete(
      database.feedSubscriptions,
    )..where((table) => table.id.equals('feed-1'))).go();

    expect(await database.select(database.articles).get(), isEmpty);
    expect(await database.select(database.articleContents).get(), isEmpty);
  });
}
