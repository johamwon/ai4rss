import 'package:river_data/river_data.dart';
import 'package:river_feed/river_feed.dart';
import 'package:test/test.dart';

void main() {
  test('persists refreshes while preserving user show policy', () async {
    final database = RiverDatabase.inMemory();
    addTearDown(database.close);
    final repository = DriftPodcastRepository(database);
    final firstAt = DateTime.utc(2026, 7, 26);
    final watchedShows = repository.watchShows().firstWhere(
      (shows) => shows.isNotEmpty,
    );
    final watchedEpisodes = repository
        .watchEpisodes('show-1')
        .firstWhere((episodes) => episodes.isNotEmpty);
    await repository.applyRefresh(
      show: _show(updatedAt: firstAt),
      episodeUpserts: <PodcastEpisodeRecord>[
        _episode(
          mediaUrl: Uri.parse('https://media.example.test/original.mp3'),
          chapterSource: _chapters,
          transcripts: _transcripts,
          updatedAt: firstAt,
        ),
      ],
    );
    expect((await watchedShows).single.title, 'River Show');
    expect((await watchedEpisodes).single.id, 'episode-1');
    await repository.updateShowPolicy(
      showId: 'show-1',
      defaultPlaybackRate: 1.75,
      downloadPolicy: PodcastDownloadPolicy.newestOnly,
      updatedAt: firstAt.add(const Duration(minutes: 1)),
    );

    final preserved = await repository.findShowById('show-1');
    final secondAt = firstAt.add(const Duration(days: 1));
    await repository.applyRefresh(
      show: _show(
        title: 'Updated show',
        playbackRate: preserved!.defaultPlaybackRate,
        downloadPolicy: preserved.downloadPolicy,
        updatedAt: secondAt,
      ),
      episodeUpserts: <PodcastEpisodeRecord>[
        _episode(
          mediaUrl: Uri.parse('https://media.example.test/rehosted.m4a'),
          chapterSource: _chapters,
          transcripts: _transcripts,
          updatedAt: secondAt,
        ),
      ],
    );

    final show = await repository.findShowByCanonicalUrl(
      Uri.parse('https://podcast.example.test/feed.xml'),
    );
    final episodes = await repository.listEpisodes('show-1');
    expect(show?.title, 'Updated show');
    expect(show?.defaultPlaybackRate, 1.75);
    expect(show?.downloadPolicy, PodcastDownloadPolicy.newestOnly);
    expect(episodes, hasLength(1));
    expect(episodes.single.id, 'episode-1');
    expect(
      episodes.single.mediaUrl,
      Uri.parse('https://media.example.test/rehosted.m4a'),
    );
    expect(episodes.single.chapterSource, _chapters);
    expect(episodes.single.transcripts, _transcripts);
  });

  test(
    'rejects a cross-show episode without partially inserting the show',
    () async {
      final database = RiverDatabase.inMemory();
      addTearDown(database.close);
      final repository = DriftPodcastRepository(database);

      await expectLater(
        repository.applyRefresh(
          show: _show(updatedAt: DateTime.utc(2026, 7, 26)),
          episodeUpserts: <PodcastEpisodeRecord>[
            _episode(
              showId: 'other-show',
              mediaUrl: Uri.parse('https://media.example.test/episode.mp3'),
              updatedAt: DateTime.utc(2026, 7, 26),
            ),
          ],
        ),
        throwsArgumentError,
      );

      expect(await repository.findShowById('show-1'), isNull);
    },
  );

  test('deleting a show cascades its episodes', () async {
    final database = RiverDatabase.inMemory();
    addTearDown(database.close);
    final repository = DriftPodcastRepository(database);
    final now = DateTime.utc(2026, 7, 26);
    await repository.applyRefresh(
      show: _show(updatedAt: now),
      episodeUpserts: <PodcastEpisodeRecord>[
        _episode(
          mediaUrl: Uri.parse('https://media.example.test/episode.mp3'),
          updatedAt: now,
        ),
      ],
    );

    await repository.deleteShow('show-1');

    expect(await repository.findShowById('show-1'), isNull);
    expect(await repository.listEpisodes('show-1'), isEmpty);
  });
}

PodcastShowRecord _show({
  String title = 'River Show',
  double playbackRate = 1,
  PodcastDownloadPolicy downloadPolicy = PodcastDownloadPolicy.manual,
  required DateTime updatedAt,
}) => PodcastShowRecord(
  id: 'show-1',
  canonicalFeedUrl: Uri.parse('https://podcast.example.test/feed.xml'),
  title: title,
  explicitRating: PodcastExplicitRating.clean,
  defaultPlaybackRate: playbackRate,
  downloadPolicy: downloadPolicy,
  lastRefreshedAt: updatedAt,
  createdAt: DateTime.utc(2026, 7, 26),
  updatedAt: updatedAt,
);

PodcastEpisodeRecord _episode({
  String showId = 'show-1',
  required Uri mediaUrl,
  PodcastChapterSource? chapterSource,
  List<PodcastTranscriptReference> transcripts =
      const <PodcastTranscriptReference>[],
  required DateTime updatedAt,
}) => PodcastEpisodeRecord(
  id: 'episode-1',
  showId: showId,
  externalId: 'guid-1',
  title: 'Episode',
  mediaUrl: mediaUrl,
  chapterSource: chapterSource,
  transcripts: transcripts,
  explicitRating: PodcastExplicitRating.clean,
  episodeType: PodcastEpisodeType.full,
  createdAt: DateTime.utc(2026, 7, 26),
  updatedAt: updatedAt,
);

final _chapters = PodcastChapterSource(
  url: Uri.parse('https://media.example.test/chapters.json'),
  mimeType: 'application/json+chapters',
);

final _transcripts = <PodcastTranscriptReference>[
  PodcastTranscriptReference(
    url: Uri.parse('https://media.example.test/transcript.vtt'),
    mimeType: 'text/vtt',
    language: 'en',
    rel: 'captions',
  ),
];
