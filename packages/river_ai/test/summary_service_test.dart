import 'dart:async';
import 'dart:convert';

import 'package:river_ai/river_ai.dart';
import 'package:river_domain/river_domain.dart';
import 'package:test/test.dart';

final class _QueueProvider implements AiProvider {
  _QueueProvider(Iterable<String> outputs)
      : _outputs = List<String>.of(outputs);

  final List<String> _outputs;
  final List<AiProviderRequest> requests = <AiProviderRequest>[];

  @override
  String get id => 'queue';

  @override
  Future<AiProviderResponse> complete(AiProviderRequest request) async {
    requests.add(request);
    if (_outputs.isEmpty) throw StateError('No response queued');
    return AiProviderResponse(
      output: _outputs.removeAt(0),
      model: request.model,
      usage: AiTokenUsage(inputTokens: 100, outputTokens: 80),
      elapsed: const Duration(milliseconds: 20),
    );
  }
}

void main() {
  test('empty content never spends provider quota', () {
    final provider = _QueueProvider(const <String>[]);
    final service = SummaryService(provider);
    final article = Article(
      id: 'a',
      url: Uri.parse('https://example.test/a'),
      title: 'Empty',
      source: ContentSource.feed,
    );

    expect(() => service.summarize(article), throwsArgumentError);
    expect(provider.requests, isEmpty);
  });

  test('valid structured output maps every required summary field', () async {
    final provider = _QueueProvider(<String>[_validSummary()]);
    final service = SummaryService(
      provider,
      model: 'replay-v1',
      outputLanguage: 'zh-CN',
    );

    final summary = await service.summarize(_article());

    expect(summary.oneLine, 'River 是一款本地优先的 RSS 阅读器。');
    expect(summary.keyPoints, hasLength(3));
    expect(summary.whyItMatters, contains('隐私'));
    expect(summary.topics, <String>['RSS', '本地优先']);
    expect(summary.entities, <String>['River']);
    expect(summary.estimatedReadingMinutes, 4);
    expect(summary.language, 'zh-CN');
    expect(summary.model, 'replay-v1');
    expect(summary.promptVersion, 'article-summary@1');
    expect(provider.requests, hasLength(1));
    expect(
      provider.requests.single.prompt.responseSchemaName,
      ArticleSummarySchema.name,
    );
  });

  test(
    'one schema repair is allowed and keeps the original prompt version',
    () async {
      final provider = _QueueProvider(<String>[
        '{"oneLine":"not enough"}',
        _validSummary(),
      ]);
      final service = SummaryService(provider, model: 'replay-v1');

      final summary = await service.summarize(_article());

      expect(summary.promptVersion, 'article-summary@1');
      expect(provider.requests, hasLength(2));
      expect(provider.requests.first.operationId, 'article-1');
      expect(provider.requests.last.operationId, 'article-1:repair');
      expect(
        provider.requests.last.prompt.versionKey,
        'article-summary-repair@1',
      );
      expect(provider.requests.last.prompt.user, contains('missingField'));
    },
  );

  test('a second invalid response fails with a stable schema code', () async {
    final provider = _QueueProvider(const <String>[
      '{}',
      '{"schemaVersion":"wrong"}',
    ]);
    final service = SummaryService(provider);

    await expectLater(
      service.summarize(_article()),
      throwsA(
        isA<AiSchemaFailure>().having(
          (failure) => failure.code,
          'code',
          AiSchemaFailureCode.missingField,
        ),
      ),
    );
    expect(provider.requests, hasLength(2));
  });

  test('validated summary is persisted and a cache hit spends no quota',
      () async {
    final provider = _QueueProvider(<String>[_validSummary()]);
    final artifacts = _MemoryArtifacts();
    final service = SummaryService(
      provider,
      model: 'replay-v1',
      artifacts: artifacts,
      clock: const _FixedClock(),
      inputUsdPerMillion: 2,
      outputUsdPerMillion: 8,
    );

    final first = await service.summarize(_article());
    final second = await service.summarize(_article());
    final stored = artifacts.values.single;

    expect(second.oneLine, first.oneLine);
    expect(provider.requests, hasLength(1));
    expect(stored.type, AiArtifactType.articleSummary);
    expect(stored.requestModel, 'replay-v1');
    expect(stored.inputTokens, 100);
    expect(stored.outputTokens, 80);
    expect(stored.providerCalls, 1);
    expect(stored.costUsd, closeTo(0.00084, 0.0000001));
    expect(stored.toString(), isNot(contains(first.oneLine)));
  });

  test('concurrent identical requests share one provider call', () async {
    final release = Completer<void>();
    final provider = _BlockingProvider(release.future);
    final service = SummaryService(provider, model: 'replay-v1');

    final first = service.summarize(_article());
    final second = service.summarize(_article());
    await Future<void>.delayed(Duration.zero);

    expect(provider.requests, hasLength(1));
    release.complete();
    final summaries = await Future.wait(<Future<ArticleSummary>>[
      first,
      second,
    ]);

    expect(summaries.map((summary) => summary.oneLine).toSet(), hasLength(1));
    expect(provider.requests, hasLength(1));
  });

  test('cache identity changes for every required invalidation dimension', () {
    final contentHash = summaryContentHash('body');
    final base = summaryCacheKey(
      contentHash: contentHash,
      model: 'model-a',
      promptVersion: 'article-summary@1',
      language: 'zh-CN',
    );
    final variants = <String>{
      base,
      summaryCacheKey(
        contentHash: summaryContentHash('changed body'),
        model: 'model-a',
        promptVersion: 'article-summary@1',
        language: 'zh-CN',
      ),
      summaryCacheKey(
        contentHash: contentHash,
        model: 'model-b',
        promptVersion: 'article-summary@1',
        language: 'zh-CN',
      ),
      summaryCacheKey(
        contentHash: contentHash,
        model: 'model-a',
        promptVersion: 'article-summary@2',
        language: 'zh-CN',
      ),
      summaryCacheKey(
        contentHash: contentHash,
        model: 'model-a',
        promptVersion: 'article-summary@1',
        language: 'en-US',
      ),
    };

    expect(variants, hasLength(5));
    expect(variants.every((key) => key.startsWith('sha256:')), isTrue);
  });

  test('malformed cached output is evicted and never returned', () async {
    final artifacts = _MemoryArtifacts();
    final identity = SummaryCacheIdentity(
      contentHash: summaryContentHash(_article().plainText!),
      model: 'replay-v1',
      promptVersion: 'article-summary@1',
      language: 'zh-CN',
    );
    await artifacts.write(
      AiArtifact(
        cacheKey: identity.cacheKey,
        articleId: 'article-1',
        type: AiArtifactType.articleSummary,
        requestModel: 'replay-v1',
        resolvedModel: 'replay-v1',
        promptVersion: 'article-summary@1',
        language: 'zh-CN',
        contentHash: identity.contentHash,
        structuredResult: '{}',
        inputTokens: 1,
        outputTokens: 1,
        providerCalls: 1,
        costUsd: 0,
        createdAt: const _FixedClock().now(),
      ),
    );
    final provider = _QueueProvider(<String>[_validSummary()]);
    final service = SummaryService(
      provider,
      model: 'replay-v1',
      artifacts: artifacts,
      clock: const _FixedClock(),
    );

    final summary = await service.summarize(_article());

    expect(summary.oneLine, isNotEmpty);
    expect(provider.requests, hasLength(1));
    expect(
      const ArticleSummaryCacheCodec().decode(artifacts.values.single).oneLine,
      summary.oneLine,
    );
  });

  test('invalid provider output is never persisted', () async {
    final artifacts = _MemoryArtifacts();
    final service = SummaryService(
      _QueueProvider(const <String>['{}', '{}']),
      artifacts: artifacts,
      clock: const _FixedClock(),
    );

    await expectLater(
      service.summarize(_article()),
      throwsA(isA<AiSchemaFailure>()),
    );

    expect(artifacts.values, isEmpty);
  });

  test('cache read failure does not discard a valid provider result', () async {
    final artifacts = _FailingReadArtifacts();
    final provider = _QueueProvider(<String>[_validSummary()]);
    final service = SummaryService(
      provider,
      artifacts: artifacts,
      clock: const _FixedClock(),
    );

    final summary = await service.summarize(_article());

    expect(summary.oneLine, isNotEmpty);
    expect(provider.requests, hasLength(1));
    expect(artifacts.written, isNotNull);
  });
}

