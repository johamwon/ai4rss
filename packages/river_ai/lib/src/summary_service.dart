import 'package:river_domain/river_domain.dart';

import 'prompt_registry.dart';
import 'provider.dart';
import 'summary_schema.dart';

final class SummaryService {
  SummaryService(
    this._provider, {
    PromptRegistry? prompts,
    this.model = 'provider-default',
    this.outputLanguage = 'zh-CN',
  }) : prompts = prompts ?? PromptRegistry.standard() {
    if (model.trim().isEmpty || model.length > 200) {
      throw ArgumentError.value(model, 'model');
    }
    if (!ArticleSummarySchema.languageTag.hasMatch(outputLanguage)) {
      throw ArgumentError.value(outputLanguage, 'outputLanguage');
    }
  }

  final AiProvider _provider;
  final PromptRegistry prompts;
  final String model;
  final String outputLanguage;

  Future<ArticleSummary> summarize(Article article) async {
    final content = (article.plainText ?? '').trim();
    if (content.isEmpty) {
      throw ArgumentError.value(article.id, 'article', 'Article has no text');
    }
    final template = prompts.resolve('article-summary', 1);
    final prompt = template.render(
      <String, String>{
        'articleId': article.id,
        'title': article.title,
        'content': content,
        'language': outputLanguage,
      },
    );
    final response = await _provider.complete(
      AiProviderRequest(
        operationId: article.id,
        model: model,
        prompt: prompt,
        responseSchema: ArticleSummarySchema.jsonSchema,
      ),
    );
    try {
      return _parse(response, prompt.versionKey);
    } on AiSchemaFailure catch (failure) {
      final repairTemplate = prompts.resolve('article-summary-repair', 1);
      final repairPrompt = repairTemplate.render(
        <String, String>{
          'language': outputLanguage,
          'failureCode': failure.code.name,
          'invalidOutput': response.output,
        },
      );
      final repaired = await _provider.complete(
        AiProviderRequest(
          operationId: '${article.id}:repair',
          model: model,
          prompt: repairPrompt,
          responseSchema: ArticleSummarySchema.jsonSchema,
        ),
      );
      return _parse(repaired, prompt.versionKey);
    }
  }

  ArticleSummary _parse(AiProviderResponse response, String promptVersion) =>
      const ArticleSummarySchema().parse(
        response.output,
        model: response.model,
        promptVersion: promptVersion,
        expectedLanguage: outputLanguage,
      );
}

String summaryCacheKey({
  required String contentHash,
  required String model,
  required String promptVersion,
  required String language,
}) =>
    '$contentHash|$model|$promptVersion|$language';
