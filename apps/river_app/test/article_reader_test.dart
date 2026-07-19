import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:river_app/app/article_reader.dart';
import 'package:river_domain/river_domain.dart';
import 'package:river_feed/river_feed.dart';

void main() {
  testWidgets('shows available feed content while full text is pending', (
    tester,
  ) async {
    final details = StreamController<FeedArticleDetailRecord?>();
    final extraction = Completer<ExtractionResult>();
    final controller = ArticleReaderController(
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
    final controller = ArticleReaderController(
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
  });

  testWidgets('cached article is readable when enhancement fails', (
    tester,
  ) async {
    final controller = ArticleReaderController(
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
    expect(find.text('完整正文暂不可用，当前内容仍可阅读'), findsOneWidget);
    expect(find.textContaining('private network detail'), findsNothing);
  });

  testWidgets('detail load failure is private and retryable', (tester) async {
    var calls = 0;
    final controller = ArticleReaderController(
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
}) =>
    FeedArticleDetailRecord(
      id: 'article-1',
      feedId: 'feed-1',
      feedTitle: 'Example Feed',
      canonicalUrl: Uri.parse('https://example.test/article'),
      title: 'Progressive article',
      read: false,
      starred: false,
      readLater: false,
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
