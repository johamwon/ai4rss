import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
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

  test(
    'article views project source state and deterministic time order',
    () async {
      final now = DateTime.utc(2026, 7, 15);
      final folder = await repository.createFolder(
        id: 'folder-1',
        path: const <String>['技术'],
        createdAt: now,
      );
      await repository.applyRefresh(
        feedId: 'feed-1',
        canonicalUrl: Uri.parse('https://one.test/feed.xml'),
        feed: const feed.ParsedFeed(
          kind: feed.FeedDocumentKind.rss,
          title: 'One Feed',
          items: <feed.ParsedFeedItem>[],
        ),
        articles: <feed.FeedArticleDraft>[
          feed.FeedArticleDraft(
            id: 'article-1',
            canonicalUrl: Uri.parse('https://one.test/1'),
            title: 'Oldest',
            publishedAt: now,
          ),
          feed.FeedArticleDraft(
            id: 'article-2',
            canonicalUrl: Uri.parse('https://one.test/2'),
            title: 'Middle',
            publishedAt: now.add(const Duration(days: 1)),
          ),
        ],
        refreshedAt: now,
      );
      await repository.moveFeed(
        feedId: 'feed-1',
        folderId: folder.id,
        updatedAt: now,
      );
      await repository.applyRefresh(
        feedId: 'feed-2',
        canonicalUrl: Uri.parse('https://two.test/feed.xml'),
        feed: const feed.ParsedFeed(
          kind: feed.FeedDocumentKind.atom,
          title: 'Two Feed',
          items: <feed.ParsedFeedItem>[],
        ),
        articles: <feed.FeedArticleDraft>[
          feed.FeedArticleDraft(
            id: 'article-3',
            canonicalUrl: Uri.parse('https://two.test/3'),
            title: 'Newest',
            publishedAt: now.add(const Duration(days: 2)),
          ),
        ],
        refreshedAt: now,
      );
      await (database.update(database.articles)
            ..where((table) => table.id.equals('article-1')))
          .write(const ArticlesCompanion(starred: Value<bool>(true)));
      await (database.update(
        database.articles,
      )..where((table) => table.id.equals('article-2'))).write(
        const ArticlesCompanion(
          readState: Value<String>('read'),
          readLater: Value<bool>(true),
        ),
      );
      await database
          .into(database.articleContents)
          .insert(
            ArticleContentsCompanion.insert(
              articleId: 'article-1',
              sanitizedHtml: '<p>cached</p>',
              markdown: 'cached',
              plainText: '中' * 401,
              extractorName: 'fixture',
              extractorVersion: '1',
              extractedAt: now,
            ),
          );

      final inbox = await repository.watchArticles().first;
      expect(inbox.map((article) => article.id), <String>[
        'article-3',
        'article-2',
        'article-1',
      ]);
      expect(inbox.last.feedTitle, 'One Feed');
      expect(inbox.last.folderId, folder.id);
      expect(inbox.last.estimatedReadingMinutes, 2);

      final unread = await repository
          .watchArticles(
            query: const feed.FeedArticleQuery(
              view: feed.FeedArticleView.unread,
            ),
          )
          .first;
      expect(unread.map((article) => article.id), <String>[
        'article-3',
        'article-1',
      ]);
      expect(unread.every((article) => !article.read), isTrue);

      final starred = await repository
          .watchArticles(
            query: const feed.FeedArticleQuery(
              view: feed.FeedArticleView.starred,
            ),
          )
          .first;
      expect(starred.single.id, 'article-1');
      expect(starred.single.starred, isTrue);

      final readLater = await repository
          .watchArticles(
            query: const feed.FeedArticleQuery(
              view: feed.FeedArticleView.readLater,
            ),
          )
          .first;
      expect(readLater.single.id, 'article-2');
      expect(readLater.single.readLater, isTrue);

      final inFolder = await repository
          .watchArticles(
            query: feed.FeedArticleQuery(
              view: feed.FeedArticleView.folder,
              folderId: folder.id,
            ),
          )
          .first;
      expect(inFolder.map((article) => article.id), <String>[
        'article-2',
        'article-1',
      ]);

      final oldestFirst = await repository
          .watchArticles(
            query: const feed.FeedArticleQuery(
              sort: feed.FeedArticleSort.oldest,
            ),
          )
          .first;
      expect(oldestFirst.map((article) => article.id), <String>[
        'article-1',
        'article-2',
        'article-3',
      ]);
    },
  );

  test('article detail streams feed content then cached extraction', () async {
    final now = DateTime.utc(2026, 7, 19);
    await repository.applyRefresh(
      feedId: 'feed-1',
      canonicalUrl: Uri.parse('https://example.test/feed.xml'),
      feed: const feed.ParsedFeed(
        kind: feed.FeedDocumentKind.rss,
        title: 'Example Feed',
        items: <feed.ParsedFeedItem>[],
      ),
      articles: <feed.FeedArticleDraft>[
        feed.FeedArticleDraft(
          id: 'article-1',
          canonicalUrl: Uri.parse('https://example.test/article'),
          title: 'Progressive reader',
          summary: 'Immediate preview',
          contentHtml: '<p>Immediate feed body</p>',
        ),
      ],
      refreshedAt: now,
    );

    final initial = await repository.watchArticle('article-1').first;
    expect(initial, isNotNull);
    expect(initial!.feedTitle, 'Example Feed');
    expect(initial.feedContentHtml, '<p>Immediate feed body</p>');
    expect(initial.content, isNull);

    await database
        .into(database.articleContents)
        .insert(
          ArticleContentsCompanion.insert(
            articleId: 'article-1',
            sanitizedHtml: '<p>Complete cached body</p>',
            markdown: 'Complete cached body',
            plainText: 'Complete cached body',
            extractorName: 'readability',
            extractorVersion: '1',
            extractedAt: now,
          ),
        );
    await (database.update(database.articles)
          ..where((table) => table.id.equals('article-1')))
        .write(const ArticlesCompanion(contentHash: Value<String>('hash-1')));

    final enhanced = await repository
        .watchArticle('article-1')
        .firstWhere((article) => article?.content?.isReadable ?? false);
    expect(enhanced!.content!.plainText, 'Complete cached body');
    expect(enhanced.content!.contentHash, 'hash-1');
  });

  test('reader state writes are idempotent and progress restores', () async {
    final now = DateTime.utc(2026, 7, 19);
    await repository.applyRefresh(
      feedId: 'feed-1',
      canonicalUrl: Uri.parse('https://example.test/feed.xml'),
      feed: const feed.ParsedFeed(
        kind: feed.FeedDocumentKind.rss,
        title: 'State Feed',
        items: <feed.ParsedFeedItem>[],
      ),
      articles: <feed.FeedArticleDraft>[
        feed.FeedArticleDraft(
          id: 'article-state',
          canonicalUrl: Uri.parse('https://example.test/state'),
          title: 'Persistent state',
          summary: 'State body',
        ),
      ],
      refreshedAt: now,
    );

    await repository.setRead('article-state', read: true, updatedAt: now);
    await repository.setRead('article-state', read: true, updatedAt: now);
    await repository.setStarred('article-state', starred: true, updatedAt: now);
    await repository.setStarred('article-state', starred: true, updatedAt: now);
    await repository.setReadLater(
      'article-state',
      readLater: true,
      updatedAt: now,
    );
    await repository.saveReadingProgress(
      'article-state',
      scrollDepth: 0.64,
      updatedAt: now,
    );

    final stored = await repository.watchArticle('article-state').first;
    expect(stored, isNotNull);
    expect(stored!.read, isTrue);
    expect(stored.starred, isTrue);
    expect(stored.readLater, isTrue);
    expect(stored.scrollDepth, 0.64);
    expect(stored.completedAt, isNull);

    await repository.setRead('article-state', read: false, updatedAt: now);
    await repository.setStarred(
      'article-state',
      starred: false,
      updatedAt: now,
    );
    await repository.setReadLater(
      'article-state',
      readLater: false,
      updatedAt: now,
    );
    final cleared = await repository.watchArticle('article-state').first;
    expect(cleared!.read, isFalse);
    expect(cleared.starred, isFalse);
    expect(cleared.readLater, isFalse);

    final completedAt = now.add(const Duration(minutes: 5));
    await repository.saveReadingProgress(
      'article-state',
      scrollDepth: 0.95,
      updatedAt: completedAt,
    );
    final completed = await repository.watchArticle('article-state').first;
    expect(completed!.scrollDepth, 0.95);
    expect(completed.completedAt?.toUtc(), completedAt);
  });

  test('reader state write reports a missing article without leaking data', () {
    expect(
      repository.setRead(
        'missing',
        read: true,
        updatedAt: DateTime.utc(2026, 7, 19),
      ),
      throwsA(
        isA<feed.ArticleReaderException>().having(
          (error) => error.code,
          'code',
          'article_missing',
        ),
      ),
    );
  });
}
