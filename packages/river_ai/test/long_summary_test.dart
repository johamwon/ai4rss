import 'dart:convert';

import 'package:river_ai/river_ai.dart';
import 'package:river_domain/river_domain.dart';
import 'package:test/test.dart';

void main() {
  test('planner preserves bounded paragraph ranges with overlap', () {
    final content = List<String>.generate(
      5,
      (index) => 'Paragraph $index ${List<String>.filled(560, 'x').join()}',
    ).join('\n\n');

    final chunks = const ArticleSummaryChunkPlanner().plan(
      articleId: 'article-1',
      content: content,
      budget: const AiContextBudget(
        mapContentCharacters: 1000,
        maxMapPromptCharacters: 4000,
      ),
    );

    expect(chunks, hasLength(5));
    expect(chunks.first.paragraphStart, 0);
    expect(chunks.first.paragraphEnd, 1);
    expect(chunks[1].paragraphStart, 0);
    expect(chunks[1].paragraphEnd, 2);
    expect(chunks.last.paragraphStart, 3);
    expect(chunks.last.paragraphEnd, 5);
    expect(chunks[1].text, contains('[P0]'));
    expect(chunks[1].text, contains('[P1]'));
    expect(chunks.first.toString(), isNot(contains('Paragraph 0')));
  });

  test('oversized single paragraphs split without exceeding chunk input', () {
    final content = List<String>.filled(2600, '界').join();

    final chunks = const ArticleSummaryChunkPlanner().plan(
      articleId: 'article-1',
      content: content,
      budget: const AiContextBudget(
        mapContentCharacters: 1000,
        overlapParagraphs: 0,
        maxMapPromptCharacters: 4000,
      ),
    );

    expect(chunks, hasLength(3));
    expect(chunks.every((chunk) => chunk.text.length <= 1005), isTrue);
    expect(chunks.every((chunk) => chunk.paragraphStart == 0), isTrue);
    expect(chunks.every((chunk) => chunk.paragraphEnd == 1), isTrue);
  });

  test('single-paragraph splitting never cuts a surrogate pair', () {
    final content = List<String>.filled(700, '📰').join();

    final chunks = const ArticleSummaryChunkPlanner().plan(
      articleId: 'article-1',
      content: content,
      budget: const AiContextBudget(
        mapContentCharacters: 1001,
        overlapParagraphs: 0,
        maxMapPromptCharacters: 5000,
      ),
    );

    expect(chunks, hasLength(2));
    expect(
      chunks.every(
        (chunk) => utf8.decode(utf8.encode(chunk.text)) == chunk.text,
      ),
      isTrue,
    );
  });

  test('planner rejects an article that exceeds the configured chunk count',
      () {
    final content = List<String>.generate(
      3,
      (index) => 'Paragraph $index ${List<String>.filled(700, 'x').join()}',
    ).join('\n\n');

    expect(
      () => const ArticleSummaryChunkPlanner().plan(
        articleId: 'article-1',
        content: content,
        budget: const AiContextBudget(
          mapContentCharacters: 1000,
          maxChunks: 2,
          maxMapPromptCharacters: 5000,
        ),
      ),
      throwsA(
        isA<AiLongSummaryFailure>().having(
          (failure) => failure.code,
          'code',
          AiLongSummaryFailureCode.tooManyChunks,
        ),
      ),
    );
  });

  test('maximum normal preflight stays within a two second CPU budget', () {
    final article = Article(
      id: 'large-preflight',
      url: Uri.parse('https://example.test/large'),
      title: 'Large preflight',
      source: ContentSource.web,
      plainText: List<String>.generate(
        60,
        (index) => 'P$index ${List<String>.filled(8000, 'x').join()}',
      ).join('\n\n'),
    );
    final service = LongArticleSummaryService(
      _ScriptedProvider((_) => fail('Preflight must not call the provider')),
      checkpoints: MemoryAiLongSummaryCheckpointStore(),
    );
    final stopwatch = Stopwatch()..start();

    final preflight = service.preflight(article);
    stopwatch.stop();

    expect(preflight.chunks, hasLength(60));
    expect(preflight.estimate.providerCalls, 62);
    expect(stopwatch.elapsed, lessThan(const Duration(seconds: 2)));
  });

  test(
    'map reduce keeps boundary facts, deduplicates cross-chunk facts, '
    'and estimates multilingual cost',
    () async {
      final article = _article(paragraphs: 4);
      const budget = AiContextBudget(
        mapContentCharacters: 1000,
        maxMapPromptCharacters: 5000,
        maxReducePromptCharacters: 8000,
      );
      final chunks = const ArticleSummaryChunkPlanner().plan(
        articleId: article.id,
        content: article.plainText!,
        budget: budget,
      );
      late _ScriptedProvider provider;
      provider = _ScriptedProvider((request) {
        if (request.operationId.endsWith(':reduce')) {
          expect(request.prompt.user, contains('opening boundary fact'));
          expect(request.prompt.user, contains('closing boundary fact'));
          expect(request.prompt.user, contains('shared cross-block fact'));
          return _finalOutput(language: 'en-US');
        }
        final index = int.parse(request.operationId.split(':').last);
        final chunk = chunks[index];
        final facts = <String>[
          if (index == 0) 'opening boundary fact',
          if (index == chunks.length - 1) 'closing boundary fact',
          'chunk $index fact',
          if (index == 1 || index == 2) 'shared cross-block fact',
        ];
        return _mapOutput(chunk, facts, language: 'en-US');
      });
      final checkpoints = MemoryAiLongSummaryCheckpointStore();
      final service = LongArticleSummaryService(
        provider,
        checkpoints: checkpoints,
        model: 'replay-model',
        outputLanguage: 'en-US',
        budget: budget,
        pricing: const AiTokenPricing(
          inputUsdPerMillion: 2,
          outputUsdPerMillion: 8,
        ),
      );

      final preflight = service.preflight(article);
      final result = await service.summarize(article);

      expect(result.summary.language, 'en-US');
      expect(result.summary.promptVersion, 'article-summary-reduce@1');
      expect(result.summary.oneLine, contains('bounded facts'));
      expect(result.resumedChunks, 0);
      expect(result.usage.inputTokens, (chunks.length + 1) * 10);
      expect(result.usage.outputTokens, (chunks.length + 1) * 5);
      expect(preflight.estimate.providerCalls, chunks.length + 2);
      expect(preflight.estimate.inputTokens, greaterThan(0));
      expect(preflight.estimate.upperBoundUsd, greaterThan(0));
      expect(
        result.preflightEstimate.upperBoundUsd,
        preflight.estimate.upperBoundUsd,
      );
      expect(result.omittedFacts, 0);
      expect(result.checkpointCleanupPending, isFalse);
      final shared = result.sourcedFacts.singleWhere(
        (fact) => fact.text == 'shared cross-block fact',
      );
      expect(shared.citations, hasLength(2));
      expect(
        result.sourcedFacts
            .where((fact) => fact.text == 'shared cross-block fact'),
        hasLength(1),
      );
      expect(await checkpoints.read(article.id), isNull);
      expect(
        provider.requests
            .where((request) => request.operationId.contains(':map:'))
            .every(
              (request) =>
                  request.prompt.responseSchemaName ==
                  AiChunkSummarySchema.name,
            ),
        isTrue,
      );
    },
  );

  test('completed map chunks resume after an interrupted provider call',
      () async {
    final article = _article(paragraphs: 3);
    const budget = AiContextBudget(
      mapContentCharacters: 1000,
      maxMapPromptCharacters: 5000,
      maxReducePromptCharacters: 8000,
    );
    final chunks = const ArticleSummaryChunkPlanner().plan(
      articleId: article.id,
      content: article.plainText!,
      budget: budget,
    );
    final checkpoints = MemoryAiLongSummaryCheckpointStore();
    final interrupted = _ScriptedProvider((request) {
      if (request.operationId.endsWith(':map:1')) {
        throw AiProviderFailure(
          code: AiProviderFailureCode.unavailable,
          retryable: true,
        );
      }
      final index = int.parse(request.operationId.split(':').last);
      return _mapOutput(chunks[index], <String>['fact $index']);
    });
    final first = LongArticleSummaryService(
      interrupted,
      checkpoints: checkpoints,
      model: 'replay-model',
      budget: budget,
    );

    await expectLater(
      first.summarize(article),
      throwsA(isA<AiProviderFailure>()),
    );
    expect(
      (await checkpoints.read(article.id))!.completedChunks.keys,
      <int>[0],
    );

    final resumed = _ScriptedProvider((request) {
      if (request.operationId.endsWith(':reduce')) return _finalOutput();
      final index = int.parse(request.operationId.split(':').last);
      return _mapOutput(chunks[index], <String>['fact $index']);
    });
    final second = LongArticleSummaryService(
      resumed,
      checkpoints: checkpoints,
      model: 'replay-model',
      budget: budget,
    );

    final result = await second.summarize(article);

    expect(result.resumedChunks, 1);
    expect(result.usage.inputTokens, 40);
    expect(result.usage.outputTokens, 20);
    expect(
      resumed.requests.map((request) => request.operationId),
      isNot(contains('${article.id}:map:0')),
    );
    expect(
      resumed.requests.map((request) => request.operationId),
      containsAll(<String>[
        '${article.id}:map:1',
        '${article.id}:map:2',
        '${article.id}:reduce',
      ]),
    );
    expect(await checkpoints.read(article.id), isNull);
  });

  test('checkpoint cleanup failure does not discard a valid summary', () async {
    final article = _article(paragraphs: 1);
    const budget = AiContextBudget(
      mapContentCharacters: 1000,
      maxMapPromptCharacters: 5000,
      maxReducePromptCharacters: 8000,
    );
    final chunk = const ArticleSummaryChunkPlanner()
        .plan(
          articleId: article.id,
          content: article.plainText!,
          budget: budget,
        )
        .single;
    final provider = _ScriptedProvider(
      (request) => request.operationId.endsWith(':reduce')
          ? _finalOutput()
          : _mapOutput(chunk, const <String>['fact']),
    );
    final checkpoints = _FailingClearCheckpointStore();
    final service = LongArticleSummaryService(
      provider,
      checkpoints: checkpoints,
      budget: budget,
    );

    final result = await service.summarize(article);

    expect(result.summary.oneLine, isNotEmpty);
    expect(result.checkpointCleanupPending, isTrue);
    expect(await checkpoints.read(article.id), isNotNull);
  });

  test('reduce refuses to discard the first fact from any chunk', () async {
    final article = _article(paragraphs: 3);
    const budget = AiContextBudget(
      mapContentCharacters: 1000,
      maxMapPromptCharacters: 5000,
      maxReducePromptCharacters: 2000,
    );
    final chunks = const ArticleSummaryChunkPlanner().plan(
      articleId: article.id,
      content: article.plainText!,
      budget: budget,
    );
    final provider = _ScriptedProvider((request) {
      if (request.operationId.endsWith(':reduce')) {
        fail('Reduce must not run after its mandatory context exceeds budget');
      }
      final index = int.parse(request.operationId.split(':').last);
      return _mapOutput(
        chunks[index],
        <String>[List<String>.filled(780, '$index').join()],
      );
    });
    final service = LongArticleSummaryService(
      provider,
      checkpoints: MemoryAiLongSummaryCheckpointStore(),
      budget: budget,
    );

    await expectLater(
      service.summarize(article),
      throwsA(
        isA<AiLongSummaryFailure>().having(
          (failure) => failure.code,
          'code',
          AiLongSummaryFailureCode.contextBudgetExceeded,
        ),
      ),
    );
  });

  test('UTF-8 request byte budget protects compatible provider transport',
      () async {
    final article = _article(paragraphs: 20);
    const budget = AiContextBudget(
      mapContentCharacters: 1000,
      maxMapPromptCharacters: 5000,
      maxReducePromptCharacters: 40000,
      maxRequestBytes: 32 * 1024,
    );
    final chunks = const ArticleSummaryChunkPlanner().plan(
      articleId: article.id,
      content: article.plainText!,
      budget: budget,
    );
    final provider = _ScriptedProvider((request) {
      if (request.operationId.endsWith(':reduce')) {
        fail('Reduce must not exceed the HTTP request byte boundary');
      }
      final index = int.parse(request.operationId.split(':').last);
      return _mapOutput(
        chunks[index],
        <String>['chunk-$index ${List<String>.filled(780, '界').join()}'],
      );
    });
    final service = LongArticleSummaryService(
      provider,
      checkpoints: MemoryAiLongSummaryCheckpointStore(),
      budget: budget,
    );

    await expectLater(
      service.summarize(article),
      throwsA(
        isA<AiLongSummaryFailure>().having(
          (failure) => failure.code,
          'code',
          AiLongSummaryFailureCode.contextBudgetExceeded,
        ),
      ),
    );
  });

  test('chunk schema rejects facts outside the supplied paragraph range', () {
    final chunk = ArticleSummaryChunk(
      articleId: 'article-1',
      index: 0,
      paragraphStart: 2,
      paragraphEnd: 4,
      text: '[P2] safe',
    );

    expect(
      () => const AiChunkSummarySchema().parse(
        _mapOutput(
          chunk,
          const <String>['fact'],
          forcedStart: 1,
        ),
        expectedChunk: chunk,
        expectedLanguage: 'zh-CN',
      ),
      throwsA(isA<AiLongSummaryFailure>()),
    );
  });
}

