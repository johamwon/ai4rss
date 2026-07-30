import 'package:flutter_test/flutter_test.dart';
import 'package:river_ai/river_ai.dart';
import 'package:river_app/app/article_summary.dart';
import 'package:river_domain/river_domain.dart';

void main() {
  test('inspection restores validated cache without a provider request',
      () async {
    final article = _article();
    final configuration = _configuration();
    final summary = _summary();
    final identity = SummaryCacheIdentity(
      contentHash: summaryContentHash(article.plainText!),
      model: configuration.model,
      promptVersion: 'article-summary@1',
      language: 'zh-CN',
    );
    final artifacts = _MemoryArtifacts()
      ..values[identity.cacheKey] = AiArtifact(
        cacheKey: identity.cacheKey,
        articleId: article.id,
        type: AiArtifactType.articleSummary,
        requestModel: configuration.model,
        resolvedModel: summary.model,
        promptVersion: identity.promptVersion,
        language: identity.language,
        contentHash: identity.contentHash,
        structuredResult: const ArticleSummaryCacheCodec().encode(summary),
        inputTokens: 100,
        outputTokens: 30,
        providerCalls: 1,
        costUsd: 0,
        createdAt: DateTime.utc(2026, 7, 30),
      );
    final transport = _NeverTransport();
    final experience = _experience(
      configuration: configuration,
      artifacts: artifacts,
      transport: transport,
      network: NetworkAvailability.offline,
    );

    final inspection = await experience.inspect(article);

    expect(inspection.cachedSummary?.oneLine, summary.oneLine);
    expect(inspection.preparation.providerLabel, 'OpenAI');
    expect(inspection.preparation.model, configuration.model);
    expect(transport.calls, 0);
  });

  test('offline cache miss fails before contacting provider', () async {
    final transport = _NeverTransport();
    final experience = _experience(
      configuration: _configuration(),
      artifacts: _MemoryArtifacts(),
      transport: transport,
      network: NetworkAvailability.offline,
    );

    await expectLater(
      experience.summarize(_article()),
      throwsA(
        isA<ArticleSummaryExperienceFailure>().having(
          (failure) => failure.code,
          'code',
          ArticleSummaryExperienceFailureCode.offline,
        ),
      ),
    );
    expect(transport.calls, 0);
  });

  test('missing BYOK configuration has a stable non-secret failure', () async {
    final experience = _experience(
      artifacts: _MemoryArtifacts(),
      transport: _NeverTransport(),
      network: NetworkAvailability.online,
    );

    await expectLater(
      experience.inspect(_article()),
      throwsA(
        isA<ArticleSummaryExperienceFailure>().having(
          (failure) => failure.code,
          'code',
          ArticleSummaryExperienceFailureCode.configurationRequired,
        ),
      ),
    );
  });
}

ByokArticleSummaryExperience _experience({
  AiByokConfiguration? configuration,
  required AiArtifactRepository artifacts,
  required AiHttpTransport transport,
  required NetworkAvailability network,
}) =>
    ByokArticleSummaryExperience(
      configurations: _MemoryConfigurationVault(configuration),
      artifacts: artifacts,
      checkpoints: MemoryAiLongSummaryCheckpointStore(),
      network: _FixedNetwork(network),
      clock: const _FixedClock(),
      transport: transport,
    );

Article _article() => Article(
      id: 'article-1',
      url: Uri.parse('https://example.test/article'),
      title: 'Article',
      source: ContentSource.web,
      plainText: 'A short article body that can be summarized safely.',
    );

AiByokConfiguration _configuration() =>
    AiProviderPresetCatalog.standard().resolve('openai').configure(
          model: 'test-model',
          apiKey: OpaqueAiApiKey('test-secret-key'),
        );

ArticleSummary _summary() => const ArticleSummary(
      oneLine: 'A cached summary.',
      keyPoints: <String>['One', 'Two', 'Three'],
      whyItMatters: 'It matters.',
      topics: <String>['testing'],
      entities: <String>['River'],
      estimatedReadingMinutes: 1,
      language: 'zh-CN',
      model: 'test-model',
      promptVersion: 'article-summary@1',
    );

final class _MemoryConfigurationVault implements AiByokConfigurationVault {
  _MemoryConfigurationVault(this.value);

  AiByokConfiguration? value;

  @override
  Future<void> clear() async => value = null;

  @override
  Future<AiByokConfiguration?> read() async => value;

  @override
  Future<void> write(AiByokConfiguration configuration) async =>
      value = configuration;
}

final class _MemoryArtifacts implements AiArtifactRepository {
  final Map<String, AiArtifact> values = <String, AiArtifact>{};

  @override
  Future<void> delete(String cacheKey) async => values.remove(cacheKey);

  @override
  Future<AiArtifact?> read(String cacheKey) async => values[cacheKey];

  @override
  Future<void> write(AiArtifact artifact) async =>
      values[artifact.cacheKey] = artifact;
}

final class _FixedNetwork implements NetworkMonitor {
  const _FixedNetwork(this.value);

  final NetworkAvailability value;

  @override
  Future<NetworkAvailability> check() async => value;

  @override
  Stream<NetworkAvailability> get changes =>
      const Stream<NetworkAvailability>.empty();
}

final class _NeverTransport implements AiHttpTransport {
  var calls = 0;

  @override
  Future<AiHttpResponse> send(AiHttpRequest request) async {
    calls += 1;
    throw StateError('Provider transport must not be called');
  }
}

final class _FixedClock implements Clock {
  const _FixedClock();

  @override
  DateTime now() => DateTime.utc(2026, 7, 30);
}
