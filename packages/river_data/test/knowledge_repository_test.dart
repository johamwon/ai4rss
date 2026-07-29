import 'package:drift/drift.dart' hide isNull;
import 'package:river_data/river_data.dart';
import 'package:river_domain/river_domain.dart';
import 'package:test/test.dart';

void main() {
  late RiverDatabase database;
  late DriftKnowledgeRepository repository;
  final now = DateTime.utc(2026, 7, 28);

  setUp(() async {
    database = RiverDatabase.inMemory();
    repository = DriftKnowledgeRepository(database);
    await database
        .into(database.feedSubscriptions)
        .insert(
          FeedSubscriptionsCompanion.insert(
            id: 'feed-1',
            canonicalUrl: 'https://example.test/feed.xml',
            title: 'River Weekly',
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
            title: 'Knowledge source',
            createdAt: now,
            updatedAt: now,
          ),
        );
  });

  tearDown(() => database.close());

  test('source identity deduplicates saves while refreshing content', () async {
    final first = await repository.saveItem(_item('knowledge-first', now));
    final second = await repository.saveItem(
      _item(
        'knowledge-retry',
        now.add(const Duration(hours: 1)),
        markdown: '# Updated',
        hashCharacter: 'b',
      ),
    );

    expect(first.id, 'knowledge-first');
    expect(second.id, 'knowledge-first');
    expect(second.savedAt, now);
    expect(second.markdown, '# Updated');
    expect(second.summary?.whyItMatters, 'Useful context');
    expect(second.summary?.topics, <String>['RSS']);
    expect(second.summary?.entities, <String>['River']);
    expect(second.summary?.estimatedReadingMinutes, 3);
    expect(await database.select(database.knowledgeItems).get(), hasLength(1));
    expect(
      (await repository.findBySource(second.source))?.contentHash,
      _hash('b'),
    );
  });

  test('concurrent retries converge on one source identity', () async {
    final results = await Future.wait(<Future<KnowledgeItem>>[
      repository.saveItem(_item('knowledge-a', now)),
      repository.saveItem(
        _item(
          'knowledge-b',
          now.add(const Duration(seconds: 1)),
          hashCharacter: 'b',
        ),
      ),
    ]);

    expect(results.map((item) => item.id).toSet(), hasLength(1));
    expect(await database.select(database.knowledgeItems).get(), hasLength(1));
  });

  test('stale saves cannot overwrite a newer knowledge snapshot', () async {
    final newer = await repository.saveItem(
      _item(
        'knowledge-new',
        now.add(const Duration(hours: 2)),
        markdown: '# Newer',
        hashCharacter: 'b',
      ),
    );
    final stale = await repository.saveItem(
      _item('knowledge-stale', now, markdown: '# Stale'),
    );

    expect(stale.id, newer.id);
    expect(stale.markdown, '# Newer');
    expect(stale.savedAt, newer.savedAt);
  });

  test('external mappings update idempotently and cascade with item', () async {
    final item = await repository.saveItem(_item('knowledge-1', now));
    final first = _mapping(item.id, now, externalObjectId: 'page-1');
    final updated = _mapping(
      item.id,
      now,
      externalObjectId: 'page-1-updated',
      hashCharacter: 'b',
      updatedAt: now.add(const Duration(minutes: 1)),
    );

    await repository.upsertExternalMapping(first);
    await repository.upsertExternalMapping(updated);

    final mappings = await repository.watchExternalMappings(item.id).first;
    expect(mappings, hasLength(1));
    expect(mappings.single.externalObjectId, 'page-1-updated');
    expect(mappings.single.exportedContentHash, _hash('b'));

    await repository.upsertExternalMapping(first);
    final afterStaleWrite =
        (await repository.watchExternalMappings(item.id).first).single;
    expect(afterStaleWrite.externalObjectId, 'page-1-updated');
    expect(afterStaleWrite.createdAt, now);

    await repository.deleteItem(item.id);
    expect(
      await database.select(database.knowledgeExternalMappings).get(),
      isEmpty,
    );
  });

  test('article deletion preserves the independent knowledge object', () async {
    final item = await repository.saveItem(_item('knowledge-1', now));

    await (database.delete(
      database.articles,
    )..where((row) => row.id.equals('article-1'))).go();

    final stored = await repository.watchItem(item.id).first;
    expect(stored?.source.sourceId, 'article-1');
    expect(
      (await database.select(database.knowledgeItems).getSingle()).articleId,
      isNull,
    );
  });

  test('corrupt JSON rows fail closed without blocking valid rows', () async {
    await repository.saveItem(_item('knowledge-1', now));
    await database
        .into(database.knowledgeItems)
        .insert(
          KnowledgeItemsCompanion.insert(
            id: 'corrupt',
            sourceKind: const Value<String>('manual'),
            sourceId: const Value<String?>('corrupt'),
            sourceTitle: const Value<String?>('Corrupt'),
            title: 'Corrupt',
            originalUrl: 'https://example.test/corrupt',
            markdown: 'Corrupt',
            notesJson: const Value<String>('{not-json'),
            contentHash: _hash('c'),
            createdAt: now,
            updatedAt: now,
          ),
        );

    expect(await repository.watchItems().first, hasLength(1));
  });
}

KnowledgeItem _item(
  String id,
  DateTime now, {
  String markdown = '# Knowledge',
  String hashCharacter = 'a',
}) => KnowledgeItem(
  id: id,
  source: KnowledgeSourceReference(
    kind: KnowledgeSourceKind.article,
    sourceId: 'article-1',
    originalUrl: Uri.parse('https://example.test/article'),
    sourceTitle: 'River Weekly',
    author: 'River Lab',
    publishedAt: now.subtract(const Duration(days: 1)),
  ),
  title: 'Knowledge source',
  markdown: markdown,
  sanitizedHtml: '<h1>Knowledge</h1>',
  summary: const ArticleSummary(
    oneLine: 'One line',
    keyPoints: <String>['One', 'Two', 'Three'],
    whyItMatters: 'Useful context',
    topics: <String>['RSS'],
    entities: <String>['River'],
    estimatedReadingMinutes: 3,
    language: 'en',
    model: 'fixture',
    promptVersion: '1',
  ),
  excerpts: <KnowledgeExcerpt>[
    KnowledgeExcerpt(
      quote: 'Selected fact',
      note: 'Remember this',
      annotationId: 'annotation-1',
    ),
  ],
  notes: const <String>['Standalone note'],
  tags: const <String>['rss'],
  topics: const <String>['reading'],
  entities: const <String>['River'],
  contentHash: _hash(hashCharacter),
  savedAt: now,
  updatedAt: now,
);

KnowledgeExternalMapping _mapping(
  String itemId,
  DateTime now, {
  required String externalObjectId,
  String hashCharacter = 'a',
  DateTime? updatedAt,
}) => KnowledgeExternalMapping(
  knowledgeItemId: itemId,
  connectorId: 'notion',
  destinationId: 'database-1',
  externalObjectId: externalObjectId,
  externalUrl: Uri.parse('https://notion.so/$externalObjectId'),
  exportedContentHash: _hash(hashCharacter),
  createdAt: now,
  updatedAt: updatedAt ?? now,
);

String _hash(String character) =>
    'sha256:${List<String>.filled(64, character).join()}';
