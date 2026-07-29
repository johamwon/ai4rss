import 'dart:convert';

import 'package:river_domain/river_domain.dart';

final class ArticleSummarySchema {
  const ArticleSummarySchema();

  static const name = 'river.article-summary.v1';
  static const maxOutputCharacters = 65536;
  static final RegExp languageTag = RegExp(
    r'^[A-Za-z]{2,8}(?:-[A-Za-z0-9]{1,8})*$',
  );

  static const Map<String, Object?> jsonSchema = <String, Object?>{
    r'$schema': 'https://json-schema.org/draft/2020-12/schema',
    'title': name,
    'type': 'object',
    'additionalProperties': false,
    'required': <String>[
      'schemaVersion',
      'oneLine',
      'keyPoints',
      'whyItMatters',
      'topics',
      'entities',
      'estimatedReadingMinutes',
      'language',
    ],
    'properties': <String, Object?>{
      'schemaVersion': <String, Object?>{
        'const': name,
      },
      'oneLine': <String, Object?>{
        'type': 'string',
        'minLength': 1,
        'maxLength': 400,
      },
      'keyPoints': <String, Object?>{
        'type': 'array',
        'minItems': 3,
        'maxItems': 7,
        'uniqueItems': true,
        'items': <String, Object?>{
          'type': 'string',
          'minLength': 1,
          'maxLength': 600,
        },
      },
      'whyItMatters': <String, Object?>{
        'type': 'string',
        'minLength': 1,
        'maxLength': 1200,
      },
      'topics': <String, Object?>{
        'type': 'array',
        'minItems': 1,
        'maxItems': 12,
        'uniqueItems': true,
        'items': <String, Object?>{
          'type': 'string',
          'minLength': 1,
          'maxLength': 80,
        },
      },
      'entities': <String, Object?>{
        'type': 'array',
        'minItems': 0,
        'maxItems': 20,
        'uniqueItems': true,
        'items': <String, Object?>{
          'type': 'string',
          'minLength': 1,
          'maxLength': 120,
        },
      },
      'estimatedReadingMinutes': <String, Object?>{
        'type': 'integer',
        'minimum': 1,
        'maximum': 480,
      },
      'language': <String, Object?>{
        'type': 'string',
        'minLength': 2,
        'maxLength': 35,
      },
    },
  };

  ArticleSummary parse(
    String output, {
    required String model,
    required String promptVersion,
    required String expectedLanguage,
  }) {
    if (output.length > maxOutputCharacters) {
      throw const AiSchemaFailure(AiSchemaFailureCode.tooLarge);
    }
    Object? decoded;
    try {
      decoded = jsonDecode(output);
    } on FormatException {
      throw const AiSchemaFailure(AiSchemaFailureCode.malformedJson);
    }
    if (decoded is! Map<String, Object?>) {
      throw const AiSchemaFailure(AiSchemaFailureCode.wrongRoot);
    }
    const fields = <String>{
      'schemaVersion',
      'oneLine',
      'keyPoints',
      'whyItMatters',
      'topics',
      'entities',
      'estimatedReadingMinutes',
      'language',
    };
    if (!fields.containsAll(decoded.keys)) {
      throw const AiSchemaFailure(AiSchemaFailureCode.unexpectedField);
    }
    if (!decoded.keys.toSet().containsAll(fields)) {
      throw const AiSchemaFailure(AiSchemaFailureCode.missingField);
    }
    if (decoded['schemaVersion'] != name) {
      throw const AiSchemaFailure(AiSchemaFailureCode.invalidValue);
    }
    final oneLine = _string(decoded['oneLine'], maxLength: 400);
    final keyPoints = _strings(
      decoded['keyPoints'],
      minItems: 3,
      maxItems: 7,
      maxLength: 600,
    );
    final whyItMatters = _string(
      decoded['whyItMatters'],
      maxLength: 1200,
    );
    final topics = _strings(
      decoded['topics'],
      minItems: 1,
      maxItems: 12,
      maxLength: 80,
    );
    final entities = _strings(
      decoded['entities'],
      minItems: 0,
      maxItems: 20,
      maxLength: 120,
    );
    final estimated = decoded['estimatedReadingMinutes'];
    if (estimated is! int || estimated < 1 || estimated > 480) {
      throw const AiSchemaFailure(AiSchemaFailureCode.invalidValue);
    }
    final language = _string(decoded['language'], maxLength: 35);
    if (!languageTag.hasMatch(language) || language != expectedLanguage) {
      throw const AiSchemaFailure(AiSchemaFailureCode.languageMismatch);
    }
    return ArticleSummary(
      oneLine: oneLine,
      keyPoints: keyPoints,
      whyItMatters: whyItMatters,
      topics: topics,
      entities: entities,
      estimatedReadingMinutes: estimated,
      language: language,
      model: model,
      promptVersion: promptVersion,
    );
  }
}

enum AiSchemaFailureCode {
  malformedJson,
  wrongRoot,
  missingField,
  unexpectedField,
  invalidValue,
  languageMismatch,
  tooLarge,
}

final class AiSchemaFailure implements Exception {
  const AiSchemaFailure(this.code);

  final AiSchemaFailureCode code;

  @override
  String toString() => 'AiSchemaFailure(${code.name})';
}

String _string(Object? value, {required int maxLength}) {
  if (value is! String) {
    throw const AiSchemaFailure(AiSchemaFailureCode.invalidValue);
  }
  final normalized = value.trim();
  if (normalized.isEmpty || normalized.length > maxLength) {
    throw const AiSchemaFailure(AiSchemaFailureCode.invalidValue);
  }
  return normalized;
}

List<String> _strings(
  Object? value, {
  required int minItems,
  required int maxItems,
  required int maxLength,
}) {
  if (value is! List<Object?> ||
      value.length < minItems ||
      value.length > maxItems) {
    throw const AiSchemaFailure(AiSchemaFailureCode.invalidValue);
  }
  final normalized = value
      .map((item) => _string(item, maxLength: maxLength))
      .toList(growable: false);
  if (normalized.toSet().length != normalized.length) {
    throw const AiSchemaFailure(AiSchemaFailureCode.invalidValue);
  }
  return List<String>.unmodifiable(normalized);
}
