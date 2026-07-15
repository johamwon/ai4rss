import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:river_data/river_data.dart';
import 'package:river_feed/river_feed.dart' as feed;
import 'package:test/test.dart';

void main() {
  late RiverDatabase database;
  late DriftFeedRepository repository;

  setUp(() {
    database = RiverDatabase(NativeDatabase.memory());
    repository = DriftFeedRepository(database);
  });

  tearDown(() => database.close());

  test(
    'refresh upsert preserves article state and avoids duplicates',
    () async {
      final firstAt = DateTime.utc(2026, 7, 15);
      const parsedFeed = feed.ParsedFeed(
        kind: feed.FeedDocumentKind.rss,
        title: 'Example',
        items: <feed.ParsedFeedItem>[],
      );
      await repository.applyRefresh(
        feedId: 'feed-1',
        canonicalUrl: Uri.parse('https://example.test/feed.xml'),
        feed: parsedFeed,
        articles: <feed.FeedArticleDraft>[
          feed.FeedArticleDraft(
            id: 'article-1',
            canonicalUrl: Uri.parse('https://example.test/one'),
            title: 'Original title',
          ),
        ],
        refreshedAt: firstAt,
        etag: 'v1',
      );
      await (database.update(database.articles)
            ..where((table) => table.id.equals('article-1')))
          .write(const ArticlesCompanion(readState: Value<String>('read')));

      final secondAt = DateTime.utc(2026, 7, 16);
      await repository.applyRefresh(
        feedId: 'feed-1',
        canonicalUrl: Uri.parse('https://example.test/feed.xml'),
        feed: const feed.ParsedFeed(
          kind: feed.FeedDocumentKind.rss,
          title: 'Renamed feed',
          items: <feed.ParsedFeedItem>[],
        ),
        articles: <feed.FeedArticleDraft>[
          feed.FeedArticleDraft(
            id: 'discarded-new-id',
            canonicalUrl: Uri.parse('https://example.test/one'),
            title: 'Updated title',
          ),
        ],
        refreshedAt: secondAt,
        etag: 'v2',
      );

      final feeds = await repository.watchSubscriptions().first;
      final articles = await repository.watchArticles().first;
      expect(feeds, hasLength(1));
      expect(feeds.single.title, 'Renamed feed');
      expect(feeds.single.etag, 'v2');
      expect(articles, hasLength(1));
      expect(articles.single.id, 'article-1');
      expect(articles.single.title, 'Updated title');
      expect(articles.single.read, isTrue);
    },
  );

  test(
    'pause and delete are observable and delete cascades articles',
    () async {
      final now = DateTime.utc(2026, 7, 15);
      await repository.applyRefresh(
        feedId: 'feed-1',
        canonicalUrl: Uri.parse('https://example.test/feed.xml'),
        feed: const feed.ParsedFeed(
          kind: feed.FeedDocumentKind.atom,
          title: 'Example',
          items: <feed.ParsedFeedItem>[],
        ),
        articles: <feed.FeedArticleDraft>[
          feed.FeedArticleDraft(
            id: 'article-1',
            canonicalUrl: Uri.parse('https://example.test/one'),
            title: 'One',
          ),
        ],
        refreshedAt: now,
      );

      await repository.setEnabled(
        'feed-1',
        enabled: false,
        updatedAt: now.add(const Duration(minutes: 1)),
      );
      expect(
        (await repository.watchSubscriptions().first).single.enabled,
        isFalse,
      );

      await repository.delete('feed-1');
      expect(await repository.watchSubscriptions().first, isEmpty);
      expect(await repository.watchArticles().first, isEmpty);
    },
  );
}
