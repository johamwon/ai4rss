import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:river_data/river_data.dart';
import 'package:river_feed/river_feed.dart' as feed;
import 'package:test/test.dart';

void main() {
  late RiverDatabase database;
  late DriftFeedRepository repository;
  final now = DateTime.utc(2026, 7, 23);

  setUp(() async {
    database = RiverDatabase(NativeDatabase.memory());
    repository = DriftFeedRepository(database);
    await repository.applyRefresh(
      feedId: 'feed-1',
      canonicalUrl: Uri.parse('https://example.test/feed.xml'),
      feed: const feed.ParsedFeed(
        kind: feed.FeedDocumentKind.rss,
        title: 'AI 深度周刊',
        items: <feed.ParsedFeedItem>[],
      ),
      articles: <feed.FeedArticleDraft>[
        feed.FeedArticleDraft(
          id: 'article-1',
          canonicalUrl: Uri.parse('https://example.test/one'),
          title: 'Practical Machine Learning',
          author: 'River Lab',
          publishedAt: now,
          summary: 'A C++ guide with 100% practical examples and_underlines.',
        ),
        feed.FeedArticleDraft(
          id: 'article-2',
          canonicalUrl: Uri.parse('https://example.test/two'),
          title: 'Older note',
          author: '另一位作者',
          publishedAt: now.subtract(const Duration(days: 1)),
          summary: '普通摘要',
        ),
      ],
      refreshedAt: now,
    );
    await database
        .into(database.articleContents)
        .insert(
          ArticleContentsCompanion.insert(
            articleId: 'article-1',
            sanitizedHtml: '<p>深度学习正文与向量检索</p>',
            markdown: '深度学习正文与向量检索',
            plainText: '这里保存了深度学习正文与向量检索内容。',
            extractorName: 'fixture',
            extractorVersion: '1',
            extractedAt: now,
          ),
        );
    await database
        .into(database.knowledgeItems)
        .insert(
          KnowledgeItemsCompanion.insert(
            id: 'knowledge-1',
            articleId: const Value<String?>('article-2'),
            title: 'Knowledge note',
            originalUrl: 'https://example.test/two',
            markdown: '私人笔记：记住这个洞察',
            summaryJson: const Value<String?>('{"brief":"知识摘要"}'),
            tagsJson: const Value<String>('["重要标签"]'),
            contentHash: 'hash-1',
            createdAt: now,
            updatedAt: now,
          ),
        );
  });

  tearDown(() => database.close());

  test(
    'searches Chinese, English, source, tags, notes, and literals',
    () async {
      expect(
        (await _search(repository, '深度学习')).single.article.id,
        'article-1',
      );
      expect(
        (await _search(repository, 'machine LEARNING')).single.article.id,
        'article-1',
      );
      expect((await _search(repository, '深度周刊')), hasLength(2));
      expect(
        (await _search(repository, '重要标签')).single.article.id,
        'article-2',
      );
      expect(
        (await _search(repository, '这个洞察')).single.article.id,
        'article-2',
      );
      expect((await _search(repository, 'C++')).single.article.id, 'article-1');
      expect(
        (await _search(repository, '100%')).single.article.id,
        'article-1',
      );
      expect((await _search(repository, '_')).single.article.id, 'article-1');
      expect(await _search(repository, '" OR * - +'), isEmpty);
    },
  );

  test('applies state filters and deterministic time sorting', () async {
    await repository.setStarred('article-2', starred: true, updatedAt: now);
    await repository.setRead('article-1', read: true, updatedAt: now);

    final starred = await _search(
      repository,
      'note',
      view: feed.FeedArticleView.starred,
    );
    expect(starred.single.article.id, 'article-2');
    final unread = await _search(
      repository,
      'note',
      view: feed.FeedArticleView.unread,
    );
    expect(unread.single.article.id, 'article-2');
    final oldest = await _search(
      repository,
      'AI 深度周刊',
      sort: feed.ArticleSearchSort.oldest,
    );
    expect(oldest.map((result) => result.article.id), <String>[
      'article-2',
      'article-1',
    ]);
  });

  test(
    'index follows article content, feed, and knowledge mutations',
    () async {
      await (database.update(
        database.articleContents,
      )..where((table) => table.articleId.equals('article-1'))).write(
        const ArticleContentsCompanion(plainText: Value<String>('更新后的独有正文')),
      );
      expect(await _search(repository, '深度学习'), isEmpty);
      expect(
        (await _search(repository, '独有正文')).single.article.id,
        'article-1',
      );

      await (database.update(database.feedSubscriptions)
            ..where((table) => table.id.equals('feed-1')))
          .write(const FeedSubscriptionsCompanion(title: Value('新来源名称')));
      expect(await _search(repository, '深度周刊'), isEmpty);
      expect((await _search(repository, '新来源名称')), hasLength(2));

      await (database.delete(
        database.knowledgeItems,
      )..where((table) => table.id.equals('knowledge-1'))).go();
      expect(await _search(repository, '重要标签'), isEmpty);
    },
  );
}

Future<List<feed.ArticleSearchResult>> _search(
  DriftFeedRepository repository,
  String text, {
  feed.FeedArticleView view = feed.FeedArticleView.inbox,
  feed.ArticleSearchSort sort = feed.ArticleSearchSort.relevance,
}) => repository
    .watchSearch(feed.ArticleSearchQuery(text: text, view: view, sort: sort))
    .first;
