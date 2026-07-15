library;

import 'package:river_domain/river_domain.dart';

final class BasicHtmlExtractor implements FullTextExtractor {
  const BasicHtmlExtractor();

  @override
  Future<ExtractedArticle> extract({
    required Uri sourceUri,
    required String rawHtml,
  }) async {
    final sanitized = sanitizeRemoteHtml(rawHtml);
    final title = _firstGroup(
          sanitized,
          RegExp(
            r'<title[^>]*>(.*?)</title>',
            caseSensitive: false,
            dotAll: true,
          ),
        ) ??
        sourceUri.host;
    final body = _firstGroup(
          sanitized,
          RegExp(
            r'''<(?:article|main|div)[^>]*(?:id=["']js_content["']|class=["'][^"']*article[^"']*["'])?[^>]*>(.*?)</(?:article|main|div)>''',
            caseSensitive: false,
            dotAll: true,
          ),
        ) ??
        sanitized;
    final plainText = body
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return ExtractedArticle(
      title: _decodeBasicEntities(title).trim(),
      html: body,
      plainText: _decodeBasicEntities(plainText),
      extractor: 'synthetic-html',
      extractorVersion: '1',
    );
  }
}

String sanitizeRemoteHtml(String html) {
  return html
      .replaceAll(
        RegExp(
          r'<script\b[^>]*>.*?</script>',
          caseSensitive: false,
          dotAll: true,
        ),
        '',
      )
      .replaceAll(
        RegExp(
          r'<iframe\b[^>]*>.*?</iframe>',
          caseSensitive: false,
          dotAll: true,
        ),
        '',
      )
      .replaceAll(
        RegExp(r'''\son[a-z]+\s*=\s*(["']).*?\1''', caseSensitive: false),
        '',
      )
      .replaceAll(RegExp(r'javascript\s*:', caseSensitive: false), '');
}

String? _firstGroup(String source, RegExp pattern) =>
    pattern.firstMatch(source)?.group(1);

String _decodeBasicEntities(String value) => value
    .replaceAll('&amp;', '&')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'");
