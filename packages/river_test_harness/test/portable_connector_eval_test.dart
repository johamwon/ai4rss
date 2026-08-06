import 'dart:io';

import 'package:river_test_harness/river_test_harness.dart';
import 'package:test/test.dart';

void main() {
  test('portable connector replay keeps writes safe and retryable', () async {
    final report =
        await HarnessEvals(_workspaceRoot()).evaluatePortableConnectorReplay();

    expect(report.isSuccess, isTrue);
    expect(report.total, 5);
    expect(report.metrics['idempotentCreates'], 1);
    expect(report.metrics['conflicts'], 1);
    expect(report.metrics['conditionalWrites'], 1);
    expect(report.metrics['rateLimits'], 1);
    expect(report.metrics['offlineRetries'], 1);
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
