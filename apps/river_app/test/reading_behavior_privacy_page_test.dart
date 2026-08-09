import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:river_app/preferences/automatic_summaries.dart';
import 'package:river_app/preferences/personalized_articles.dart';
import 'package:river_app/preferences/reading_behavior_privacy_page.dart';
import 'package:river_data/river_data.dart';
import 'package:river_domain/river_domain.dart';
import 'package:river_preferences/river_preferences.dart';

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

  testWidgets('profile can be viewed, edited, disabled, and cleared',
      (tester) async {
    final personalization = _FakePreferenceProfileExperience();
    await tester.pumpWidget(
      MaterialApp(
        home: ReadingBehaviorPrivacyPage(
          repository: repository,
          clock: _FixedClock(),
          personalization: personalization,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('查看和编辑偏好画像'));
    await tester.pumpAndSettle();

    expect(find.text('偏好画像'), findsOneWidget);
    expect(find.text('Example Feed'), findsOneWidget);
    expect(find.bySemanticsLabel('个性化排序与本地行为学习'), findsOneWidget);

    await tester.tap(find.byTooltip('调整Example Feed的偏好'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('减少此类内容').last);
    await tester.pumpAndSettle();
    expect(personalization.sourceAdjustment, -2);

    await tester.tap(find.text('个性化排序'));
    await tester.pumpAndSettle();
    expect(find.text('关闭个性化排序？'), findsOneWidget);
    await tester.tap(find.text('关闭并回到时间排序'));
    await tester.pumpAndSettle();
    expect(personalization.enabled, isFalse);

    await tester.ensureVisible(find.text('清空偏好画像'));
    await tester.tap(find.text('清空偏好画像'));
    await tester.pumpAndSettle();
    expect(find.text('清空偏好画像？'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '清空画像'));
    await tester.pumpAndSettle();
    expect(personalization.cleared, isTrue);
  });

  testWidgets('automatic summary policy discloses AI use and updates limits',
      (tester) async {
    final automatic = _FakeAutomaticSummaryExperience();
    await tester.pumpWidget(
      MaterialApp(
        home: ReadingBehaviorPrivacyPage(
          repository: repository,
          clock: _FixedClock(),
          automaticSummaries: automatic,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('自动摘要'));
    await tester.pumpAndSettle();
    expect(find.textContaining('失败和缓存命中不占用每日额度'), findsOneWidget);
    expect(find.bySemanticsLabel('自动摘要'), findsWidgets);

    await tester.tap(find.text('自动生成高匹配文章摘要'));
    await tester.pumpAndSettle();
    expect(find.text('启用自动摘要？'), findsOneWidget);
    expect(find.textContaining('发送到你配置的 AI 服务'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '启用'));
    await tester.pumpAndSettle();
    expect(automatic.settings.enabled, isTrue);

    await tester.tap(find.text('3 篇'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('5 篇').last);
    await tester.pumpAndSettle();
    expect(automatic.settings.dailyLimit, 5);
  });

  testWidgets('ranking experiment is explicit, local-only, and stable',
      (tester) async {
    final ranking = LocalRankingExperiment(
      repository: DriftRankingExperimentRepository(database),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ReadingBehaviorPrivacyPage(
          repository: repository,
          clock: _FixedClock(),
          rankingExperiment: ranking,
          experimentIds: _Ids(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('本地排序对照实验'));
    await tester.pumpAndSettle();
    expect(find.textContaining('不会自动上传'), findsOneWidget);
    expect(find.textContaining('样本不足'), findsOneWidget);
    expect(find.text('未参加；现有智能排序行为不变'), findsOneWidget);

    await tester.tap(find.text('参加实验'));
    await tester.pumpAndSettle();
    expect(find.text('参加本地排序对照实验？'), findsOneWidget);
    expect(find.textContaining('不会记录或上传文章'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '仅在本机参加'));
    await tester.pumpAndSettle();

    final enrollment = await ranking.readEnrollment();
    expect(enrollment, isNotNull);
    expect(find.textContaining('本机稳定分组'), findsOneWidget);
  });
}

final class _Ids implements IdGenerator {
  var _next = 0;

  @override
  String next() => 'experiment-device-${_next++}';
}

final class _FakePreferenceProfileExperience
    implements PreferenceProfileExperience {
  bool enabled = true;
  bool cleared = false;
  double sourceAdjustment = 0;

  @override
  Future<PreferenceProfileSnapshot> loadProfile() async =>
      PreferenceProfileSnapshot(
        settings: ReadingBehaviorSettings(captureEnabled: enabled),
        evidenceCount: cleared ? 0 : 3,
        sources: cleared
            ? const <PreferenceProfileDimension>[]
            : <PreferenceProfileDimension>[
                PreferenceProfileDimension(
                  id: 'feed-1',
                  label: 'Example Feed',
                  learnedScore: 1.5,
                  adjustment: sourceAdjustment,
                  blocked: false,
                ),
              ],
        topics: const <PreferenceProfileDimension>[],
      );

  @override
  Future<int> clearProfile() async {
    cleared = true;
    sourceAdjustment = 0;
    return 3;
  }

  @override
  Future<void> setEnabled(bool value) async => enabled = value;

  @override
  Future<void> setSourceAdjustment(String sourceId, double adjustment) async {
    sourceAdjustment = adjustment;
  }

  @override
  Future<void> setSourceBlocked(String sourceId, bool blocked) async {}

  @override
  Future<void> setTopicAdjustment(String topic, double adjustment) async {}

  @override
  Future<void> setTopicBlocked(String topic, bool blocked) async {}
}

final class _FakeAutomaticSummaryExperience
    implements AutomaticSummaryExperience {
  AutomaticSummarySettings settings = const AutomaticSummarySettings();

  @override
  Future<AutomaticSummaryDashboard> loadDashboard() async =>
      AutomaticSummaryDashboard(
        settings: settings,
        usage: const AutomaticSummaryUsageSnapshot(
          dayKey: '2026-08-05',
          reserved: 0,
          completed: 1,
        ),
      );

  @override
  Future<void> updateSettings(AutomaticSummarySettings value) async {
    settings = value;
  }
}
