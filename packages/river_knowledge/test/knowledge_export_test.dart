import 'package:river_domain/river_domain.dart';
import 'package:river_knowledge/river_knowledge.dart';
import 'package:test/test.dart';

final class _Connector implements KnowledgeConnector {
  @override
  String get id => 'test-notion';

  @override
  Future<Uri> upsert(Article article, ArticleSummary? summary) async {
    return Uri.parse('https://notion.test/${article.id}');
  }
}

void main() {
  test('connector idempotency key is stable per article', () {
    final service = KnowledgeExportService(_Connector());
    final article = Article(
      id: 'article-1',
      url: Uri.parse('https://example.test/article-1'),
      title: 'Article',
      source: ContentSource.feed,
    );

    expect(service.idempotencyKey(article), 'test-notion:article-1');
  });
}
