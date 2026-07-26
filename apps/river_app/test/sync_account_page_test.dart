import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:river_app/sync/sync_account_page.dart';
import 'package:river_sync/river_sync.dart';

void main() {
  testWidgets('shows status, conflict history, retry, and safe sign out', (
    tester,
  ) async {
    final experience = _Experience();
    addTearDown(experience.close);
    await tester.pumpWidget(
      MaterialApp(home: SyncAccountPage(experience: experience)),
    );
    await tester.pumpAndSettle();

    expect(find.text('同步已就绪'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('1 个尚未解决'), findsOneWidget);

    await tester.tap(find.text('冲突历史'));
    await tester.pumpAndSettle();
    expect(find.text('subscription · subscription-1'), findsOneWidget);
    expect(find.text('merged'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('立即重试同步'));
    await tester.pumpAndSettle();
    expect(experience.retryCalls, 1);

    await tester.tap(find.text('退出账号（保留本地数据）'));
    await tester.pumpAndSettle();
    expect(find.textContaining('已下载文章和本地阅读数据会保留'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '退出账号'));
    await tester.pumpAndSettle();
    expect(experience.signOutCalls, 1);
    expect(find.text('尚未登录同步账号'), findsOneWidget);
  });

  testWidgets('cloud deletion requires an exact destructive confirmation', (
    tester,
  ) async {
    final experience = _Experience();
    addTearDown(experience.close);
    await tester.pumpWidget(
      MaterialApp(home: SyncAccountPage(experience: experience)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('永久删除云端同步数据'));
    await tester.pumpAndSettle();
    final deleteButton = find.widgetWithText(FilledButton, '永久删除');
    expect(tester.widget<FilledButton>(deleteButton).onPressed, isNull);

    await tester.enterText(find.byType(TextField), '删除云端数据');
    await tester.pump();
    expect(tester.widget<FilledButton>(deleteButton).onPressed, isNotNull);
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();

    expect(experience.deleteCalls, 1);
    expect(find.text('尚未登录同步账号'), findsOneWidget);
  });
}

final class _Experience implements SyncAccountExperience {
  final StreamController<SyncAccountState> _states =
      StreamController<SyncAccountState>.broadcast();
  SyncAccountState _state = const SyncAccountState.loading();
  var retryCalls = 0;
  var signOutCalls = 0;
  var deleteCalls = 0;

  @override
  SyncAccountState get state => _state;

  @override
  Stream<SyncAccountState> get states => _states.stream;

  @override
  Future<void> load() async {
    _emit(
      SyncAccountState(
        phase: SyncAccountPhase.ready,
        session: _session(),
        storage: SyncStorageStatus(
          pendingMutations: 2,
          unresolvedConflicts: 1,
          serverSequence: 9,
          updatedAt: DateTime.utc(2026, 7, 27),
        ),
      ),
    );
  }

  @override
  Future<void> retryNow() async {
    retryCalls += 1;
  }

  @override
  Future<List<SyncConflictHistoryEntry>> conflictHistory({
    int limit = 100,
  }) async =>
      <SyncConflictHistoryEntry>[
        SyncConflictHistoryEntry(
          mutationId: 'remote-1',
          objectKind: SyncObjectKind.subscription,
          objectId: 'subscription-1',
          detectedAt: DateTime.utc(2026, 7, 27),
          resolutionKind: 'merged',
          resolutionMutationId: 'resolution-1',
          resolvedAt: DateTime.utc(2026, 7, 27),
        ),
      ];

  @override
  Future<void> signOut() async {
    signOutCalls += 1;
    _emit(const SyncAccountState.signedOut());
  }

  @override
  Future<SyncAuthResult<CloudDataDeletionReceipt>> deleteCloudData() async {
    deleteCalls += 1;
    _emit(const SyncAccountState.signedOut());
    return SyncAuthSuccess<CloudDataDeletionReceipt>(
      CloudDataDeletionReceipt(
        requestId: 'delete-1',
        accountId: 'account-1',
        completedAt: DateTime.utc(2026, 7, 27),
      ),
    );
  }

  Future<void> close() => _states.close();

  void _emit(SyncAccountState state) {
    _state = state;
    _states.add(state);
  }
}

SyncSession _session() => SyncSession(
      id: 'session-1',
      accountId: 'account-1',
      deviceId: 'Windows',
      accessToken: OpaqueSyncToken('access'),
      refreshToken: OpaqueSyncToken('refresh'),
      issuedAt: DateTime.utc(2026, 7, 26),
      expiresAt: DateTime.utc(2026, 7, 28),
      deviceStatus: SyncDeviceStatus.active,
    );
