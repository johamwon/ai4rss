import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:river_app/app/article_reader.dart';
import 'package:river_domain/river_domain.dart';
import 'package:river_feed/river_feed.dart';

import '../test_support/article_reader_fakes.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('full text replacement keeps viewport and text selection', (
    tester,
  ) async {
    const selected = 'runner selection anchor';
    final preview = List<String>.generate(
      120,
      (index) => index == 70
          ? 'Paragraph $index contains the $selected for verification.'
          : 'Paragraph $index is deterministic feed preview content.',
    ).join('\n');
    final complete = 'New full-text introduction.\n$preview\nComplete ending.';
    final details = StreamController<FeedArticleDetailRecord?>();
    final extraction = Completer<ExtractionResult>();
    final repository = FakeArticleReaderRepository((_) => details.stream);
    final controller = buildReaderController(
      articleId: 'article-1',
      watch: repository.watch,
      repository: repository,
      extract: (_) => extraction.future,
    );
    addTearDown(() async {
      controller.dispose();
      await details.close();
    });
    await tester.pumpWidget(
      MaterialApp(home: ArticleReaderScreen(controller: controller)),
    );
    details.add(
      FeedArticleDetailRecord(
        id: 'article-1',
        feedId: 'feed-1',
        feedTitle: 'Runner Feed',
        canonicalUrl: Uri.parse('https://example.test/article'),
        title: 'Runner progressive reader',
        read: false,
        starred: false,
        readLater: false,
        scrollDepth: 0,
        activeReadSeconds: 0,
        summary: preview,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final document = tester.state<ArticleDocumentViewState>(
      find.byType(ArticleDocumentView),
    );
    document.scrollToFraction(0.6);
    final start = preview.indexOf(selected);
    document.selectRange(start, start + selected.length);
    await tester.pump(const Duration(milliseconds: 50));
    expect(document.scrollOffset, greaterThan(0));

    extraction.complete(
      ExtractionSuccess(
        article: ExtractedArticle(
          title: 'Runner progressive reader',
          html: '<p>$complete</p>',
          plainText: complete,
          extractor: 'runner-fixture',
          extractorVersion: '1',
        ),
        attempts: const <ExtractionAttempt>[
          ExtractionAttempt(
            extractor: 'runner-fixture',
            extractorVersion: '1',
            outcome: ExtractionAttemptOutcome.succeeded,
          ),
        ],
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(document.documentText, complete);
    expect(document.selectedText, selected);
    expect(document.scrollOffset, greaterThan(0));
    await tester.pump(const Duration(milliseconds: 500));
    expect(repository.readWrites, <bool>[true]);
    expect(repository.progressWrites, isNotEmpty);
    await tester.tap(find.byTooltip('收藏'));
    await tester.pump();
    expect(repository.starredWrites, <bool>[true]);
    expect(find.text('完整正文已就绪'), findsOneWidget);
  });
}
