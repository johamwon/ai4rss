import 'dart:async';

import 'package:river_audio/river_audio.dart';
import 'package:river_domain/river_domain.dart';
import 'package:test/test.dart';

final class _Engine implements AudioEngine {
  _Engine({
    required this.article,
    required this.podcast,
    this.voice = false,
  });

  final bool article;
  final bool podcast;
  final bool voice;
  final StreamController<AudioEngineEvent> controller =
      StreamController<AudioEngineEvent>.broadcast(sync: true);
  final List<AudioLoadRequest> loads = <AudioLoadRequest>[];
  var stops = 0;
  var disposed = false;

  @override
  Stream<AudioEngineEvent> get events => controller.stream;

  @override
  Future<AudioEngineCapabilities> capabilities() async =>
      AudioEngineCapabilities(
        supportsArticleTts: article,
        supportsPodcastMedia: podcast,
        canPause: true,
        canResume: true,
        canSeek: true,
        canSetRate: true,
        canSetPitch: article,
        canSelectVoice: voice,
      );

  @override
  Future<List<AudioVoice>> voices() async => voice
      ? const <AudioVoice>[
          AudioVoice(
            id: 'voice',
            name: 'Voice',
            languageTag: 'en-US',
            isLocal: true,
          ),
        ]
      : const <AudioVoice>[];

  @override
  Future<void> load(AudioLoadRequest request) async => loads.add(request);

  @override
  Future<void> stop() async => stops += 1;

  @override
  Future<void> dispose() async {
    disposed = true;
    await controller.close();
  }

  @override
  Future<void> pause() async {}

  @override
  Future<void> play() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<void> seek(AudioPlaybackPosition position) async {}

  @override
  Future<void> updateSettings(AudioPlaybackSettings settings) async {}
}

void main() {
  test('routes article and podcast loads without losing combined capability',
      () async {
    final article = _Engine(article: true, podcast: false, voice: true);
    final podcast = _Engine(article: false, podcast: true);
    final engine = RoutedAudioEngine(
      articleEngine: article,
      podcastEngine: podcast,
    );

    final capabilities = await engine.capabilities();
    expect(capabilities.supportsArticleTts, isTrue);
    expect(capabilities.supportsPodcastMedia, isTrue);
    expect(capabilities.canSetPitch, isTrue);
    expect(await engine.voices(), hasLength(1));

    await engine.load(_articleRequest());
    await engine.load(_podcastRequest());

    expect(article.loads, hasLength(1));
    expect(article.stops, 1);
    expect(podcast.loads, hasLength(1));
    await engine.dispose();
    expect(article.disposed, isTrue);
    expect(podcast.disposed, isTrue);
  });

  test('forwards backend events through the shared stream', () async {
    final article = _Engine(article: true, podcast: false);
    final podcast = _Engine(article: false, podcast: true);
    final engine = RoutedAudioEngine(
      articleEngine: article,
      podcastEngine: podcast,
    );
    final events = <AudioEngineEvent>[];
    final subscription = engine.events.listen(events.add);

    podcast.controller.add(
      AudioEngineEvent(
        phase: AudioEnginePhase.playing,
        itemId: 'podcast',
        position: AudioPlaybackPosition.media(const Duration(seconds: 3)),
      ),
    );

    expect(events.single.itemId, 'podcast');
    await subscription.cancel();
    await engine.dispose();
  });
}

AudioLoadRequest _articleRequest() => AudioLoadRequest(
      item: AudioItem(
        id: 'article',
        kind: AudioKind.articleTts,
        title: 'Article',
        sourceUri: Uri.parse('https://example.test/article'),
      ),
      speechSegments: const <SpeechSegment>[
        SpeechSegment(
          index: 0,
          text: 'Sentence.',
          sourceStart: 0,
          sourceEnd: 9,
        ),
      ],
      contentRevision: 'revision',
    );

AudioLoadRequest _podcastRequest() => AudioLoadRequest(
      item: AudioItem(
        id: 'podcast',
        kind: AudioKind.podcastEpisode,
        title: 'Podcast',
        sourceUri: Uri.parse('https://example.test/episode.mp3'),
      ),
    );
