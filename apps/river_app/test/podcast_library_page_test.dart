import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:river_app/podcast/podcast_library_page.dart';
import 'package:river_audio/river_audio.dart';
import 'package:river_domain/river_domain.dart';
import 'package:river_feed/river_feed.dart';

void main() {
  testWidgets('empty library validates Podcast RSS addresses', (tester) async {
    final catalog = _Catalog();
    final downloads = _Downloads();
    addTearDown(downloads.close);
    final audio = AudioPlaybackController(
      engine: _AudioEngine(),
      repository: const UnavailableAudioPlaybackRepository(),
      clock: const _Clock(),
    );
    addTearDown(audio.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: PodcastLibraryPage(
          repository: catalog,
          refresh: _refresh(catalog),
          policies: PodcastDownloadPolicyService(
            repository: catalog,
            downloads: downloads,
          ),
          downloads: downloads,
          audio: audio,
          clock: const _Clock(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('还没有播客'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '添加播客'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'ftp://example.test/feed');
    await tester.tap(find.widgetWithText(FilledButton, '添加'));
    await tester.pump();

    expect(find.text('请输入有效的 HTTP(S) Podcast RSS 地址'), findsOneWidget);
  });

  testWidgets('episode playback prefers a verified local download', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 7, 27);
    final show = PodcastShowRecord(
      id: 'show-1',
      canonicalFeedUrl: Uri.parse('https://podcast.example.test/feed.xml'),
      title: 'River Show',
      explicitRating: PodcastExplicitRating.clean,
      defaultPlaybackRate: 1.5,
      downloadPolicy: PodcastDownloadPolicy.manual,
      lastRefreshedAt: now,
      createdAt: now,
      updatedAt: now,
    );
    final episode = PodcastEpisodeRecord(
      id: 'episode-1',
      showId: show.id,
      externalId: 'guid-1',
      title: 'Episode 1',
      mediaUrl: Uri.parse('https://media.example.test/episode.mp3'),
      mediaMimeType: 'audio/mpeg',
      mediaLengthBytes: 8,
      duration: const Duration(minutes: 42),
      publishedAt: now,
      explicitRating: PodcastExplicitRating.clean,
      episodeType: PodcastEpisodeType.full,
      createdAt: now,
      updatedAt: now,
    );
    final catalog =
        _Catalog(show: show, episodes: <PodcastEpisodeRecord>[episode]);
    final downloads = _Downloads(
      PodcastDownloadState(
        episodeId: episode.id,
        phase: PodcastDownloadPhase.available,
        sourceUri: episode.mediaUrl,
        availablePath: r'C:\River\episode.mp3',
        downloadedBytes: 8,
        totalBytes: 8,
      ),
    );
    addTearDown(downloads.close);
    final engine = _AudioEngine();
    final audio = AudioPlaybackController(
      engine: engine,
      repository: const UnavailableAudioPlaybackRepository(),
      clock: const _Clock(),
    );
    addTearDown(audio.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: PodcastShowPage(
          initialShow: show,
          repository: catalog,
          refresh: _refresh(catalog),
          policies: PodcastDownloadPolicyService(
            repository: catalog,
            downloads: downloads,
          ),
          downloads: downloads,
          audio: audio,
          clock: const _Clock(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Episode 1'), findsOneWidget);
    expect(find.textContaining('42 分钟'), findsOneWidget);
    await tester.tap(find.byTooltip('播放 Episode 1'));
    await tester.pumpAndSettle();

    expect(engine.loaded?.item.sourceUri, Uri.file(r'C:\River\episode.mp3'));
    expect(engine.settings?.rate, 1.5);
    expect(find.byTooltip('暂停'), findsOneWidget);

    await tester.tap(find.byTooltip('已下载；点击删除本地文件'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();
    expect(downloads.removed, <String>['episode-1']);
  });
}

PodcastRefreshService _refresh(PodcastRepository repository) =>
    PodcastRefreshService(
      http: const _Http(),
      repository: repository,
      clock: const _Clock(),
      ids: _Ids(),
    );

final class _Catalog implements PodcastCatalogRepository {
  _Catalog({this.show, this.episodes = const <PodcastEpisodeRecord>[]});

  PodcastShowRecord? show;
  final List<PodcastEpisodeRecord> episodes;

  @override
  Future<void> applyRefresh({
    required PodcastShowRecord show,
    required List<PodcastEpisodeRecord> episodeUpserts,
  }) async {
    this.show = show;
  }

  @override
  Future<void> deleteShow(String showId) async {
    show = null;
  }

  @override
  Future<PodcastEpisodeRecord?> findEpisodeById(String episodeId) async {
    for (final episode in episodes) {
      if (episode.id == episodeId) return episode;
    }
    return null;
  }

  @override
  Future<PodcastShowRecord?> findShowByCanonicalUrl(
    Uri canonicalFeedUrl,
  ) async =>
      show;

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
  }) async {}

  @override
  Stream<List<PodcastEpisodeRecord>> watchEpisodes(String showId) =>
      Stream<List<PodcastEpisodeRecord>>.value(episodes);

  @override
  Stream<List<PodcastShowRecord>> watchShows() =>
      Stream<List<PodcastShowRecord>>.value(
        show == null ? const <PodcastShowRecord>[] : <PodcastShowRecord>[show!],
      );
}

final class _Downloads implements PodcastDownloadManager {
  _Downloads([PodcastDownloadState? initial])
      : _state =
            initial ?? const PodcastDownloadState.notDownloaded('episode-1');

  PodcastDownloadState _state;
  final StreamController<PodcastDownloadState> _changes =
      StreamController<PodcastDownloadState>.broadcast();
  final List<String> removed = <String>[];

  Future<void> close() => _changes.close();

  @override
  Future<void> enqueue(String episodeId) async {}

  @override
  Future<void> remove(String episodeId) async {
    removed.add(episodeId);
    _state = PodcastDownloadState.notDownloaded(episodeId);
    _changes.add(_state);
  }

  @override
  Future<void> resumePending() async {}

  @override
  Future<void> retry(String episodeId) async {}

  @override
  Future<PodcastDownloadState> status(String episodeId) async => _state;

  @override
  Stream<PodcastDownloadState> watch(String episodeId) async* {
    yield _state;
    yield* _changes.stream;
  }
}

final class _AudioEngine implements AudioEngine {
  final StreamController<AudioEngineEvent> _events =
      StreamController<AudioEngineEvent>.broadcast();
  AudioLoadRequest? loaded;
  AudioPlaybackSettings? settings;

  @override
  Stream<AudioEngineEvent> get events => _events.stream;

  @override
  Future<AudioEngineCapabilities> capabilities() async =>
      const AudioEngineCapabilities(
        supportsArticleTts: false,
        supportsPodcastMedia: true,
        canPause: true,
        canResume: true,
        canSeek: true,
        canSetRate: true,
        canSetPitch: false,
        canSelectVoice: false,
      );

  @override
  Future<void> dispose() => _events.close();

  @override
  Future<void> load(AudioLoadRequest request) async {
    loaded = request;
  }

  @override
  Future<void> pause() async {
    _events.add(
      AudioEngineEvent(
        phase: AudioEnginePhase.paused,
        itemId: loaded?.item.id,
        position: AudioPlaybackPosition.media(Duration.zero),
      ),
    );
  }

  @override
  Future<void> play() async {
    _events.add(
      AudioEngineEvent(
        phase: AudioEnginePhase.playing,
        itemId: loaded?.item.id,
        position: AudioPlaybackPosition.media(Duration.zero),
      ),
    );
  }

  @override
  Future<void> resume() => play();

  @override
  Future<void> seek(AudioPlaybackPosition position) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> updateSettings(AudioPlaybackSettings settings) async {
    this.settings = settings;
  }

  @override
  Future<List<AudioVoice>> voices() async => const <AudioVoice>[];
}

final class _Clock implements Clock {
  const _Clock();

  @override
  DateTime now() => DateTime.utc(2026, 7, 27);
}

final class _Ids implements IdGenerator {
  var value = 0;

  @override
  String next() => 'id-${++value}';
}

final class _Http implements HttpPort {
  const _Http();

  @override
  Future<PortHttpResponse> get(
    Uri uri, {
    Map<String, String> headers = const <String, String>{},
  }) async =>
      throw StateError('HTTP is not expected in this widget test');
}