final class _ScriptedProvider implements AiProvider {
  _ScriptedProvider(this.handler);

  final String Function(AiProviderRequest request) handler;
  final List<AiProviderRequest> requests = <AiProviderRequest>[];

  @override
  String get id => 'scripted';

  @override
  Future<AiProviderResponse> complete(AiProviderRequest request) async {
    requests.add(request);
    return AiProviderResponse(
      output: handler(request),
      model: request.model,
      usage: AiTokenUsage(inputTokens: 10, outputTokens: 5),
      elapsed: const Duration(milliseconds: 1),
    );
  }
}

final class _FailingClearCheckpointStore
    implements AiLongSummaryCheckpointStore {
  final MemoryAiLongSummaryCheckpointStore _delegate =
      MemoryAiLongSummaryCheckpointStore();

  @override
  Future<void> clear(String articleId) =>
      throw StateError('simulated cleanup failure');

  @override
  Future<AiLongSummaryCheckpoint?> read(String articleId) =>
      _delegate.read(articleId);

  @override
  Future<void> write(AiLongSummaryCheckpoint checkpoint) =>
      _delegate.write(checkpoint);
}

Article _article({required int paragraphs}) => Article(
      id: 'long-article',
      url: Uri.parse('https://example.test/long'),
      title: 'Long article',
      source: ContentSource.web,
      plainText: List<String>.generate(
        paragraphs,
        (index) => 'Paragraph $index ${List<String>.filled(560, 'x').join()}',
      ).join('\n\n'),
    );

