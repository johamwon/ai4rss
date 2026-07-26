import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:river_domain/river_domain.dart';
import 'package:river_platform/river_platform.dart';

void main() {
  test('loads and speaks one source-mapped article segment', () async {
    final client = _FakeSystemTtsClient();
    final engine = SystemTtsAudioEngine(
      client: client,
      platform: TargetPlatform.windows,
    );
    final events = <AudioEngineEvent>[];
    final subscription = engine.events.listen(events.add);
    addTearDown(() async {
      await subscription.cancel();
      await engine.dispose();
    });

    await engine.load(_articleRequest());
    await engine.play();
    client
      ..started()
      ..progress(3, 7)
      ..completed();

    expect(client.stopCalls, 1);
    expect(client.spoken, <String>['First sentence.']);
    expect(client.languages, <String>['en-US']);
    expect(
      events.map((event) => event.phase),
      <AudioEnginePhase>[
        AudioEnginePhase.loading,
        AudioEnginePhase.ready,
        AudioEnginePhase.playing,
        AudioEnginePhase.playing,
        AudioEnginePhase.completed,
      ],
    );
    expect(events[3].position?.characterOffset, 3);
    expect(events.last.position?.characterOffset, 15);
  });

  test('seeks and resumes from an absolute sentence offset', () async {
    final client = _FakeSystemTtsClient();
    final engine = SystemTtsAudioEngine(
      client: client,
      platform: TargetPlatform.android,
    );
    final events = <AudioEngineEvent>[];
    final subscription = engine.events.listen(events.add);
    addTearDown(() async {
      await subscription.cancel();
      await engine.dispose();
    });
    await engine.load(_articleRequest());

    await engine.seek(
      const AudioPlaybackPosition.speech(
        segmentIndex: 1,
        characterOffset: 4,
      ),
    );
    await engine.resume();
    client.progress(2, 5);

    expect(client.spoken.last, 'nd sentence.');
    expect(client.languages.last, 'en-US');
    expect(events.last.position?.segmentIndex, 1);
    expect(events.last.position?.characterOffset, 6);
  });

  test('Android resume restarts truncated text with a rebased offset',
      () async {
    final client = _FakeSystemTtsClient();
    final engine = SystemTtsAudioEngine(
      client: client,
      platform: TargetPlatform.android,
    );
    final events = <AudioEngineEvent>[];
    final subscription = engine.events.listen(events.add);
    addTearDown(() async {
      await subscription.cancel();
      await engine.dispose();
    });
    await engine.load(_articleRequest());
    await engine.play();
    client
      ..started()
      ..progress(3, 7);

    await engine.pause();
    await engine.resume();
    client
      ..continued()
      ..progress(2, 5);

    expect(client.spoken, <String>['First sentence.', 'st sentence.']);
    expect(events.last.position?.characterOffset, 5);
  });

  test('iOS native continuation keeps progress relative to the full segment',
      () async {
    final client = _FakeSystemTtsClient();
    final engine = SystemTtsAudioEngine(
      client: client,
      platform: TargetPlatform.iOS,
    );
    final events = <AudioEngineEvent>[];
    final subscription = engine.events.listen(events.add);
    addTearDown(() async {
      await subscription.cancel();
      await engine.dispose();
    });
    await engine.load(_articleRequest());
    await engine.play();
    client
      ..started()
      ..progress(3, 7);

    await engine.pause();
    await engine.resume();
    client
      ..continued()
      ..progress(5, 8);

    expect(client.spoken, <String>['First sentence.', 'First sentence.']);
    expect(events.last.position?.characterOffset, 5);
  });

  test('maps rate pitch language and a native voice without vendor leakage',
      () async {
    final client = _FakeSystemTtsClient()
      ..nativeVoices = <Map<String, Object?>>[
        <String, Object?>{
          'identifier': 'voice-local',
          'name': 'River Voice',
          'locale': 'zh-CN',
          'network_required': false,
          'private_detail': 'must not leave the adapter',
        },
        <String, Object?>{
          'name': 'Cloud Voice',
          'locale': 'en-US',
          'network_required': 'true',
        },
        <String, Object?>{'name': 'Malformed'},
      ];
    final engine = SystemTtsAudioEngine(
      client: client,
      platform: TargetPlatform.iOS,
    );
    addTearDown(engine.dispose);

    final voices = await engine.voices();
    await engine.updateSettings(
      const AudioPlaybackSettings(
        rate: 1.5,
        pitch: 0.8,
        languageTag: 'zh-CN',
        voiceId: 'voice-local',
      ),
    );

    expect(voices, hasLength(2));
    expect(voices.first.id, 'voice-local');
    expect(voices.first.isLocal, isTrue);
    expect(voices.last.id, 'en-US::Cloud Voice');
    expect(voices.last.isLocal, isFalse);
    expect(client.rates.single, 0.625);
    expect(client.pitches.single, 0.8);
    expect(client.languages.single, 'zh-CN');
    expect(
      client.selectedVoices.single,
      <String, String>{
        'name': 'River Voice',
        'locale': 'zh-CN',
        'identifier': 'voice-local',
      },
    );
  });

  test('pause and stop commands deduplicate matching native callbacks',
      () async {
    final client = _FakeSystemTtsClient();
    final engine = SystemTtsAudioEngine(
      client: client,
      platform: TargetPlatform.windows,
    );
    final events = <AudioEngineEvent>[];
    final subscription = engine.events.listen(events.add);
    addTearDown(() async {
      await subscription.cancel();
      await engine.dispose();
    });
    await engine.load(_articleRequest());
    await engine.play();
    client.started();

    await engine.pause();
    client.paused();
    await engine.stop();
    client.cancelled();

    expect(client.pauseCalls, 1);
    expect(
      events.where((event) => event.phase == AudioEnginePhase.paused),
      hasLength(1),
    );
    expect(
      events.where((event) => event.phase == AudioEnginePhase.stopped),
      hasLength(1),
    );
  });

  test('reports stable failures and honest unsupported capabilities', () async {
    final client = _FakeSystemTtsClient();
    final engine = SystemTtsAudioEngine(
      client: client,
      platform: TargetPlatform.linux,
    );
    final events = <AudioEngineEvent>[];
    final subscription = engine.events.listen(events.add);
    addTearDown(() async {
      await subscription.cancel();
      await engine.dispose();
    });

    final capabilities = await engine.capabilities();
    await engine.play();

    expect(capabilities.supportsArticleTts, isFalse);
    expect(capabilities.supportsPodcastMedia, isFalse);
    expect(client.spoken, isEmpty);
    expect(events.single.failureCode, 'tts_platform_unsupported');
  });

  test('sanitizes native errors and rejects podcast or invalid positions',
      () async {
    final client = _FakeSystemTtsClient();
    final engine = SystemTtsAudioEngine(
      client: client,
      platform: TargetPlatform.windows,
    );
    final events = <AudioEngineEvent>[];
    final subscription = engine.events.listen(events.add);
    addTearDown(() async {
      await subscription.cancel();
      await engine.dispose();
    });

    await engine.load(
      AudioLoadRequest(
        item: AudioItem(
          id: 'podcast-1',
          kind: AudioKind.podcastEpisode,
          title: 'Episode',
          sourceUri: Uri.parse('https://example.test/episode.mp3'),
        ),
      ),
    );
    await engine.load(_articleRequest());
    await engine.seek(AudioPlaybackPosition.media(Duration.zero));
    client.failed('private native voice and article detail');

    expect(
      events.where((event) => event.phase == AudioEnginePhase.failed).map(
            (event) => event.failureCode,
          ),
      <String>[
        'tts_unsupported_audio_kind',
        'tts_invalid_position',
        'tts_engine_error',
      ],
    );
  });
}

