import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:river_app/sync/sync_recovery_dialog.dart';
import 'package:river_sync/river_sync.dart';

void main() {
  testWidgets('recovery confirmation stays blocked until offline save',
      (tester) async {
    var confirmations = 0;
    final secret = SyncRecoverySecret(List<int>.filled(32, 24));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SyncRecoveryCodeDialog(
            secret: secret,
            onConfirmed: () => confirmations += 1,
          ),
        ),
      ),
    );

    expect(find.textContaining('服务端无法'), findsOneWidget);
    expect(find.text(secret.revealCode()), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '已安全保存'))
          .onPressed,
      isNull,
    );

    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '已安全保存'));

    expect(confirmations, 1);
  });

  testWidgets('recovery code is exposed as selectable read-only semantics',
      (tester) async {
    final secret = SyncRecoverySecret(List<int>.filled(32, 25));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SyncRecoveryCodeDialog(
            secret: secret,
            onConfirmed: () {},
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('sync-recovery-code')),
      findsOneWidget,
    );
    expect(find.byType(SelectableText), findsOneWidget);
    expect(find.textContaining('不要发送给任何人'), findsOneWidget);
  });
}
