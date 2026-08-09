import 'dart:io';

import 'package:river_test_harness/river_test_harness.dart';
import 'package:test/test.dart';

void main() {
  test('knowledge search golden set meets recall and precision gates',
      () async {
    final report =
        await HarnessEvals(_workspaceRoot()).evaluateKnowledgeSearchReplay();

    expect(report.isSuccess, isTrue);
    expect(report.total, 6);
    expect(report.metrics['recallAtK'], 1.0);
    expect(report.metrics['precisionAtK'], 1.0);
    expect(report.metrics['evidenceHits'], 10);
    expect(report.metrics['queryEmbeddingCalls'], 5);
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
