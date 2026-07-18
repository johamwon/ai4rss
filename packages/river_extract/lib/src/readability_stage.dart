import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:river_domain/river_domain.dart';

import 'extraction_pipeline.dart';
import 'html_sanitizer.dart';
import 'readability.dart';

final class ReadabilityExtractionStage implements ExtractionStage {
  const ReadabilityExtractionStage({
    this.parser = const ReadabilityParser(),
    this.maxInputCharacters = 5 * 1024 * 1024,
    this.maxElements = 20000,
  });

  final ReadabilityParser parser;
  final int maxInputCharacters;
  final int maxElements;

  @override
  String get id => 'readability';

  @override
  String get version => '1';

  @override
  StageExtractionResult extract(ExtractionRequest request) {
    final pageHtml = request.pageHtml;
    if (pageHtml == null || pageHtml.trim().isEmpty) {
      return const StageExtractionFailure(
        ExtractionFailure(
          code: ExtractionFailureCode.sourceContentMissing,
          message: 'The page HTML is missing.',
        ),
        skipped: true,
      );
    }
    if (pageHtml.length > maxInputCharacters) {
      return const StageExtractionFailure(
        ExtractionFailure(
          code: ExtractionFailureCode.responseTooLarge,
          message: 'The page HTML exceeds the extraction size limit.',
        ),
      );
    }

    final Document document;
    try {
      document = html_parser.parse(pageHtml);
    } catch (_) {
      return const StageExtractionFailure(
        ExtractionFailure(
          code: ExtractionFailureCode.malformedDocument,
          message: 'The page HTML could not be parsed.',
        ),
      );
    }
    if (document.querySelectorAll('*').length > maxElements) {
      return const StageExtractionFailure(
        ExtractionFailure(
          code: ExtractionFailureCode.responseTooLarge,
          message: 'The page DOM exceeds the extraction element limit.',
        ),
      );
    }

    final selection = parser.parse(document);
    if (selection == null) {
      return const StageExtractionFailure(
        ExtractionFailure(
          code: ExtractionFailureCode.articleBodyMissing,
          message: 'Readability could not identify an article body.',
        ),
      );
    }

    final sanitized = sanitizeHtmlFragment(
      selection.content.innerHtml,
      baseUri: request.sourceUri,
    );
    if (sanitized.plainText.isEmpty) {
      return const StageExtractionFailure(
        ExtractionFailure(
          code: ExtractionFailureCode.unsafeContent,
          message: 'No readable content remained after safety cleanup.',
        ),
      );
    }

    final quality = _qualityScore(sanitized, selection.score);
    if (sanitized.plainText.length < 120 || quality < 0.50) {
      return const StageExtractionFailure(
        ExtractionFailure(
          code: ExtractionFailureCode.contentTooShort,
          message: 'The Readability result is too short to trust.',
        ),
      );
    }

    return StageExtractionSuccess(
      ExtractedArticle(
        title: _firstNonEmpty(<String?>[
              request.title,
              _meta(document, 'meta[property="og:title"]'),
              _meta(document, 'meta[name="twitter:title"]'),
              document.querySelector('h1')?.text,
              document.querySelector('title')?.text,
            ]) ??
            request.sourceUri.host,
        author: _firstNonEmpty(<String?>[
          request.author,
          _meta(document, 'meta[name="author"]'),
          _meta(document, 'meta[property="article:author"]'),
          document.querySelector('[rel="author"]')?.text,
          document.querySelector('[itemprop="author"]')?.text,
          document.querySelector('.byline, .author')?.text,
        ]),
        canonicalUri: _canonicalUri(document, request.sourceUri),
        publishedAt: request.publishedAt ?? _publishedAt(document),
        html: sanitized.html,
        plainText: sanitized.plainText,
        imageUrls: sanitized.imageUrls,
        extractor: id,
        extractorVersion: version,
        qualityScore: quality,
      ),
    );
  }
}

double _qualityScore(SanitizedHtml content, double readabilityScore) {
  final lengthScore = switch (content.plainText.length) {
    >= 1600 => 0.50,
    >= 800 => 0.42,
    >= 400 => 0.34,
    >= 200 => 0.26,
    _ => 0.16,
  };
  final structureScore = (content.blockCount.clamp(0, 5) * 0.05).toDouble();
  final mediaScore = content.imageUrls.isEmpty ? 0 : 0.04;
  final candidateScore = (readabilityScore / 100).clamp(0, 0.12).toDouble();
  return (lengthScore + structureScore + mediaScore + candidateScore)
      .clamp(0, 1)
      .toDouble();
}

String? _meta(Document document, String selector) =>
    _clean(document.querySelector(selector)?.attributes['content']);

Uri _canonicalUri(Document document, Uri fallback) {
  final value = _firstNonEmpty(<String?>[
    document.querySelector('link[rel="canonical"]')?.attributes['href'],
    _meta(document, 'meta[property="og:url"]'),
  ]);
  if (value == null) return fallback;
  final parsed = Uri.tryParse(value);
  if (parsed == null) return fallback;
  final resolved = parsed.hasScheme ? parsed : fallback.resolveUri(parsed);
  return resolved.scheme == 'http' || resolved.scheme == 'https'
      ? resolved
      : fallback;
}

DateTime? _publishedAt(Document document) {
  final value = _firstNonEmpty(<String?>[
    _meta(document, 'meta[property="article:published_time"]'),
    _meta(document, 'meta[itemprop="datePublished"]'),
    document.querySelector('time[datetime]')?.attributes['datetime'],
  ]);
  return value == null ? null : DateTime.tryParse(value)?.toUtc();
}

String? _firstNonEmpty(Iterable<String?> values) {
  for (final value in values) {
    final cleaned = _clean(value);
    if (cleaned != null) return cleaned;
  }
  return null;
}

String? _clean(String? value) {
  final cleaned = value?.replaceAll(RegExp(r'\s+'), ' ').trim();
  return cleaned == null || cleaned.isEmpty ? null : cleaned;
}
