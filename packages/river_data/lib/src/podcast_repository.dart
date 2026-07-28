import 'package:drift/drift.dart';
import 'package:river_feed/river_feed.dart' as feed;

import 'database.dart';

final class DriftPodcastRepository implements feed.PodcastCatalogRepository {
  const DriftPodcastRepository(this.database);

  final RiverDatabase database;

  @override
  Stream<List<feed.PodcastShowRecord>> watchShows() {
    final query = database.select(database.podcastShows)
      ..orderBy(<OrderingTerm Function($PodcastShowsTable)>[
        (table) => OrderingTerm.desc(table.lastRefreshedAt),
        (table) => OrderingTerm.asc(table.title),
      ]);
    return query.watch().map((rows) => rows.map(_show).toList(growable: false));
  }

  @override
  Stream<List<feed.PodcastEpisodeRecord>> watchEpisodes(String showId) {
    final query = database.select(database.podcastEpisodes)
      ..where((table) => table.showId.equals(showId))
      ..orderBy(<OrderingTerm Function($PodcastEpisodesTable)>[
        (table) => OrderingTerm.desc(table.publishedAt),
        (table) => OrderingTerm.desc(table.updatedAt),
        (table) => OrderingTerm.asc(table.id),
      ]);
    return query.watch().map(
      (rows) => rows.map(_episode).toList(growable: false),
    );
  }

  @override
  Future<feed.PodcastShowRecord?> findShowByCanonicalUrl(
    Uri canonicalFeedUrl,
  ) async {
    final row =
        await (database.select(database.podcastShows)..where(
              (table) =>
                  table.canonicalFeedUrl.equals(canonicalFeedUrl.toString()),
            ))
            .getSingleOrNull();
    return row == null ? null : _show(row);
  }

  @override
  Future<feed.PodcastShowRecord?> findShowById(String showId) async {
    final row = await (database.select(
      database.podcastShows,
    )..where((table) => table.id.equals(showId))).getSingleOrNull();
    return row == null ? null : _show(row);
  }

  @override
  Future<List<feed.PodcastEpisodeRecord>> listEpisodes(String showId) async {
    final query = database.select(database.podcastEpisodes)
      ..where((table) => table.showId.equals(showId))
      ..orderBy(<OrderingTerm Function($PodcastEpisodesTable)>[
        (table) => OrderingTerm.desc(table.publishedAt),
        (table) => OrderingTerm.asc(table.id),
      ]);
    final rows = await query.get();
    return rows.map(_episode).toList(growable: false);
  }

  @override
  Future<feed.PodcastEpisodeRecord?> findEpisodeById(String episodeId) async {
    final row = await (database.select(
      database.podcastEpisodes,
    )..where((table) => table.id.equals(episodeId))).getSingleOrNull();
    return row == null ? null : _episode(row);
  }

  @override
  Future<void> deleteShow(String showId) async {
    await (database.delete(
      database.podcastShows,
    )..where((table) => table.id.equals(showId))).go();
  }

  @override
  Future<void> applyRefresh({
    required feed.PodcastShowRecord show,
    required List<feed.PodcastEpisodeRecord> episodeUpserts,
  }) {
    return database.transaction(() async {
      await database
          .into(database.podcastShows)
          .insertOnConflictUpdate(
            PodcastShowsCompanion.insert(
              id: show.id,
              canonicalFeedUrl: show.canonicalFeedUrl.toString(),
              title: _limited(show.title, 2048),
              description: Value<String?>(show.description),
              author: Value<String?>(show.author),
              websiteUrl: Value<String?>(show.websiteUrl?.toString()),
              imageUrl: Value<String?>(show.imageUrl?.toString()),
              language: Value<String?>(show.language),
              explicitRating: show.explicitRating.name,
              defaultPlaybackRate: Value<double>(show.defaultPlaybackRate),
              downloadPolicy: Value<String>(show.downloadPolicy.name),
              etag: Value<String?>(show.etag),
              lastModified: Value<String?>(show.lastModified),
              lastRefreshedAt: show.lastRefreshedAt,
              createdAt: show.createdAt,
              updatedAt: show.updatedAt,
            ),
          );
      for (final episode in episodeUpserts) {
        if (episode.showId != show.id) {
          throw ArgumentError.value(
            episode.showId,
            'episodeUpserts',
            'Episode belongs to another podcast show.',
          );
        }
        await database
            .into(database.podcastEpisodes)
            .insertOnConflictUpdate(
              PodcastEpisodesCompanion.insert(
                id: episode.id,
                showId: episode.showId,
                externalId: episode.externalId,
                title: _limited(episode.title, 2048),
                description: Value<String?>(episode.description),
                author: Value<String?>(episode.author),
                episodeUrl: Value<String?>(episode.episodeUrl?.toString()),
                mediaUrl: episode.mediaUrl.toString(),
                imageUrl: Value<String?>(episode.imageUrl?.toString()),
                mediaMimeType: Value<String?>(episode.mediaMimeType),
                mediaLengthBytes: Value<int?>(episode.mediaLengthBytes),
                publishedAt: Value<DateTime?>(episode.publishedAt),
                durationMs: Value<int?>(episode.duration?.inMilliseconds),
                episodeNumber: Value<int?>(episode.episodeNumber),
                seasonNumber: Value<int?>(episode.seasonNumber),
                explicitRating: episode.explicitRating.name,
                episodeType: episode.episodeType.name,
                createdAt: episode.createdAt,
                updatedAt: episode.updatedAt,
              ),
            );
      }
    });
  }

