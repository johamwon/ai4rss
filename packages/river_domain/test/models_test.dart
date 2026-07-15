import 'package:river_domain/river_domain.dart';
import 'package:test/test.dart';

void main() {
  test('article keeps canonical source identity', () {
    final article = Article(
      id: 'article-1',
      url: Uri.parse('https://example.test/a'),
      title: 'A synthetic article',
      source: ContentSource.feed,
    );

    expect(article.id, 'article-1');
    expect(article.url.host, 'example.test');
  });
}
