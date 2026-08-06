import 'dart:io';

import 'package:river_test_harness/river_test_harness.dart';
import 'package:test/test.dart';

void main() {
  test(
      'cloud TTS replay enforces billing, idempotency, cancellation and policy',
      () async {
    final report =
        await HarnessEvals(_workspaceRoot()).evaluateCloudTtsReplay();

    expect(report.isSuccess, isTrue);
    expect(report.total, 5);
    expect(report.metrics['providerCalls'], 5);
    expect(report.metrics['billedMilliseconds'], 17500);
    expect(report.metrics['cancellationPropagated'], isTrue);
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
