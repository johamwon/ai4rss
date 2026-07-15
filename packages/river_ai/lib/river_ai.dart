library;

import 'package:river_domain/river_domain.dart';

final class SummaryService {
  const SummaryService(this._provider);

  final AiProvider _provider;

  Future<ArticleSummary> summarize(Article article) {
    if ((article.plainText ?? '').trim().isEmpty) {
      throw ArgumentError.value(article.id, 'article', 'Article has no text');
    }
    return _provider.summarize(article);
  }
}

String summaryCacheKey({
  required String contentHash,
  required String model,
  required String promptVersion,
  required String language,
}) =>
    '$contentHash|$model|$promptVersion|$language';
