import 'dart:convert';

import 'package:river_ai/river_ai.dart';
import 'package:test/test.dart';

void main() {
  test('schema accepts exactly the documented structured shape', () {
    final summary = const ArticleSummarySchema().parse(
      jsonEncode(_valid),
      model: 'model',
      promptVersion: 'article-summary@1',
      expectedLanguage: 'en',
    );

    expect(summary.keyPoints, hasLength(3));
    expect(summary.topics, <String>['RSS']);
    expect(summary.estimatedReadingMinutes, 2);
  });

  test('schema rejects extra fields, wrong language, and weak cardinality', () {
    expect(
      () => _parse(<String, Object?>{..._valid, 'rawReasoning': 'secret'}),
      _failure(AiSchemaFailureCode.unexpectedField),
    );
    expect(
      () => _parse(<String, Object?>{..._valid, 'language': 'zh-CN'}),
      _failure(AiSchemaFailureCode.languageMismatch),
    );
    expect(
      () => _parse(
        <String, Object?>{
          ..._valid,
          'keyPoints': <String>['Only one'],
        },
      ),
      _failure(AiSchemaFailureCode.invalidValue),
    );
    expect(
      () => const ArticleSummarySchema().parse(
        'x' * (ArticleSummarySchema.maxOutputCharacters + 1),
        model: 'model',
        promptVersion: 'article-summary@1',
        expectedLanguage: 'en',
      ),
      _failure(AiSchemaFailureCode.tooLarge),
    );
  });

  test('schema accepts fenced, prose-prefixed, and allow-listed wrappers', () {
    final encoded = jsonEncode(_valid);
    for (final output in <String>[
      '```json\n$encoded\n```',
      'Here is the requested result:\n$encoded',
      jsonEncode(<String, Object?>{'result': _valid}),
      jsonEncode(<String, Object?>{'data': encoded}),
    ]) {
      final summary = const ArticleSummarySchema().parse(
        output,
        model: 'model',
        promptVersion: 'article-summary@1',
        expectedLanguage: 'en',
      );
      expect(summary.oneLine, _valid['oneLine']);
    }
  });
}

const Map<String, Object?> _valid = <String, Object?>{
  'schemaVersion': ArticleSummarySchema.name,
  'oneLine': 'River is a local-first RSS reader.',
  'keyPoints': <String>[
    'Reading works without a cloud account.',
    'Subscription data remains portable.',
    'The core reading path stays reliable.',
  ],
  'whyItMatters': 'Readers retain control of private reading data.',
  'topics': <String>['RSS'],
  'entities': <String>['River'],
  'estimatedReadingMinutes': 2,
  'language': 'en',
};

void _parse(Map<String, Object?> value) {
  const ArticleSummarySchema().parse(
    jsonEncode(value),
    model: 'model',
    promptVersion: 'article-summary@1',
    expectedLanguage: 'en',
  );
}

Matcher _failure(AiSchemaFailureCode code) => throwsA(
      isA<AiSchemaFailure>().having(
        (failure) => failure.code,
        'code',
        code,
      ),
    );
