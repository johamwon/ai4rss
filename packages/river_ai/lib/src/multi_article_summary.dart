import 'dart:convert';

import 'package:river_domain/river_domain.dart';

import 'model_json.dart';
import 'prompt_registry.dart';
import 'provider.dart';
import 'summary_cache.dart';
import 'summary_schema.dart';

final class MultiArticleHighlight {
  const MultiArticleHighlight({
    required this.articleId,
    required this.title,
    required this.takeaway,
  });

  final String articleId;
  final String title;
  final String takeaway;
}

final class MultiArticleSummary {
  const MultiArticleSummary({
    required this.overview,
    required this.keyThemes,
    required this.articleHighlights,
    required this.connections,
    required this.language,
    required this.model,
    required this.promptVersion,
  });

  final String overview;
  final List<String> keyThemes;
  final List<MultiArticleHighlight> articleHighlights;
  final List<String> connections;
  final String language;
  final String model;
  final String promptVersion;
}

final class MultiArticleSummarySchema {
  const MultiArticleSummarySchema();

  static const name = 'river.multi-article-summary.v1';
  static const Map<String, Object?> jsonSchema = <String, Object?>{
    r'$schema': 'https://json-schema.org/draft/2020-12/schema',
    'title': name,
    'type': 'object',
    'additionalProperties': false,
    'required': <String>[
      'schemaVersion',
      'overview',
      'keyThemes',
      'articleHighlights',
      'connections',
      'language',
    ],
    'properties': <String, Object?>{
      'schemaVersion': <String, Object?>{'const': name},
      'overview': <String, Object?>{
        'type': 'string',
        'minLength': 1,
        'maxLength': 1600,
      },
      'keyThemes': <String, Object?>{
        'type': 'array',
        'minItems': 2,
        'maxItems': 8,
        'uniqueItems': true,
        'items': <String, Object?>{
          'type': 'string',
          'minLength': 1,
          'maxLength': 120,
        },
      },
      'articleHighlights': <String, Object?>{
        'type': 'array',
        'minItems': 2,
        'maxItems': 20,
        'items': <String, Object?>{
          'type': 'object',
          'additionalProperties': false,
          'required': <String>['articleId', 'takeaway'],
          'properties': <String, Object?>{
            'articleId': <String, Object?>{
              'type': 'string',
              'minLength': 1,
              'maxLength': 256,
            },
            'takeaway': <String, Object?>{
              'type': 'string',
              'minLength': 1,
              'maxLength': 800,
            },
          },
        },
      },
      'connections': <String, Object?>{
        'type': 'array',
        'minItems': 0,
        'maxItems': 8,
        'uniqueItems': true,
        'items': <String, Object?>{
          'type': 'string',
          'minLength': 1,
          'maxLength': 800,
        },
      },
      'language': <String, Object?>{
        'type': 'string',
        'minLength': 2,
        'maxLength': 35,
      },
    },
  };

  MultiArticleSummary parse(
    String output, {
    required String model,
    required String promptVersion,
    required String expectedLanguage,
    required Map<String, String> expectedArticles,
  }) {
    if (output.length > ArticleSummarySchema.maxOutputCharacters) {
      throw const AiSchemaFailure(AiSchemaFailureCode.tooLarge);
    }
    late Map<String, Object?> value;
    try {
      value = decodeModelJsonObject(output);
    } on FormatException {
      throw const AiSchemaFailure(AiSchemaFailureCode.malformedJson);
    }
    const fields = <String>{
      'schemaVersion',
      'overview',
      'keyThemes',
      'articleHighlights',
      'connections',
      'language',
    };
    if (!fields.containsAll(value.keys)) {
      throw const AiSchemaFailure(AiSchemaFailureCode.unexpectedField);
    }
    if (!value.keys.toSet().containsAll(fields)) {
      throw const AiSchemaFailure(AiSchemaFailureCode.missingField);
    }
    if (value['schemaVersion'] != name) {
      throw const AiSchemaFailure(AiSchemaFailureCode.invalidValue);
    }
    final overview = _boundedString(value['overview'], 1600);
    final themes = _boundedStrings(value['keyThemes'], 2, 8, 120);
    final connections = _boundedStrings(value['connections'], 0, 8, 800);
    final language = _boundedString(value['language'], 35);
    if (!ArticleSummarySchema.languageTag.hasMatch(language) ||
        language != expectedLanguage) {
      throw const AiSchemaFailure(AiSchemaFailureCode.languageMismatch);
    }
    final rawHighlights = value['articleHighlights'];
    if (rawHighlights is! List ||
        rawHighlights.length != expectedArticles.length) {
      throw const AiSchemaFailure(AiSchemaFailureCode.invalidValue);
    }
    final highlights = <MultiArticleHighlight>[];
    final seen = <String>{};
    for (final raw in rawHighlights) {
      if (raw is! Map) {
        throw const AiSchemaFailure(AiSchemaFailureCode.invalidValue);
      }
      final item = Map<String, Object?>.from(raw);
      if (item.length != 2 ||
          !item.containsKey('articleId') ||
          !item.containsKey('takeaway')) {
        throw const AiSchemaFailure(AiSchemaFailureCode.unexpectedField);
      }
      final id = _boundedString(item['articleId'], 256);
      final title = expectedArticles[id];
      if (title == null || !seen.add(id)) {
        throw const AiSchemaFailure(AiSchemaFailureCode.invalidValue);
      }
      highlights.add(
        MultiArticleHighlight(
          articleId: id,
          title: title,
          takeaway: _boundedString(item['takeaway'], 800),
        ),
      );
    }
    if (seen.length != expectedArticles.length) {
      throw const AiSchemaFailure(AiSchemaFailureCode.missingField);
    }
    highlights.sort(
      (left, right) => expectedArticles.keys
          .toList(growable: false)
          .indexOf(left.articleId)
          .compareTo(
            expectedArticles.keys
                .toList(growable: false)
                .indexOf(right.articleId),
          ),
    );
    return MultiArticleSummary(
      overview: overview,
      keyThemes: themes,
      articleHighlights: List<MultiArticleHighlight>.unmodifiable(highlights),
      connections: connections,
      language: language,
      model: model,
      promptVersion: promptVersion,
    );
  }
}

