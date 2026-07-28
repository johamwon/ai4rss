import 'package:river_data/river_data.dart';
import 'package:river_domain/river_domain.dart';
import 'package:test/test.dart';

void main() {
  late RiverDatabase database;
  late DriftArticleAnnotationRepository repository;
  final now = DateTime.utc(2026, 7, 28);

  setUp(() async {
    database = RiverDatabase.inMemory();
    repository = DriftArticleAnnotationRepository(database);
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
            title: 'Article',
            createdAt: now,
            updatedAt: now,
          ),
        );
  });

  tearDown(() => database.close());

  test('annotation and note round trip with idempotent updates', () async {
    final annotation = _annotation(now);

    await repository.upsertAnnotation(annotation);
    await repository.upsertAnnotation(
      annotation.copyWith(
        color: ArticleAnnotationColor.green,
        note: '  A durable note.  ',
        updatedAt: now.add(const Duration(minutes: 1)),
      ),
    );

    final stored =
        (await repository.watchArticleAnnotations('article-1').first).single;
    expect(stored.anchor.exact, 'selected fact');
    expect(stored.anchor.startDomPath, '/article/p[2]');
    expect(stored.color, ArticleAnnotationColor.green);
    expect(stored.note, 'A durable note.');
    expect(
      await database.select(database.articleAnnotations).get(),
      hasLength(1),
    );
  });

  test('deleting an article cascades its annotations', () async {
    await repository.upsertAnnotation(_annotation(now));

    await (database.delete(
      database.articles,
    )..where((row) => row.id.equals('article-1'))).go();

    expect(await database.select(database.articleAnnotations).get(), isEmpty);
  });

  test('corrupt stored annotations fail closed', () async {
    await database.customStatement('''
      INSERT INTO article_annotations (
        id, article_id, exact_text, prefix_text, suffix_text,
        original_start, original_end, content_revision,
        start_dom_path, start_dom_offset, end_dom_path, end_dom_offset,
        color, note, created_at, updated_at
      ) VALUES (
        'bad', 'article-1', '', '', '', 3, 2, '',
        '', -1, '', -1, 'removed', NULL, 0, 0
      )
    ''');

    expect(
      await repository.watchArticleAnnotations('article-1').first,
      isEmpty,
    );
  });
}

ArticleAnnotation _annotation(DateTime now) => ArticleAnnotation(
  id: 'annotation-1',
  articleId: 'article-1',
  anchor: const ArticleTextAnchor(
    exact: 'selected fact',
    prefix: 'before ',
    suffix: ' after',
    originalStart: 7,
    originalEnd: 20,
    contentRevision: 'sha256:revision-1',
    startDomPath: '/article/p[2]',
    startDomOffset: 0,
    endDomPath: '/article/p[2]',
    endDomOffset: 13,
  ),
  color: ArticleAnnotationColor.yellow,
  createdAt: now,
  updatedAt: now,
);
