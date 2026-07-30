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

final class DynamicPageRenderRequest {
  const DynamicPageRenderRequest({
    required this.sourceUri,
    this.timeout = const Duration(seconds: 12),
    this.maxHtmlCharacters = 5 * 1024 * 1024,
  });

  final Uri sourceUri;
  final Duration timeout;
  final int maxHtmlCharacters;
}

sealed class DynamicPageRenderResult {
  const DynamicPageRenderResult();
}

final class DynamicPageRenderSuccess extends DynamicPageRenderResult {
  const DynamicPageRenderSuccess({required this.html, required this.finalUri});

  final String html;
  final Uri finalUri;
}

final class DynamicPageRenderFailure extends DynamicPageRenderResult {
  const DynamicPageRenderFailure(this.failure);

  final ExtractionFailure failure;
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
    this.whyItMatters = '',
    this.topics = const <String>[],
    this.entities = const <String>[],
    this.estimatedReadingMinutes = 0,
  });

  final String oneLine;
  final List<String> keyPoints;
  final String language;
  final String model;
  final String promptVersion;
  final String whyItMatters;
  final List<String> topics;
  final List<String> entities;
  final int estimatedReadingMinutes;
}

enum ReaderFontFamily { system, serif, sansSerif }

enum ReaderThemePreference { system, light, dark }

final class ReaderSettings {
  const ReaderSettings({
    this.fontFamily = ReaderFontFamily.system,
    this.fontScale = 1,
    this.lineHeight = 1.75,
    this.contentWidth = 760,
    this.theme = ReaderThemePreference.system,
  })  : assert(fontScale >= 0.8 && fontScale <= 1.6),
        assert(lineHeight >= 1.3 && lineHeight <= 2.2),
        assert(contentWidth >= 480 && contentWidth <= 1000);

  final ReaderFontFamily fontFamily;
  final double fontScale;
  final double lineHeight;
  final double contentWidth;
  final ReaderThemePreference theme;

  ReaderSettings copyWith({
    ReaderFontFamily? fontFamily,
    double? fontScale,
    double? lineHeight,
    double? contentWidth,
    ReaderThemePreference? theme,
  }) =>
      ReaderSettings(
        fontFamily: fontFamily ?? this.fontFamily,
        fontScale: fontScale ?? this.fontScale,
        lineHeight: lineHeight ?? this.lineHeight,
        contentWidth: contentWidth ?? this.contentWidth,
        theme: theme ?? this.theme,
      );

  @override
  bool operator ==(Object other) =>
      other is ReaderSettings &&
      other.fontFamily == fontFamily &&
      other.fontScale == fontScale &&
      other.lineHeight == lineHeight &&
      other.contentWidth == contentWidth &&
      other.theme == theme;

  @override
  int get hashCode =>
      Object.hash(fontFamily, fontScale, lineHeight, contentWidth, theme);
}

final class ShareAnchor {
  const ShareAnchor({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final double left;
  final double top;
  final double width;
  final double height;
}

final class ShareRequest {
  const ShareRequest({
    required this.text,
    this.title,
    this.subject,
    this.anchor,
  });

  final String text;
  final String? title;
  final String? subject;
  final ShareAnchor? anchor;
}

enum ShareOutcome { completed, dismissed, unavailable }

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