final class MultiArticleSummaryService {
  MultiArticleSummaryService(
    this._provider, {
    PromptRegistry? prompts,
    this.model = 'provider-default',
    this.outputLanguage = 'zh-CN',
  }) : prompts = prompts ?? PromptRegistry.standard();

  static const maximumArticles = 20;
  static const maximumArticleCharacters = 12000;
  static const maximumTotalCharacters = 60000;

  final AiProvider _provider;
  final PromptRegistry prompts;
  final String model;
  final String outputLanguage;

  Future<MultiArticleSummary> summarize(List<Article> articles) async {
    final prepared = prepare(articles);
    final template = prompts.resolve('multi-article-summary', 1);
    final prompt = template.render(<String, String>{
      'language': outputLanguage,
      'articlesJson': jsonEncode(prepared.payload),
    });
    final operationHash = summaryContentHash(jsonEncode(prepared.payload));
    final response = await _provider.complete(
      AiProviderRequest(
        operationId: 'multi:${operationHash.substring(7, 31)}',
        model: model,
        prompt: prompt,
        responseSchema: MultiArticleSummarySchema.jsonSchema,
        maxOutputTokens: 4000,
      ),
    );
    try {
      return _parse(response, template.versionKey, prepared.titles);
    } on AiSchemaFailure catch (failure) {
      final repair = prompts.resolve('multi-article-summary-repair', 1).render(
        <String, String>{
          'language': outputLanguage,
          'failureCode': failure.code.name,
          'articleIds': jsonEncode(prepared.titles.keys.toList()),
          'invalidOutput': response.output,
        },
      );
      final repaired = await _provider.complete(
        AiProviderRequest(
          operationId: 'multi:${operationHash.substring(7, 31)}:repair',
          model: model,
          prompt: repair,
          responseSchema: MultiArticleSummarySchema.jsonSchema,
          maxOutputTokens: 4000,
        ),
      );
      return _parse(repaired, template.versionKey, prepared.titles);
    }
  }

  MultiArticleSummaryPreparation prepare(List<Article> articles) {
    if (articles.length < 2 || articles.length > maximumArticles) {
      throw RangeError.range(articles.length, 2, maximumArticles, 'articles');
    }
    final titles = <String, String>{};
    final payload = <Map<String, String>>[];
    final perArticleBudget = (maximumTotalCharacters ~/ articles.length)
        .clamp(
          1,
          maximumArticleCharacters,
        )
        .toInt();
    var contentCharacters = 0;
    for (final article in articles) {
      if (titles.containsKey(article.id) || article.title.trim().isEmpty) {
        throw ArgumentError('Articles require unique IDs and non-empty titles');
      }
      final content = normalizeSummaryContent(article.plainText ?? '');
      if (content.isEmpty) throw ArgumentError('Every article requires text');
      final bounded = content.length <= perArticleBudget
          ? content
          : content.substring(0, perArticleBudget);
      contentCharacters += bounded.length;
      titles[article.id] = article.title.trim();
      payload.add(<String, String>{
        'articleId': article.id,
        'title': article.title.trim(),
        'content': bounded,
      });
    }
    return MultiArticleSummaryPreparation(
      payload: List<Map<String, String>>.unmodifiable(payload),
      titles: Map<String, String>.unmodifiable(titles),
      contentCharacters: contentCharacters,
    );
  }

  MultiArticleSummary _parse(
    AiProviderResponse response,
    String promptVersion,
    Map<String, String> titles,
  ) =>
      const MultiArticleSummarySchema().parse(
        response.output,
        model: response.model,
        promptVersion: promptVersion,
        expectedLanguage: outputLanguage,
        expectedArticles: titles,
      );
}

final class MultiArticleSummaryPreparation {
  const MultiArticleSummaryPreparation({
    required this.payload,
    required this.titles,
    required this.contentCharacters,
  });

  final List<Map<String, String>> payload;
  final Map<String, String> titles;
  final int contentCharacters;
}

String _boundedString(Object? value, int maximumLength) {
  if (value is! String) {
    throw const AiSchemaFailure(AiSchemaFailureCode.invalidValue);
  }
  final result = value.trim();
  if (result.isEmpty || result.length > maximumLength) {
    throw const AiSchemaFailure(AiSchemaFailureCode.invalidValue);
  }
  return result;
}

List<String> _boundedStrings(
  Object? value,
  int minimumItems,
  int maximumItems,
  int maximumLength,
) {
  if (value is! List ||
      value.length < minimumItems ||
      value.length > maximumItems) {
    throw const AiSchemaFailure(AiSchemaFailureCode.invalidValue);
  }
  final result = value
      .map((item) => _boundedString(item, maximumLength))
      .toList(growable: false);
  if (result.toSet().length != result.length) {
    throw const AiSchemaFailure(AiSchemaFailureCode.invalidValue);
  }
  return List<String>.unmodifiable(result);
}
