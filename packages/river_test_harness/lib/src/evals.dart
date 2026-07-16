import 'dart:convert';
import 'dart:io';

import 'package:river_domain/river_domain.dart';
import 'package:river_extract/river_extract.dart';
import 'package:river_feed/river_feed.dart';
import 'package:river_preferences/river_preferences.dart';

final class EvalFailure {
  const EvalFailure(this.caseId, this.message);

  final String caseId;
  final String message;

  @override
  String toString() => '$caseId: $message';
}

final class EvalReport {
  const EvalReport({
    required this.name,
    required this.total,
    required this.failures,
  });

  final String name;
  final int total;
  final List<EvalFailure> failures;

  int get failedCases =>
      failures.map((failure) => failure.caseId).toSet().length;
  int get passed => total - failedCases;
  bool get isSuccess => failures.isEmpty;

  Map<String, Object> toJson() => <String, Object>{
        'name': name,
        'total': total,
        'passed': passed,
        'failed': failedCases,
        'failures': failures
            .map(
              (failure) => <String, String>{
                'caseId': failure.caseId,
                'message': failure.message,
              },
            )
            .toList(),
      };
}

final class HarnessEvals {
  const HarnessEvals(this.workspaceRoot);

  final Directory workspaceRoot;

  EvalReport verifyFixtures() {
    final manifest = _readJson('fixtures/manifest.json');
    final fixtures = _list(manifest['fixtures']);
    final failures = <EvalFailure>[];

    for (final fixture in fixtures) {
      final id = fixture['path'] as String;
      final file = File(_path(id));
      if (!file.existsSync()) {
        failures.add(EvalFailure(id, 'fixture does not exist'));
        continue;
      }
      final content = file.readAsStringSync();
      for (final expected in _strings(fixture['contains'])) {
        if (!content.contains(expected)) {
          failures.add(EvalFailure(id, 'missing marker: $expected'));
        }
      }
    }
    return EvalReport(
      name: 'fixtures',
      total: fixtures.length,
      failures: failures,
    );
  }

  Future<EvalReport> evaluateExtraction() async {
    final manifest = _readJson('evals/extraction_manifest.json');
    final cases = _list(manifest['cases']);
    final failures = <EvalFailure>[];
    const extractor = BasicHtmlExtractor();

    for (final item in cases) {
      final id = item['id'] as String;
      final input = File(_path(item['fixture'] as String)).readAsStringSync();
      final sourceUri = Uri.parse(item['url'] as String);
      final request = switch (item['input']) {
        'pageHtml' => ExtractionRequest(
            sourceUri: sourceUri,
            pageHtml: input,
          ),
        'feedContentHtml' => ExtractionRequest(
            sourceUri: sourceUri,
            feedContentHtml: input,
          ),
        'feedSummary' => ExtractionRequest(
            sourceUri: sourceUri,
            feedSummary: input,
          ),
        _ => throw StateError('Unsupported extraction fixture input'),
      };
      final result = await extractor.extract(request);
      final expectedOutcome = item['expectedOutcome'] as String;
      if (expectedOutcome == 'failure') {
        if (result is! ExtractionFailureResult) {
          failures.add(EvalFailure(id, 'expected a classified failure'));
          continue;
        }
        final expectedFailure = item['expectedFailure'] as String;
        if (result.failure.code.name != expectedFailure) {
          failures.add(
            EvalFailure(
              id,
              'expected $expectedFailure, got ${result.failure.code.name}',
            ),
          );
        }
        continue;
      }
      if (result is! ExtractionSuccess) {
        final code = (result as ExtractionFailureResult).failure.code.name;
        failures.add(EvalFailure(id, 'unexpected extraction failure: $code'));
        continue;
      }
      final article = result.article;
      final expectedExtractor = item['expectedExtractor'] as String;
      if (article.extractor != expectedExtractor) {
        failures.add(
          EvalFailure(
            id,
            'expected extractor $expectedExtractor, got ${article.extractor}',
          ),
        );
      }
      final qualityAtLeast = (item['qualityAtLeast'] as num).toDouble();
      if (article.qualityScore < qualityAtLeast) {
        failures.add(
          EvalFailure(
            id,
            'quality ${article.qualityScore} is below $qualityAtLeast',
          ),
        );
      }
      for (final expected in _strings(item['plainTextContains'])) {
        if (!article.plainText.contains(expected)) {
          failures.add(EvalFailure(id, 'plain text missing: $expected'));
        }
      }
      for (final forbidden in _strings(item['htmlForbids'])) {
        if (article.html.toLowerCase().contains(forbidden.toLowerCase())) {
          failures.add(EvalFailure(id, 'unsafe HTML retained: $forbidden'));
        }
      }
    }
    return EvalReport(
      name: 'extraction',
      total: cases.length,
      failures: failures,
    );
  }

