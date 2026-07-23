import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:river_data/river_data.dart';
import 'package:river_feed/river_feed.dart' as feed;
import 'package:test/test.dart';

void main() {
  test(
    '10,000 article local search P95 stays below 500ms',
    () async {
      final database = RiverDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final now = DateTime.utc(2026, 7, 23);
      await database
          .into(database.feedSubscriptions)
          .insert(
            FeedSubscriptionsCompanion.insert(
              id: 'feed-performance',
              canonicalUrl: 'https://performance.test/feed.xml',
              title: 'Performance feed',
              feedKind: 'rss',
              createdAt: now,
              updatedAt: now,
            ),
          );
      await database.batch((batch) {
        for (var index = 0; index < 10000; index += 1) {
          batch.insert(
            database.articles,
            ArticlesCompanion.insert(
              id: 'article-$index',
              feedId: 'feed-performance',
              canonicalUrl: 'https://performance.test/$index',
              title:
                  'Search performance marker${index.toString().padLeft(5, '0')}',
              feedSummary: Value<String?>(
                'Local search benchmark document number $index',
              ),
              publishedAt: Value<DateTime?>(
                now.subtract(Duration(seconds: index)),
              ),
              createdAt: now,
              updatedAt: now,
            ),
          );
        }
      });
      final repository = DriftFeedRepository(database);
      const query = feed.ArticleSearchQuery(text: 'marker09999');

      await repository.watchSearch(query).first;
      final samples = <int>[];
      for (var run = 0; run < 20; run += 1) {
        final stopwatch = Stopwatch()..start();
        final results = await repository.watchSearch(query).first;
        stopwatch.stop();
        expect(results.single.article.id, 'article-9999');
        samples.add(stopwatch.elapsedMicroseconds);
      }
      samples.sort();
      final p95Microseconds = samples[(samples.length * 0.95).ceil() - 1];
      // ignore: avoid_print
      print(
        'READ-005 benchmark: 10,000 articles P95 '
        '${(p95Microseconds / 1000).toStringAsFixed(1)}ms',
      );

      expect(
        p95Microseconds,
        lessThan(500000),
        reason:
            'P95 was ${(p95Microseconds / 1000).toStringAsFixed(1)}ms '
            'for 10,000 articles',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
