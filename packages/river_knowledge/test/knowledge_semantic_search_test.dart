import 'package:river_domain/river_domain.dart';
import 'package:river_knowledge/river_knowledge.dart';
import 'package:test/test.dart';

void main() {
  test('semantic search ranks items and returns bounded source evidence',
      () async {
    final fixture = await _Fixture.create();

    final hits = await fixture.search.search('renewable electricity', limit: 3);

    expect(hits.map((hit) => hit.itemId), <String>['solar', 'wind']);
    expect(hits.first.score, closeTo(1, 0.000001));
    expect(hits.first.evidence, isNotEmpty);
    expect(hits.first.evidence.length, lessThanOrEqualTo(2));
    expect(hits.first.evidence.first.text, contains('Solar'));
  });

  test('source tag topic and saved-time filters compose before ranking',
      () async {
    final fixture = await _Fixture.create();

    final hits = await fixture.search.search(
      'renewable electricity',
      filter: KnowledgeVectorQueryFilter(
        sourceKinds: const <KnowledgeSourceKind>{KnowledgeSourceKind.webClip},
        sourceIds: const <String>{'source-wind'},
        tags: const <String>{'favorite'},
        topics: const <String>{'climate'},
        savedFrom: DateTime.utc(2026, 8, 2),
        savedBefore: DateTime.utc(2026, 8, 4),
      ),
    );

    expect(hits.map((hit) => hit.itemId), <String>['wind']);
  });

  test('similar items exclude the source and reuse indexed vectors', () async {
    final fixture = await _Fixture.create();
    final queryCalls = fixture.provider.queryCalls;

    final hits = await fixture.search.similarItems('solar');

    expect(hits.map((hit) => hit.itemId), <String>['wind']);
    expect(fixture.provider.queryCalls, queryCalls);
  });

  test('profile identity prevents stale-model results', () async {
    final fixture = await _Fixture.create();
    final upgraded = KnowledgeSemanticSearch(
      profile: _profile(revision: 2),
      provider: fixture.provider,
      index: fixture.index,
    );

    final hits = await upgraded.search('renewable electricity');

    expect(hits, isEmpty);
    await expectLater(
      upgraded.similarItems('solar'),
      throwsA(
        isA<KnowledgeSemanticSearchFailure>().having(
          (error) => error.code,
          'code',
          KnowledgeSemanticSearchFailureCode.incompatibleProfile,
        ),
      ),
    );
  });

  test('invalid query vectors fail before reaching the index', () async {
    final fixture = await _Fixture.create();
    fixture.provider.invalidQuery = true;

    await expectLater(
      fixture.search.search('renewable electricity'),
      throwsA(
        isA<VectorIndexFailure>().having(
          (error) => error.code,
          'code',
          VectorIndexFailureCode.invalidProviderOutput,
        ),
      ),
    );
  });

  test('equal-score ordering is deterministic by item identity', () async {
    final fixture = await _Fixture.create();

    final first = await fixture.search.search('renewable electricity');
    final second = await fixture.search.search('renewable electricity');

    expect(first.map((hit) => hit.itemId), second.map((hit) => hit.itemId));
    expect(first.take(2).map((hit) => hit.itemId), <String>['solar', 'wind']);
  });
}

final class _Fixture {
  _Fixture(this.provider, this.index, this.search);

  final _TopicProvider provider;
  final MemoryKnowledgeVectorIndex index;
  final KnowledgeSemanticSearch search;

