import 'dart:convert';

import 'package:xml/xml.dart';

import 'feed_models.dart';

final class FeedParser {
  const FeedParser();

  ParsedFeed parse(String document, {Uri? sourceUri}) {
    final kind = detectFeedDocument(document);
    try {
      return switch (kind) {
        FeedDocumentKind.rss => _parseRss(document, sourceUri),
        FeedDocumentKind.atom => _parseAtom(document, sourceUri),
        FeedDocumentKind.jsonFeed => _parseJsonFeed(document, sourceUri),
        FeedDocumentKind.unknown =>
          throw const FeedParseException('Unsupported feed document'),
      };
    } on FeedParseException {
      rethrow;
    } catch (error) {
      throw FeedParseException('Malformed ${kind.name} document', cause: error);
    }
  }

  ParsedFeed _parseRss(String document, Uri? sourceUri) {
    final xml = XmlDocument.parse(document);
    final root = xml.rootElement;
    final channel = _firstDescendant(root, 'channel');
    if (channel == null) {
      throw const FeedParseException('RSS channel is missing');
    }

    final itemElements = root.descendants
        .whereType<XmlElement>()
        .where((element) => element.name.local == 'item');
    final items = itemElements.map((item) {
      final link = _uri(_text(item, 'link'), sourceUri);
      final title = _text(item, 'title') ?? '(untitled)';
      final enclosure = _child(item, 'enclosure');
      return ParsedFeedItem(
        id: _text(item, 'guid') ?? link?.toString() ?? title,
        title: title,
        url: link,
        author: _text(item, 'creator', prefix: 'dc') ?? _text(item, 'author'),
        publishedAt: _date(_text(item, 'pubDate')),
        updatedAt: _date(_text(item, 'updated')),
        summary: _text(item, 'description'),
        contentHtml: _text(item, 'encoded', prefix: 'content'),
        enclosureUrl: _uri(enclosure?.getAttribute('url'), sourceUri),
        enclosureMimeType: enclosure?.getAttribute('type'),
      );
    }).toList(growable: false);

    return ParsedFeed(
      kind: FeedDocumentKind.rss,
      title: _text(channel, 'title') ?? '(untitled feed)',
      homePageUrl: _uri(_text(channel, 'link'), sourceUri),
      feedUrl: sourceUri,
      description: _text(channel, 'description'),
      items: items,
    );
  }

  ParsedFeed _parseAtom(String document, Uri? sourceUri) {
    final xml = XmlDocument.parse(document);
    final feed = xml.rootElement;
    if (feed.name.local != 'feed') {
      throw const FeedParseException('Atom feed element is missing');
    }

    final items = _children(feed, 'entry').map((entry) {
      final link = _atomLink(entry, sourceUri);
      final title = _text(entry, 'title') ?? '(untitled)';
      final author = _child(entry, 'author');
      final content = _child(entry, 'content');
      return ParsedFeedItem(
        id: _text(entry, 'id') ?? link?.toString() ?? title,
        title: title,
        url: link,
        author: author == null ? null : _text(author, 'name'),
        publishedAt: _date(_text(entry, 'published')),
        updatedAt: _date(_text(entry, 'updated')),
        summary: _text(entry, 'summary'),
        contentHtml: content?.innerText.trim(),
      );
    }).toList(growable: false);

    return ParsedFeed(
      kind: FeedDocumentKind.atom,
      title: _text(feed, 'title') ?? '(untitled feed)',
      homePageUrl: _atomLink(feed, sourceUri),
      feedUrl: _atomLink(feed, sourceUri, relation: 'self') ?? sourceUri,
      description: _text(feed, 'subtitle'),
      items: items,
    );
  }

  ParsedFeed _parseJsonFeed(String document, Uri? sourceUri) {
    final root = _map(jsonDecode(document));
    final rawItems = root['items'];
    if (rawItems is! List<Object?>) {
      throw const FeedParseException('JSON Feed items must be a list');
    }
    final items = rawItems.map((rawItem) {
      final item = _map(rawItem);
      final url = _uri(_string(item['url']), sourceUri);
      final title = _string(item['title']) ?? '(untitled)';
      final attachment = _firstAttachment(item['attachments']);
      return ParsedFeedItem(
        id: _string(item['id']) ?? url?.toString() ?? title,
        title: title,
        url: url,
        author: _jsonAuthor(item),
        publishedAt: _date(_string(item['date_published'])),
        updatedAt: _date(_string(item['date_modified'])),
        summary: _string(item['summary']) ?? _string(item['content_text']),
        contentHtml: _string(item['content_html']),
        enclosureUrl: _uri(_string(attachment?['url']), sourceUri),
        enclosureMimeType: _string(attachment?['mime_type']),
        duration: _duration(attachment?['duration_in_seconds']),
      );
    }).toList(growable: false);

    return ParsedFeed(
      kind: FeedDocumentKind.jsonFeed,
      title: _string(root['title']) ?? '(untitled feed)',
      homePageUrl: _uri(_string(root['home_page_url']), sourceUri),
      feedUrl: _uri(_string(root['feed_url']), sourceUri) ?? sourceUri,
      description: _string(root['description']),
      items: items,
    );
  }
}

