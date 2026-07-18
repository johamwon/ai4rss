import 'dart:math';

import 'package:html/dom.dart';

final class ReadabilitySelection {
  const ReadabilitySelection({
    required this.content,
    required this.score,
  });

  final Element content;
  final double score;
}

/// Deterministic, DOM-only article selection inspired by the candidate scoring
/// model used by reader-mode implementations. Network and script execution are
/// deliberately outside this parser.
final class ReadabilityParser {
  const ReadabilityParser();

  ReadabilitySelection? parse(Document document) {
    final root = document.body;
    if (root == null) return null;

    _removeUnlikelyContent(root);
    _normalizeLazyImages(root);
    _replaceMediaWithPlaceholders(root);

    final scores = <Element, double>{};
    for (final block in root.querySelectorAll('p, pre, td, blockquote')) {
      final text = _normalizedText(block);
      if (text.length < 25) continue;

      final contentScore = _contentScore(text);
      final parent = block.parent;
      if (parent == null) continue;
      _addScore(scores, parent, contentScore);

      final grandparent = parent.parent;
      if (grandparent != null && grandparent.localName != 'html') {
        _addScore(scores, grandparent, contentScore / 2);
      }
    }

    Element? best;
    var bestScore = double.negativeInfinity;
    for (final entry in scores.entries) {
      final adjusted = entry.value * (1 - _linkDensity(entry.key));
      if (adjusted > bestScore) {
        best = entry.key;
        bestScore = adjusted;
      }
    }

    if (best == null || bestScore <= 0) {
      best = _structuredFallback(root);
      if (best == null) return null;
      bestScore = _contentScore(_normalizedText(best));
    }

    final article = _collectSiblings(best, scores, bestScore);
    _pruneCandidate(article);
    if (_normalizedText(article).length < 80) return null;
    return ReadabilitySelection(content: article, score: bestScore);
  }
}

const _positivePattern =
    r'(?:^|[\s_-])(?:article|body|content|entry|hentry|main|page|post|read|'
    r'story|text|blog)(?:$|[\s_-])';
const _negativePattern =
    r'(?:^|[\s_-])(?:ad|ads|banner|breadcrumb|comments?|combx|contact|cookie|'
    r'footer|gdpr|masthead|menu|meta|nav|outbrain|paywall|promo|recommend|'
    r'recommendations|related|scroll|share|shoutbox|sidebar|skyscraper|'
    r'sponsor|sponsored|shopping|subscribe|tags|tool|widget)(?:$|[\s_-])';
final _positive = RegExp(_positivePattern, caseSensitive: false);
final _negative = RegExp(_negativePattern, caseSensitive: false);
final _punctuation = RegExp(r'[,.，。！？!?；;：:]');

void _removeUnlikelyContent(Element root) {
  for (final element in root.querySelectorAll(
    'script, style, noscript, template, nav, aside, footer, form, dialog, '
    '[hidden], [aria-hidden="true"]',
  )) {
    element.remove();
  }

  for (final element in root.querySelectorAll('*').toList(growable: false)) {
    if (element.parent == null ||
        element.localName == 'article' ||
        element.localName == 'main') {
      continue;
    }
    final signature = _signature(element);
    if (signature.isNotEmpty &&
        _negative.hasMatch(signature) &&
        !_positive.hasMatch(signature)) {
      element.remove();
    }
  }
}

void _normalizeLazyImages(Element root) {
  for (final image in root.querySelectorAll('img')) {
    final source = _firstNonEmpty(<String?>[
      image.attributes['src'],
      image.attributes['data-src'],
      image.attributes['data-original'],
      image.attributes['data-lazy-src'],
    ]);
    if (source != null) image.attributes['src'] = source;

    final sourceSet = _firstNonEmpty(<String?>[
      image.attributes['srcset'],
      image.attributes['data-srcset'],
    ]);
    if (sourceSet != null) image.attributes['srcset'] = sourceSet;
  }
}

