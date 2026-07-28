library;

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:river_domain/river_domain.dart';

export 'src/knowledge_markdown.dart';

final class KnowledgeExportService {
  const KnowledgeExportService(this._connector);

  final KnowledgeConnector _connector;

  String idempotencyKey(KnowledgeItem item) => '${_connector.id}:${item.id}';

  Future<Uri> export(KnowledgeItem item) {
    return _connector.upsert(item);
  }
}

final class KnowledgeContentHasher {
  const KnowledgeContentHasher();

  String hash({
    required String title,
    required String markdown,
    required String sanitizedHtml,
    ArticleSummary? summary,
    Iterable<KnowledgeExcerpt> excerpts = const <KnowledgeExcerpt>[],
    Iterable<String> notes = const <String>[],
    Iterable<String> tags = const <String>[],
    Iterable<String> topics = const <String>[],
    Iterable<String> entities = const <String>[],
  }) {
    final canonical = jsonEncode(<String, Object?>{
      'schema': 1,
      'title': title,
      'markdown': markdown,
      'sanitizedHtml': sanitizedHtml,
      'summary': summary == null
          ? null
          : <String, Object>{
              'oneLine': summary.oneLine,
              'keyPoints': summary.keyPoints,
              'language': summary.language,
              'model': summary.model,
              'promptVersion': summary.promptVersion,
            },
      'excerpts': excerpts
          .map(
            (excerpt) => <String, Object?>{
              'quote': excerpt.quote,
              'note': excerpt.note,
              'annotationId': excerpt.annotationId,
            },
          )
          .toList(growable: false),
      'notes': notes.toList(growable: false),
      'tags': _canonicalSet(tags),
      'topics': _canonicalSet(topics),
      'entities': _canonicalSet(entities),
    });
    return 'sha256:${sha256.convert(utf8.encode(canonical))}';
  }
}

List<String> _canonicalSet(Iterable<String> values) {
  final result = values.map((value) => value.trim()).toSet().toList()..sort();
  return result;
}
