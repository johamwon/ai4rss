import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:river_app/app/article_reader.dart';
import 'package:river_domain/river_domain.dart';
import 'package:river_feed/river_feed.dart';

import '../test_support/article_reader_fakes.dart';

void main() {
  const goldenDiffTolerance = 0.025;
  late GoldenFileComparator originalComparator;

  setUpAll(() {
    originalComparator = goldenFileComparator;
    final localComparator = originalComparator;
    if (localComparator is LocalFileComparator) {
      goldenFileComparator = _CrossPlatformGoldenComparator(
        localComparator.basedir.resolve('reader_layout_golden_test.dart'),
        tolerance: goldenDiffTolerance,
      );
    }
  });

  tearDownAll(() {
    goldenFileComparator = originalComparator;
  });

  final cases = <({
    String name,
    Size size,
    ReaderSettings settings,
    String golden,
  })>[
    (
      name: 'phone light',
      size: const Size(390, 844),
      settings: const ReaderSettings(theme: ReaderThemePreference.light),
      golden: 'goldens/reader_phone_light.png',
    ),
    (
      name: 'phone dark and large type',
      size: const Size(390, 844),
      settings: const ReaderSettings(
        fontScale: 1.4,
        lineHeight: 2,
        theme: ReaderThemePreference.dark,
      ),
      golden: 'goldens/reader_phone_dark_large.png',
    ),
    (
      name: 'tablet serif',
      size: const Size(820, 1180),
      settings: const ReaderSettings(
        fontFamily: ReaderFontFamily.serif,
        contentWidth: 680,
        theme: ReaderThemePreference.light,
      ),
      golden: 'goldens/reader_tablet_serif.png',
    ),
    (
      name: 'windows wide dark',
      size: const Size(1440, 900),
      settings: const ReaderSettings(
        contentWidth: 880,
        theme: ReaderThemePreference.dark,
      ),
      golden: 'goldens/reader_windows_wide_dark.png',
    ),
    (
      name: 'windows narrow light',
      size: const Size(720, 900),
      settings: const ReaderSettings(
        contentWidth: 600,
        theme: ReaderThemePreference.light,
      ),
      golden: 'goldens/reader_windows_narrow_light.png',
    ),
  ];

  for (final scenario in cases) {
    testWidgets('reader golden ${scenario.name}', (tester) async {
      await tester.binding.setSurfaceSize(scenario.size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final settings = FakeReaderSettingsRepository(
        initial: scenario.settings,
      );
      final controller = buildReaderController(
        articleId: 'golden-article',
        watch: (_) => Stream<FeedArticleDetailRecord?>.value(
          FeedArticleDetailRecord(
            id: 'golden-article',
            feedId: 'golden-feed',
            feedTitle: 'River Design Review',
            canonicalUrl: Uri.parse('https://example.test/golden'),
            title: 'A calm reading surface for every screen',
            author: 'River Lab',
            publishedAt: DateTime.utc(2026, 7, 19),
            summary: _body,
            read: false,
            starred: true,
            readLater: true,
            scrollDepth: 0,
            activeReadSeconds: 0,
          ),
        ),
        extract: (_) async => ExtractionSuccess(
          article: const ExtractedArticle(
            title: 'A calm reading surface for every screen',
            html: '<p>$_body</p>',
            plainText: _body,
            extractor: 'golden',
            extractorVersion: '1',
          ),
          attempts: const <ExtractionAttempt>[],
        ),
        settings: settings,
      );
      addTearDown(() async {
        controller.dispose();
        await settings.close();
      });

      await tester.pumpWidget(
        MaterialApp(home: ArticleReaderScreen(controller: controller)),
      );
      await tester.pumpAndSettle();

      _expectExactReaderLayout(tester, scenario.size, scenario.settings);
      await expectLater(
        find.byType(ArticleReaderScreen),
        matchesGoldenFile(scenario.golden),
      );
    });
  }
}

void _expectExactReaderLayout(
  WidgetTester tester,
  Size surfaceSize,
  ReaderSettings settings,
) {
  expect(tester.takeException(), isNull);
  expect(find.byType(ArticleReaderScreen), findsOneWidget);
  expect(find.byType(ArticleDocumentView), findsOneWidget);
  expect(find.byTooltip('标记已读'), findsOneWidget);
  expect(find.byTooltip('取消收藏'), findsOneWidget);
  expect(find.byTooltip('移出稍后读'), findsOneWidget);
  expect(find.byTooltip('分享'), findsOneWidget);
  expect(find.byTooltip('打开原文'), findsOneWidget);
  expect(find.byTooltip('阅读排版'), findsOneWidget);

  final documentSize = tester.getSize(find.byType(ArticleDocumentView));
  final textFieldFinder = find.byType(TextField);
  final textFieldSize = tester.getSize(textFieldFinder);
  expect(documentSize.width, closeTo(surfaceSize.width, 0.01));
  expect(textFieldSize.width, greaterThan(0));
  expect(
    textFieldSize.width,
    lessThanOrEqualTo(settings.contentWidth + 0.01),
  );
  expect(
    textFieldSize.width,
    lessThanOrEqualTo(documentSize.width - 40 + 0.01),
  );

  final textField = tester.widget<TextField>(textFieldFinder);
  final context = tester.element(textFieldFinder);
  final baseFontSize = Theme.of(context).textTheme.bodyLarge!.fontSize!;
  expect(
    textField.style!.fontSize,
    closeTo(baseFontSize * settings.fontScale, 0.01),
  );
  expect(textField.style!.height, settings.lineHeight);
  expect(
    textField.style!.fontFamily,
    switch (settings.fontFamily) {
      ReaderFontFamily.system =>
        Theme.of(context).textTheme.bodyLarge!.fontFamily,
      ReaderFontFamily.serif => 'Noto Serif CJK SC',
      ReaderFontFamily.sansSerif => 'Noto Sans CJK SC',
    },
  );
  expect(
    Theme.of(context).brightness,
    switch (settings.theme) {
      ReaderThemePreference.system => Theme.of(context).brightness,
      ReaderThemePreference.light => Brightness.light,
      ReaderThemePreference.dark => Brightness.dark,
    },
  );
}

final class _CrossPlatformGoldenComparator extends LocalFileComparator {
  _CrossPlatformGoldenComparator(
    super.testFile, {
    required this.tolerance,
  });

  final double tolerance;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    if (result.passed || result.diffPercent <= tolerance) {
      result.dispose();
      return true;
    }

    final feedback = await generateFailureOutput(result, golden, basedir);
    final actual = (result.diffPercent * 100).toStringAsFixed(2);
    final allowed = (tolerance * 100).toStringAsFixed(2);
    result.dispose();
    throw FlutterError(
      '$feedback\n'
      'Cross-platform golden difference was $actual%; '
      'the allowed maximum is $allowed%.',
    );
  }
}

const _body = '''
River shows locally available content first, then improves it without moving the reader away from the paragraph they chose.

Typography remains comfortable on a phone, a tablet, and a wide desktop window. System text scaling still applies on top of the reader's own preference.

收藏、稍后读和阅读进度都保存在本地。断网或重新启动应用后，用户仍然可以回到上一次阅读的位置。
''';
