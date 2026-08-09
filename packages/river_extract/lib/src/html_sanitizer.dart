import 'dart:convert';

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

enum SanitizedResourceKind { image }

abstract interface class SanitizedResourcePolicy {
  String get cacheKey;

  Uri? rewrite(Uri source, SanitizedResourceKind kind);
}

final class DirectSanitizedResourcePolicy implements SanitizedResourcePolicy {
  const DirectSanitizedResourcePolicy();

  @override
  String get cacheKey => 'direct-v1';

  @override
  Uri? rewrite(Uri source, SanitizedResourceKind kind) => source;
}

final class HttpsImageProxyPolicy implements SanitizedResourcePolicy {
  HttpsImageProxyPolicy({
    required Uri proxyBaseUri,
    this.maximumSourceCharacters = 2048,
  }) : proxyBaseUri = _validateProxyBase(proxyBaseUri) {
    if (maximumSourceCharacters < 128 || maximumSourceCharacters > 8192) {
      throw ArgumentError('Invalid image proxy source limit.');
    }
  }

  final Uri proxyBaseUri;
  final int maximumSourceCharacters;

  @override
  String get cacheKey => 'https-image-proxy-v1';

  @override
  Uri? rewrite(Uri source, SanitizedResourceKind kind) {
    final normalizedSource = source.removeFragment();
    if (kind != SanitizedResourceKind.image ||
        normalizedSource.scheme != 'https' ||
        normalizedSource.host.isEmpty ||
        normalizedSource.userInfo.isNotEmpty ||
        normalizedSource.port != 443 ||
        normalizedSource.toString().length > maximumSourceCharacters ||
        _looksLocal(normalizedSource.host)) {
      return null;
    }
    final encoded = base64Url
        .encode(utf8.encode(normalizedSource.toString()))
        .replaceAll('=', '');
    var path = proxyBaseUri.path;
    if (!path.endsWith('/')) path = '$path/';
    return proxyBaseUri.replace(path: '${path}v1/images/$encoded');
  }
}

final class SanitizedResource {
  const SanitizedResource({
    required this.kind,
    required this.sourceUri,
    required this.displayUri,
  });

  final SanitizedResourceKind kind;
  final Uri sourceUri;
  final Uri displayUri;
}

final class SanitizedHtml {
  const SanitizedHtml({
    required this.html,
    required this.plainText,
    required this.imageUrls,
    this.resources = const <SanitizedResource>[],
    required this.blockCount,
  });

  final String html;
  final String plainText;
  final List<Uri> imageUrls;
  final List<SanitizedResource> resources;
  final int blockCount;
}

String sanitizeRemoteHtml(
  String html, {
  Uri? baseUri,
  SanitizedResourcePolicy resourcePolicy =
      const DirectSanitizedResourcePolicy(),
}) =>
    sanitizeHtmlFragment(
      html,
      baseUri: baseUri,
      resourcePolicy: resourcePolicy,
    ).html;

SanitizedHtml sanitizeHtmlFragment(
  String html, {
  Uri? baseUri,
  SanitizedResourcePolicy resourcePolicy =
      const DirectSanitizedResourcePolicy(),
}) {
  final fragment = html_parser.parseFragment(html);
  for (final element in fragment.querySelectorAll(
    'script, iframe, frame, frameset, form, input, button, textarea, select, '
    'option, object, embed, applet, link, meta, base, style, svg, math',
  )) {
    element.remove();
  }

  final images = <Uri>{};
  final resources = <Uri, SanitizedResource>{};
  for (final element in fragment.querySelectorAll('*')) {
    _sanitizeAttributes(
      element,
      baseUri,
      images,
      resources,
      resourcePolicy,
    );
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
    resources: List<SanitizedResource>.unmodifiable(resources.values),
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
  Map<Uri, SanitizedResource> resources,
  SanitizedResourcePolicy resourcePolicy,
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
    if (element.localName == 'img' && name == 'src') {
      final display = resourcePolicy.rewrite(
        uri,
        SanitizedResourceKind.image,
      );
      if (display == null) {
        element.attributes.remove(name);
        continue;
      }
      element.attributes[name] = display.toString();
      imageUrls.add(display);
      resources[display] = SanitizedResource(
        kind: SanitizedResourceKind.image,
        sourceUri: uri,
        displayUri: display,
      );
    } else {
      element.attributes[name] = uri.toString();
    }
  }

  final sourceSet = element.attributes['srcset'];
  if (sourceSet != null) {
    final safeCandidates = <String>[];
    for (final rawCandidate in sourceSet.split(',')) {
      final parts = rawCandidate.trim().split(RegExp(r'\s+'));
      if (parts.isEmpty || parts.first.isEmpty) continue;
      final uri = _safeUri(parts.first, baseUri);
      if (uri == null) continue;
      final display = element.localName == 'img'
          ? resourcePolicy.rewrite(uri, SanitizedResourceKind.image)
          : uri;
      if (display == null) continue;
      safeCandidates.add(
        <String>[display.toString(), ...parts.skip(1)].join(' '),
      );
      if (element.localName == 'img') {
        imageUrls.add(display);
        resources[display] = SanitizedResource(
          kind: SanitizedResourceKind.image,
          sourceUri: uri,
          displayUri: display,
        );
      }
    }
    if (safeCandidates.isEmpty) {
      element.attributes.remove('srcset');
    } else {
      element.attributes['srcset'] = safeCandidates.join(', ');
    }
  }
}

Uri _validateProxyBase(Uri value) {
  if (value.scheme != 'https' ||
      value.host.isEmpty ||
      value.userInfo.isNotEmpty ||
      value.port != 443 ||
      value.hasQuery ||
      value.hasFragment) {
    throw ArgumentError(
      'Image proxy base must be a credential-free HTTPS URL.',
    );
  }
  return value.replace(host: value.host.toLowerCase());
}

bool _looksLocal(String host) {
  final normalized = host.toLowerCase();
  if (normalized == 'localhost' || normalized.endsWith('.local')) return true;
  final literal = Uri.tryParse('http://$normalized')?.host;
  if (literal == null) return true;
  final ipv4 = RegExp(r'^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$')
      .firstMatch(literal);
  if (ipv4 == null) return normalized.contains(':');
  final bytes = <int>[
    for (var index = 1; index <= 4; index += 1) int.parse(ipv4.group(index)!),
  ];
  if (bytes.any((value) => value > 255)) return true;
  return bytes[0] == 10 ||
      bytes[0] == 127 ||
      bytes[0] == 0 ||
      bytes[0] >= 224 ||
      bytes[0] == 100 && bytes[1] >= 64 && bytes[1] <= 127 ||
      bytes[0] == 169 && bytes[1] == 254 ||
      bytes[0] == 172 && bytes[1] >= 16 && bytes[1] <= 31 ||
      bytes[0] == 192 && bytes[1] == 168 ||
      bytes[0] == 192 && bytes[1] == 0 ||
      bytes[0] == 198 && (bytes[1] == 18 || bytes[1] == 19) ||
      bytes[0] == 198 && bytes[1] == 51 && bytes[2] == 100 ||
      bytes[0] == 203 && bytes[1] == 0 && bytes[2] == 113;
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
