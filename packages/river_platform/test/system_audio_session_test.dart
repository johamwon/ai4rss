import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:river_domain/river_domain.dart';
import 'package:river_platform/river_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('SystemAudioSession delegates its stable domain contract', () async {
    final client = _FakeAudioSystemSessionClient();
    final session = SystemAudioSession.withClient(client);
    final events = <AudioSystemEvent>[];
    final subscription = session.events.listen(events.add);
    addTearDown(subscription.cancel);

    expect(await session.activate(), isTrue);
    await session.publish(_playbackState());
    client.emit(AudioSystemEventType.pause);
    await session.deactivate();
    await session.clear();

    expect(events.single.type, AudioSystemEventType.pause);
    expect(client.published.single.item.id, 'article-1');
    expect(client.activateCalls, 1);
    expect(client.deactivateCalls, 1);
    expect(client.clearCalls, 1);
  });

  test('Windows method channel maps bounded playback state and commands',
      () async {
    const channel = MethodChannel('app.river/test-audio-system-session');
    final calls = <MethodCall>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'activate') return false;
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
    });
    final client = MethodChannelAudioSystemSessionClient(channel: channel);
    final events = <AudioSystemEvent>[];
    final subscription = client.events.listen(events.add);
    addTearDown(subscription.cancel);

    await client.initialize();
    expect(await client.activate(), isFalse);
    await client.publish(_playbackState());
    await messenger.handlePlatformMessage(
      channel.name,
      const StandardMethodCodec().encodeMethodCall(
        const MethodCall('onCommand', 'next'),
      ),
      (_) {},
    );
    await Future<void>.delayed(Duration.zero);
    await client.deactivate();
    await client.clear();
    await client.dispose();

    expect(
      calls.map((call) => call.method),
      <String>[
        'initialize',
        'activate',
        'publish',
        'deactivate',
        'clear',
        'dispose',
      ],
    );
    expect(
      calls[2].arguments,
      <String, Object?>{
        'id': 'article-1',
        'title': 'Article one',
        'kind': 'articleTts',
        'sourceUri': 'river://article/1',
        'phase': 'playing',
        'playing': true,
        'segmentIndex': 1,
        'characterOffset': 4,
        'positionMs': null,
        'rate': 1.25,
        'canSkipPrevious': true,
        'canSkipNext': false,
      },
    );
    expect(events.single.type, AudioSystemEventType.skipNext);
  });
}

AudioSystemPlaybackState _playbackState() => AudioSystemPlaybackState(
      item: AudioItem(
        id: 'article-1',
        kind: AudioKind.articleTts,
        title: 'Article one',
        sourceUri: Uri.parse('river://article/1'),
      ),
      phase: AudioEnginePhase.playing,
      position: const AudioPlaybackPosition.speech(
        segmentIndex: 1,
        characterOffset: 4,
      ),
      settings: const AudioPlaybackSettings(rate: 1.25),
      canSkipPrevious: true,
      canSkipNext: false,
    );

final class _FakeAudioSystemSessionClient implements AudioSystemSessionClient {
  final StreamController<AudioSystemEvent> _events =
      StreamController<AudioSystemEvent>.broadcast(sync: true);
  final List<AudioSystemPlaybackState> published = <AudioSystemPlaybackState>[];
  var activateCalls = 0;
  var deactivateCalls = 0;
  var clearCalls = 0;

  @override
  Stream<AudioSystemEvent> get events => _events.stream;

  @override
  Future<bool> activate() async {
    activateCalls += 1;
    return true;
  }

  @override
  Future<void> clear() async {
    clearCalls += 1;
  }

  @override
  Future<void> deactivate() async {
    deactivateCalls += 1;
  }

  @override
  Future<void> dispose() => _events.close();

  @override
  Future<void> publish(AudioSystemPlaybackState state) async {
    published.add(state);
  }

  void emit(AudioSystemEventType type) {
    _events.add(AudioSystemEvent(type: type));
  }
}
