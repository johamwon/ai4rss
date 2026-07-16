import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:river_domain/river_domain.dart';

import 'extraction_pipeline.dart';
import 'html_sanitizer.dart';

final class WeChatStaticExtractionStage implements ExtractionStage {
  const WeChatStaticExtractionStage();

  @override
  String get id => 'wechat-static';

  @override
  String get version => '1';

  @override
  StageExtractionResult extract(ExtractionRequest request) {
    if (!_isWeChatHost(request.sourceUri.host)) {
      return const StageExtractionFailure(
        ExtractionFailure(
          code: ExtractionFailureCode.unsupportedSource,
          message: 'The source is not a supported WeChat article URL.',
        ),
        skipped: true,
      );
    }
    final pageHtml = request.pageHtml;
    if (pageHtml == null || pageHtml.trim().isEmpty) {
      return const StageExtractionFailure(
        ExtractionFailure(
          code: ExtractionFailureCode.sourceContentMissing,
          message: 'The WeChat page HTML is missing.',
          retryable: true,
        ),
      );
    }

    final document = html_parser.parse(pageHtml);
    final body = document.querySelector('#js_content');
    if (body == null) {
      return const StageExtractionFailure(
        ExtractionFailure(
          code: ExtractionFailureCode.articleBodyMissing,
          message: 'The WeChat article body was not found.',
        ),
      );
    }

    _removeWeChatChrome(body);
    _normalizeLazyImages(body);
    _replaceMediaWithPlaceholders(body);
    final sanitized = sanitizeHtmlFragment(
      body.innerHtml,
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

    final quality = _qualityScore(
      sanitized,
      sourceBonus: 0.28,
    );
    if (sanitized.plainText.length < 40 || quality < 0.48) {
      return const StageExtractionFailure(
        ExtractionFailure(
          code: ExtractionFailureCode.contentTooShort,
          message: 'The WeChat article body is too short to trust.',
        ),
      );
    }

    final canonicalUri = _canonicalUri(document, request.sourceUri);
    return StageExtractionSuccess(
      ExtractedArticle(
        title: _firstNonEmpty(<String?>[
              request.title,
              document.querySelector('#activity-name')?.text,
              _meta(document, 'meta[property="og:title"]'),
              document.querySelector('title')?.text,
            ]) ??
            request.sourceUri.host,
        author: _firstNonEmpty(<String?>[
          request.author,
          document.querySelector('#js_name')?.text,
          _meta(document, 'meta[name="author"]'),
        ]),
        canonicalUri: canonicalUri,
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

final class GenericHtmlExtractionStage implements ExtractionStage {
  const GenericHtmlExtractionStage();

  @override
  String get id => 'basic-html';

  @override
  String get version => '2';

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

    final document = html_parser.parse(pageHtml);
    final body = document.querySelector('article') ??
        document.querySelector('main') ??
        document.querySelector('[role="main"]') ??
        document.body;
    if (body == null) {
      return const StageExtractionFailure(
        ExtractionFailure(
          code: ExtractionFailureCode.articleBodyMissing,
          message: 'The page does not contain a readable body.',
        ),
      );
    }
    final sanitized = sanitizeHtmlFragment(
      body.innerHtml,
      baseUri: request.sourceUri,
    );
    if (sanitized.plainText.length < 80) {
      return const StageExtractionFailure(
        ExtractionFailure(
          code: ExtractionFailureCode.contentTooShort,
          message: 'The page body is too short to trust.',
        ),
      );
    }
    final quality = _qualityScore(sanitized, sourceBonus: 0.08);
    return StageExtractionSuccess(
      ExtractedArticle(
        title: _firstNonEmpty(<String?>[
              request.title,
              document.querySelector('title')?.text,
            ]) ??
            request.sourceUri.host,
        author: request.author,
        canonicalUri: request.sourceUri,
        publishedAt: request.publishedAt,
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

bool _isWeChatHost(String host) {
  final normalized = host.toLowerCase();
  return normalized == 'mp.weixin.qq.com' ||
      normalized.endsWith('.mp.weixin.qq.com');
}

void _removeWeChatChrome(Element body) {
  for (final element in body.querySelectorAll(
    '#js_pc_qr_code, #js_profile_qrcode, .qr_code_pc, .rich_media_tool, '
    '.reward_area, .js_ad_link, .rich_media_extra, mpprofile',
  )) {
    element.remove();
  }
}

void _normalizeLazyImages(Element body) {
  for (final image in body.querySelectorAll('img')) {
    final lazySource = _firstNonEmpty(<String?>[
      image.attributes['data-src'],
      image.attributes['data-original'],
    ]);
    if ((image.attributes['src']?.trim().isEmpty ?? true) &&
        lazySource != null) {
      image.attributes['src'] = lazySource;
    }
    final lazySourceSet = image.attributes['data-srcset'];
    if ((image.attributes['srcset']?.trim().isEmpty ?? true) &&
        lazySourceSet != null &&
        lazySourceSet.trim().isNotEmpty) {
      image.attributes['srcset'] = lazySourceSet;
    }
  }
}

void _replaceMediaWithPlaceholders(Element body) {
  for (final media in body.querySelectorAll(
    'mpvoice, qqmusic, mp-common-mpaudio, audio, video, iframe',
  )) {
    final placeholder = Element.tag('p')
      ..text = media.localName == 'video' || media.localName == 'iframe'
          ? '[Video content]'
          : '[Audio content]';
    media.replaceWith(placeholder);
  }
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
    _meta(document, 'meta[name="publish_time"]'),
    document.querySelector('#publish_time')?.text,
  ]);
  return value == null ? null : DateTime.tryParse(value)?.toUtc();
}

double _qualityScore(SanitizedHtml content, {required double sourceBonus}) {
  final lengthScore = switch (content.plainText.length) {
    >= 1200 => 0.50,
    >= 600 => 0.42,
    >= 300 => 0.34,
    >= 120 => 0.25,
    _ => 0.12,
  };
  final structureScore = (content.blockCount.clamp(0, 5) * 0.05).toDouble();
  final mediaScore = content.imageUrls.isEmpty ? 0 : 0.04;
  return (lengthScore + structureScore + mediaScore + sourceBonus)
      .clamp(0, 1)
      .toDouble();
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
