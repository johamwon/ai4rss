enum ContentSource { feed, web, weChat, podcast }

enum ExtractionFailureCode {
  invalidInput,
  unsupportedSource,
  sourceContentMissing,
  articleBodyMissing,
  contentTooShort,
  truncatedContent,
  unsafeContent,
  malformedDocument,
  network,
  timeout,
  responseTooLarge,
  cancelled,
  unavailable,
  unexpected,
}

enum ExtractionAttemptOutcome { succeeded, skipped, failed }

final class ExtractionRequest {
  const ExtractionRequest({
    required this.sourceUri,
    this.articleId,
    this.pageHtml,
    this.feedContentHtml,
    this.feedSummary,
    this.title,
    this.author,
    this.publishedAt,
    this.etag,
    this.lastModified,
    this.forceReparse = false,
  });

  final Uri sourceUri;
  final String? articleId;
  final String? pageHtml;
  final String? feedContentHtml;
  final String? feedSummary;
  final String? title;
  final String? author;
  final DateTime? publishedAt;
  final String? etag;
  final String? lastModified;
  final bool forceReparse;
}

final class ExtractionFailure {
  const ExtractionFailure({
    required this.code,
    required this.message,
    this.retryable = false,
  });

  final ExtractionFailureCode code;
  final String message;
  final bool retryable;
}

final class ExtractionAttempt {
  const ExtractionAttempt({
    required this.extractor,
    required this.extractorVersion,
    required this.outcome,
    this.failureCode,
    this.qualityScore,
  }) : assert(
          qualityScore == null || (qualityScore >= 0 && qualityScore <= 1),
          'qualityScore must be between 0 and 1',
        );

  final String extractor;
  final String extractorVersion;
  final ExtractionAttemptOutcome outcome;
  final ExtractionFailureCode? failureCode;
  final double? qualityScore;
}

sealed class ExtractionResult {
  const ExtractionResult({required this.attempts});

  final List<ExtractionAttempt> attempts;
}

final class ExtractionSuccess extends ExtractionResult {
  const ExtractionSuccess({required this.article, required super.attempts});

  final ExtractedArticle article;
}

final class ExtractionFailureResult extends ExtractionResult {
  const ExtractionFailureResult({
    required this.failure,
    required super.attempts,
  });

  final ExtractionFailure failure;
}

final class Article {
  const Article({
    required this.id,
    required this.url,
    required this.title,
    required this.source,
    this.author,
    this.publishedAt,
    this.plainText,
  });

  final String id;
  final Uri url;
  final String title;
  final ContentSource source;
  final String? author;
  final DateTime? publishedAt;
  final String? plainText;
}

final class ExtractedArticle {
  const ExtractedArticle({
    required this.title,
    required this.html,
    required this.plainText,
    required this.extractor,
    required this.extractorVersion,
    this.author,
    this.canonicalUri,
    this.publishedAt,
    this.imageUrls = const <Uri>[],
    this.qualityScore = 0,
  }) : assert(
          qualityScore >= 0 && qualityScore <= 1,
          'qualityScore must be between 0 and 1',
        );

  final String title;
  final String? author;
  final Uri? canonicalUri;
  final DateTime? publishedAt;
  final String html;
  final String plainText;
  final List<Uri> imageUrls;
  final String extractor;
  final String extractorVersion;
  final double qualityScore;
}

final class CachedExtraction {
  const CachedExtraction({
    required this.articleId,
    required this.article,
    required this.contentHash,
    required this.extractedAt,
    this.etag,
    this.lastModified,
    this.lastFailureCode,
  });

  final String articleId;
  final ExtractedArticle article;
  final String contentHash;
  final DateTime extractedAt;
  final String? etag;
  final String? lastModified;
  final ExtractionFailureCode? lastFailureCode;
}

final class ArticleSummary {
  const ArticleSummary({
    required this.oneLine,
    required this.keyPoints,
    required this.language,
    required this.model,
    required this.promptVersion,
  });

  final String oneLine;
  final List<String> keyPoints;
  final String language;
  final String model;
  final String promptVersion;
}

enum ReadingEventType {
  impression,
  open,
  activeRead,
  completed,
  starred,
  savedToKnowledge,
  notInterested,
}

final class ReadingEvent {
  const ReadingEvent({
    required this.articleId,
    required this.type,
    required this.occurredAt,
    this.activeSeconds = 0,
    this.completionRatio = 0,
  });

  final String articleId;
  final ReadingEventType type;
  final DateTime occurredAt;
  final int activeSeconds;
  final double completionRatio;
}

enum AudioKind { articleTts, podcastEpisode }

final class AudioItem {
  const AudioItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.sourceUri,
  });

  final String id;
  final AudioKind kind;
  final String title;
  final Uri sourceUri;
}
