import 'package:river_domain/river_domain.dart';
import 'package:river_feed/river_feed.dart';
import 'package:test/test.dart';

void main() {
  test('newest-only refresh queues only the current newest episode', () async {
    final repository = _Catalog(
      show: _show(PodcastDownloadPolicy.newestOnly),
      episodes: <PodcastEpisodeRecord>[
        _episode('episode-new', DateTime.utc(2026, 7, 27)),
        _episode('episode-old', DateTime.utc(2026, 7, 26)),
      ],
    );
    final downloads = _Downloads();
    final service = PodcastDownloadPolicyService(
      repository: repository,
      downloads: downloads,
    );

    await service.applyAfterRefresh(_refresh(<String>['episode-new']));

    expect(downloads.enqueued, <String>['episode-new']);
  });

  test('all policy queues only newly inserted episodes after refresh',
      () async {
    final repository = _Catalog(
      show: _show(PodcastDownloadPolicy.all),
      episodes: <PodcastEpisodeRecord>[
        _episode('episode-new', DateTime.utc(2026, 7, 27)),
        _episode('episode-old', DateTime.utc(2026, 7, 26)),
      ],
    );
    final downloads = _Downloads();
    final service = PodcastDownloadPolicyService(
      repository: repository,
      downloads: downloads,
    );

    await service.applyAfterRefresh(_refresh(<String>['episode-new']));

    expect(downloads.enqueued, <String>['episode-new']);
  });

  test('changing to all persists settings and queues existing episodes',
      () async {
    final repository = _Catalog(
      show: _show(PodcastDownloadPolicy.manual),
      episodes: <PodcastEpisodeRecord>[
        _episode('episode-new', DateTime.utc(2026, 7, 27)),
        _episode('episode-old', DateTime.utc(2026, 7, 26)),
      ],
    );
    final downloads = _Downloads();
    final service = PodcastDownloadPolicyService(
      repository: repository,
      downloads: downloads,
    );
    final updatedAt = DateTime.utc(2026, 7, 27);

    await service.updatePolicy(
      showId: 'show-1',
      defaultPlaybackRate: 1.5,
      downloadPolicy: PodcastDownloadPolicy.all,
      updatedAt: updatedAt,
    );

    expect(repository.updatedRate, 1.5);
    expect(repository.updatedPolicy, PodcastDownloadPolicy.all);
    expect(repository.updatedAt, updatedAt);
    expect(downloads.enqueued, <String>['episode-new', 'episode-old']);
  });
}

PodcastRefreshResult _refresh(List<String> insertedIds) => PodcastRefreshResult(
      showId: 'show-1',
      insertedEpisodeIds: insertedIds,
      insertedEpisodes: insertedIds.length,
      updatedEpisodes: 0,
      unchangedEpisodes: 0,
      discardedDuplicates: 0,
      notModified: false,
    );

PodcastShowRecord _show(PodcastDownloadPolicy policy) {
  final now = DateTime.utc(2026, 7, 26);
  return PodcastShowRecord(
    id: 'show-1',
    canonicalFeedUrl: Uri.parse('https://podcast.example.test/feed.xml'),
    title: 'River Show',
    explicitRating: PodcastExplicitRating.clean,
    defaultPlaybackRate: 1,
    downloadPolicy: policy,
    lastRefreshedAt: now,
    createdAt: now,
    updatedAt: now,
  );
}

PodcastEpisodeRecord _episode(String id, DateTime publishedAt) =>
    PodcastEpisodeRecord(
      id: id,
      showId: 'show-1',
      externalId: 'guid-$id',
      title: id,
      mediaUrl: Uri.parse('https://media.example.test/$id.mp3'),
      publishedAt: publishedAt,
      explicitRating: PodcastExplicitRating.clean,
      episodeType: PodcastEpisodeType.full,
      createdAt: publishedAt,
      updatedAt: publishedAt,
    );

final class _Catalog implements PodcastCatalogRepository {
  _Catalog({required this.show, required this.episodes});

  PodcastShowRecord show;
  final List<PodcastEpisodeRecord> episodes;
  double? updatedRate;
  PodcastDownloadPolicy? updatedPolicy;
  DateTime? updatedAt;

  @override
  Future<void> applyRefresh({
    required PodcastShowRecord show,
    required List<PodcastEpisodeRecord> episodeUpserts,
  }) async {}

  @override
  Future<void> deleteShow(String showId) async {}

  @override
  Future<PodcastShowRecord?> findShowByCanonicalUrl(
    Uri canonicalFeedUrl,
  ) async =>
      show;

  @override
  Future<PodcastEpisodeRecord?> findEpisodeById(String episodeId) async =>
      episodes.where((episode) => episode.id == episodeId).firstOrNull;

  @override
  Future<PodcastShowRecord?> findShowById(String showId) async => show;

  @override
  Future<List<PodcastEpisodeRecord>> listEpisodes(String showId) async =>
      episodes;

  @override
  Future<void> markNotModified({
    required String showId,
    required DateTime refreshedAt,
  }) async {}

  @override
  Future<void> updateShowPolicy({
    required String showId,
    required double defaultPlaybackRate,
    required PodcastDownloadPolicy downloadPolicy,
    required DateTime updatedAt,
  }) async {
    updatedRate = defaultPlaybackRate;
    updatedPolicy = downloadPolicy;
    this.updatedAt = updatedAt;
  }

  @override
  Stream<List<PodcastEpisodeRecord>> watchEpisodes(String showId) =>
      Stream<List<PodcastEpisodeRecord>>.value(episodes);

  @override
  Stream<List<PodcastShowRecord>> watchShows() =>
      Stream<List<PodcastShowRecord>>.value(<PodcastShowRecord>[show]);
}

final class _Downloads implements PodcastDownloadManager {
  final List<String> enqueued = <String>[];

  @override
  Future<void> enqueue(String episodeId) async => enqueued.add(episodeId);

  @override
  Future<void> remove(String episodeId) async {}

  @override
  Future<void> resumePending() async {}

  @override
  Future<void> retry(String episodeId) async => enqueued.add(episodeId);

  @override
  Future<PodcastDownloadState> status(String episodeId) async =>
      PodcastDownloadState.notDownloaded(episodeId);

  @override
  Stream<PodcastDownloadState> watch(String episodeId) =>
      Stream<PodcastDownloadState>.value(
        PodcastDownloadState.notDownloaded(episodeId),
      );
}