  static Future<_Fixture> create() async {
    final provider = _TopicProvider();
    final index = MemoryKnowledgeVectorIndex();
    final indexer = KnowledgeVectorIndexer(
      profile: _profile(),
      provider: provider,
      index: index,
      chunker: const KnowledgeChunker(
        maximumCharacters: 128,
        overlapCharacters: 16,
      ),
      clock: const _Clock(),
    );
    for (final item in <KnowledgeItem>[
      _item(
        'solar',
        'Solar panels generate renewable electricity from sunlight.',
        kind: KnowledgeSourceKind.article,
        sourceId: 'source-solar',
        tags: const <String>['favorite'],
        topics: const <String>['climate'],
        day: 1,
      ),
      _item(
        'wind',
        'Wind turbines generate renewable electricity from moving air.',
        kind: KnowledgeSourceKind.webClip,
        sourceId: 'source-wind',
        tags: const <String>['favorite'],
        topics: const <String>['climate'],
        day: 3,
      ),
      _item(
        'pasta',
        'Pasta cooking uses salted water and a tomato sauce recipe.',
        kind: KnowledgeSourceKind.manual,
        sourceId: 'source-pasta',
        tags: const <String>['recipe'],
        topics: const <String>['food'],
        day: 2,
      ),
      _item(
        'security',
        'Security teams rotate credentials and patch software systems.',
        kind: KnowledgeSourceKind.article,
        sourceId: 'source-security',
        tags: const <String>['work'],
        topics: const <String>['security'],
        day: 4,
      ),
    ]) {
      await indexer.indexItem(item);
    }
    return _Fixture(
      provider,
      index,
      KnowledgeSemanticSearch(
        profile: _profile(),
        provider: provider,
        index: index,
        maximumEvidencePerItem: 2,
      ),
    );
  }
}

final class _TopicProvider implements KnowledgeEmbeddingProvider {
  var queryCalls = 0;
  var invalidQuery = false;

  @override
  Future<List<EmbeddingVector>> embed({
    required EmbeddingProfile profile,
    required List<KnowledgeChunk> chunks,
  }) async =>
      chunks
          .map(
            (chunk) => EmbeddingVector(
              chunkId: chunk.id,
              values: _vector(chunk.text),
            ),
          )
          .toList(growable: false);

  @override
  Future<List<double>> embedQuery({
    required EmbeddingProfile profile,
    required String query,
  }) async {
    queryCalls += 1;
    if (invalidQuery) return const <double>[1, 0];
    return _vector(query);
  }

  List<double> _vector(String text) {
    final value = text.toLowerCase();
    if (value.contains('solar') ||
        value.contains('wind') ||
        value.contains('renewable')) {
      return const <double>[1, 0, 0, 0];
    }
    if (value.contains('pasta') || value.contains('cooking')) {
      return const <double>[0, 1, 0, 0];
    }
    if (value.contains('security') || value.contains('credentials')) {
      return const <double>[0, 0, 1, 0];
    }
    return const <double>[0, 0, 0, 1];
  }
}

EmbeddingProfile _profile({int revision = 1}) => EmbeddingProfile(
      modelId: 'river-topic-test',
      revision: revision,
      dimensions: 4,
      location: EmbeddingExecutionLocation.local,
    );

KnowledgeItem _item(
  String id,
  String markdown, {
  required KnowledgeSourceKind kind,
  required String sourceId,
  required List<String> tags,
  required List<String> topics,
  required int day,
}) {
  final title = 'Knowledge $id';
  final html = '<p>$markdown</p>';
  return KnowledgeItem(
    id: id,
    source: KnowledgeSourceReference(
      kind: kind,
      sourceId: sourceId,
      originalUrl: Uri.parse('https://example.test/$id'),
      sourceTitle: 'River',
    ),
    title: title,
    markdown: markdown,
    sanitizedHtml: html,
    tags: tags,
    topics: topics,
    contentHash: const KnowledgeContentHasher().hash(
      title: title,
      markdown: markdown,
      sanitizedHtml: html,
      tags: tags,
      topics: topics,
    ),
    savedAt: DateTime.utc(2026, 8, day),
    updatedAt: DateTime.utc(2026, 8, day),
  );
}

final class _Clock implements KnowledgeIndexClock {
  const _Clock();

  @override
  DateTime now() => DateTime.utc(2026, 8, 6, 12);
}
