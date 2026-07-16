import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

final class SanitizedHtml {
  const SanitizedHtml({
    required this.html,
    required this.plainText,
    required this.imageUrls,
    required this.blockCount,
  });

  final String html;
  final String plainText;
  final List<Uri> imageUrls;
  final int blockCount;
}

String sanitizeRemoteHtml(String html, {Uri? baseUri}) =>
    sanitizeHtmlFragment(html, baseUri: baseUri).html;

SanitizedHtml sanitizeHtmlFragment(String html, {Uri? baseUri}) {
  final fragment = html_parser.parseFragment(html);
  for (final element in fragment.querySelectorAll(
    'script, iframe, frame, frameset, form, input, button, textarea, select, '
    'option, object, embed, applet, link, meta, base, style, svg, math',
  )) {
    element.remove();
  }

  final images = <Uri>{};
  for (final element in fragment.querySelectorAll('*')) {
    _sanitizeAttributes(element, baseUri, images);
  }

  final plainText = _plainText(fragment);
  final blockCount = fragment
      .querySelectorAll(
        'p, h1, h2, h3, h4, h5, h6, li, blockquote, pre, table, figure',
      )
      .length;
  return SanitizedHtml(
    html: fragment.outerHtml,
    plainText: plainText,
    imageUrls: List<Uri>.unmodifiable(images),
    blockCount: blockCount,
  );
}

const _allowedAttributes = <String>{
  'href',
  'src',
  'srcset',
  'alt',
  'title',
  'width',
  'height',
  'colspan',
  'rowspan',
  'scope',
  'loading',
  'decoding',
  'controls',
};

void _sanitizeAttributes(
  Element element,
  Uri? baseUri,
  Set<Uri> imageUrls,
) {
  for (final name in element.attributes.keys.toList(growable: false)) {
    final normalizedName = name.toString().toLowerCase();
    if (!_allowedAttributes.contains(normalizedName)) {
      element.attributes.remove(name);
    }
  }

  for (final name in <String>['href', 'src']) {
    final value = element.attributes[name];
    if (value == null) continue;
    final uri = _safeUri(value, baseUri, allowFragment: name == 'href');
    if (uri == null) {
      element.attributes.remove(name);
      continue;
    }
    element.attributes[name] = uri.toString();
    if (element.localName == 'img' && name == 'src') imageUrls.add(uri);
  }

  final sourceSet = element.attributes['srcset'];
  if (sourceSet != null) {
    final safeCandidates = <String>[];
    for (final rawCandidate in sourceSet.split(',')) {
      final parts = rawCandidate.trim().split(RegExp(r'\s+'));
      if (parts.isEmpty || parts.first.isEmpty) continue;
      final uri = _safeUri(parts.first, baseUri);
      if (uri == null) continue;
      safeCandidates.add(
        <String>[uri.toString(), ...parts.skip(1)].join(' '),
      );
      if (element.localName == 'img') imageUrls.add(uri);
    }
    if (safeCandidates.isEmpty) {
      element.attributes.remove('srcset');
    } else {
      element.attributes['srcset'] = safeCandidates.join(', ');
    }
  }
}

Uri? _safeUri(String value, Uri? baseUri, {bool allowFragment = false}) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  if (allowFragment && trimmed.startsWith('#')) return Uri.parse(trimmed);

  final compact =
      trimmed.replaceAll(RegExp(r'[\u0000-\u0020]+'), '').toLowerCase();
  if (compact.startsWith('javascript:') ||
      compact.startsWith('data:') ||
      compact.startsWith('vbscript:') ||
      compact.startsWith('file:')) {
    return null;
  }

  final parsed = Uri.tryParse(trimmed);
  if (parsed == null) return null;
  final resolved = parsed.hasScheme
      ? parsed
      : baseUri == null
          ? null
          : baseUri.resolveUri(parsed);
  if (resolved == null ||
      (resolved.scheme != 'http' && resolved.scheme != 'https')) {
    return null;
  }
  return resolved;
}

const _blockElements = <String>{
  'article',
  'section',
  'div',
  'p',
  'h1',
  'h2',
  'h3',
  'h4',
  'h5',
  'h6',
  'li',
  'blockquote',
  'pre',
  'tr',
  'figure',
  'figcaption',
};

String _plainText(Node root) {
  final buffer = StringBuffer();

  void visit(Node node) {
    if (node is Text) {
      buffer.write(node.data);
      return;
    }
    if (node is Element && node.localName == 'br') buffer.write('\n');
    for (final child in node.nodes) {
      visit(child);
    }
    if (node is Element && _blockElements.contains(node.localName)) {
      buffer.write('\n');
    }
  }

  visit(root);
  return buffer
      .toString()
      .split('\n')
      .map((line) => line.replaceAll(RegExp(r'[\t\r ]+'), ' ').trim())
      .where((line) => line.isNotEmpty)
      .join('\n')
      .trim();
}
