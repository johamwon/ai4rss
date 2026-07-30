import 'package:river_domain/river_domain.dart';

import 'prompt_registry.dart';
import 'provider.dart';
import 'summary_cache.dart';
import 'summary_schema.dart';

final class SummaryService {
  SummaryService(
    this._provider, {
    PromptRegistry? prompts,
    this.model = 'provider-default',
    this.outputLanguage = 'zh-CN',
    this.summaryPromptVersion = 1,
    this.artifacts,
    this.clock,
    AiSummaryRequestCoalescer? requests,
    this.inputUsdPerMillion = 0,
    this.outputUsdPerMillion = 0,
  })  : prompts = prompts ?? PromptRegistry.standard(),
        _requests = requests ?? AiSummaryRequestCoalescer() {
    if (model.trim().isEmpty || model.length > 200) {
      throw ArgumentError.value(model, 'model');
    }
    if (!ArticleSummarySchema.languageTag.hasMatch(outputLanguage)) {
      throw ArgumentError.value(outputLanguage, 'outputLanguage');
    }
    if (summaryPromptVersion < 1) {
      throw RangeError.range(summaryPromptVersion, 1, null);
    }
    if ((artifacts == null) != (clock == null)) {
      throw ArgumentError('artifacts and clock must be supplied together');
    }
    if (!inputUsdPerMillion.isFinite ||
        inputUsdPerMillion < 0 ||
        !outputUsdPerMillion.isFinite ||
        outputUsdPerMillion < 0) {
      throw ArgumentError('AI pricing must be finite and non-negative');
    }
  }

  final AiProvider _provider;
  final PromptRegistry prompts;
  final String model;
  final String outputLanguage;
  final int summaryPromptVersion;
  final AiArtifactRepository? artifacts;
  final Clock? clock;
  final double inputUsdPerMillion;
  final double outputUsdPerMillion;
  final AiSummaryRequestCoalescer _requests;

  Future<ArticleSummary> summarize(Article article) {
    final content = normalizeSummaryContent(article.plainText ?? '');
    if (content.isEmpty) {
      throw ArgumentError.value(article.id, 'article', 'Article has no text');
    }
    final template = prompts.resolve('article-summary', summaryPromptVersion);
    final identity = SummaryCacheIdentity(
      contentHash: summaryContentHash(content),
      model: model,
      promptVersion: template.versionKey,
      language: outputLanguage,
    );
    return _requests.run(
      identity.cacheKey,
      () => _summarize(article, content, template, identity),
    );
  }

  Future<ArticleSummary> _summarize(
    Article article,
    String content,
    PromptTemplate template,
    SummaryCacheIdentity identity,
  ) async {
    final cached = await _readCached(identity);
    if (cached != null) return cached;

    final prompt = template.render(
      <String, String>{
        'articleId': article.id,
        'title': article.title,
        'content': content,
        'language': outputLanguage,
      },
    );
    final response = await _provider.complete(
      AiProviderRequest(
        operationId: article.id,
        model: model,
        prompt: prompt,
        responseSchema: ArticleSummarySchema.jsonSchema,
      ),
    );
    var inputTokens = response.usage.inputTokens;
    var outputTokens = response.usage.outputTokens;
    var providerCalls = 1;
    late ArticleSummary summary;
    try {
      summary = _parse(response, prompt.versionKey);
    } on AiSchemaFailure catch (failure) {
      final repairTemplate = prompts.resolve('article-summary-repair', 1);
      final repairPrompt = repairTemplate.render(
        <String, String>{
          'language': outputLanguage,
          'failureCode': failure.code.name,
          'invalidOutput': response.output,
        },
      );
      final repaired = await _provider.complete(
        AiProviderRequest(
          operationId: '${article.id}:repair',
          model: model,
          prompt: repairPrompt,
          responseSchema: ArticleSummarySchema.jsonSchema,
        ),
      );
      inputTokens += repaired.usage.inputTokens;
      outputTokens += repaired.usage.outputTokens;
      providerCalls++;
      summary = _parse(repaired, prompt.versionKey);
    }
    await _writeCached(
      article: article,
      identity: identity,
      summary: summary,
      inputTokens: inputTokens,
      outputTokens: outputTokens,
      providerCalls: providerCalls,
    );
    return summary;
  }

  ArticleSummary _parse(AiProviderResponse response, String promptVersion) =>
      const ArticleSummarySchema().parse(
        response.output,
        model: response.model,
        promptVersion: promptVersion,
        expectedLanguage: outputLanguage,
      );

  Future<ArticleSummary?> _readCached(SummaryCacheIdentity identity) async {
    final repository = artifacts;
    if (repository == null) return null;
    AiArtifact? artifact;
    try {
      artifact = await repository.read(identity.cacheKey);
    } on FormatException {
      await _deleteInvalid(identity.cacheKey);
      return null;
    } on ArgumentError {
      await _deleteInvalid(identity.cacheKey);
      return null;
    } on Object {
      return null;
    }
    if (artifact == null) return null;
    if (!identity.matches(artifact, AiArtifactType.articleSummary)) {
      await _deleteInvalid(identity.cacheKey);
      return null;
    }
    try {
      return const ArticleSummaryCacheCodec().decode(artifact);
    } on AiSchemaFailure {
      await _deleteInvalid(identity.cacheKey);
      return null;
    }
  }

  Future<void> _writeCached({
    required Article article,
    required SummaryCacheIdentity identity,
    required ArticleSummary summary,
    required int inputTokens,
    required int outputTokens,
    required int providerCalls,
  }) async {
    final repository = artifacts;
    if (repository == null) return;
    final costUsd = inputTokens * inputUsdPerMillion / 1000000 +
        outputTokens * outputUsdPerMillion / 1000000;
    try {
      await repository.write(
        AiArtifact(
          cacheKey: identity.cacheKey,
          articleId: article.id,
          type: AiArtifactType.articleSummary,
          requestModel: model,
          resolvedModel: summary.model,
          promptVersion: identity.promptVersion,
          language: outputLanguage,
          contentHash: identity.contentHash,
          structuredResult: const ArticleSummaryCacheCodec().encode(summary),
          inputTokens: inputTokens,
          outputTokens: outputTokens,
          providerCalls: providerCalls,
          costUsd: costUsd,
          createdAt: clock!.now().toUtc(),
        ),
      );
    } on Object {
      // A valid provider result remains usable when local cache persistence
      // is temporarily unavailable.
    }
  }

  Future<void> _deleteInvalid(String cacheKey) async {
    try {
      await artifacts!.delete(cacheKey);
    } on Object {
      // A corrupt cache value is never returned even if cleanup is deferred.
    }
  }
}
