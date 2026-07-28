import 'models.dart';

enum KnowledgeSourceKind { article, podcastEpisode, webClip, manual }

final class KnowledgeSourceReference {
  KnowledgeSourceReference({
    required this.kind,
    required this.sourceId,
    required this.originalUrl,
    required this.sourceTitle,
    this.author,
    this.publishedAt,
  }) {
    if (sourceId.trim().isEmpty || sourceId.length > 256) {
      throw ArgumentError.value(sourceId, 'sourceId');
    }
    if (!_isPublicWebUri(originalUrl)) {
      throw ArgumentError.value(originalUrl, 'originalUrl');
    }
    if (sourceTitle.trim().isEmpty || sourceTitle.length > 2048) {
      throw ArgumentError.value(sourceTitle, 'sourceTitle');
    }
    if ((author?.length ?? 0) > 2048) {
      throw ArgumentError.value(author, 'author');
    }
  }

  final KnowledgeSourceKind kind;
  final String sourceId;
  final Uri originalUrl;
  final String sourceTitle;
  final String? author;
  final DateTime? publishedAt;

  String get stableKey => '${kind.name}:$sourceId';
}

final class KnowledgeExcerpt {
  KnowledgeExcerpt({
    required this.quote,
    this.note,
    this.annotationId,
  }) {
    if (quote.trim().isEmpty || quote.length > 16384) {
      throw ArgumentError.value(quote, 'quote');
    }
    if ((note?.length ?? 0) > 20000) {
      throw ArgumentError.value(note, 'note');
    }
    if ((annotationId?.length ?? 0) > 256) {
      throw ArgumentError.value(annotationId, 'annotationId');
    }
  }

  final String quote;
  final String? note;
  final String? annotationId;
}

final class KnowledgeItem {
  KnowledgeItem({
    required this.id,
    required this.source,
    required this.title,
    required this.markdown,
    required this.sanitizedHtml,
    required this.contentHash,
    required this.savedAt,
    required this.updatedAt,
    this.summary,
    Iterable<KnowledgeExcerpt> excerpts = const <KnowledgeExcerpt>[],
    Iterable<String> notes = const <String>[],
    Iterable<String> tags = const <String>[],
    Iterable<String> topics = const <String>[],
    Iterable<String> entities = const <String>[],
  })  : excerpts = List<KnowledgeExcerpt>.unmodifiable(excerpts),
        notes = _boundedStrings(notes, 'notes'),
        tags = _boundedStrings(tags, 'tags'),
        topics = _boundedStrings(topics, 'topics'),
        entities = _boundedStrings(entities, 'entities') {
    if (id.trim().isEmpty || id.length > 256) {
      throw ArgumentError.value(id, 'id');
    }
    if (title.trim().isEmpty || title.length > 2048) {
      throw ArgumentError.value(title, 'title');
    }
    if (markdown.length > 5 * 1024 * 1024) {
      throw ArgumentError.value(markdown.length, 'markdown');
    }
    if (sanitizedHtml.length > 5 * 1024 * 1024) {
      throw ArgumentError.value(sanitizedHtml.length, 'sanitizedHtml');
    }
    if (!_isContentHash(contentHash)) {
      throw ArgumentError.value(contentHash, 'contentHash');
    }
    if (updatedAt.isBefore(savedAt)) {
      throw ArgumentError.value(updatedAt, 'updatedAt');
    }
    if (this.excerpts.length > 10000) {
      throw ArgumentError.value(this.excerpts.length, 'excerpts');
    }
    final excerptCharacters = this.excerpts.fold<int>(
          0,
          (total, excerpt) =>
              total + excerpt.quote.length + (excerpt.note?.length ?? 0),
        );
    if (excerptCharacters > 5 * 1024 * 1024) {
      throw ArgumentError.value(excerptCharacters, 'excerpts');
    }
  }

  final String id;
  final KnowledgeSourceReference source;
  final String title;
  final String markdown;
  final String sanitizedHtml;
  final ArticleSummary? summary;
  final List<KnowledgeExcerpt> excerpts;
  final List<String> notes;
  final List<String> tags;
  final List<String> topics;
  final List<String> entities;
  final String contentHash;
  final DateTime savedAt;
  final DateTime updatedAt;

  KnowledgeItem withId(String id, {DateTime? savedAt}) => KnowledgeItem(
        id: id,
        source: source,
        title: title,
        markdown: markdown,
        sanitizedHtml: sanitizedHtml,
        summary: summary,
        excerpts: excerpts,
        notes: notes,
        tags: tags,
        topics: topics,
        entities: entities,
        contentHash: contentHash,
        savedAt: savedAt ?? this.savedAt,
        updatedAt: updatedAt,
      );
}

final class KnowledgeExternalMapping {
  KnowledgeExternalMapping({
    required this.knowledgeItemId,
    required this.connectorId,
    required this.destinationId,
    required this.externalObjectId,
    required this.exportedContentHash,
    required this.createdAt,
    required this.updatedAt,
    this.externalUrl,
  }) {
    for (final entry in <(String, String)>[
      ('knowledgeItemId', knowledgeItemId),
      ('connectorId', connectorId),
      ('destinationId', destinationId),
      ('externalObjectId', externalObjectId),
    ]) {
      if (entry.$2.trim().isEmpty || entry.$2.length > 512) {
        throw ArgumentError.value(entry.$2, entry.$1);
      }
    }
    if (!_isContentHash(exportedContentHash)) {
      throw ArgumentError.value(exportedContentHash, 'exportedContentHash');
    }
    if (externalUrl != null && !_isPublicWebUri(externalUrl!)) {
      throw ArgumentError.value(externalUrl, 'externalUrl');
    }
    if (updatedAt.isBefore(createdAt)) {
      throw ArgumentError.value(updatedAt, 'updatedAt');
    }
  }

  final String knowledgeItemId;
  final String connectorId;
  final String destinationId;
  final String externalObjectId;
  final Uri? externalUrl;
  final String exportedContentHash;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get stableKey => '$knowledgeItemId:$connectorId:$destinationId';
}

List<String> _boundedStrings(Iterable<String> values, String name) {
  final normalized = <String>[];
  final seen = <String>{};
  var totalCharacters = 0;
  for (final value in values) {
    final item = value.trim();
    if (item.isEmpty || item.length > 20000) {
      throw ArgumentError.value(value, name);
    }
    if (seen.add(item)) {
      normalized.add(item);
      totalCharacters += item.length;
    }
    if (normalized.length > 10000) {
      throw ArgumentError.value(normalized.length, name);
    }
    if (totalCharacters > 5 * 1024 * 1024) {
      throw ArgumentError.value(totalCharacters, name);
    }
  }
  return List<String>.unmodifiable(normalized);
}

bool _isContentHash(String value) => RegExp(
      r'^(sha256:[0-9a-f]{64}|[0-9a-f]{64}|[A-Za-z0-9][A-Za-z0-9:._-]{0,255})$',
    ).hasMatch(value);

bool _isPublicWebUri(Uri uri) =>
    (uri.scheme == 'http' || uri.scheme == 'https') &&
    uri.host.isNotEmpty &&
    uri.userInfo.isEmpty;
