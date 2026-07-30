import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:river_app/preferences/reading_behavior_privacy_page.dart';
import 'package:river_data/river_data.dart';
import 'package:river_domain/river_domain.dart';

final class _FixedClock implements Clock {
  @override
  DateTime now() => DateTime.utc(2026, 7, 30, 12);
}

void main() {
  late RiverDatabase database;
  late DriftReadingEventRepository repository;

  setUp(() {
    database = RiverDatabase.inMemory();
    repository = DriftReadingEventRepository(database);
  });

  tearDown(() => database.close());

  testWidgets(
    'explains local-only scope before first enable and persists consent',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          home: ReadingBehaviorPrivacyPage(
            repository: repository,
            clock: _FixedClock(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('你的数据由你控制'), findsOneWidget);
      expect(find.text(readingBehaviorLocalOnlyExplanation), findsOneWidget);
      expect(find.text(readingBehaviorExcludedDataExplanation), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          '$readingBehaviorLocalOnlyExplanation '
          '$readingBehaviorExcludedDataExplanation',
        ),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('本地阅读偏好记录'), findsOneWidget);

      await tester.tap(find.text('记录本地阅读偏好'));
      await tester.pumpAndSettle();
      expect(find.text('是否启用本地阅读偏好？'), findsOneWidget);
      expect(find.text('仅在本机启用'), findsOneWidget);
      await tester.tap(find.text('仅在本机启用'));
      await tester.pumpAndSettle();

      expect((await repository.readSettings()).captureEnabled, isTrue);
      expect(await repository.needsIntroduction(), isFalse);
      expect(find.text('已开启，只写入这台设备'), findsOneWidget);
      semantics.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets('retention, export, and destructive clear stay explicit',
      (tester) async {
    String? copiedExport;
    await repository.saveSettings(
      const ReadingBehaviorSettings(captureEnabled: true),
      updatedAt: _FixedClock().now(),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ReadingBehaviorPrivacyPage(
          repository: repository,
          clock: _FixedClock(),
          copyExport: (contents) async => copiedExport = contents,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('90 天'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('30 天').last);
    await tester.pumpAndSettle();
    expect((await repository.readSettings()).retentionDays, 30);

    await tester.tap(find.text('复制行为数据'));
    await tester.pumpAndSettle();
    expect(find.text('行为数据已复制到剪贴板'), findsOneWidget);
    expect(copiedExport, contains('river.reading-event-export'));

    await tester.tap(find.text('清空本地行为记录'));
    await tester.pumpAndSettle();
    expect(find.text('清空本地行为记录？'), findsOneWidget);
    expect(
      find.textContaining('不会删除订阅、文章、收藏、笔记或知识库内容'),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(FilledButton, '清空记录'));
    await tester.pumpAndSettle();
    expect(find.text('已清空 0 条本地行为记录'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
