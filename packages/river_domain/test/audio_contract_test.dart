import 'dart:async';

import 'package:river_domain/river_domain.dart';
import 'package:test/test.dart';

void main() {
  test('audio engine contract carries a bounded article speech plan', () async {
    final engine = _RecordingAudioEngine();
    addTearDown(engine.close);
    final item = AudioItem(
      id: 'article-audio-1',
      kind: AudioKind.articleTts,
      title: 'Article',
      sourceUri: Uri.parse('river://article/1'),
    );
    final request = AudioLoadRequest(
      item: item,
      contentRevision: 'sha256:one',
      speechSegments: const <SpeechSegment>[
        SpeechSegment(
          index: 0,
          text: 'First sentence.',
          sourceStart: 0,
          sourceEnd: 15,
          languageTag: 'en-US',
        ),
      ],
    );
    final firstEvent = engine.events.first;

    await engine.load(request);
    await engine.updateSettings(
      const AudioPlaybackSettings(
        rate: 1.25,
        pitch: 0.9,
        voiceId: 'voice-1',
        languageTag: 'en-US',
      ),
    );
    await engine.play();
    await engine.seek(
      const AudioPlaybackPosition.speech(
        segmentIndex: 0,
        characterOffset: 4,
      ),
    );

    expect(engine.loaded, same(request));
    expect(engine.settings.rate, 1.25);
    expect(engine.position.segmentIndex, 0);
    expect(engine.position.characterOffset, 4);
    expect(await firstEvent, isA<AudioEngineEvent>());
  });

  test('load requests enforce source-specific payloads and stable indexes', () {
    final article = AudioItem(
      id: 'article',
      kind: AudioKind.articleTts,
      title: 'Article',
      sourceUri: Uri.parse('river://article/1'),
    );
    final podcast = AudioItem(
      id: 'podcast',
      kind: AudioKind.podcastEpisode,
      title: 'Podcast',
      sourceUri: Uri.parse('https://example.test/episode.mp3'),
    );
    const segment = SpeechSegment(
      index: 0,
      text: 'Sentence.',
      sourceStart: 0,
      sourceEnd: 9,
    );

    expect(
      () => AudioLoadRequest(item: article),
      throwsA(isA<AssertionError>()),
    );
    expect(
      () => AudioLoadRequest(
        item: article,
        speechSegments: const [segment],
      ),
      throwsA(isA<AssertionError>()),
    );
    expect(
      () => AudioLoadRequest(item: podcast, speechSegments: const [segment]),
      throwsA(isA<AssertionError>()),
    );
    expect(
      () => AudioLoadRequest(
        item: article,
        contentRevision: 'sha256:one',
        speechSegments: const [
          SpeechSegment(
            index: 1,
            text: 'Wrong index.',
            sourceStart: 0,
            sourceEnd: 12,
          ),
        ],
      ),
      throwsA(isA<AssertionError>()),
    );
  });

  test('playback settings and positions reject unsafe values', () {
    expect(
      () => AudioPlaybackSettings(rate: 0.49),
      throwsA(isA<AssertionError>()),
    );
    expect(
      () => AudioPlaybackSettings(pitch: 2.01),
      throwsA(isA<AssertionError>()),
    );
    expect(
      () => AudioPlaybackPosition.media(const Duration(seconds: -1)),
      throwsA(isA<AssertionError>()),
    );
    expect(
      () => AudioPlaybackPosition.speech(segmentIndex: -1),
      throwsA(isA<AssertionError>()),
    );
  });

  test('playback snapshots keep source-specific restart state', () {
    final item = AudioItem(
      id: 'article-1',
      kind: AudioKind.articleTts,
      title: 'Article',
      sourceUri: Uri.parse('river://article/1'),
    );
    final snapshot = AudioPlaybackSnapshot(
      item: item,
      position: const AudioPlaybackPosition.speech(
        segmentIndex: 4,
        characterOffset: 12,
      ),
      settings: const AudioPlaybackSettings(
        rate: 1.5,
        pitch: 0.9,
        voiceId: 'voice-1',
        languageTag: 'zh-CN',
      ),
      contentRevision: 'sha256:article-1',
      updatedAt: DateTime.utc(2026, 7, 26),
    );

    expect(snapshot.position.segmentIndex, 4);
    expect(snapshot.settings.rate, 1.5);
    expect(snapshot.contentRevision, 'sha256:article-1');
  });

  test('system playback events bound automatic resume authorization', () {
    expect(
      () => AudioSystemEvent(
        type: AudioSystemEventType.pause,
        mayResume: true,
      ),
      throwsA(isA<AssertionError>()),
    );

    const ended = AudioSystemEvent(
      type: AudioSystemEventType.interruptionEnded,
      mayResume: true,
    );
    expect(ended.mayResume, isTrue);
  });
}

final class _RecordingAudioEngine implements AudioEngine {
  final StreamController<AudioEngineEvent> _events =
      StreamController<AudioEngineEvent>.broadcast();
  AudioLoadRequest? loaded;
  AudioPlaybackSettings settings = const AudioPlaybackSettings();
  AudioPlaybackPosition position = AudioPlaybackPosition.media(Duration.zero);

  @override
  Stream<AudioEngineEvent> get events => _events.stream;

  @override
  Future<AudioEngineCapabilities> capabilities() async =>
      const AudioEngineCapabilities(
        supportsArticleTts: true,
        supportsPodcastMedia: false,
        canPause: true,
        canResume: true,
        canSeek: true,
        canSetRate: true,
        canSetPitch: true,
        canSelectVoice: true,
      );

  @override
  Future<void> load(AudioLoadRequest request) async {
    loaded = request;
    _events.add(
      AudioEngineEvent(
        phase: AudioEnginePhase.ready,
        itemId: request.item.id,
      ),
    );
  }

  @override
  Future<void> pause() async {}

  @override
  Future<void> play() async {
    _events.add(
      AudioEngineEvent(
        phase: AudioEnginePhase.playing,
        itemId: loaded?.item.id,
      ),
    );
  }

  @override
  Future<void> resume() async {}

  @override
  Future<void> seek(AudioPlaybackPosition position) async {
    this.position = position;
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> updateSettings(AudioPlaybackSettings settings) async {
    this.settings = settings;
  }

  @override
  Future<void> dispose() => close();

  @override
  Future<List<AudioVoice>> voices() async => const <AudioVoice>[
        AudioVoice(
          id: 'voice-1',
          name: 'Local English',
          languageTag: 'en-US',
          isLocal: true,
        ),
      ];

  Future<void> close() => _events.close();
}
