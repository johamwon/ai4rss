import 'package:drift/native.dart';
import 'package:river_data/river_data.dart';
import 'package:river_domain/river_domain.dart' as domain;
import 'package:test/test.dart';

void main() {
  late RiverDatabase database;
  late DriftExtractionCache cache;

  setUp(() async {
    database = RiverDatabase(NativeDatabase.memory());
    cache = DriftExtractionCache(database);
    await _seedArticle(database);
  });

  tearDown(() => database.close());

  test('round-trips successful content and updates the article hash', () async {
    final extractedAt = DateTime.utc(2026, 7, 18, 10);
    await cache.writeSuccess(
      articleId: 'article-1',
      article: _article(),
      contentHash: 'sha256-value',
      extractedAt: extractedAt,
      etag: 'etag-1',
      lastModified: 'Sat, 18 Jul 2026 10:00:00 GMT',
    );

    final stored = await cache.read(
      sourceUri: Uri.parse('https://example.test/article'),
    );
    final articleRow = await database.select(database.articles).getSingle();

    expect(stored, isNotNull);
    expect(stored!.articleId, 'article-1');
    expect(stored.article.html, '<p>Safe content</p>');
    expect(stored.article.extractor, 'readability');
    expect(stored.contentHash, 'sha256-value');
    expect(stored.etag, 'etag-1');
    expect(stored.extractedAt, extractedAt);
    expect(articleRow.contentHash, 'sha256-value');
  });

  test('records refresh failure without discarding readable content', () async {
    final extractedAt = DateTime.utc(2026, 7, 18, 10);
    await cache.writeSuccess(
      articleId: 'article-1',
      article: _article(),
      contentHash: 'sha256-value',
      extractedAt: extractedAt,
    );

    await cache.writeFailure(
      articleId: 'article-1',
      failureCode: domain.ExtractionFailureCode.timeout,
      extractorVersion: 'readability@2',
      attemptedAt: extractedAt.add(const Duration(hours: 1)),
    );

    final stored = await cache.read(
      sourceUri: Uri.parse('https://example.test/article'),
      articleId: 'article-1',
    );
    final contentRow = await database
        .select(database.articleContents)
        .getSingle();

    expect(stored, isNotNull);
    expect(stored!.article.html, '<p>Safe content</p>');
    expect(stored.lastFailureCode, domain.ExtractionFailureCode.timeout);
    expect(contentRow.extractedAt.toUtc(), extractedAt);
    expect(contentRow.failureCode, 'timeout');
  });

  test(
    'does not expose a failure-only row as cached article content',
    () async {
      await cache.writeFailure(
        articleId: 'article-1',
        failureCode: domain.ExtractionFailureCode.network,
        extractorVersion: 'readability@1',
        attemptedAt: DateTime.utc(2026, 7, 18, 10),
        etag: 'failed-etag',
      );

      final stored = await cache.read(
        sourceUri: Uri.parse('https://example.test/article'),
        articleId: 'article-1',
      );
      final contentRow = await database
          .select(database.articleContents)
          .getSingle();

      expect(stored, isNull);
      expect(contentRow.failureCode, 'network');
      expect(contentRow.etag, 'failed-etag');
    },
  );
}

domain.ExtractedArticle _article() => domain.ExtractedArticle(
  title: 'Extracted title',
  html: '<p>Safe content</p>',
  plainText: 'Safe content',
  extractor: 'readability',
  extractorVersion: '1',
  canonicalUri: Uri.parse('https://example.test/article'),
);

Future<void> _seedArticle(RiverDatabase database) async {
  final now = DateTime.utc(2026, 7, 18);
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
          canonicalUrl: 'https://example.test/article',
          title: 'Feed title',
          createdAt: now,
          updatedAt: now,
        ),
      );
}