void _replaceMediaWithPlaceholders(Element root) {
  for (final media in root.querySelectorAll(
    'audio, video, iframe, mpvoice, qqmusic, mp-common-mpaudio',
  )) {
    final isVideo = media.localName == 'video' || media.localName == 'iframe';
    media.replaceWith(
      Element.tag('p')..text = isVideo ? '[Video content]' : '[Audio content]',
    );
  }
}

void _addScore(Map<Element, double> scores, Element element, double value) {
  scores.update(
    element,
    (current) => current + value,
    ifAbsent: () => _baseScore(element) + value,
  );
}

double _baseScore(Element element) {
  final tagScore = switch (element.localName) {
    'article' => 12.0,
    'main' => 10.0,
    'section' => 6.0,
    'div' => 5.0,
    'blockquote' => 3.0,
    'pre' => 3.0,
    'td' => 2.0,
    'form' => -3.0,
    _ => 0.0,
  };
  return tagScore + _classWeight(element);
}

double _classWeight(Element element) {
  final signature = _signature(element);
  var weight = 0.0;
  if (_positive.hasMatch(signature)) weight += 25;
  if (_negative.hasMatch(signature)) weight -= 25;
  return weight;
}

double _contentScore(String text) {
  final punctuationCount = min(_punctuation.allMatches(text).length, 10);
  return 1 + punctuationCount + min(text.length / 100, 3);
}

double _linkDensity(Element element) {
  final textLength = _normalizedText(element).length;
  if (textLength == 0) return 0;
  var linkedLength = 0;
  for (final link in element.querySelectorAll('a')) {
    linkedLength += _normalizedText(link).length;
  }
  return (linkedLength / textLength).clamp(0, 1).toDouble();
}

Element? _structuredFallback(Element root) {
  for (final selector in <String>['article', 'main', '[role="main"]']) {
    final candidate = root.querySelector(selector);
    if (candidate != null && _normalizedText(candidate).length >= 80) {
      return candidate;
    }
  }
  return null;
}

Element _collectSiblings(
  Element best,
  Map<Element, double> scores,
  double bestScore,
) {
  final article = Element.tag('article');
  final parent = best.parent;
  if (best.localName == 'body') {
    for (final node in best.nodes) {
      article.append(node.clone(true));
    }
    return article;
  }
  if (parent == null) {
    article.append(best.clone(true));
    return article;
  }

  final threshold = max(10.0, bestScore * 0.2);
  for (final sibling in parent.children) {
    final siblingScore = scores[sibling] ?? double.negativeInfinity;
    final text = _normalizedText(sibling);
    final isSubstantialParagraph = sibling.localName == 'p' &&
        text.length >= 80 &&
        _linkDensity(sibling) < 0.25;
    if (identical(sibling, best) ||
        siblingScore >= threshold ||
        isSubstantialParagraph) {
      article.append(sibling.clone(true));
    }
  }
  return article;
}

void _pruneCandidate(Element article) {
  for (final element in article.querySelectorAll('*').toList(growable: false)) {
    if (element.parent == null) continue;
    final signature = _signature(element);
    if (signature.isNotEmpty &&
        _negative.hasMatch(signature) &&
        !_positive.hasMatch(signature)) {
      element.remove();
      continue;
    }

    if (element.localName == 'p' && _normalizedText(element).isEmpty) {
      element.remove();
      continue;
    }
    if (const <String>{'div', 'section', 'ul'}.contains(element.localName) &&
        !_containsRichContent(element)) {
      final textLength = _normalizedText(element).length;
      if (textLength < 40 ||
          (_linkDensity(element) > 0.5 && textLength < 500)) {
        element.remove();
      }
    }
  }
}

bool _containsRichContent(Element element) =>
    element.querySelector('img, table, pre, code, blockquote') != null;

String _signature(Element element) =>
    '${element.id} ${element.attributes['class'] ?? ''}'.trim().toLowerCase();

String _normalizedText(Element element) =>
    element.text.replaceAll(RegExp(r'\s+'), ' ').trim();

String? _firstNonEmpty(Iterable<String?> values) {
  for (final value in values) {
    final cleaned = value?.trim();
    if (cleaned != null && cleaned.isNotEmpty) return cleaned;
  }
  return null;
}
