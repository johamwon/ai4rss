import 'dart:io';

import 'package:river_test_harness/river_test_harness.dart';
import 'package:test/test.dart';

void main() {
  test('knowledge vector replay preserves incremental index contracts',
      () async {
    final report =
        await HarnessEvals(_workspaceRoot()).evaluateKnowledgeVectorReplay();

    expect(report.isSuccess, isTrue);
    expect(report.total, 5);
    expect(report.metrics['skippedBuilds'], 1);
    expect(report.metrics['rebuiltBuilds'], 8);
    expect(report.metrics['deletedDocuments'], 1);
    expect(report.metrics['recoveredCorruptions'], 1);
    expect((report.metrics['providerCalls'] as int), greaterThanOrEqualTo(8));
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
