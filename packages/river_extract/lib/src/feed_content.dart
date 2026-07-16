import 'package:river_domain/river_domain.dart';

import 'extraction_pipeline.dart';
import 'html_sanitizer.dart';

enum FeedContentKind { full, summary, truncated, empty }

final class FeedContentAssessment {
  const FeedContentAssessment({
    required this.kind,
    required this.qualityScore,
    required this.content,
    required this.usedExplicitContent,
  });

  final FeedContentKind kind;
  final double qualityScore;
  final SanitizedHtml content;
  final bool usedExplicitContent;
}

final class FeedContentAssessor {
  const FeedContentAssessor();

  FeedContentAssessment assess({
    String? contentHtml,
    String? summary,
    Uri? sourceUri,
  }) {
    final explicitContent = contentHtml?.trim();
    final usesExplicitContent = explicitContent?.isNotEmpty ?? false;
    final candidate = usesExplicitContent ? explicitContent! : summary ?? '';
    final sanitized = sanitizeHtmlFragment(candidate, baseUri: sourceUri);
    final text = sanitized.plainText;
    if (text.isEmpty) {
      return FeedContentAssessment(
        kind: FeedContentKind.empty,
        qualityScore: 0,
        content: sanitized,
        usedExplicitContent: usesExplicitContent,
      );
    }

    final truncated = _hasTruncationSignal(candidate, text);
    final lengthScore = switch (text.length) {
      >= 1200 => 0.56,
      >= 650 => 0.49,
      >= 320 => 0.40,
      >= 220 => 0.32,
      >= 120 => 0.16,
      _ => 0.06,
    };
    final structureScore = (sanitized.blockCount.clamp(0, 5) * 0.06).toDouble();
    final explicitScore = usesExplicitContent ? 0.12 : 0;
    final mediaScore = sanitized.imageUrls.isEmpty ? 0 : 0.04;
    final truncationPenalty = truncated ? 0.55 : 0;
    final quality = (lengthScore +
            structureScore +
            explicitScore +
            mediaScore -
            truncationPenalty)
        .clamp(0, 1)
        .toDouble();
    final isFull = !truncated &&
        quality >= 0.62 &&
        (text.length >= 650 || sanitized.blockCount >= 2);

    return FeedContentAssessment(
      kind: truncated
          ? FeedContentKind.truncated
          : isFull
              ? FeedContentKind.full
              : FeedContentKind.summary,
      qualityScore: quality,
      content: sanitized,
      usedExplicitContent: usesExplicitContent,
    );
  }
}

final class FeedContentExtractionStage implements ExtractionStage {
  const FeedContentExtractionStage({
    this.assessor = const FeedContentAssessor(),
  });

  final FeedContentAssessor assessor;

  @override
  String get id => 'feed-full-content';

  @override
  String get version => '1';

  @override
  StageExtractionResult extract(ExtractionRequest request) {
    if ((request.feedContentHtml?.trim().isEmpty ?? true) &&
        (request.feedSummary?.trim().isEmpty ?? true)) {
      return const StageExtractionFailure(
        ExtractionFailure(
          code: ExtractionFailureCode.sourceContentMissing,
          message: 'The feed did not provide article content.',
        ),
        skipped: true,
      );
    }

    final assessment = assessor.assess(
      contentHtml: request.feedContentHtml,
      summary: request.feedSummary,
      sourceUri: request.sourceUri,
    );
    if (assessment.kind != FeedContentKind.full) {
      final truncated = assessment.kind == FeedContentKind.truncated;
      return StageExtractionFailure(
        ExtractionFailure(
          code: truncated
              ? ExtractionFailureCode.truncatedContent
              : ExtractionFailureCode.contentTooShort,
          message: truncated
              ? 'The feed content contains a truncation marker.'
              : 'The feed content is not complete enough to trust.',
        ),
      );
    }

    return StageExtractionSuccess(
      ExtractedArticle(
        title: request.title?.trim().isNotEmpty ?? false
            ? request.title!.trim()
            : request.sourceUri.host,
        author: request.author,
        canonicalUri: request.sourceUri,
        publishedAt: request.publishedAt,
        html: assessment.content.html,
        plainText: assessment.content.plainText,
        imageUrls: assessment.content.imageUrls,
        extractor: id,
        extractorVersion: version,
        qualityScore: assessment.qualityScore,
      ),
    );
  }
}

bool _hasTruncationSignal(String html, String text) {
  final normalizedText = text.trim().toLowerCase();
  final normalizedHtml = html.toLowerCase();
  final callToAction = RegExp(
    r'(?:read|continue)\s+(?:the\s+)?(?:full\s+)?(?:article|story|more)|'
    r'阅读全文|查看全文|继续阅读|点击阅读原文',
    caseSensitive: false,
  );
  if (callToAction.hasMatch(normalizedText) ||
      callToAction.hasMatch(normalizedHtml)) {
    return true;
  }
  return RegExp(r'(?:\.\.\.|…|\.\.\.\s*\])$').hasMatch(normalizedText);
}
