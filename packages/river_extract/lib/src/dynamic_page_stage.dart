import 'package:river_domain/river_domain.dart';

import 'extraction_pipeline.dart';
import 'readability_stage.dart';

final class DynamicPageExtractionStage implements ExtractionStage {
  const DynamicPageExtractionStage({
    required this.renderer,
    this.readability = const ReadabilityExtractionStage(),
  });

  static const extractorId = 'dynamic-page';
  static const extractorVersion = '1';

  final DynamicPageRenderer renderer;
  final ReadabilityExtractionStage readability;

  @override
  String get id => extractorId;

  @override
  String get version => extractorVersion;

  @override
  Future<StageExtractionResult> extract(ExtractionRequest request) async {
    final rendered = await renderer.render(
      DynamicPageRenderRequest(sourceUri: request.sourceUri),
    );
    switch (rendered) {
      case DynamicPageRenderFailure(:final failure):
        return StageExtractionFailure(failure);
      case DynamicPageRenderSuccess(:final html, :final finalUri):
        final parsed = readability.extract(
          ExtractionRequest(
            sourceUri: finalUri,
            articleId: request.articleId,
            pageHtml: html,
            title: request.title,
            author: request.author,
            publishedAt: request.publishedAt,
          ),
        );
        return switch (parsed) {
          StageExtractionFailure() => parsed,
          StageExtractionSuccess(:final article) => StageExtractionSuccess(
              ExtractedArticle(
                title: article.title,
                author: article.author,
                canonicalUri: article.canonicalUri,
                publishedAt: article.publishedAt,
                html: article.html,
                plainText: article.plainText,
                imageUrls: article.imageUrls,
                extractor: id,
                extractorVersion: version,
                qualityScore: article.qualityScore,
              ),
            ),
        };
    }
  }
}