  @override
  Future<void> markNotModified({
    required String showId,
    required DateTime refreshedAt,
  }) async {
    final changed =
        await (database.update(
          database.podcastShows,
        )..where((table) => table.id.equals(showId))).write(
          PodcastShowsCompanion(
            lastRefreshedAt: Value<DateTime>(refreshedAt),
            updatedAt: Value<DateTime>(refreshedAt),
          ),
        );
    if (changed == 0) {
      throw const feed.PodcastRefreshException('Podcast show is missing');
    }
  }

  @override
  Future<void> updateShowPolicy({
    required String showId,
    required double defaultPlaybackRate,
    required feed.PodcastDownloadPolicy downloadPolicy,
    required DateTime updatedAt,
  }) async {
    if (defaultPlaybackRate < 0.5 || defaultPlaybackRate > 3) {
      throw ArgumentError.value(
        defaultPlaybackRate,
        'defaultPlaybackRate',
        'Playback rate must be between 0.5 and 3.',
      );
    }
    final changed =
        await (database.update(
          database.podcastShows,
        )..where((table) => table.id.equals(showId))).write(
          PodcastShowsCompanion(
            defaultPlaybackRate: Value<double>(defaultPlaybackRate),
            downloadPolicy: Value<String>(downloadPolicy.name),
            updatedAt: Value<DateTime>(updatedAt),
          ),
        );
    if (changed == 0) {
      throw const feed.PodcastRefreshException('Podcast show is missing');
    }
  }
}

feed.PodcastShowRecord _show(PodcastShow row) => feed.PodcastShowRecord(
  id: row.id,
  canonicalFeedUrl: Uri.parse(row.canonicalFeedUrl),
  title: row.title,
  description: row.description,
  author: row.author,
  websiteUrl: _uri(row.websiteUrl),
  imageUrl: _uri(row.imageUrl),
  language: row.language,
  explicitRating: feed.PodcastExplicitRating.values.byName(row.explicitRating),
  defaultPlaybackRate: row.defaultPlaybackRate,
  downloadPolicy: feed.PodcastDownloadPolicy.values.byName(row.downloadPolicy),
  etag: row.etag,
  lastModified: row.lastModified,
  lastRefreshedAt: row.lastRefreshedAt.toUtc(),
  createdAt: row.createdAt.toUtc(),
  updatedAt: row.updatedAt.toUtc(),
);

feed.PodcastEpisodeRecord _episode(PodcastEpisode row) =>
    feed.PodcastEpisodeRecord(
      id: row.id,
      showId: row.showId,
      externalId: row.externalId,
      title: row.title,
      description: row.description,
      author: row.author,
      episodeUrl: _uri(row.episodeUrl),
      mediaUrl: Uri.parse(row.mediaUrl),
      imageUrl: _uri(row.imageUrl),
      mediaMimeType: row.mediaMimeType,
      mediaLengthBytes: row.mediaLengthBytes,
      publishedAt: row.publishedAt?.toUtc(),
      duration: row.durationMs == null
          ? null
          : Duration(milliseconds: row.durationMs!),
      episodeNumber: row.episodeNumber,
      seasonNumber: row.seasonNumber,
      explicitRating: feed.PodcastExplicitRating.values.byName(
        row.explicitRating,
      ),
      episodeType: feed.PodcastEpisodeType.values.byName(row.episodeType),
      createdAt: row.createdAt.toUtc(),
      updatedAt: row.updatedAt.toUtc(),
    );

Uri? _uri(String? value) => value == null ? null : Uri.tryParse(value);

String _limited(String value, int maximum) =>
    value.length <= maximum ? value : value.substring(0, maximum);
