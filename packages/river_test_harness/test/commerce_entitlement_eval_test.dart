import 'dart:io';

import 'package:river_test_harness/river_test_harness.dart';
import 'package:test/test.dart';

void main() {
  test('commerce replay preserves Free and verifies Pro grants', () async {
    final report = await HarnessEvals(_workspaceRoot())
        .evaluateCommerceEntitlementReplay();

    expect(report.isSuccess, isTrue);
    expect(report.total, 6);
    expect(report.metrics['freeChecks'], 18);
    expect(report.metrics['premiumChecks'], 3);
    expect(report.metrics['forgedSnapshotsRejected'], 1);
    expect(report.metrics['uiProductIdentifierReferences'], 0);
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
