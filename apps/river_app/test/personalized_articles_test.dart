import 'package:flutter_test/flutter_test.dart';
import 'package:river_app/preferences/personalized_articles.dart';
import 'package:river_data/river_data.dart' hide ReadingEvent;
import 'package:river_domain/river_domain.dart';
import 'package:river_feed/river_feed.dart';

final class _FixedClock implements Clock {
  @override
  DateTime now() => DateTime.utc(2026, 8, 3, 12);
}

void main() {
  late RiverDatabase database;
  late DriftFeedRepository feeds;
  late DriftReadingEventRepository behavior;
  late LocalPersonalizedArticleExperience experience;

  setUp(() async {
    database = RiverDatabase.inMemory();
    await database.verifyReady();
    feeds = DriftFeedRepository(database);
    behavior = DriftReadingEventRepository(database);
    experience = LocalPersonalizedArticleExperience(
      feeds: feeds,
      behavior: behavior,
      clock: _FixedClock(),
    );
    await _seedArticles(database);
    await behavior.saveSettings(
      const ReadingBehaviorSettings(captureEnabled: true),
      updatedAt: _FixedClock().now(),
    );
    await behavior.record(
      ReadingEvent(
        eventId: 'star-b',
        articleId: 'article-b',
        type: ReadingEventType.starred,
        occurredAt: DateTime.utc(2026, 8, 3, 11),
      ),
    );
  });

  tearDown(() => database.close());

  test('real local evidence ranks, explains, blocks, and falls back', () async {
    const query = FeedArticleQuery(sort: FeedArticleSort.smart);
    final ranked = await experience.watch(query).first;

    expect(ranked.personalized, isTrue);
    expect(ranked.articles.map((article) => article.id), contains('article-b'));
    expect(
      ranked.explanations.keys,
      orderedEquals(ranked.articles.map((article) => article.id)),
    );
    expect(
      ranked.explanations.values
          .expand((explanation) => explanation.reasons)
          .every(
            (reason) => reason.contribution == reason.value * reason.weight,
          ),
      isTrue,
    );

    await experience.setSourceBlocked('feed-b', true);
    final blocked = await experience.watch(query).first;
    expect(blocked.filteredByBlockedSource, 1);
    expect(blocked.articles, isNotEmpty);
    expect(
      blocked.articles.map((article) => article.feedId),
      isNot(contains('feed-b')),
    );

    await experience.setEnabled(false);
    final chronological = await experience.watch(query).first;
    expect(chronological.personalized, isFalse);
    expect(chronological.articles, hasLength(4));
    expect(chronological.articles.first.id, 'article-a1');
  });

  test('clear profile is atomic and preserves the capture choice', () async {
    await experience.setSourceAdjustment('feed-a', 2);
    await experience.setTopicBlocked('spoilers', true);

    expect(await behavior.readEvents(), isNotEmpty);
    expect((await behavior.readSettings()).preferenceControls.isEmpty, isFalse);
    expect(await experience.clearProfile(), 1);

    final settings = await behavior.readSettings();
    expect(settings.captureEnabled, isTrue);
    expect(settings.preferenceControls.isEmpty, isTrue);
    expect(await behavior.readEvents(), isEmpty);
    expect(await database.select(database.articles).get(), hasLength(4));
    expect(
      await database.select(database.feedSubscriptions).get(),
      hasLength(2),
    );
  });
}

Future<void> _seedArticles(RiverDatabase database) async {
  final createdAt = DateTime.utc(2026, 8, 3, 8);
  for (final (id, title) in <(String, String)>[
    ('feed-a', 'Feed A'),
    ('feed-b', 'Feed B'),
  ]) {
    await database.into(database.feedSubscriptions).insert(
          FeedSubscriptionsCompanion.insert(
            id: id,
            canonicalUrl: 'https://example.test/$id.xml',
            title: title,
            feedKind: 'rss',
            createdAt: createdAt,
            updatedAt: createdAt,
          ),
        );
  }
  for (final (id, feedId, hour) in <(String, String, int)>[
    ('article-a1', 'feed-a', 11),
    ('article-a2', 'feed-a', 10),
    ('article-a3', 'feed-a', 9),
    ('article-b', 'feed-b', 8),
  ]) {
    final articleTime = DateTime.utc(2026, 8, 3, hour);
    await database.into(database.articles).insert(
          ArticlesCompanion.insert(
            id: id,
            feedId: feedId,
            canonicalUrl: 'https://example.test/$id',
            title: id,
            createdAt: articleTime,
            updatedAt: articleTime,
          ),
        );
  }
}
