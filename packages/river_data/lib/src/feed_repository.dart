import 'package:drift/drift.dart';
import 'package:river_feed/river_feed.dart' as feed;

import 'database.dart';

final class DriftFeedRepository implements feed.FeedRepository {
  const DriftFeedRepository(this.database);

  final RiverDatabase database;

  @override
  Future<feed.FeedSubscriptionRecord?> findByCanonicalUrl(
    Uri canonicalUrl,
  ) async {
    final query = database.select(database.feedSubscriptions)
      ..where((table) => table.canonicalUrl.equals(canonicalUrl.toString()));
    final row = await query.getSingleOrNull();
    return row == null ? null : _subscription(row);
  }

  @override
  Stream<List<feed.FeedSubscriptionRecord>> watchSubscriptions() {
    final query = database.select(database.feedSubscriptions)
      ..orderBy(<OrderingTerm Function($FeedSubscriptionsTable)>[
        (table) => OrderingTerm.asc(table.title),
      ]);
    return query.watch().map(
      (rows) => rows.map(_subscription).toList(growable: false),
    );
  }

  @override
  Stream<List<feed.FeedArticleRecord>> watchArticles({String? feedId}) {
    final query = database.select(database.articles);
    if (feedId != null) {
      query.where((table) => table.feedId.equals(feedId));
    }
    query.orderBy(<OrderingTerm Function($ArticlesTable)>[
      (table) => OrderingTerm.desc(table.publishedAt),
      (table) => OrderingTerm.desc(table.createdAt),
    ]);
    return query.watch().map(
      (rows) => rows.map(_article).toList(growable: false),
    );
  }

  @override
  Future<void> applyRefresh({
    required String feedId,
    required Uri canonicalUrl,
    required feed.ParsedFeed feed,
    required List<feed.FeedArticleDraft> articles,
    required DateTime refreshedAt,
    String? etag,
    String? lastModified,
  }) {
    return database.transaction(() async {
      final existingFeed = await (database.select(
        database.feedSubscriptions,
      )..where((table) => table.id.equals(feedId))).getSingleOrNull();
      if (existingFeed == null) {
        await database
            .into(database.feedSubscriptions)
            .insert(
              FeedSubscriptionsCompanion.insert(
                id: feedId,
                canonicalUrl: canonicalUrl.toString(),
                title: _limited(feed.title, 1024),
                feedKind: feed.kind.name,
                etag: Value<String?>(etag),
                lastModified: Value<String?>(lastModified),
                lastRefreshedAt: Value<DateTime>(refreshedAt),
                createdAt: refreshedAt,
                updatedAt: refreshedAt,
              ),
            );
      } else {
        await (database.update(
          database.feedSubscriptions,
        )..where((table) => table.id.equals(feedId))).write(
          FeedSubscriptionsCompanion(
            canonicalUrl: Value<String>(canonicalUrl.toString()),
            title: Value<String>(_limited(feed.title, 1024)),
            feedKind: Value<String>(feed.kind.name),
            etag: Value<String?>(etag),
            lastModified: Value<String?>(lastModified),
            lastRefreshedAt: Value<DateTime>(refreshedAt),
            updatedAt: Value<DateTime>(refreshedAt),
          ),
        );
      }

      for (final article in articles) {
        await _upsertArticle(
          feedId: feedId,
          article: article,
          refreshedAt: refreshedAt,
        );
      }
    });
  }

  Future<void> _upsertArticle({
    required String feedId,
    required feed.FeedArticleDraft article,
    required DateTime refreshedAt,
  }) async {
    final existing =
        await (database.select(database.articles)..where(
              (table) =>
                  table.feedId.equals(feedId) &
                  table.canonicalUrl.equals(article.canonicalUrl.toString()),
            ))
            .getSingleOrNull();
    if (existing == null) {
      await database
          .into(database.articles)
          .insert(
            ArticlesCompanion.insert(
              id: article.id,
              feedId: feedId,
              canonicalUrl: article.canonicalUrl.toString(),
              title: _limited(article.title, 2048),
              author: Value<String?>(article.author),
              publishedAt: Value<DateTime?>(article.publishedAt),
              feedSummary: Value<String?>(article.summary),
              createdAt: refreshedAt,
              updatedAt: refreshedAt,
            ),
          );
      return;
    }
    await (database.update(
      database.articles,
    )..where((table) => table.id.equals(existing.id))).write(
      ArticlesCompanion(
        title: Value<String>(_limited(article.title, 2048)),
        author: Value<String?>(article.author),
        publishedAt: Value<DateTime?>(article.publishedAt),
        feedSummary: Value<String?>(article.summary),
        updatedAt: Value<DateTime>(refreshedAt),
      ),
    );
  }

  @override
  Future<void> markNotModified({
    required String feedId,
    required DateTime refreshedAt,
  }) {
    return (database.update(
      database.feedSubscriptions,
    )..where((table) => table.id.equals(feedId))).write(
      FeedSubscriptionsCompanion(
        lastRefreshedAt: Value<DateTime>(refreshedAt),
        updatedAt: Value<DateTime>(refreshedAt),
      ),
    );
  }

  @override
  Future<void> setEnabled(
    String feedId, {
    required bool enabled,
    required DateTime updatedAt,
  }) {
    return (database.update(
      database.feedSubscriptions,
    )..where((table) => table.id.equals(feedId))).write(
      FeedSubscriptionsCompanion(
        enabled: Value<bool>(enabled),
        updatedAt: Value<DateTime>(updatedAt),
      ),
    );
  }

  @override
  Future<void> delete(String feedId) {
    return (database.delete(
      database.feedSubscriptions,
    )..where((table) => table.id.equals(feedId))).go();
  }
}

feed.FeedSubscriptionRecord _subscription(FeedSubscription row) =>
    feed.FeedSubscriptionRecord(
      id: row.id,
      canonicalUrl: Uri.parse(row.canonicalUrl),
      title: row.title,
      kind: feed.FeedDocumentKind.values.byName(row.feedKind),
      enabled: row.enabled,
      etag: row.etag,
      lastModified: row.lastModified,
      lastRefreshedAt: row.lastRefreshedAt,
    );

feed.FeedArticleRecord _article(Article row) => feed.FeedArticleRecord(
  id: row.id,
  feedId: row.feedId,
  canonicalUrl: Uri.parse(row.canonicalUrl),
  title: row.title,
  author: row.author,
  publishedAt: row.publishedAt,
  summary: row.feedSummary,
  read: row.readState != 'unread',
  starred: row.starred,
);

String _limited(String value, int maxLength) =>
    value.length <= maxLength ? value : value.substring(0, maxLength);
