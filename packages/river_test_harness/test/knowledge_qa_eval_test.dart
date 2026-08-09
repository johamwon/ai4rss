import 'dart:io';

import 'package:river_test_harness/river_test_harness.dart';
import 'package:test/test.dart';

void main() {
  test('knowledge questions require sufficient cited evidence', () async {
    final report =
        await HarnessEvals(_workspaceRoot()).evaluateKnowledgeQuestionReplay();

    expect(report.isSuccess, isTrue);
    expect(report.total, 5);
    expect(report.metrics['answered'], 1);
    expect(report.metrics['refusedWithoutProvider'], 1);
    expect(report.metrics['providerRefusals'], 1);
    expect(report.metrics['rejectedOutputs'], 2);
    expect(report.metrics['materializedCitations'], 1);
    expect(report.metrics['privateContentInDiagnostics'], isFalse);
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
