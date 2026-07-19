import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:river_app/app/article_list.dart';
import 'package:river_feed/river_feed.dart';

void main() {
  test('article list controller preserves sort while changing views', () {
    final controller = ArticleListController(
      load: (query) => const Stream<List<FeedArticleRecord>>.empty(),
    );
    var notifications = 0;
    controller.addListener(() => notifications += 1);

    controller.sortBy(FeedArticleSort.oldest);
    controller.show(FeedArticleView.unread);
    controller.showFolder('folder-1');

    expect(controller.query.view, FeedArticleView.folder);
    expect(controller.query.folderId, 'folder-1');
    expect(controller.query.sort, FeedArticleSort.oldest);
    expect(notifications, 3);
    controller.showFolder('folder-1');
    expect(notifications, 3);
    controller.dispose();
  });

  testWidgets('toolbar requests unread, folder, and oldest queries', (
    tester,
  ) async {
    final requested = <FeedArticleQuery>[];
    final controller = ArticleListController(
      load: (query) {
        requested.add(query);
        return Stream<List<FeedArticleRecord>>.value(
          const <FeedArticleRecord>[],
        );
      },
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _TestHost(
        controller: controller,
        folders: const <FeedFolderRecord>[
          FeedFolderRecord(
            id: 'folder-1',
            path: <String>['技术'],
            position: 0,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('未读'));
    await tester.pumpAndSettle();
    expect(requested.last.view, FeedArticleView.unread);
    expect(find.text('没有未读文章'), findsOneWidget);

    await tester.tap(find.byTooltip('选择文件夹'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('技术').last);
    await tester.pumpAndSettle();
    expect(requested.last.view, FeedArticleView.folder);
    expect(requested.last.folderId, 'folder-1');

    await tester.tap(find.byTooltip('排序：最新优先'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('最早优先').last);
    await tester.pumpAndSettle();
    expect(requested.last.sort, FeedArticleSort.oldest);
  });

  testWidgets('large list is lazy and restores each view scroll position', (
    tester,
  ) async {
    final articles = List<FeedArticleRecord>.generate(
      1000,
      (index) => _article(
        id: 'article-$index',
        title: 'Article $index',
        publishedAt: DateTime.utc(2026, 7, 19).subtract(Duration(days: index)),
        starred: index == 0,
        readLater: index == 0,
      ),
    );
    final controller = ArticleListController(
      load: (query) => Stream<List<FeedArticleRecord>>.value(articles),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(_TestHost(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('Article 0'), findsOneWidget);
    expect(find.text('Example Feed · 2026-07-19 · 4 分钟'), findsOneWidget);
    expect(find.byType(ArticleListTile).evaluate().length, lessThan(40));
    expect(find.text('Article 999'), findsNothing);

    await tester.drag(
      find.byType(ListView).last,
      const Offset(0, -900),
    );
    await tester.pumpAndSettle();
    expect(find.text('Article 0'), findsNothing);

    await tester.tap(find.text('未读'));
    await tester.pumpAndSettle();
    expect(find.text('Article 0'), findsOneWidget);
    await tester.tap(find.text('收件箱'));
    await tester.pumpAndSettle();
    expect(find.text('Article 0'), findsNothing);
  });

  testWidgets('article rows expose source and status semantics',
      (tester) async {
    final semantics = tester.ensureSemantics();
    final controller = ArticleListController(
      load: (query) => Stream<List<FeedArticleRecord>>.value(
        <FeedArticleRecord>[
          _article(
            id: 'accessible',
            title: 'Accessible article',
            starred: true,
            readLater: true,
          ),
        ],
      ),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(_TestHost(controller: controller));
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsLabel(
        RegExp(
          'Accessible article，Example Feed.*未读，已收藏，稍后读',
        ),
      ),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('article row delegates opening to the reader route', (
    tester,
  ) async {
    FeedArticleRecord? opened;
    final controller = ArticleListController(
      load: (query) => Stream<List<FeedArticleRecord>>.value(
        <FeedArticleRecord>[_article(id: 'open-me', title: 'Open article')],
      ),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ArticleListPane(
            controller: controller,
            folders: const <FeedFolderRecord>[],
            onOpenArticle: (article) => opened = article,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open article'));

    expect(opened?.id, 'open-me');
  });

  testWidgets('loading and failure states are safe and retryable', (
    tester,
  ) async {
    final gate = StreamController<List<FeedArticleRecord>>();
    final loadingController =
        ArticleListController(load: (query) => gate.stream);
    addTearDown(() async {
      loadingController.dispose();
      await gate.close();
    });
    await tester.pumpWidget(_TestHost(controller: loadingController));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    var calls = 0;
    final retryController = ArticleListController(
      load: (query) {
        calls += 1;
        if (calls == 1) {
          return Stream<List<FeedArticleRecord>>.error(
            StateError('private article body must stay hidden'),
          );
        }
        return Stream<List<FeedArticleRecord>>.value(
          <FeedArticleRecord>[_article(id: 'recovered', title: 'Recovered')],
        );
      },
    );
    addTearDown(retryController.dispose);
    await tester.pumpWidget(_TestHost(controller: retryController));
    await tester.pumpAndSettle();

    expect(find.text('无法加载文章'), findsOneWidget);
    expect(find.textContaining('private article body'), findsNothing);
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(find.text('Recovered'), findsOneWidget);
    expect(calls, 2);
  });
}

final class _TestHost extends StatelessWidget {
  const _TestHost({required this.controller, this.folders = const []});

  final ArticleListController controller;
  final List<FeedFolderRecord> folders;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: ArticleListPane(
          controller: controller,
          folders: folders,
          onOpenArticle: (_) {},
        ),
      ),
    );
  }
}

FeedArticleRecord _article({
  required String id,
  required String title,
  DateTime? publishedAt,
  bool starred = false,
  bool readLater = false,
}) =>
    FeedArticleRecord(
      id: id,
      feedId: 'feed-1',
      feedTitle: 'Example Feed',
      canonicalUrl: Uri.parse('https://example.test/$id'),
      title: title,
      read: false,
      starred: starred,
      readLater: readLater,
      publishedAt: publishedAt,
      summary: 'A concise summary for the article.',
      estimatedReadingMinutes: 4,
    );
