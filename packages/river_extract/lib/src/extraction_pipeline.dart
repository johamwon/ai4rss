import 'package:river_domain/river_domain.dart';

import 'feed_content.dart';
import 'html_stages.dart';

abstract interface class ExtractionStage {
  String get id;
  String get version;

  StageExtractionResult extract(ExtractionRequest request);
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
        stageResult = stage.extract(request);
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

final class BasicHtmlExtractor implements FullTextExtractor {
  const BasicHtmlExtractor();

  static const _pipeline = ExtractionPipeline(
    stages: <ExtractionStage>[
      FeedContentExtractionStage(),
      WeChatStaticExtractionStage(),
      GenericHtmlExtractionStage(),
    ],
  );

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
