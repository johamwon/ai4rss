import 'dart:io';

import 'package:river_test_harness/river_test_harness.dart';
import 'package:test/test.dart';

void main() {
  test('feed server replay covers adapters, mapping, cursor and removal',
      () async {
    final report =
        await HarnessEvals(_workspaceRoot()).evaluateFeedServerAccountReplay();

    expect(report.isSuccess, isTrue, reason: report.failures.join('\n'));
    expect(report.total, 6);
    expect(report.passed, 6);
    expect(report.metrics, containsPair('freshPulls', 1));
    expect(report.metrics, containsPair('minifluxPulls', 1));
    expect(report.metrics, containsPair('duplicateSources', 1));
    expect(report.metrics, containsPair('monotonicCursors', 1));
    expect(report.metrics, containsPair('stateUpdates', 1));
    expect(report.metrics, containsPair('safeRemovals', 1));
    expect(report.metrics, containsPair('credentialInDiagnostics', false));
  });
}

Directory _workspaceRoot() {
  var current = Directory.current.absolute;
  while (true) {
    final pubspec =
        File('${current.path}${Platform.pathSeparator}pubspec.yaml');
    if (pubspec.existsSync() &&
        pubspec.readAsStringSync().contains('river_workspace')) {
      return current;
    }
    if (current.parent.path == current.path) {
      throw StateError('River workspace root not found.');
    }
    current = current.parent;
  }
}