Article _article() => Article(
      id: 'article-1',
      url: Uri.parse('https://example.test/article'),
      title: 'River 产品原则',
      source: ContentSource.web,
      plainText: 'River 是本地优先的 RSS 阅读工具，基础阅读不要求云端账号。',
    );

String _validSummary() => jsonEncode(
      <String, Object?>{
        'schemaVersion': ArticleSummarySchema.name,
        'oneLine': 'River 是一款本地优先的 RSS 阅读器。',
        'keyPoints': <String>[
          '基础阅读不依赖云端账号。',
          '用户可以掌控自己的订阅数据。',
          '产品优先保证可靠阅读体验。',
        ],
        'whyItMatters': '它让用户在保护隐私的同时稳定获取信息。',
        'topics': <String>['RSS', '本地优先'],
        'entities': <String>['River'],
        'estimatedReadingMinutes': 4,
        'language': 'zh-CN',
      },
    );

final class _BlockingProvider implements AiProvider {
  _BlockingProvider(this.release);

  final Future<void> release;
  final List<AiProviderRequest> requests = <AiProviderRequest>[];

  @override
  String get id => 'blocking';

  @override
  Future<AiProviderResponse> complete(AiProviderRequest request) async {
    requests.add(request);
    await release;
    return AiProviderResponse(
      output: _validSummary(),
      model: request.model,
      usage: AiTokenUsage(inputTokens: 100, outputTokens: 80),
      elapsed: const Duration(milliseconds: 20),
    );
  }
}

final class _MemoryArtifacts implements AiArtifactRepository {
  final Map<String, AiArtifact> _values = <String, AiArtifact>{};

  Iterable<AiArtifact> get values => _values.values;

  @override
  Future<void> delete(String cacheKey) async {
    _values.remove(cacheKey);
  }

  @override
  Future<AiArtifact?> read(String cacheKey) async => _values[cacheKey];

  @override
  Future<void> write(AiArtifact artifact) async {
    _values[artifact.cacheKey] = artifact;
  }
}

final class _FixedClock implements Clock {
  const _FixedClock();

  @override
  DateTime now() => DateTime.utc(2026, 7, 30, 12);
}

final class _FailingReadArtifacts implements AiArtifactRepository {
  AiArtifact? written;

  @override
  Future<void> delete(String cacheKey) async {}

  @override
  Future<AiArtifact?> read(String cacheKey) =>
      throw StateError('simulated cache outage');

  @override
  Future<void> write(AiArtifact artifact) async {
    written = artifact;
  }
}
