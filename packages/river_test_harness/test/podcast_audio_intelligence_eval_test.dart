import 'dart:io';

import 'package:river_test_harness/river_test_harness.dart';
import 'package:test/test.dart';

void main() {
  test('podcast audio intelligence stays grounded, safe, and metered',
      () async {
    final report = await HarnessEvals(_workspaceRoot())
        .evaluatePodcastAudioIntelligenceReplay();

    expect(report.isSuccess, isTrue, reason: report.failures.toString());
    expect(report.total, 6);
    expect(report.metrics['groundedAnswers'], 1);
    expect(report.metrics['zeroProviderRefusals'], 1);
    expect(report.metrics['forgedCitationsRejected'], 1);
    expect(report.metrics['dialogueBriefs'], 1);
    expect(report.metrics['safetyBlocks'], 1);
    expect(report.metrics['lateCancellationCosts'], 1);
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