AudioLoadRequest _articleRequest() => AudioLoadRequest(
      item: AudioItem(
        id: 'article-1',
        kind: AudioKind.articleTts,
        title: 'Article',
        sourceUri: Uri.parse('river://article/1'),
      ),
      contentRevision: 'sha256:one',
      speechSegments: const <SpeechSegment>[
        SpeechSegment(
          index: 0,
          text: 'First sentence.',
          sourceStart: 0,
          sourceEnd: 15,
          languageTag: 'en-US',
        ),
        SpeechSegment(
          index: 1,
          text: 'Second sentence.',
          sourceStart: 16,
          sourceEnd: 32,
          languageTag: 'en-US',
        ),
      ],
    );

final class _FakeSystemTtsClient implements SystemTtsClient {
  late SystemTtsCallbacks callbacks;
  List<Map<String, Object?>> nativeVoices = <Map<String, Object?>>[];
  final List<String> spoken = <String>[];
  final List<double> rates = <double>[];
  final List<double> pitches = <double>[];
  final List<String> languages = <String>[];
  final List<Map<String, String>> selectedVoices = <Map<String, String>>[];
  var pauseCalls = 0;
  var stopCalls = 0;
  var clearVoiceCalls = 0;

  @override
  void configure(SystemTtsCallbacks callbacks) {
    this.callbacks = callbacks;
  }

  @override
  Future<void> clearVoice() async {
    clearVoiceCalls += 1;
  }

  @override
  Future<void> pause() async {
    pauseCalls += 1;
  }

  @override
  Future<void> setLanguage(String languageTag) async {
    languages.add(languageTag);
  }

  @override
  Future<void> setPitch(double pitch) async {
    pitches.add(pitch);
  }

  @override
  Future<void> setRate(double rate) async {
    rates.add(rate);
  }

  @override
  Future<void> setVoice(Map<String, String> voice) async {
    selectedVoices.add(voice);
  }

  @override
  Future<void> speak(String text) async {
    spoken.add(text);
  }

  @override
  Future<void> stop() async {
    stopCalls += 1;
  }

  @override
  Future<List<Map<String, Object?>>> voices() async => nativeVoices;

  void started() => callbacks.onStarted();

  void completed() => callbacks.onCompleted();

  void paused() => callbacks.onPaused();

  void continued() => callbacks.onContinued();

  void cancelled() => callbacks.onCancelled();

  void progress(int start, int end) => callbacks.onProgress(start, end);

  void failed(String privateMessage) => callbacks.onError();
}