XmlElement? _child(XmlElement parent, String local, {String? prefix}) {
  for (final child in parent.children.whereType<XmlElement>()) {
    if (child.name.local == local &&
        (prefix == null || child.name.prefix == prefix)) {
      return child;
    }
  }
  return null;
}

Iterable<XmlElement> _children(XmlElement parent, String local) =>
    parent.children
        .whereType<XmlElement>()
        .where((element) => element.name.local == local);

XmlElement? _firstDescendant(XmlElement parent, String local) {
  for (final element in parent.descendants.whereType<XmlElement>()) {
    if (element.name.local == local) {
      return element;
    }
  }
  return null;
}

String? _text(XmlElement parent, String local, {String? prefix}) {
  final value = _child(parent, local, prefix: prefix)?.innerText.trim();
  return value == null || value.isEmpty ? null : value;
}

Uri? _atomLink(XmlElement parent, Uri? base, {String relation = 'alternate'}) {
  for (final link in _children(parent, 'link')) {
    final rel = link.getAttribute('rel') ?? 'alternate';
    if (rel == relation) {
      return _uri(link.getAttribute('href'), base);
    }
  }
  return null;
}

Uri? _uri(String? value, Uri? base) {
  if (value == null || value.trim().isEmpty) {
    return null;
  }
  final uri = Uri.tryParse(value.trim());
  if (uri == null) {
    return null;
  }
  return uri.hasScheme || base == null ? uri : base.resolveUri(uri);
}

DateTime? _date(String? value) {
  if (value == null) {
    return null;
  }
  final iso = DateTime.tryParse(value);
  if (iso != null) {
    return iso.toUtc();
  }
  final match = RegExp(
    r'^(?:[A-Za-z]{3},\s*)?(\d{1,2})\s+([A-Za-z]{3})\s+(\d{2,4})\s+(\d{2}):(\d{2})(?::(\d{2}))?\s+([A-Za-z]+|[+-]\d{4})$',
  ).firstMatch(value.trim());
  if (match == null) {
    return null;
  }
  const months = <String, int>{
    'jan': 1,
    'feb': 2,
    'mar': 3,
    'apr': 4,
    'may': 5,
    'jun': 6,
    'jul': 7,
    'aug': 8,
    'sep': 9,
    'oct': 10,
    'nov': 11,
    'dec': 12,
  };
  final month = months[match.group(2)!.toLowerCase()];
  if (month == null) {
    return null;
  }
  var year = int.parse(match.group(3)!);
  if (year < 100) {
    year += year >= 70 ? 1900 : 2000;
  }
  final zone = match.group(7)!.toUpperCase();
  var offset = Duration.zero;
  if (RegExp(r'^[+-]\d{4}$').hasMatch(zone)) {
    final sign = zone.startsWith('-') ? -1 : 1;
    offset = Duration(
      hours: sign * int.parse(zone.substring(1, 3)),
      minutes: sign * int.parse(zone.substring(3, 5)),
    );
  }
  return DateTime.utc(
    year,
    month,
    int.parse(match.group(1)!),
    int.parse(match.group(4)!),
    int.parse(match.group(5)!),
    int.parse(match.group(6) ?? '0'),
  ).subtract(offset);
}

Map<String, Object?> _map(Object? value) {
  if (value is! Map<Object?, Object?>) {
    throw const FeedParseException('Expected a JSON object');
  }
  return value.cast<String, Object?>();
}

String? _string(Object? value) => value is String ? value : null;

Map<String, Object?>? _firstAttachment(Object? value) {
  if (value is! List<Object?> || value.isEmpty) {
    return null;
  }
  return _map(value.first);
}

String? _jsonAuthor(Map<String, Object?> item) {
  final authors = item['authors'];
  if (authors is List<Object?> && authors.isNotEmpty) {
    return _string(_map(authors.first)['name']);
  }
  final author = item['author'];
  return author == null ? null : _string(_map(author)['name']);
}

Duration? _duration(Object? seconds) =>
    seconds is num ? Duration(milliseconds: (seconds * 1000).round()) : null;
