import 'dart:async';

import 'package:river_domain/river_domain.dart';

import 'dynamic_page_stage.dart';
import 'feed_content.dart';
import 'html_stages.dart';
import 'readability_stage.dart';

abstract interface class ExtractionStage {
  String get id;
  String get version;

  FutureOr<StageExtractionResult> extract(ExtractionRequest request);
}

sealed class StageExtractionResult {
  const StageExtractionResult();
}

final class StageExtractionSuccess extends StageExtractionResult {
  const StageExtractionSuccess(this.article);

  final ExtractedArticle article;
}

final class StageExtractionFailure extends StageExtractionResult {
  const StageExtractionFailure(this.failure, {this.skipped = false});

  final ExtractionFailure failure;
  final bool skipped;
}

final class ExtractionPipeline implements FullTextExtractor {
  const ExtractionPipeline({required this.stages});

  final List<ExtractionStage> stages;

  @override
  Future<ExtractionResult> extract(ExtractionRequest request) async {
    final inputFailure = _validate(request);
    if (inputFailure != null) {
      return ExtractionFailureResult(
        failure: inputFailure,
        attempts: const <ExtractionAttempt>[],
      );
    }

    final attempts = <ExtractionAttempt>[];
    ExtractionFailure? mostRelevantFailure;
    for (final stage in stages) {
      StageExtractionResult stageResult;
      try {
        stageResult = await stage.extract(request);
      } catch (_) {
        stageResult = const StageExtractionFailure(
          ExtractionFailure(
            code: ExtractionFailureCode.unexpected,
            message: 'The extraction stage failed unexpectedly.',
            retryable: true,
          ),
        );
      }

      switch (stageResult) {
        case StageExtractionSuccess(:final article):
          attempts.add(
            ExtractionAttempt(
              extractor: stage.id,
              extractorVersion: stage.version,
              outcome: ExtractionAttemptOutcome.succeeded,
              qualityScore: article.qualityScore,
            ),
          );
          return ExtractionSuccess(
            article: article,
            attempts: List<ExtractionAttempt>.unmodifiable(attempts),
          );
        case StageExtractionFailure(:final failure, :final skipped):
          attempts.add(
            ExtractionAttempt(
              extractor: stage.id,
              extractorVersion: stage.version,
              outcome: skipped
                  ? ExtractionAttemptOutcome.skipped
                  : ExtractionAttemptOutcome.failed,
              failureCode: failure.code,
            ),
          );
          if (!skipped || mostRelevantFailure == null) {
            mostRelevantFailure = failure;
          }
      }
    }

    return ExtractionFailureResult(
      failure: mostRelevantFailure ??
          const ExtractionFailure(
            code: ExtractionFailureCode.unavailable,
            message: 'No extraction stage was available for this input.',
          ),
      attempts: List<ExtractionAttempt>.unmodifiable(attempts),
    );
  }
}

final class LayeredFullTextExtractor implements FullTextExtractor {
  const LayeredFullTextExtractor()
      : _pipeline = _staticPipeline,
        extractorVersions = currentExtractorVersions;

  LayeredFullTextExtractor.withDynamicPageRenderer(
    DynamicPageRenderer renderer,
  )   : _pipeline = ExtractionPipeline(
          stages: <ExtractionStage>[
            ..._staticStages,
            DynamicPageExtractionStage(renderer: renderer),
          ],
        ),
        extractorVersions = Map<String, String>.unmodifiable(
          <String, String>{
            ...currentExtractorVersions,
            DynamicPageExtractionStage.extractorId:
                DynamicPageExtractionStage.extractorVersion,
          },
        );

  static const _staticStages = <ExtractionStage>[
    FeedContentExtractionStage(),
    WeChatStaticExtractionStage(),
    ReadabilityExtractionStage(),
  ];

  static const Map<String, String> currentExtractorVersions = <String, String>{
    'feed-full-content': '1',
    'wechat-static': '1',
    'readability': '1',
  };

  static const _staticPipeline = ExtractionPipeline(
    stages: _staticStages,
  );

  final ExtractionPipeline _pipeline;
  final Map<String, String> extractorVersions;

  @override
  Future<ExtractionResult> extract(ExtractionRequest request) =>
      _pipeline.extract(request);
}

ExtractionFailure? _validate(ExtractionRequest request) {
  if (!request.sourceUri.hasScheme ||
      (request.sourceUri.scheme != 'http' &&
          request.sourceUri.scheme != 'https')) {
    return const ExtractionFailure(
      code: ExtractionFailureCode.invalidInput,
      message: 'Only HTTP and HTTPS source URLs can be extracted.',
    );
  }
  if (request.pageHtml == null &&
      request.feedContentHtml == null &&
      request.feedSummary == null) {
    return const ExtractionFailure(
      code: ExtractionFailureCode.sourceContentMissing,
      message: 'The extraction request does not contain source content.',
    );
  }
  return null;
}
