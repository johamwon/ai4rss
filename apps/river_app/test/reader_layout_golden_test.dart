import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:river_app/app/article_reader.dart';
import 'package:river_domain/river_domain.dart';
import 'package:river_feed/river_feed.dart';

import '../test_support/article_reader_fakes.dart';

void main() {
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

      await expectLater(
        find.byType(ArticleReaderScreen),
        matchesGoldenFile(scenario.golden),
      );
    });
  }
}

const _body = '''
River shows locally available content first, then improves it without moving the reader away from the paragraph they chose.

Typography remains comfortable on a phone, a tablet, and a wide desktop window. System text scaling still applies on top of the reader's own preference.

收藏、稍后读和阅读进度都保存在本地。断网或重新启动应用后，用户仍然可以回到上一次阅读的位置。
''';
