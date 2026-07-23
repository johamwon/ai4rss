import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:river_app/app/article_search.dart';
import 'package:river_feed/river_feed.dart';

void main() {
  testWidgets('debounces local search and exposes highlighted results', (
    tester,
  ) async {
    final requested = <ArticleSearchQuery>[];
    FeedArticleRecord? opened;
    await tester.pumpWidget(
      _host(
        load: (query) {
          requested.add(query);
          return Stream<List<ArticleSearchResult>>.value(
            <ArticleSearchResult>[
              ArticleSearchResult(
                article: _article(title: 'Machine Learning in River'),
                excerpt: 'A practical machine learning guide.',
              ),
            ],
          );
        },
        onOpenArticle: (article) => opened = article,
      ),
    );

    expect(find.text('输入关键词开始搜索'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'machine learning');
    await tester.pump(const Duration(milliseconds: 299));
    expect(requested, isEmpty);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();

    expect(requested.single.text, 'machine learning');
    expect(
      find.text('Machine Learning in River', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.text(
        'A practical machine learning guide.',
        findRichText: true,
      ),
      findsOneWidget,
    );
    await tester.tap(
      find.text('Machine Learning in River', findRichText: true),
    );
    expect(opened?.id, 'article-1');
  });

  testWidgets('filters, source selection, sorting, and retry are observable', (
    tester,
  ) async {
    final requested = <ArticleSearchQuery>[];
    var calls = 0;
    await tester.pumpWidget(
      _host(
        subscriptions: <FeedSubscriptionRecord>[_subscription()],
        load: (query) {
          requested.add(query);
          calls += 1;
          if (calls == 1) {
            return Stream<List<ArticleSearchResult>>.error(
              StateError('private indexed body'),
            );
          }
          return Stream<List<ArticleSearchResult>>.value(
            const <ArticleSearchResult>[],
          );
        },
      ),
    );
    await tester.enterText(find.byType(TextField), 'river');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    await tester.pump();

    expect(find.text('无法完成搜索'), findsOneWidget);
    expect(find.textContaining('private indexed body'), findsNothing);
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(find.text('没有匹配的文章'), findsOneWidget);

    await tester.tap(find.text('未读'));
    await tester.pumpAndSettle();
    expect(requested.last.view, FeedArticleView.unread);

    await tester.tap(find.byTooltip('按来源筛选'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Example Feed').last);
    await tester.pumpAndSettle();
    expect(requested.last.feedId, 'feed-1');

    await tester.tap(find.byTooltip('搜索结果排序'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('最早优先').last);
    await tester.pumpAndSettle();
    expect(requested.last.sort, ArticleSearchSort.oldest);
  });

  testWidgets('a newer query replaces a stale result stream', (tester) async {
    final streams = <String, StreamController<List<ArticleSearchResult>>>{};
    await tester.pumpWidget(
      _host(
        debounce: Duration.zero,
        load: (query) {
          final controller = StreamController<List<ArticleSearchResult>>();
          streams[query.text] = controller;
          addTearDown(controller.close);
          return controller.stream;
        },
      ),
    );

    await tester.enterText(find.byType(TextField), 'old');
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'new');
    await tester.pump();
    streams['old']!.add(
      <ArticleSearchResult>[
        ArticleSearchResult(
          article: _article(title: 'Stale old result'),
          excerpt: 'old',
        ),
      ],
    );
    streams['new']!.add(
      <ArticleSearchResult>[
        ArticleSearchResult(
          article: _article(title: 'Fresh new result'),
          excerpt: 'new',
        ),
      ],
    );
    await tester.pump();

    expect(find.text('Stale old result'), findsNothing);
    expect(
      find.text('Fresh new result', findRichText: true),
      findsOneWidget,
    );
  });
}

Widget _host({
  required ArticleSearchLoader load,
  ValueChanged<FeedArticleRecord>? onOpenArticle,
  List<FeedSubscriptionRecord> subscriptions = const <FeedSubscriptionRecord>[],
  Duration debounce = const Duration(milliseconds: 300),
}) {
  return MaterialApp(
    home: ArticleSearchPage(
      load: load,
      folders: const <FeedFolderRecord>[],
      subscriptions: subscriptions,
      onOpenArticle: onOpenArticle ?? (_) {},
      debounce: debounce,
    ),
  );
}

FeedArticleRecord _article({required String title}) => FeedArticleRecord(
      id: 'article-1',
      feedId: 'feed-1',
      feedTitle: 'Example Feed',
      canonicalUrl: Uri.parse('https://example.test/article'),
      title: title,
      author: 'River Lab',
      read: false,
      starred: false,
      readLater: false,
    );

FeedSubscriptionRecord _subscription() => FeedSubscriptionRecord(
      id: 'feed-1',
      canonicalUrl: Uri.parse('https://example.test/feed.xml'),
      title: 'Example Feed',
      kind: FeedDocumentKind.rss,
      enabled: true,
    );
