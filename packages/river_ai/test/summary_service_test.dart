import 'package:river_ai/river_ai.dart';
import 'package:river_domain/river_domain.dart';
import 'package:test/test.dart';

final class _NeverCalledProvider implements AiProvider {
  @override
  Future<ArticleSummary> summarize(Article article) =>
      throw StateError('unexpected');
}

void main() {
  test('empty content never spends provider quota', () {
    final service = SummaryService(_NeverCalledProvider());
    final article = Article(
      id: 'a',
      url: Uri.parse('https://example.test/a'),
      title: 'Empty',
      source: ContentSource.feed,
    );

    expect(() => service.summarize(article), throwsArgumentError);
  });
}
