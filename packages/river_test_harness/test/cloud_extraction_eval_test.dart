import 'dart:io';

import 'package:river_test_harness/river_test_harness.dart';
import 'package:test/test.dart';

void main() {
  test('cloud extraction replay blocks SSRF and sanitizes HTML', () async {
    final report =
        await HarnessEvals(_workspaceRoot()).evaluateCloudExtractionReplay();

    expect(report.isSuccess, isTrue);
    expect(report.total, 5);
    expect(report.metrics['transportCalls'], 4);
    expect(report.metrics['privateLiteralTransportCalls'], 0);
    expect(report.metrics['dnsPinned'], isTrue);
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
