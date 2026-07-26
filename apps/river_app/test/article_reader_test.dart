import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:river_app/app/article_reader.dart';
import 'package:river_domain/river_domain.dart';
import 'package:river_feed/river_feed.dart';

import '../test_support/article_reader_fakes.dart';

void main() {
  testWidgets('shows available feed content while full text is pending', (
    tester,
  ) async {
    final details = StreamController<FeedArticleDetailRecord?>();
    final extraction = Completer<ExtractionResult>();
    final controller = buildReaderController(
      articleId: 'article-1',
      watch: (_) => details.stream,
      extract: (_) => extraction.future,
    );
    addTearDown(() async {
      controller.dispose();
      await details.close();
    });
    await tester.pumpWidget(_TestHost(controller: controller));

    details.add(_detail(summary: 'Immediate feed preview'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Immediate feed preview'), findsOneWidget);
    expect(find.text('已显示可用内容，正在获取完整正文'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    extraction.complete(_success('Complete extracted article'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Complete extracted article'), findsOneWidget);
    expect(find.text('完整正文已就绪'), findsOneWidget);
  });

  testWidgets('progressive replacement preserves viewport and selection', (
    tester,
  ) async {
    const selected = 'KEEP THIS SELECTED PHRASE';
    final preview = List<String>.generate(
      90,
      (index) => index == 55
          ? 'Paragraph $index $selected continues here.'
          : 'Paragraph $index contains deterministic preview text.',
    ).join('\n');
    final complete = 'New introduction before the feed text.\n$preview\n'
        'Additional complete article ending.';
    final details = StreamController<FeedArticleDetailRecord?>();
    final extraction = Completer<ExtractionResult>();
    final controller = buildReaderController(
      articleId: 'article-1',
      watch: (_) => details.stream,
      extract: (_) => extraction.future,
    );
    addTearDown(() async {
      controller.dispose();
      await details.close();
    });
    await tester.pumpWidget(_TestHost(controller: controller));
    details.add(_detail(summary: preview));
    await tester.pump();
    await tester.pump();

    final state = tester.state<ArticleDocumentViewState>(
      find.byType(ArticleDocumentView),
    );
    state.scrollToFraction(0.65);
    final selectionStart = preview.indexOf(selected);
    state.selectRange(selectionStart, selectionStart + selected.length);
    await tester.pump();
    expect(state.scrollOffset, greaterThan(0));
    expect(state.selectedText, selected);

    extraction.complete(_success(complete));
    await tester.pump();
    await tester.pump();

    final updatedState = tester.state<ArticleDocumentViewState>(
      find.byType(ArticleDocumentView),
    );
    expect(identical(updatedState, state), isTrue);
    expect(updatedState.documentText, complete);
    expect(updatedState.selectedText, selected);
    expect(updatedState.scrollOffset, greaterThan(0));
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets('cached article is readable when enhancement fails', (
    tester,
  ) async {
    final controller = buildReaderController(
      articleId: 'article-1',
      watch: (_) => Stream<FeedArticleDetailRecord?>.value(
        _detail(
          summary: 'Short preview',
          content: FeedArticleContentRecord(
            sanitizedHtml: '<p>Offline cached body</p>',
            markdown: 'Offline cached body',
            plainText: 'Offline cached body',
            extractorName: 'readability',
            extractorVersion: '1',
            extractedAt: DateTime.utc(2026, 7, 19),
            contentHash: 'hash-1',
          ),
        ),
      ),
      extract: (_) async => const ExtractionFailureResult(
        failure: ExtractionFailure(
          code: ExtractionFailureCode.network,
          message: 'private network detail',
          retryable: true,
        ),
        attempts: <ExtractionAttempt>[],
      ),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(_TestHost(controller: controller));
    await tester.pump();
    await tester.pump();

    expect(find.text('Offline cached body'), findsOneWidget);
    expect(find.text('完整正文暂不可用'), findsOneWidget);
    expect(
      find.text('未能获取完整正文，Feed 或缓存内容仍可阅读'),
      findsOneWidget,
    );
    expect(find.text('使用当前内容'), findsOneWidget);
    expect(find.text('重试全文'), findsOneWidget);
    expect(find.text('打开原文'), findsOneWidget);
    expect(find.text('报告问题'), findsOneWidget);
    expect(find.textContaining('private network detail'), findsNothing);
    expect(find.byTooltip('已可离线阅读'), findsOneWidget);
  });

  testWidgets('offline download queues, exposes failure, and retries', (
    tester,
  ) async {
    final offline = FakeOfflineArticleManager();
    final controller = buildReaderController(
      articleId: 'article-1',
      watch: (_) => Stream<FeedArticleDetailRecord?>.value(
        _detail(summary: 'Readable Feed preview'),
      ),
      extract: (_) => Completer<ExtractionResult>().future,
      offlineArticles: offline,
    );
    addTearDown(() async {
      controller.dispose();
      await offline.close();
    });
    await tester.pumpWidget(_TestHost(controller: controller));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byTooltip('离线下载'));
    await tester.pump();

    expect(offline.enqueued, <String>['article-1']);
    expect(find.byTooltip('等待离线下载'), findsOneWidget);
    expect(find.text('已排队，联网后自动完成离线下载'), findsOneWidget);

    offline.emit(
      const OfflineArticleState(
        articleId: 'article-1',
        phase: OfflineArticlePhase.failed,
        failureCode: 'network',
      ),
    );
    await tester.pump();
    expect(find.byTooltip('重试离线下载'), findsOneWidget);
    expect(find.text('离线下载失败，可以重试'), findsOneWidget);

    await tester.tap(find.byTooltip('重试离线下载'));
    await tester.pump();
    expect(offline.retried, <String>['article-1']);
    expect(find.byTooltip('等待离线下载'), findsOneWidget);

    offline.emit(
      const OfflineArticleState(
        articleId: 'article-1',
        phase: OfflineArticlePhase.available,
      ),
    );
    await tester.pump();
    expect(find.byTooltip('已可离线阅读'), findsOneWidget);
    expect(find.text('已可离线阅读'), findsOneWidget);
  });

  testWidgets('full-text retry forces reparse and replaces the fallback',
      (tester) async {
    final requests = <ExtractionRequest>[];
    var calls = 0;
    final controller = buildReaderController(
      articleId: 'article-1',
      watch: (_) => Stream<FeedArticleDetailRecord?>.value(
        _detail(summary: 'Readable Feed fallback'),
      ),
      extract: (request) async {
        requests.add(request);
        calls += 1;
        if (calls == 1) {
          return const ExtractionFailureResult(
            failure: ExtractionFailure(
              code: ExtractionFailureCode.timeout,
              message: 'private timeout detail',
              retryable: true,
            ),
            attempts: <ExtractionAttempt>[],
          );
        }
        return _success('Recovered full article');
      },
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(_TestHost(controller: controller));
    await tester.pump();
    await tester.pump();

    expect(find.text('Readable Feed fallback'), findsOneWidget);
    await tester.tap(find.text('重试全文'));
    await tester.pump();
    await tester.pump();

    expect(requests, hasLength(2));
    expect(requests.first.forceReparse, isFalse);
    expect(requests.last.forceReparse, isTrue);
    expect(find.text('Recovered full article'), findsOneWidget);
    expect(find.text('完整正文已就绪'), findsOneWidget);
    expect(find.text('重试全文'), findsNothing);
  });

  testWidgets('failure actions open original and report only safe diagnostics',
      (tester) async {
    final external = FakeExternalUriGateway();
    final share = FakeShareGateway();
    final controller = buildReaderController(
      articleId: 'article-1',
      watch: (_) => Stream<FeedArticleDetailRecord?>.value(
        _detail(summary: 'Sensitive fallback body'),
      ),
      extract: (_) async => const ExtractionFailureResult(
        failure: ExtractionFailure(
          code: ExtractionFailureCode.network,
          message: 'private network detail',
          retryable: true,
        ),
        attempts: <ExtractionAttempt>[
          ExtractionAttempt(
            extractor: 'readability',
            extractorVersion: '2',
            outcome: ExtractionAttemptOutcome.failed,
            failureCode: ExtractionFailureCode.network,
          ),
        ],
      ),
      externalUri: external,
      share: share,
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(_TestHost(controller: controller));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('打开原文'));
    await tester.pump();
    expect(external.lastUri, Uri.parse('https://example.test/article'));

    await tester.tap(find.text('报告问题'));
    await tester.pump();
    final report = share.lastRequest!;
    expect(report.title, 'River 全文提取问题');
    expect(report.text, contains('https://example.test/article'));
    expect(report.text, contains('network'));
    expect(report.text, contains('readability@2:failed'));
    expect(report.text, isNot(contains('private network detail')));
    expect(report.text, isNot(contains('Sensitive fallback body')));

    external.outcome = ExternalUriOpenOutcome.unavailable;
    await tester.tap(find.byTooltip('打开原文'));
    await tester.pump();
    expect(find.text('无法打开原文，请检查系统浏览器设置后重试'), findsOneWidget);

    await tester.tap(find.text('使用当前内容'));
    await tester.pump();
    expect(find.text('正在使用 Feed 或缓存内容'), findsOneWidget);
    expect(find.text('报告问题'), findsNothing);
    expect(find.text('Sensitive fallback body'), findsOneWidget);
  });

  testWidgets('missing fallback exposes recovery instead of a spinner',
      (tester) async {
    final controller = buildReaderController(
      articleId: 'article-1',
      watch: (_) => Stream<FeedArticleDetailRecord?>.value(
        _detail(summary: ''),
      ),
      extract: (_) async => const ExtractionFailureResult(
        failure: ExtractionFailure(
          code: ExtractionFailureCode.articleBodyMissing,
          message: 'private parser detail',
        ),
        attempts: <ExtractionAttempt>[],
      ),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(_TestHost(controller: controller));
    await tester.pump();
    await tester.pump();

    expect(find.text('未能获取可阅读正文，请重试全文或打开原文'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('使用当前内容'), findsNothing);
    expect(find.text('重试全文'), findsOneWidget);
    expect(find.textContaining('private parser detail'), findsNothing);
  });

  testWidgets('detail load failure is private and retryable', (tester) async {
    var calls = 0;
    final controller = buildReaderController(
      articleId: 'article-1',
      watch: (_) {
        calls += 1;
        return calls == 1
            ? Stream<FeedArticleDetailRecord?>.error(
                StateError('private article data'),
              )
            : Stream<FeedArticleDetailRecord?>.value(
                _detail(summary: 'Recovered article'),
              );
      },
      extract: (_) => Completer<ExtractionResult>().future,
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(_TestHost(controller: controller));
    await tester.pump();

    expect(find.text('无法打开文章'), findsOneWidget);
    expect(find.textContaining('private article data'), findsNothing);
    await tester.tap(find.text('重试'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Recovered article'), findsOneWidget);
    expect(calls, 2);
  });

  testWidgets(
    'restores progress and persists reader actions settings and safe share',
    (tester) async {
      final body = List<String>.generate(
        140,
        (index) => 'Paragraph $index keeps the reader scrollable.',
      ).join('\n');
      final repository = FakeArticleReaderRepository(
        (_) => Stream<FeedArticleDetailRecord?>.value(
          _detail(summary: body, scrollDepth: 0.52),
        ),
      );
      final settings = FakeReaderSettingsRepository();
      final share = FakeShareGateway();
      final controller = buildReaderController(
        articleId: 'article-1',
        watch: repository.watch,
        repository: repository,
        settings: settings,
        share: share,
        extract: (_) => Completer<ExtractionResult>().future,
      );
      addTearDown(() async {
        controller.dispose();
        await settings.close();
      });

      await tester.pumpWidget(_TestHost(controller: controller));
      await tester.pump();
      await tester.pump();

      final document = tester.state<ArticleDocumentViewState>(
        find.byType(ArticleDocumentView),
      );
      expect(document.scrollOffset, greaterThan(0));
      expect(repository.readWrites, <bool>[true]);

      await tester.tap(find.byTooltip('收藏'));
      await tester.pump();
      await tester.tap(find.byTooltip('稍后读'));
      await tester.pump();
      await tester.tap(find.byTooltip('分享'));
      await tester.pump();

      expect(repository.starredWrites, <bool>[true]);
      expect(repository.readLaterWrites, <bool>[true]);
      expect(share.lastRequest, isNotNull);
      expect(share.lastRequest!.text, contains('Progressive article'));
      expect(share.lastRequest!.text, contains('https://example.test/article'));
      expect(share.lastRequest!.text, isNot(contains('Paragraph 100')));

      await tester.tap(find.byTooltip('阅读排版'));
      await tester.pumpAndSettle();
      expect(find.text('阅读排版'), findsOneWidget);
      expect(find.byType(Slider), findsNWidgets(3));
      await tester.tap(find.text('深色'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, '保存'));
      await tester.pumpAndSettle();

      expect(settings.current.theme, ReaderThemePreference.dark);
      expect(
        Theme.of(tester.element(find.byType(TextField))).brightness,
        Brightness.dark,
      );

      document.scrollToFraction(0.81);
      await tester.pump(const Duration(milliseconds: 500));
      expect(repository.progressWrites.last, closeTo(0.81, 0.02));
    },
  );

  testWidgets('reader keeps system text scaling above its own typography', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
          child: Scaffold(
            body: ArticleDocumentView(
              content: const ArticleReaderContent(
                text: 'Accessible reading text',
                source: ArticleReaderContentSource.feed,
                revision: 'one',
              ),
              settings: const ReaderSettings(fontScale: 1.2),
              initialProgress: 0,
              onProgressChanged: (_) {},
            ),
          ),
        ),
      ),
    );

    final field = find.byType(TextField);
    final media = MediaQuery.of(tester.element(field));
    expect(media.textScaler.scale(10), 15);
    expect(tester.widget<TextField>(field).style!.fontSize, greaterThan(18));
  });
}

final class _TestHost extends StatelessWidget {
  const _TestHost({required this.controller});

  final ArticleReaderController controller;

  @override
  Widget build(BuildContext context) => MaterialApp(
        home: ArticleReaderScreen(controller: controller),
      );
}

FeedArticleDetailRecord _detail({
  required String summary,
  FeedArticleContentRecord? content,
  double scrollDepth = 0,
  bool read = false,
  bool starred = false,
  bool readLater = false,
}) =>
    FeedArticleDetailRecord(
      id: 'article-1',
      feedId: 'feed-1',
      feedTitle: 'Example Feed',
      canonicalUrl: Uri.parse('https://example.test/article'),
      title: 'Progressive article',
      read: read,
      starred: starred,
      readLater: readLater,
      scrollDepth: scrollDepth,
      activeReadSeconds: 0,
      publishedAt: DateTime.utc(2026, 7, 19),
      summary: summary,
      content: content,
    );

ExtractionSuccess _success(String text) => ExtractionSuccess(
      article: ExtractedArticle(
        title: 'Progressive article',
        html: '<p>$text</p>',
        plainText: text,
        extractor: 'readability',
        extractorVersion: '1',
      ),
      attempts: const <ExtractionAttempt>[
        ExtractionAttempt(
          extractor: 'readability',
          extractorVersion: '1',
          outcome: ExtractionAttemptOutcome.succeeded,
        ),
      ],
    );