  EvalReport evaluateAiReplay() {
    final manifest = _readJson('evals/summary_cases.json');
    final cases = _list(manifest['cases']);
    final failures = <EvalFailure>[];

    for (final item in cases) {
      final id = item['id'] as String;
      final replay = _map(item['replay']);
      final oneLine = replay['oneLine'];
      final keyPoints = replay['keyPoints'];
      if (oneLine is! String || oneLine.trim().isEmpty) {
        failures.add(EvalFailure(id, 'oneLine is missing'));
      }
      if (keyPoints is! List || keyPoints.isEmpty) {
        failures.add(EvalFailure(id, 'keyPoints are missing'));
      }
      final combined = <String>[
        if (oneLine is String) oneLine,
        if (keyPoints is List) ...keyPoints.whereType<String>(),
      ].join(' ');
      for (final fact in _strings(item['requiredFacts'])) {
        if (!combined.contains(fact)) {
          failures.add(EvalFailure(id, 'required fact missing: $fact'));
        }
      }
      for (final forbidden in _strings(item['forbiddenClaims'])) {
        if (combined.contains(forbidden)) {
          failures.add(EvalFailure(id, 'forbidden claim present: $forbidden'));
        }
      }
    }
    return EvalReport(
      name: 'ai-replay',
      total: cases.length,
      failures: failures,
    );
  }

  EvalReport evaluateRanking() {
    final manifest = _readJson('evals/ranking_sessions.json');
    final cases = _list(manifest['cases']);
    final failures = <EvalFailure>[];

    for (final item in cases) {
      final id = item['id'] as String;
      final positive = _event(item['positive'] as String);
      final negative = _event(item['negative'] as String);
      final at = DateTime.utc(2026, 7, 14);
      final positiveWeight = readingSignalWeight(
        ReadingEvent(articleId: id, type: positive, occurredAt: at),
      );
      final negativeWeight = readingSignalWeight(
        ReadingEvent(articleId: id, type: negative, occurredAt: at),
      );
      if (negativeWeight >= positiveWeight) {
        failures.add(
          EvalFailure(id, '$negative must score below $positive'),
        );
      }
    }
    return EvalReport(name: 'ranking', total: cases.length, failures: failures);
  }

  EvalReport evaluateFeeds() {
    final manifest = _readJson('evals/feed_manifest.json');
    final cases = _list(manifest['cases']);
    final failures = <EvalFailure>[];
    for (final item in cases) {
      final id = item['id'] as String;
      final content = File(_path(item['fixture'] as String)).readAsStringSync();
      try {
        final feed = const FeedParser().parse(content);
        final expectedKind = item['kind'] as String;
        final expectedTitle = item['title'] as String;
        final expectedCount = item['itemCount'] as int;
        if (feed.kind.name != expectedKind) {
          failures.add(
            EvalFailure(id, 'expected $expectedKind, got ${feed.kind.name}'),
          );
        }
        if (feed.title != expectedTitle) {
          failures.add(
            EvalFailure(id, 'expected title $expectedTitle, got ${feed.title}'),
          );
        }
        if (feed.items.length != expectedCount) {
          failures.add(
            EvalFailure(
              id,
              'expected $expectedCount items, got ${feed.items.length}',
            ),
          );
        }
      } on FeedParseException catch (error) {
        failures.add(EvalFailure(id, error.toString()));
      }
    }
    return EvalReport(name: 'feeds', total: cases.length, failures: failures);
  }

  Map<String, Object?> _readJson(String relativePath) {
    return _map(jsonDecode(File(_path(relativePath)).readAsStringSync()));
  }

  String _path(String relativePath) {
    return '${workspaceRoot.path}${Platform.pathSeparator}${relativePath.replaceAll('/', Platform.pathSeparator)}';
  }
}

Map<String, Object?> _map(Object? value) =>
    (value as Map).cast<String, Object?>();

List<Map<String, Object?>> _list(Object? value) =>
    (value as List).map((item) => _map(item)).toList();

List<String> _strings(Object? value) => (value as List).cast<String>();

ReadingEventType _event(String name) => ReadingEventType.values.byName(name);
