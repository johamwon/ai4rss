import 'package:river_ai/river_ai.dart';
import 'package:river_domain/river_domain.dart';

enum ArticleSummaryExperienceFailureCode {
  configurationRequired,
  secureStorageUnavailable,
  offline,
  authenticationRequired,
  quotaExceeded,
  rateLimited,
  timeout,
  articleTooLong,
  responseFormatInvalid,
  responseIncomplete,
  responseLanguageMismatch,
  invalidResponse,
  providerUnavailable,
}

final class ArticleSummaryExperienceFailure implements Exception {
  const ArticleSummaryExperienceFailure({
    required this.code,
    required this.retryable,
  });

  final ArticleSummaryExperienceFailureCode code;
  final bool retryable;

  @override
  String toString() =>
      'ArticleSummaryExperienceFailure(${code.name}, retryable: $retryable)';
}

final class ArticleSummaryPreparation {
  const ArticleSummaryPreparation({
    required this.providerLabel,
    required this.model,
    required this.contentCharacters,
    required this.isLongArticle,
    required this.maximumProviderCalls,
    required this.estimatedInputTokens,
    required this.estimatedOutputTokens,
  });

  final String providerLabel;
  final String model;
  final int contentCharacters;
  final bool isLongArticle;
  final int maximumProviderCalls;
  final int estimatedInputTokens;
  final int estimatedOutputTokens;
}

final class ArticleSummaryInspection {
  const ArticleSummaryInspection({
    required this.preparation,
    this.cachedSummary,
    this.accounting,
  });

  final ArticleSummaryPreparation preparation;
  final ArticleSummary? cachedSummary;
  final ArticleSummaryAccounting? accounting;
}

final class ArticleSummaryAccounting {
  const ArticleSummaryAccounting({
    required this.inputTokens,
    required this.outputTokens,
    required this.providerCalls,
    required this.costUsd,
  });

  final int inputTokens;
  final int outputTokens;
  final int providerCalls;
  final double costUsd;
}

abstract interface class ArticleSummaryExperience {
  Future<ArticleSummaryInspection> inspect(Article article);

  Future<ArticleSummary> summarize(Article article);
}

final class MultiArticleSummaryInspection {
  const MultiArticleSummaryInspection({
    required this.providerLabel,
    required this.model,
    required this.articleCount,
    required this.contentCharacters,
    required this.maximumProviderCalls,
  });

  final String providerLabel;
  final String model;
  final int articleCount;
  final int contentCharacters;
  final int maximumProviderCalls;
}

abstract interface class MultiArticleSummaryExperience {
  Future<MultiArticleSummaryInspection> inspectMany(List<Article> articles);

  Future<MultiArticleSummary> summarizeMany(List<Article> articles);
}

