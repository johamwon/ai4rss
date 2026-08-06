import 'package:river_domain/river_domain.dart';
import 'package:river_knowledge/river_knowledge.dart';
import 'package:test/test.dart';

void main() {
  test('answer materializes exact source citations for every statement',
      () async {
    final fixture = await _Fixture.create();

    final result = await fixture.qa.ask('How is renewable power generated?');

    expect(result.outcome, KnowledgeAnswerOutcome.answered);
    expect(result.providerCalled, isTrue);
    expect(result.statements, hasLength(1));
    final citation = result.statements.single.citations.single;
    expect(citation.itemId, 'solar');
    expect(citation.quote, contains('Solar panels'));
    expect(citation.sourceEnd, greaterThan(citation.sourceStart));
    expect(
      fixture.answer.requests.single.toString(),
      isNot(contains('renewable')),
    );
  });

  test('insufficient retrieval refuses without calling answer provider',
      () async {
    final fixture = await _Fixture.create();

    final result = await fixture.qa.ask('What is quantum gravity?');

    expect(result.outcome, KnowledgeAnswerOutcome.insufficientEvidence);
    expect(result.providerCalled, isFalse);
    expect(result.evidence, isEmpty);
    expect(fixture.answer.requests, isEmpty);
  });

  test('provider may explicitly refuse when retrieved evidence is insufficient',
      () async {
    final fixture = await _Fixture.create();
    fixture.answer.response = KnowledgeQuestionProviderResponse(
      insufficientEvidence: true,
    );

    final result = await fixture.qa.ask('How is renewable power generated?');

    expect(result.outcome, KnowledgeAnswerOutcome.insufficientEvidence);
    expect(result.providerCalled, isTrue);
    expect(result.evidence, isNotEmpty);
  });

  test('unknown citation IDs fail closed', () async {
    final fixture = await _Fixture.create();
    fixture.answer.response = KnowledgeQuestionProviderResponse(
      insufficientEvidence: false,
      statements: <KnowledgeQuestionProviderStatement>[
        KnowledgeQuestionProviderStatement(
          text: 'Unsupported statement.',
          citationChunkIds: const <String>['unknown-chunk'],
        ),
      ],
    );

    await expectLater(
      fixture.qa.ask('How is renewable power generated?'),
      throwsA(isA<KnowledgeQuestionFailure>()),
    );
  });

  test('uncited statements fail closed', () async {
    final fixture = await _Fixture.create();
    fixture.answer.response = KnowledgeQuestionProviderResponse(
      insufficientEvidence: false,
      statements: <KnowledgeQuestionProviderStatement>[
        KnowledgeQuestionProviderStatement(
          text: 'Uncited statement.',
          citationChunkIds: const <String>[],
        ),
      ],
    );

    await expectLater(
      fixture.qa.ask('How is renewable power generated?'),
      throwsA(isA<KnowledgeQuestionFailure>()),
    );
  });

  test('refusal cannot smuggle statements', () async {
    final fixture = await _Fixture.create();
    fixture.answer.response = KnowledgeQuestionProviderResponse(
      insufficientEvidence: true,
      statements: <KnowledgeQuestionProviderStatement>[
        KnowledgeQuestionProviderStatement(
          text: 'Contradictory output.',
          citationChunkIds: const <String>['ignored'],
        ),
      ],
    );

    await expectLater(
      fixture.qa.ask('How is renewable power generated?'),
      throwsA(isA<KnowledgeQuestionFailure>()),
    );
  });
}

final class _Fixture {
  _Fixture(this.answer, this.qa);

  final _AnswerProvider answer;
  final KnowledgeGroundedQuestionAnswering qa;

  static Future<_Fixture> create() async {
    final embeddings = _EmbeddingProvider();
    final index = MemoryKnowledgeVectorIndex();
    final indexer = KnowledgeVectorIndexer(
      profile: _profile,
      provider: embeddings,
      index: index,
      chunker: const KnowledgeChunker(
        maximumCharacters: 128,
        overlapCharacters: 16,
      ),
      clock: const _Clock(),
    );
    await indexer.indexItem(
      _item('solar', 'Solar panels generate renewable power from sunlight.'),
    );
    await indexer.indexItem(
      _item('pasta', 'Pasta cooking uses salted water and tomato sauce.'),
    );
    final answer = _AnswerProvider();
    return _Fixture(
      answer,
      KnowledgeGroundedQuestionAnswering(
        search: KnowledgeSemanticSearch(
          profile: _profile,
          provider: embeddings,
          index: index,
        ),
        provider: answer,
      ),
    );
  }
}

final class _EmbeddingProvider implements KnowledgeEmbeddingProvider {
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
  }) async =>
      _vector(query);

  List<double> _vector(String text) {
    final value = text.toLowerCase();
    if (value.contains('solar') ||
        value.contains('renewable') ||
        value.contains('power generated')) {
      return const <double>[1, 0, 0, 0];
    }
    if (value.contains('pasta') || value.contains('cooking')) {
      return const <double>[0, 1, 0, 0];
    }
    return const <double>[0, 0, 1, 0];
  }
}

final class _AnswerProvider implements KnowledgeQuestionAnswerProvider {
  final List<KnowledgeQuestionProviderRequest> requests =
      <KnowledgeQuestionProviderRequest>[];
  KnowledgeQuestionProviderResponse? response;

  @override
  Future<KnowledgeQuestionProviderResponse> answer(
    KnowledgeQuestionProviderRequest request,
  ) async {
    requests.add(request);
    return response ??
        KnowledgeQuestionProviderResponse(
          insufficientEvidence: false,
          statements: <KnowledgeQuestionProviderStatement>[
            KnowledgeQuestionProviderStatement(
              text: 'Solar panels turn sunlight into renewable power.',
              citationChunkIds: <String>[request.evidence.first.chunkId],
            ),
          ],
        );
  }
}

final _profile = EmbeddingProfile(
  modelId: 'river-qa-test',
  revision: 1,
  dimensions: 4,
  location: EmbeddingExecutionLocation.local,
);

KnowledgeItem _item(String id, String markdown) {
  final title = 'Knowledge $id';
  final html = '<p>$markdown</p>';
  return KnowledgeItem(
    id: id,
    source: KnowledgeSourceReference(
      kind: KnowledgeSourceKind.article,
      sourceId: 'source-$id',
      originalUrl: Uri.parse('https://example.test/$id'),
      sourceTitle: 'River',
    ),
    title: title,
    markdown: markdown,
    sanitizedHtml: html,
    contentHash: const KnowledgeContentHasher().hash(
      title: title,
      markdown: markdown,
      sanitizedHtml: html,
    ),
    savedAt: DateTime.utc(2026, 8, 6),
    updatedAt: DateTime.utc(2026, 8, 6),
  );
}

final class _Clock implements KnowledgeIndexClock {
  const _Clock();

  @override
  DateTime now() => DateTime.utc(2026, 8, 6, 12);
}
