import 'dart:convert';
import 'dart:io';

import 'package:river_test_harness/river_test_harness.dart';
import 'package:test/test.dart';

void main() {
  test('production ranking replay covers scoring and diversity guardrails', () {
    final report = HarnessEvals(_workspaceRoot()).evaluateRanking();

    expect(report.isSuccess, isTrue);
    expect(report.total, 7);
  });

  test('ranking replay rejects a mismatched model version', () {
    final root = Directory.systemTemp.createTempSync('river-ranking-eval-');
    addTearDown(() => root.deleteSync(recursive: true));
    Directory('${root.path}/evals').createSync(recursive: true);
    File('${root.path}/evals/ranking_sessions.json').writeAsStringSync(
      jsonEncode(
        <String, Object>{
          'cases': <Object>[
            <String, Object>{
              'id': 'future-model',
              'kind': 'profile',
              'expectedModelVersion': 2,
              'evidence': <Object>[],
              'expectedSources': <String, Object>{},
              'expectedTopics': <String, Object>{},
            },
          ],
        },
      ),
    );

    final report = HarnessEvals(root).evaluateRanking();

    expect(report.isSuccess, isFalse);
    expect(report.failures.single.message, contains('model version'));
  });
}

Directory _workspaceRoot() {
  var current = Directory.current.absolute;
  while (true) {
    final pubspec = File('${current.path}/pubspec.yaml');
    if (pubspec.existsSync() &&
        pubspec.readAsStringSync().contains('river_workspace')) {
      return current;
    }
    if (current.parent.path == current.path) {
      throw StateError('Workspace root not found');
    }
    current = current.parent;
  }
}
