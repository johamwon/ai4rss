library;

import 'package:river_domain/river_domain.dart';

final class KnowledgeExportService {
  const KnowledgeExportService(this._connector);

  final KnowledgeConnector _connector;

  String idempotencyKey(Article article) => '${_connector.id}:${article.id}';

  Future<Uri> export(Article article, ArticleSummary? summary) {
    return _connector.upsert(article, summary);
  }
}