String _mapOutput(
  ArticleSummaryChunk chunk,
  List<String> facts, {
  String language = 'zh-CN',
  int? forcedStart,
}) =>
    jsonEncode(
      <String, Object?>{
        'schemaVersion': AiChunkSummarySchema.name,
        'articleId': chunk.articleId,
        'chunkIndex': chunk.index,
        'paragraphStart': chunk.paragraphStart,
        'paragraphEnd': chunk.paragraphEnd,
        'facts': <Map<String, Object?>>[
          for (final fact in facts)
            <String, Object?>{
              'text': fact,
              'articleId': chunk.articleId,
              'paragraphStart': forcedStart ?? chunk.paragraphStart,
              'paragraphEnd': (forcedStart ?? chunk.paragraphStart) + 1,
            },
        ],
        'topics': <String>['testing'],
        'entities': <String>['River'],
        'language': language,
      },
    );

String _finalOutput({String language = 'zh-CN'}) => jsonEncode(
      <String, Object?>{
        'schemaVersion': ArticleSummarySchema.name,
        'oneLine': 'A final summary based only on bounded facts.',
        'keyPoints': <String>[
          'The opening fact is retained.',
          'Cross-block evidence is merged.',
          'The closing fact is retained.',
        ],
        'whyItMatters': 'Readers receive a traceable long-form summary.',
        'topics': <String>['testing'],
        'entities': <String>['River'],
        'estimatedReadingMinutes': 4,
        'language': language,
      },
    );
