import 'package:river_domain/river_domain.dart';

import 'feed_content.dart';

/// Adds the bounded static-page download between feed assessment and the
/// layered extractor. A complete feed body never incurs a page request.
final class HttpLoadingFullTextExtractor implements FullTextExtractor {
  const HttpLoadingFullTextExtractor({
    required this.http,
    required this.delegate,
    this.feedAssessor = const FeedContentAssessor(),
  });

  final HttpPort http;
  final FullTextExtractor delegate;
  final FeedContentAssessor feedAssessor;

  @override
  Future<ExtractionResult> extract(ExtractionRequest request) async {
    if (request.pageHtml != null || _feedIsComplete(request)) {
      return delegate.extract(request);
    }

    try {
      final response = await http.get(request.sourceUri);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return delegate.extract(
          _withPageHtml(
            request,
            response.body,
            response.effectiveUri ?? request.sourceUri,
          ),
        );
      }
    } on Object {
      // The delegate may still recover through its platform-rendered stage.
    }
    return delegate.extract(request);
  }

  bool _feedIsComplete(ExtractionRequest request) =>
      feedAssessor
          .assess(
            contentHtml: request.feedContentHtml,
            summary: request.feedSummary,
            sourceUri: request.sourceUri,
          )
          .kind ==
      FeedContentKind.full;
}

ExtractionRequest _withPageHtml(
  ExtractionRequest request,
  String pageHtml,
  Uri effectiveUri,
) =>
    ExtractionRequest(
      sourceUri: effectiveUri,
      articleId: request.articleId,
      pageHtml: pageHtml,
      feedContentHtml: request.feedContentHtml,
      feedSummary: request.feedSummary,
      title: request.title,
      author: request.author,
      publishedAt: request.publishedAt,
      etag: request.etag,
      lastModified: request.lastModified,
      forceReparse: request.forceReparse,
    );
