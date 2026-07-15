enum FeedDocumentKind { rss, atom, jsonFeed, unknown }

FeedDocumentKind detectFeedDocument(String document) {
  final trimmed = document.trimLeft();
  if (trimmed.startsWith('{') && trimmed.contains('jsonfeed.org/version')) {
    return FeedDocumentKind.jsonFeed;
  }
  if (RegExp(r'<feed(?:\s|>)', caseSensitive: false).hasMatch(trimmed)) {
    return FeedDocumentKind.atom;
  }
  if (RegExp(
    r'<rss(?:\s|>)|<(?:rdf:)?RDF(?:\s|>)',
    caseSensitive: false,
  ).hasMatch(trimmed)) {
    return FeedDocumentKind.rss;
  }
  return FeedDocumentKind.unknown;
}

final class ParsedFeed {
  const ParsedFeed({
    required this.kind,
    required this.title,
    required this.items,
    this.homePageUrl,
    this.feedUrl,
    this.description,
  });

  final FeedDocumentKind kind;
  final String title;
  final Uri? homePageUrl;
  final Uri? feedUrl;
  final String? description;
  final List<ParsedFeedItem> items;
}

final class ParsedFeedItem {
  const ParsedFeedItem({
    required this.id,
    required this.title,
    this.url,
    this.author,
    this.publishedAt,
    this.updatedAt,
    this.summary,
    this.contentHtml,
    this.enclosureUrl,
    this.enclosureMimeType,
    this.duration,
  });

  final String id;
  final String title;
  final Uri? url;
  final String? author;
  final DateTime? publishedAt;
  final DateTime? updatedAt;
  final String? summary;
  final String? contentHtml;
  final Uri? enclosureUrl;
  final String? enclosureMimeType;
  final Duration? duration;
}

final class FeedParseException implements Exception {
  const FeedParseException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => 'FeedParseException: $message';
}
