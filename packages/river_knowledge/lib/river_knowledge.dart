library;

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:river_domain/river_domain.dart';

export 'src/knowledge_grounded_qa.dart';
export 'src/knowledge_markdown.dart';
export 'src/knowledge_markdown_export.dart';
export 'src/knowledge_semantic_search.dart';
export 'src/knowledge_vector_index.dart';
export 'src/notion_connector.dart';
export 'src/notion_http.dart';
export 'src/notion_models.dart';
export 'src/notion_oauth.dart';
export 'src/notion_oauth_server.dart';
export 'src/portable_knowledge_connectors.dart';

final class KnowledgeExportService {
  const KnowledgeExportService(this._manager);

  final KnowledgeExportManager _manager;

  Future<void> export(
    KnowledgeItem item, {
    required String connectorId,
    required String destinationId,
  }) {
    return _manager.enqueueUpsert(
      KnowledgeExportTarget(
        knowledgeItemId: item.id,
        connectorId: connectorId,
        destinationId: destinationId,
      ),
    );
  }

  Future<void> delete(
    KnowledgeItem item, {
    required String connectorId,
    required String destinationId,
  }) {
    return _manager.enqueueDelete(
      KnowledgeExportTarget(
        knowledgeItemId: item.id,
        connectorId: connectorId,
        destinationId: destinationId,
      ),
    );
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
              'whyItMatters': summary.whyItMatters,
              'topics': summary.topics,
              'entities': summary.entities,
              'estimatedReadingMinutes': summary.estimatedReadingMinutes,
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