final class ByokArticleSummaryExperience
    implements ArticleSummaryExperience, MultiArticleSummaryExperience {
  ByokArticleSummaryExperience({
    required AiByokConfigurationVault configurations,
    required AiArtifactRepository artifacts,
    required AiLongSummaryCheckpointStore checkpoints,
    required NetworkMonitor network,
    required Clock clock,
    required AiHttpTransport transport,
    AiSummaryRequestCoalescer? requests,
  })  : _configurations = configurations,
        _artifacts = artifacts,
        _checkpoints = checkpoints,
        _network = network,
        _clock = clock,
        _transport = transport,
        _requests = requests ?? AiSummaryRequestCoalescer();

  final AiByokConfigurationVault _configurations;
  final AiArtifactRepository _artifacts;
  final AiLongSummaryCheckpointStore _checkpoints;
  final NetworkMonitor _network;
  final Clock _clock;
  final AiHttpTransport _transport;
  final AiSummaryRequestCoalescer _requests;

  @override
  Future<ArticleSummaryInspection> inspect(Article article) async {
    final route = await _route(article);
    try {
      final cached = route.isLongArticle
          ? (await route.longService.readCached(article))?.summary
          : await route.shortService.readCached(article);
      final artifact = cached == null
          ? null
          : route.isLongArticle
              ? await route.longService.readCachedArtifact(article)
              : await route.shortService.readCachedArtifact(article);
      return ArticleSummaryInspection(
        preparation: route.preparation,
        cachedSummary: cached,
        accounting: artifact == null
            ? null
            : ArticleSummaryAccounting(
                inputTokens: artifact.inputTokens,
                outputTokens: artifact.outputTokens,
                providerCalls: artifact.providerCalls,
                costUsd: artifact.costUsd,
              ),
      );
    } on Object catch (error) {
      throw _mapFailure(error);
    }
  }

  @override
  Future<ArticleSummary> summarize(Article article) async {
    final route = await _route(article);
    try {
      final cached = route.isLongArticle
          ? (await route.longService.readCached(article))?.summary
          : await route.shortService.readCached(article);
      if (cached != null) return cached;
      if ((await _network.check()).isOffline) {
        throw const ArticleSummaryExperienceFailure(
          code: ArticleSummaryExperienceFailureCode.offline,
          retryable: true,
        );
      }
      return route.isLongArticle
          ? (await route.longService.summarize(article)).summary
          : await route.shortService.summarize(article);
    } on Object catch (error) {
      throw _mapFailure(error);
    }
  }

  @override
  Future<MultiArticleSummaryInspection> inspectMany(
    List<Article> articles,
  ) async {
    final configuration = await _configuration();
    try {
      final service = _multiService(configuration);
      final prepared = service.prepare(articles);
      return MultiArticleSummaryInspection(
        providerLabel: configuration.displayName,
        model: configuration.model,
        articleCount: articles.length,
        contentCharacters: prepared.contentCharacters,
        maximumProviderCalls: 2,
      );
    } on Object catch (error) {
      throw _mapFailure(error);
    }
  }

  @override
  Future<MultiArticleSummary> summarizeMany(List<Article> articles) async {
    final configuration = await _configuration();
    try {
      if ((await _network.check()).isOffline) {
        throw const ArticleSummaryExperienceFailure(
          code: ArticleSummaryExperienceFailureCode.offline,
          retryable: true,
        );
      }
      return await _multiService(configuration).summarize(articles);
    } on Object catch (error) {
      throw _mapFailure(error);
    }
  }

  MultiArticleSummaryService _multiService(AiByokConfiguration configuration) =>
      MultiArticleSummaryService(
        OpenAiCompatibleProvider(
          configuration: configuration,
          transport: _transport,
          clock: StopwatchAiMonotonicClock(),
        ),
        model: configuration.model,
      );

  Future<_SummaryRoute> _route(Article article) async {
    final configuration = await _configuration();
    try {
      final provider = OpenAiCompatibleProvider(
        configuration: configuration,
        transport: _transport,
        clock: StopwatchAiMonotonicClock(),
      );
      final short = SummaryService(
        provider,
        model: configuration.model,
        artifacts: _artifacts,
        clock: _clock,
        requests: _requests,
      );
      final long = LongArticleSummaryService(
        provider,
        checkpoints: _checkpoints,
        model: configuration.model,
        artifacts: _artifacts,
        clock: _clock,
        requests: _requests,
      );
      final preflight = long.preflight(article);
      final isLongArticle = preflight.chunks.length > 1;
      final estimate = preflight.estimate;
      return _SummaryRoute(
        shortService: short,
        longService: long,
        isLongArticle: isLongArticle,
        preparation: ArticleSummaryPreparation(
          providerLabel: configuration.displayName,
          model: configuration.model,
          contentCharacters:
              normalizeSummaryContent(article.plainText ?? '').length,
          isLongArticle: isLongArticle,
          maximumProviderCalls: isLongArticle ? estimate.providerCalls : 2,
          estimatedInputTokens: isLongArticle ? estimate.inputTokens : 0,
          estimatedOutputTokens: isLongArticle ? estimate.outputTokens : 3200,
        ),
      );
    } on Object catch (error) {
      throw _mapFailure(error);
    }
  }

  Future<AiByokConfiguration> _configuration() async {
    try {
      final configuration = await _configurations.read();
      if (configuration == null) {
        throw const ArticleSummaryExperienceFailure(
          code: ArticleSummaryExperienceFailureCode.configurationRequired,
          retryable: false,
        );
      }
      return configuration;
    } on ArticleSummaryExperienceFailure {
      rethrow;
    } on Object {
      throw const ArticleSummaryExperienceFailure(
        code: ArticleSummaryExperienceFailureCode.secureStorageUnavailable,
        retryable: true,
      );
    }
  }

  ArticleSummaryExperienceFailure _mapFailure(Object error) {
    if (error is ArticleSummaryExperienceFailure) return error;
    if (error is AiProviderFailure) {
      return switch (error.code) {
        AiProviderFailureCode.authenticationRequired =>
          const ArticleSummaryExperienceFailure(
            code: ArticleSummaryExperienceFailureCode.authenticationRequired,
            retryable: false,
          ),
        AiProviderFailureCode.quotaExceeded =>
          const ArticleSummaryExperienceFailure(
            code: ArticleSummaryExperienceFailureCode.quotaExceeded,
            retryable: false,
          ),
        AiProviderFailureCode.rateLimited =>
          const ArticleSummaryExperienceFailure(
            code: ArticleSummaryExperienceFailureCode.rateLimited,
            retryable: true,
          ),
        AiProviderFailureCode.timeout => const ArticleSummaryExperienceFailure(
            code: ArticleSummaryExperienceFailureCode.timeout,
            retryable: true,
          ),
        AiProviderFailureCode.invalidRequest =>
          const ArticleSummaryExperienceFailure(
            code: ArticleSummaryExperienceFailureCode.responseFormatInvalid,
            retryable: true,
          ),
        AiProviderFailureCode.cancelled =>
          const ArticleSummaryExperienceFailure(
            code: ArticleSummaryExperienceFailureCode.providerUnavailable,
            retryable: true,
          ),
        AiProviderFailureCode.unavailable =>
          const ArticleSummaryExperienceFailure(
            code: ArticleSummaryExperienceFailureCode.providerUnavailable,
            retryable: true,
          ),
      };
    }
    if (error is AiLongSummaryFailure) {
      return ArticleSummaryExperienceFailure(
        code: error.code == AiLongSummaryFailureCode.tooManyChunks ||
                error.code == AiLongSummaryFailureCode.contextBudgetExceeded
            ? ArticleSummaryExperienceFailureCode.articleTooLong
            : ArticleSummaryExperienceFailureCode.invalidResponse,
        retryable: false,
      );
    }
    if (error is AiSchemaFailure) {
      return ArticleSummaryExperienceFailure(
        code: switch (error.code) {
          AiSchemaFailureCode.malformedJson ||
          AiSchemaFailureCode.wrongRoot =>
            ArticleSummaryExperienceFailureCode.responseFormatInvalid,
          AiSchemaFailureCode.missingField =>
            ArticleSummaryExperienceFailureCode.responseIncomplete,
          AiSchemaFailureCode.languageMismatch =>
            ArticleSummaryExperienceFailureCode.responseLanguageMismatch,
          AiSchemaFailureCode.unexpectedField ||
          AiSchemaFailureCode.invalidValue ||
          AiSchemaFailureCode.tooLarge =>
            ArticleSummaryExperienceFailureCode.invalidResponse,
        },
        retryable: true,
      );
    }
    if (error is FormatException || error is ArgumentError) {
      return const ArticleSummaryExperienceFailure(
        code: ArticleSummaryExperienceFailureCode.responseFormatInvalid,
        retryable: true,
      );
    }
    return const ArticleSummaryExperienceFailure(
      code: ArticleSummaryExperienceFailureCode.providerUnavailable,
      retryable: true,
    );
  }
}

final class _SummaryRoute {
  const _SummaryRoute({
    required this.shortService,
    required this.longService,
    required this.isLongArticle,
    required this.preparation,
  });

  final SummaryService shortService;
  final LongArticleSummaryService longService;
  final bool isLongArticle;
  final ArticleSummaryPreparation preparation;
}
