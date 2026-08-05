import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:river_app/app/article_list.dart';
import 'package:river_app/preferences/personalized_articles.dart';
import 'package:river_domain/river_domain.dart';
import 'package:river_feed/river_feed.dart';
import 'package:river_preferences/river_preferences.dart';

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

  test('disabling personalization immediately restores newest sorting',
      () async {
    final settings = StreamController<ReadingBehaviorSettings>();
    final controller = ArticleListController(
      load: (_) => const Stream<List<FeedArticleRecord>>.empty(),
      loadPersonalized: (_) =>
          const Stream<PersonalizedArticleListSnapshot>.empty(),
      behaviorSettings: settings.stream,
      personalizationEnabled: false,
      initialQuery: const FeedArticleQuery(sort: FeedArticleSort.smart),
    );
    addTearDown(() async {
      controller.dispose();
      await settings.close();
    });

    settings.add(const ReadingBehaviorSettings(captureEnabled: false));
    await Future<void>.delayed(Duration.zero);

    expect(controller.personalizationEnabled, isFalse);
    expect(controller.query.sort, FeedArticleSort.newest);
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
    expect(
      tester
          .getSemantics(find.byType(ArticleListTile))
          .getSemanticsData()
          .flagsCollection
          .isButton,
      isTrue,
    );
    semantics.dispose();
  });

  testWidgets('article row is reachable and activatable from the keyboard', (
    tester,
  ) async {
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ArticleListTile(
            article: _article(id: 'keyboard', title: 'Keyboard article'),
            onOpen: () => opened = true,
          ),
        ),
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(opened, isTrue);
  });

  testWidgets('article list remains usable at 200 percent system text size', (
    tester,
  ) async {
    final controller = ArticleListController(
      load: (_) => Stream<List<FeedArticleRecord>>.value(
        <FeedArticleRecord>[
          _article(
            id: 'large-text',
            title: 'A long accessible article title that may wrap safely',
            starred: true,
            readLater: true,
          ),
        ],
      ),
    );
    addTearDown(controller.dispose);
    tester.view.physicalSize = const Size(640, 1280);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: ArticleListPane(
              controller: controller,
              folders: const <FeedFolderRecord>[],
              onOpenArticle: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('A long accessible article'), findsOneWidget);
    expect(tester.takeException(), isNull);
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

  testWidgets('smart list exposes exact recommendation reasons', (
    tester,
  ) async {
    final article = _article(id: 'recommended', title: 'Recommended article');
    final explanation = RecommendationExplanation(
      version: recommendationExplanationVersion,
      rankingModelVersion: articleRankingModelVersion,
      guardrailModelVersion: rankingGuardrailModelVersion,
      score: 0.72,
      reasons: const <RecommendationReason>[
        RecommendationReason(
          kind: RecommendationReasonKind.preferredSource,
          factor: RankingFactor.source,
          value: 0.8,
          weight: 0.15,
          contribution: 0.12,
        ),
      ],
    );
    final controller = ArticleListController(
      load: (_) => Stream<List<FeedArticleRecord>>.value(<FeedArticleRecord>[
        article,
      ]),
      loadPersonalized: (_) => Stream<PersonalizedArticleListSnapshot>.value(
        PersonalizedArticleListSnapshot(
          articles: <FeedArticleRecord>[article],
          explanations: <String, RecommendationExplanation>{
            article.id: explanation,
          },
          personalized: true,
        ),
      ),
      personalizationEnabled: true,
      initialQuery: const FeedArticleQuery(sort: FeedArticleSort.smart),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(_TestHost(controller: controller));
    await tester.pumpAndSettle();

    expect(find.byTooltip('为什么推荐'), findsOneWidget);
    await tester.tap(find.byTooltip('为什么推荐'));
    await tester.pumpAndSettle();

    expect(find.text('为什么推荐'), findsOneWidget);
    expect(find.text('你更常认真阅读这个来源'), findsOneWidget);
    expect(find.text('该因子贡献 12.0%'), findsOneWidget);
    expect(find.text('排序模型 1 · 护栏模型 1'), findsOneWidget);
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
