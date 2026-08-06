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

  test('usage replay is idempotent and emits exact thresholds', () async {
    final report =
        await HarnessEvals(_workspaceRoot()).evaluateUsageLedgerReplay();

    expect(report.isSuccess, isTrue);
    expect(report.total, 5);
    expect(report.metrics['committedUnits'], 3);
    expect(report.metrics['refundedUnits'], 5);
    expect(report.metrics['rejectedReservations'], 1);
    expect(report.metrics['thresholdNotices'], 2);
  });

  test('Free product survives guest trial expiry and downgrade', () async {
    final report =
        await HarnessEvals(_workspaceRoot()).evaluateFreeProductReplay();

    expect(report.isSuccess, isTrue);
    expect(report.total, 18);
    expect(report.metrics['states'], 3);
    expect(report.metrics['wechatExtractions'], 3);
    expect(report.metrics['offlineReads'], 3);
    expect((report.metrics['speechSegments'] as int), greaterThanOrEqualTo(3));
    expect((report.metrics['podcastEpisodes'] as int), greaterThanOrEqualTo(3));
    expect(report.metrics['knowledgeItems'], 3);
    expect(report.metrics['exportBundles'], 3);
    expect(report.metrics['networkCalls'], 0);
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
