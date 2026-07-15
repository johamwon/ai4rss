import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:river_data/river_data.dart';
import 'package:river_domain/river_domain.dart' as domain;
import 'package:river_feed/river_feed.dart' as feed;
import 'package:test/test.dart';

final class _Ids implements domain.IdGenerator {
  var value = 0;

  @override
  String next() => 'generated-${++value}';
}

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

  test('OPML import is idempotent and preserves nested folder paths', () async {
    final source = File(
      '../../fixtures/opml/subscriptions_nested.opml',
    ).readAsStringSync();
    final document = const feed.OpmlCodec().parse(source);
    final ids = _Ids();
    final importedAt = DateTime.utc(2026, 7, 15);

    final first = await repository.importOpml(
      document: document,
      ids: ids,
      importedAt: importedAt,
    );

    expect(first.importedSubscriptions, 2);
    expect(first.createdFolders, 1);
    expect(first.skippedDuplicates, 1);
    expect(first.skippedInvalid, 1);
    final folders = await repository.watchFolders().first;
    expect(folders.single.path, <String>['技术', 'AI & 工具']);
    final subscriptions = await repository.watchSubscriptions().first;
    expect(subscriptions, hasLength(2));
    expect(
      subscriptions.singleWhere((item) => item.title == 'Example AI').folderId,
      folders.single.id,
    );
    expect(
      subscriptions.singleWhere((item) => item.title == 'Ungrouped').folderId,
      isNull,
    );

    final second = await repository.importOpml(
      document: document,
      ids: ids,
      importedAt: importedAt.add(const Duration(minutes: 1)),
    );
    expect(second.importedSubscriptions, 0);
    expect(second.createdFolders, 0);
    expect(second.skippedDuplicates, 3);
    expect(await repository.watchSubscriptions().first, hasLength(2));

    final exported = await repository.exportOpml();
    expect(exported.feeds, hasLength(2));
    expect(
      exported.feeds
          .singleWhere((item) => item.title == 'Example AI')
          .folderPath,
      <String>['技术', 'AI & 工具'],
    );
  });

  test('folder rename, move, and delete remain observable', () async {
    final now = DateTime.utc(2026, 7, 15);
    final folder = await repository.createFolder(
      id: 'folder-1',
      path: const <String>['Technology'],
      createdAt: now,
    );
    await repository.applyRefresh(
      feedId: 'feed-1',
      canonicalUrl: Uri.parse('https://example.test/feed.xml'),
      feed: const feed.ParsedFeed(
        kind: feed.FeedDocumentKind.rss,
        title: 'Example',
        items: <feed.ParsedFeedItem>[],
      ),
      articles: const <feed.FeedArticleDraft>[],
      refreshedAt: now,
    );

    await repository.moveFeed(
      feedId: 'feed-1',
      folderId: folder.id,
      updatedAt: now.add(const Duration(minutes: 1)),
    );
    expect(
      (await repository.watchSubscriptions().first).single.folderId,
      folder.id,
    );

    await repository.renameFolder(
      folderId: folder.id,
      name: 'Tech',
      updatedAt: now.add(const Duration(minutes: 2)),
    );
    expect((await repository.watchFolders().first).single.displayPath, 'Tech');

    await repository.deleteFolder(
      folderId: folder.id,
      updatedAt: now.add(const Duration(minutes: 3)),
    );
    expect(await repository.watchFolders().first, isEmpty);
    expect(
      (await repository.watchSubscriptions().first).single.folderId,
      isNull,
    );
  });

  test(
    'OPML import rolls back when a folder path cannot be persisted',
    () async {
      final document = feed.OpmlDocument(
        title: 'Rollback',
        feeds: <feed.OpmlFeedEntry>[
          feed.OpmlFeedEntry(
            title: 'First',
            xmlUrl: Uri.parse('https://first.test/rss'),
          ),
          feed.OpmlFeedEntry(
            title: 'Second',
            xmlUrl: Uri.parse('https://second.test/rss'),
            folderPath: <String>['x' * 250],
          ),
        ],
      );

      await expectLater(
        repository.importOpml(
          document: document,
          ids: _Ids(),
          importedAt: DateTime.utc(2026, 7, 15),
        ),
        throwsA(isA<feed.SubscriptionOrganizerException>()),
      );
      expect(await repository.watchSubscriptions().first, isEmpty);
      expect(await repository.watchFolders().first, isEmpty);
    },
  );
}
