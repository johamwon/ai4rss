import 'dart:io';

import 'package:river_test_harness/river_test_harness.dart';
import 'package:test/test.dart';

void main() {
  test('cloud governance replay trips cost and preserves local core', () async {
    final report =
        await HarnessEvals(_workspaceRoot()).evaluateCloudGovernanceReplay();

    expect(report.isSuccess, isTrue);
    expect(report.total, 4);
    expect(report.metrics['costTrip'], isTrue);
    expect(report.metrics['remoteDisabled'], isTrue);
    expect(report.metrics['forgedRejected'], isTrue);
    expect(report.metrics['localReads'], 1);
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
