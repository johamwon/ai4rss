import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:river_app/app/article_reader.dart';
import 'package:river_app/app/article_summary.dart';
import 'package:river_design_system/river_design_system.dart';
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

  testWidgets('newer progressive content clears a stale pending replacement', (
    tester,
  ) async {
    const selected = 'stable selected quote';
    const preview = 'Preview begins. $selected Preview ends.';
    const incompatible = 'Intermediate content no longer contains the quote.';
    const latest = 'Latest introduction. $preview';

    Widget host(ArticleReaderContent content) => MaterialApp(
          home: Scaffold(
            body: ArticleDocumentView(
              content: content,
              settings: const ReaderSettings(),
              initialProgress: 0,
              onProgressChanged: (_) {},
            ),
          ),
        );

    await tester.pumpWidget(
      host(
        const ArticleReaderContent(
          text: preview,
          source: ArticleReaderContentSource.feed,
          revision: 'preview',
        ),
      ),
    );
    final document = tester.state<ArticleDocumentViewState>(
      find.byType(ArticleDocumentView),
    );
    final selectedStart = preview.indexOf(selected);
    document.selectRange(selectedStart, selectedStart + selected.length);
    await tester.pump();

    await tester.pumpWidget(
      host(
        const ArticleReaderContent(
          text: incompatible,
          source: ArticleReaderContentSource.cache,
          revision: 'intermediate',
        ),
      ),
    );
    expect(document.documentText, preview);

    await tester.pumpWidget(
      host(
        const ArticleReaderContent(
          text: latest,
          source: ArticleReaderContentSource.extracted,
          revision: 'latest',
        ),
      ),
    );
    expect(document.documentText, latest);
    expect(document.selectedText, selected);

    document.selectRange(document.selection.end, document.selection.end);
    await tester.pump();
    expect(document.documentText, latest);
  });

  testWidgets('selected text becomes a durable highlight with a note', (
    tester,
  ) async {
    const selected = 'knowledge-worthy sentence';
    const preview = 'Opening context. $selected. Closing context.';
    final details = StreamController<FeedArticleDetailRecord?>();
    final extraction = Completer<ExtractionResult>();
    final annotations = FakeArticleAnnotationRepository();
    final controller = buildReaderController(
      articleId: 'article-1',
      watch: (_) => details.stream,
      extract: (_) => extraction.future,
      annotations: annotations,
      ids: SequentialReaderIds(),
    );
    addTearDown(() async {
      controller.dispose();
      await details.close();
      await annotations.close();
    });
    await tester.pumpWidget(_TestHost(controller: controller));
    details.add(_detail(summary: preview));
    await tester.pump();
    await tester.pump();

    final document = tester.state<ArticleDocumentViewState>(
      find.byType(ArticleDocumentView),
    );
    final start = preview.indexOf(selected);
    document.selectRange(start, start + selected.length);
    await tester.pump();

    expect(find.text('高亮'), findsOneWidget);
    expect(find.text('高亮并添加笔记'), findsOneWidget);
    await tester.tap(find.text('高亮并添加笔记'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '连接到产品决策');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(annotations.annotations, hasLength(1));
    expect(annotations.annotations.single.anchor.exact, selected);
    expect(annotations.annotations.single.note, '连接到产品决策');
    expect(annotations.annotations.single.anchor.contentRevision, isNotEmpty);
    expect(find.byTooltip('高亮与笔记'), findsOneWidget);

    await tester.tap(find.byTooltip('高亮与笔记'));
    await tester.pumpAndSettle();
    expect(find.text(selected), findsOneWidget);
    expect(find.text('连接到产品决策'), findsOneWidget);
    expect(find.text('正文变化后已失联'), findsNothing);
  });

  testWidgets(
    'article, highlight, and note save as one idempotent knowledge item',
    (tester) async {
      const selected = 'knowledge-worthy sentence';
      const preview = 'Opening context. $selected. Closing context.';
      final details = StreamController<FeedArticleDetailRecord?>();
      final extraction = Completer<ExtractionResult>();
      final annotations = FakeArticleAnnotationRepository();
      final knowledge = MemoryKnowledgeRepository();
      final controller = buildReaderController(
        articleId: 'article-1',
        watch: (_) => details.stream,
        extract: (_) => extraction.future,
        annotations: annotations,
        ids: SequentialReaderIds(),
        knowledge: knowledge,
      );
      addTearDown(() async {
        controller.dispose();
        await details.close();
        await annotations.close();
        await knowledge.close();
      });
      await tester.pumpWidget(_TestHost(controller: controller));
      details.add(_detail(summary: preview));
      await tester.pump();
      await tester.pump();

      final document = tester.state<ArticleDocumentViewState>(
        find.byType(ArticleDocumentView),
      );
      final start = preview.indexOf(selected);
      document.selectRange(start, start + selected.length);
      await tester.pump();
      await tester.tap(find.text('高亮并添加笔记'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, '连接到产品决策');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('保存到知识库'));
      await tester.pumpAndSettle();

      expect(knowledge.items, hasLength(1));
      final first = knowledge.items.single;
      expect(first.source.sourceId, 'article-1');
      expect(first.excerpts.single.quote, selected);
      expect(first.excerpts.single.note, '连接到产品决策');
      expect(first.notes, <String>['连接到产品决策']);
      expect(first.markdown, contains(preview));
      expect(find.textContaining('已保存到知识库'), findsOneWidget);
      expect(find.byTooltip('更新知识库内容'), findsOneWidget);

      await tester.tap(find.byTooltip('更新知识库内容'));
      await tester.pumpAndSettle();
      expect(knowledge.items, hasLength(1));
      expect(knowledge.items.single.id, first.id);
    },
  );

  testWidgets('highlight capture uses the revision still visible to selection',
      (
    tester,
  ) async {
    const selected = 'old-only quote';
    const preview = 'Preview prefix $selected preview suffix.';
    final details = StreamController<FeedArticleDetailRecord?>();
    final extraction = Completer<ExtractionResult>();
    final annotations = FakeArticleAnnotationRepository();
    final controller = buildReaderController(
      articleId: 'article-1',
      watch: (_) => details.stream,
      extract: (_) => extraction.future,
      annotations: annotations,
      ids: SequentialReaderIds(),
    );
    addTearDown(() async {
      controller.dispose();
      await details.close();
      await annotations.close();
    });
    await tester.pumpWidget(_TestHost(controller: controller));
    details.add(_detail(summary: preview));
    await tester.pump();
    await tester.pump();

    final document = tester.state<ArticleDocumentViewState>(
      find.byType(ArticleDocumentView),
    );
    final start = preview.indexOf(selected);
    document.selectRange(start, start + selected.length);
    await tester.pump();

    extraction.complete(_success('Replacement without the selected words.'));
    await tester.pump();
    await tester.pump();
    expect(document.documentText, preview);
    final latestRevision = controller.state.content!.revision;

    await tester.tap(find.text('高亮'));
    await tester.pumpAndSettle();

    expect(annotations.annotations.single.anchor.exact, selected);
    expect(
      annotations.annotations.single.anchor.contentRevision,
      isNot(latestRevision),
    );
    expect(document.documentText, 'Replacement without the selected words.');
    expect(find.textContaining('部分高亮因正文变化已失联'), findsOneWidget);
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

  testWidgets(
    'article TTS restores progress, highlights the sentence, and updates controls',
    (tester) async {
      const body = '第一句适合朗读。第二句从断点继续。';
      final engine = FakeArticleAudioEngine();
      final playback = MemoryAudioPlaybackRepository();
      final controller = buildReaderController(
        articleId: 'article-1',
        watch: (_) => Stream<FeedArticleDetailRecord?>.value(
          _detail(summary: body),
        ),
        extract: (_) => Completer<ExtractionResult>().future,
        audio: engine,
        audioPlayback: playback,
      );
      addTearDown(() async {
        controller.dispose();
        await engine.dispose();
      });
      await tester.pumpWidget(_TestHost(controller: controller));
      await tester.pump();
      await tester.pump();

      final revision = controller.state.content!.revision;
      playback.values['article-1'] = AudioPlaybackSnapshot(
        item: AudioItem(
          id: 'article-1',
          kind: AudioKind.articleTts,
          title: 'Progressive article',
          sourceUri: Uri.parse('https://example.test/article'),
        ),
        position: const AudioPlaybackPosition.speech(segmentIndex: 1),
        settings: const AudioPlaybackSettings(rate: 1.25),
        updatedAt: DateTime.utc(2026, 7, 19, 7),
        contentRevision: revision,
      );

      expect(find.byTooltip('朗读文章'), findsOneWidget);
      await tester.tap(find.byTooltip('朗读文章'));
      await tester.pumpAndSettle();

      expect(engine.loaded, isNotNull);
      expect(engine.loaded!.speechSegments, hasLength(2));
      expect(engine.seeks.last.segmentIndex, 1);
      expect(engine.playCalls, 1);
      expect(find.textContaining('第 2/2 句'), findsOneWidget);
      expect(find.byTooltip('暂停朗读'), findsOneWidget);
      final document = tester.state<ArticleDocumentViewState>(
        find.byType(ArticleDocumentView),
      );
      expect(
        document.highlightedRange,
        TextRange(
          start: engine.loaded!.speechSegments[1].sourceStart,
          end: engine.loaded!.speechSegments[1].sourceEnd,
        ),
      );

      await tester.tap(find.byTooltip('朗读速度'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(CheckedPopupMenuItem<double>, '1.5 倍速'),
      );
      await tester.pumpAndSettle();
      expect(engine.settingsWrites.last.rate, 1.5);

      await tester.tap(find.byTooltip('定时停止'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('10 分钟后停止'));
      await tester.pump();
      expect(controller.state.audio.sleepDeadline, isNotNull);
      expect(find.textContaining('已开启定时停止'), findsOneWidget);

      await tester.tap(find.byTooltip('暂停朗读'));
      await tester.pump();
      expect(engine.pauseCalls, 1);
      expect(find.byTooltip('继续朗读'), findsOneWidget);
      await tester.tap(find.byTooltip('定时停止'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('关闭定时'));
      await tester.pump();
      expect(controller.state.audio.sleepDeadline, isNull);
    },
  );

  testWidgets('reader shortcuts invoke accessible article actions', (
    tester,
  ) async {
    final repository = FakeArticleReaderRepository(
      (_) => Stream<FeedArticleDetailRecord?>.value(
        _detail(summary: 'Keyboard readable body', read: true),
      ),
    );
    final offline = FakeOfflineArticleManager();
    final external = FakeExternalUriGateway();
    final controller = buildReaderController(
      articleId: 'article-1',
      watch: repository.watch,
      repository: repository,
      offlineArticles: offline,
      externalUri: external,
      extract: (_) => Completer<ExtractionResult>().future,
    );
    addTearDown(() async {
      controller.dispose();
      await offline.close();
    });
    await tester.pumpWidget(_TestHost(controller: controller));
    await tester.pump();
    await tester.pump();

    await _sendControlShortcut(tester, LogicalKeyboardKey.keyM);
    await _sendControlShortcut(tester, LogicalKeyboardKey.keyS);
    await _sendControlShortcut(tester, LogicalKeyboardKey.keyL);
    await _sendControlShortcut(tester, LogicalKeyboardKey.keyO);
    await _sendControlShortcut(tester, LogicalKeyboardKey.keyD);
    await tester.pump();

    expect(repository.readWrites, <bool>[true, false]);
    expect(repository.starredWrites, <bool>[true]);
    expect(repository.readLaterWrites, <bool>[true]);
    expect(external.lastUri, Uri.parse('https://example.test/article'));
    expect(offline.enqueued, <String>['article-1']);
  });

  testWidgets('reader honors high contrast and exposes the title as a header', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final settings = FakeReaderSettingsRepository(
      initial: const ReaderSettings(theme: ReaderThemePreference.light),
    );
    final controller = buildReaderController(
      articleId: 'article-1',
      watch: (_) => Stream<FeedArticleDetailRecord?>.value(
        _detail(summary: 'Accessible high contrast body'),
      ),
      settings: settings,
      extract: (_) => Completer<ExtractionResult>().future,
    );
    addTearDown(() async {
      controller.dispose();
      await settings.close();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(highContrast: true),
          child: ArticleReaderScreen(controller: controller),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final readerTheme = Theme.of(tester.element(find.byType(TextField)));
    expect(
      readerTheme.colorScheme.primary,
      RiverTheme.highContrastLight().colorScheme.primary,
    );
    expect(
      tester
          .getSemantics(find.text('Progressive article'))
          .getSemanticsData()
          .flagsCollection
          .isHeader,
      isTrue,
    );
    semantics.dispose();
  });

  testWidgets('AI summary discloses scope and renders structured result', (
    tester,
  ) async {
    final summaries = _FakeSummaryExperience(
      results: <Future<ArticleSummary> Function()>[
        () async => _articleSummary(),
      ],
    );
    final controller = _summaryController(summaries);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_TestHost(controller: controller));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byTooltip('AI 摘要'));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('Test Provider · test-model'), findsOneWidget);
    expect(find.textContaining('不会发送笔记、高亮'), findsOneWidget);

    await tester.tap(find.text('生成摘要'));
    await tester.pumpAndSettle();
    expect(find.textContaining('可能计入你的供应商用量'), findsOneWidget);
    await tester.tap(find.text('确认生成'));
    await tester.pump();
    await tester.pump();

    expect(find.text('一句话结论'), findsOneWidget);
    expect(find.text('• 关键点一'), findsOneWidget);
    expect(find.text('为什么值得阅读'), findsOneWidget);
    expect(find.text('主题 · RSS'), findsOneWidget);
    expect(find.text('实体 · River'), findsOneWidget);
    expect(find.text('约 4 分钟'), findsOneWidget);
    expect(summaries.summarizeCalls, 1);
  });

  testWidgets('AI summary cancellation ignores a late provider result', (
    tester,
  ) async {
    final pending = Completer<ArticleSummary>();
    final summaries = _FakeSummaryExperience(
      results: <Future<ArticleSummary> Function()>[
        () => pending.future,
      ],
    );
    final controller = _summaryController(summaries);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_TestHost(controller: controller));
    await tester.pump();
    await tester.pump();

    await _openAndConfirmSummary(tester);
    expect(find.text('正在生成摘要'), findsOneWidget);
    await tester.tap(find.byKey(const Key('article-summary-cancel')));
    await tester.pump();
    expect(find.textContaining('已停止等待摘要'), findsOneWidget);

    pending.complete(_articleSummary());
    await tester.pump();
    await tester.pump();
    expect(find.text('一句话结论'), findsNothing);
    expect(controller.state.summaryState.phase, ArticleSummaryPhase.cancelled);
  });

  testWidgets('AI summary failure retries without breaking article reading', (
    tester,
  ) async {
    final summaries = _FakeSummaryExperience(
      results: <Future<ArticleSummary> Function()>[
        () async => throw const ArticleSummaryExperienceFailure(
              code: ArticleSummaryExperienceFailureCode.providerUnavailable,
              retryable: true,
            ),
        () async => _articleSummary(),
      ],
    );
    final controller = _summaryController(summaries);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_TestHost(controller: controller));
    await tester.pump();
    await tester.pump();

    await _openAndConfirmSummary(tester);
    await tester.pump();
    expect(find.textContaining('AI 提供商暂时不可用'), findsOneWidget);
    expect(find.text('Summary source body'), findsOneWidget);

    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认生成'));
    await tester.pump();
    await tester.pump();
    expect(find.text('一句话结论'), findsOneWidget);
    expect(summaries.summarizeCalls, 2);
  });

  testWidgets('AI summary becomes stale when full text replaces feed content', (
    tester,
  ) async {
    final details = StreamController<FeedArticleDetailRecord?>();
    final extraction = Completer<ExtractionResult>();
    final summaries = _FakeSummaryExperience(
      results: <Future<ArticleSummary> Function()>[
        () async => _articleSummary(),
      ],
    );
    final controller = buildReaderController(
      articleId: 'article-1',
      watch: (_) => details.stream,
      extract: (_) => extraction.future,
      summaries: summaries,
    );
    addTearDown(() async {
      controller.dispose();
      await details.close();
    });
    await tester.pumpWidget(_TestHost(controller: controller));
    details.add(_detail(summary: 'Summary source body'));
    await tester.pump();
    await tester.pump();

    await _openAndConfirmSummary(tester);
    await tester.pump();
    expect(find.text('一句话结论'), findsOneWidget);

    extraction.complete(_success('A different complete article body'));
    await tester.pump();
    await tester.pump();
    expect(find.text('正文已更新，当前摘要可能过期。'), findsOneWidget);
    expect(controller.state.summaryState.phase, ArticleSummaryPhase.stale);
  });

  testWidgets('AI summary shows stable offline recovery and keeps body', (
    tester,
  ) async {
    final summaries = _FakeSummaryExperience(
      results: <Future<ArticleSummary> Function()>[
        () async => throw const ArticleSummaryExperienceFailure(
              code: ArticleSummaryExperienceFailureCode.offline,
              retryable: true,
            ),
      ],
    );
    final controller = _summaryController(summaries);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_TestHost(controller: controller));
    await tester.pump();
    await tester.pump();

    await _openAndConfirmSummary(tester);
    await tester.pump();
    expect(find.textContaining('当前离线且没有匹配'), findsOneWidget);
    expect(find.text('Summary source body'), findsOneWidget);
  });

  testWidgets('AI summary restores a cached result without provider call', (
    tester,
  ) async {
    final summaries = _FakeSummaryExperience(cached: _articleSummary());
    final controller = _summaryController(summaries);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_TestHost(controller: controller));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byTooltip('AI 摘要'));
    await tester.pump();
    await tester.pump();
    expect(find.text('一句话结论'), findsOneWidget);
    expect(summaries.summarizeCalls, 0);
  });

  testWidgets('current AI summary is included in the knowledge snapshot', (
    tester,
  ) async {
    final knowledge = MemoryKnowledgeRepository();
    final summaries = _FakeSummaryExperience(
      results: <Future<ArticleSummary> Function()>[
        () async => _articleSummary(),
      ],
    );
    final controller = _summaryController(
      summaries,
      knowledge: knowledge,
      ids: SequentialReaderIds(),
    );
    addTearDown(() async {
      controller.dispose();
      await knowledge.close();
    });
    await tester.pumpWidget(_TestHost(controller: controller));
    await tester.pump();
    await tester.pump();
    await _openAndConfirmSummary(tester);
    await tester.pump();

    final saved = await controller.saveToKnowledge();

    expect(saved?.summary?.oneLine, '一句话结论');
    expect(saved?.topics, <String>['RSS']);
    expect(saved?.entities, <String>['River']);
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

Future<void> _sendControlShortcut(
  WidgetTester tester,
  LogicalKeyboardKey key,
) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
}

ArticleReaderController _summaryController(
  ArticleSummaryExperience summaries, {
  KnowledgeRepository? knowledge,
  IdGenerator? ids,
}) =>
    buildReaderController(
      articleId: 'article-1',
      watch: (_) => Stream<FeedArticleDetailRecord?>.value(
        _detail(summary: 'Summary source body'),
      ),
      extract: (_) => Completer<ExtractionResult>().future,
      summaries: summaries,
      knowledge: knowledge,
      ids: ids,
    );

Future<void> _openAndConfirmSummary(WidgetTester tester) async {
  await tester.tap(find.byTooltip('AI 摘要'));
  await tester.pump();
  await tester.pump();
  await tester.tap(find.text('生成摘要'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('确认生成'));
  await tester.pump();
}

ArticleSummary _articleSummary() => const ArticleSummary(
      oneLine: '一句话结论',
      keyPoints: <String>['关键点一', '关键点二', '关键点三'],
      whyItMatters: '它能帮助读者判断是否继续阅读。',
      topics: <String>['RSS'],
      entities: <String>['River'],
      estimatedReadingMinutes: 4,
      language: 'zh-CN',
      model: 'test-model',
      promptVersion: 'article-summary@1',
    );

final class _FakeSummaryExperience implements ArticleSummaryExperience {
  _FakeSummaryExperience({
    this.cached,
    List<Future<ArticleSummary> Function()> results =
        const <Future<ArticleSummary> Function()>[],
  }) : _results = List<Future<ArticleSummary> Function()>.of(results);

  final ArticleSummary? cached;
  final List<Future<ArticleSummary> Function()> _results;
  var summarizeCalls = 0;

  @override
  Future<ArticleSummaryInspection> inspect(Article article) async =>
      ArticleSummaryInspection(
        preparation: ArticleSummaryPreparation(
          providerLabel: 'Test Provider',
          model: 'test-model',
          contentCharacters: article.plainText!.length,
          isLongArticle: false,
          maximumProviderCalls: 2,
          estimatedInputTokens: 0,
          estimatedOutputTokens: 3200,
        ),
        cachedSummary: cached,
      );

  @override
  Future<ArticleSummary> summarize(Article article) {
    summarizeCalls += 1;
    return _results.removeAt(0)();
  }
}
