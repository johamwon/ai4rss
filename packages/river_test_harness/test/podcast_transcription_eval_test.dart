import 'dart:io';

import 'package:river_test_harness/river_test_harness.dart';
import 'package:test/test.dart';

void main() {
  test('podcast transcription replay is bounded, resumable and deletable',
      () async {
    final report = await HarnessEvals(_workspaceRoot())
        .evaluatePodcastTranscriptionReplay();

    expect(report.isSuccess, isTrue);
    expect(report.total, 5);
    expect(report.metrics['ingestCalls'], 5);
    expect(report.metrics['transcriptionCalls'], 4);
    expect(report.metrics['resumeSkippedStages'], isTrue);
    expect(report.metrics['deletionComplete'], isTrue);
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
