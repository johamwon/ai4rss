import 'dart:io';

import 'package:river_test_harness/river_test_harness.dart';
import 'package:test/test.dart';

void main() {
  test('IMA replay stays portable and avoids private APIs', () async {
    final report =
        await HarnessEvals(_workspaceRoot()).evaluateImaPortableReplay();

    expect(report.isSuccess, isTrue, reason: report.failures.toString());
    expect(report.total, 5);
    expect(report.metrics['markdownPackages'], 1);
    expect(report.metrics['zipPackages'], 1);
    expect(report.metrics['explicitDismissals'], 1);
    expect(report.metrics['publicEntries'], 1);
    expect(report.metrics['unsafeEntriesRejected'], 1);
    expect(report.metrics['nativePrivateApi'], isFalse);
    expect(report.metrics['privateContentInDiagnostics'], isFalse);
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
      throw StateError('Workspace root not found');
    }
    current = current.parent;
  }
}
