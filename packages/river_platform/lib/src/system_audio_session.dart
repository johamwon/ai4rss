import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart' as service;
import 'package:audio_session/audio_session.dart' as session;
import 'package:flutter/services.dart';
import 'package:river_domain/river_domain.dart';

abstract interface class AudioSystemSessionClient {
  Stream<AudioSystemEvent> get events;

  Future<bool> activate();
  Future<void> deactivate();
  Future<void> publish(AudioSystemPlaybackState state);
  Future<void> clear();
  Future<void> dispose();
}

final class SystemAudioSession implements AudioSystemSession {
  SystemAudioSession.withClient(AudioSystemSessionClient client)
      : _client = client;

  final AudioSystemSessionClient _client;

  static Future<AudioSystemSession> create() async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        return SystemAudioSession.withClient(
          await _AudioServiceSessionClient.create(),
        );
      }
      if (Platform.isWindows) {
        final client = MethodChannelAudioSystemSessionClient();
        await client.initialize();
        return SystemAudioSession.withClient(client);
      }
    } on Object {
      // System media integration is an enhancement. A missing native service
      // must never prevent the feed reader itself from starting.
    }
    return SystemAudioSession.withClient(
      const _UnavailableAudioSystemSessionClient(),
    );
  }

  @override
  Stream<AudioSystemEvent> get events => _client.events;

  @override
  Future<bool> activate() => _client.activate();

  @override
  Future<void> clear() => _client.clear();

  @override
  Future<void> deactivate() => _client.deactivate();

  @override
  Future<void> dispose() => _client.dispose();

  @override
  Future<void> publish(AudioSystemPlaybackState state) =>
      _client.publish(state);
}

final class MethodChannelAudioSystemSessionClient
    implements AudioSystemSessionClient {
  MethodChannelAudioSystemSessionClient({
    MethodChannel channel =
        const MethodChannel('app.river/audio_system_session'),
  }) : _channel = channel;

  final MethodChannel _channel;
  final StreamController<AudioSystemEvent> _events =
      StreamController<AudioSystemEvent>.broadcast(sync: true);
  var _initialized = false;

  @override
  Stream<AudioSystemEvent> get events => _events.stream;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    _channel.setMethodCallHandler(_handleMethodCall);
    try {
      await _channel.invokeMethod<void>('initialize');
    } on Object {
      _initialized = false;
      _channel.setMethodCallHandler(null);
      await _events.close();
      rethrow;
    }
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method != 'onCommand') return;
    final type = switch (call.arguments) {
      'play' => AudioSystemEventType.play,
      'pause' => AudioSystemEventType.pause,
      'stop' => AudioSystemEventType.stop,
      'next' => AudioSystemEventType.skipNext,
      'previous' => AudioSystemEventType.skipPrevious,
      _ => null,
    };
    if (type != null && !_events.isClosed) {
      _events.add(AudioSystemEvent(type: type));
    }
  }

  @override
  Future<bool> activate() async =>
      await _channel.invokeMethod<bool>('activate') ?? true;

  @override
  Future<void> clear() => _channel.invokeMethod<void>('clear');

  @override
  Future<void> deactivate() => _channel.invokeMethod<void>('deactivate');

  @override
  Future<void> publish(AudioSystemPlaybackState state) {
    final position = state.position;
    return _channel.invokeMethod<void>('publish', <String, Object?>{
      'id': state.item.id,
      'title': state.item.title,
      'kind': state.item.kind.name,
      'sourceUri': state.item.sourceUri.toString(),
      'phase': state.phase.name,
      'playing': state.phase == AudioEnginePhase.playing,
      'segmentIndex': position.segmentIndex,
      'characterOffset': position.characterOffset,
      'positionMs': position.mediaPosition?.inMilliseconds,
      'rate': state.settings.rate,
      'canSkipPrevious': state.canSkipPrevious,
      'canSkipNext': state.canSkipNext,
    });
  }

  @override
  Future<void> dispose() async {
    if (!_initialized) return;
    _initialized = false;
    _channel.setMethodCallHandler(null);
    try {
      await _channel.invokeMethod<void>('dispose');
    } finally {
      await _events.close();
    }
  }
}

final class _AudioServiceSessionClient implements AudioSystemSessionClient {
  _AudioServiceSessionClient({
    required _RiverAudioHandler handler,
    required session.AudioSession audioSession,
  })  : _handler = handler,
        _audioSession = audioSession {
    _subscriptions.add(
      audioSession.interruptionEventStream.listen(_handleInterruption),
    );
    _subscriptions.add(
      audioSession.becomingNoisyEventStream.listen(
        (_) => _add(
          const AudioSystemEvent(
            type: AudioSystemEventType.becomingNoisy,
          ),
        ),
      ),
    );
  }

  final _RiverAudioHandler _handler;
  final session.AudioSession _audioSession;
  final StreamController<AudioSystemEvent> _events =
      StreamController<AudioSystemEvent>.broadcast(sync: true);
  final List<StreamSubscription<Object?>> _subscriptions =
      <StreamSubscription<Object?>>[];

  static Future<_AudioServiceSessionClient> create() async {
    final handler = await service.AudioService.init<_RiverAudioHandler>(
      builder: _RiverAudioHandler.new,
      config: const service.AudioServiceConfig(
        androidNotificationChannelId: 'app.river.playback',
        androidNotificationChannelName: 'River 文章朗读与播客',
        androidStopForegroundOnPause: false,
      ),
    );
    final audioSession = await session.AudioSession.instance;
    await audioSession.configure(session.AudioSessionConfiguration.speech());
    final client = _AudioServiceSessionClient(
      handler: handler,
      audioSession: audioSession,
    );
    client._subscriptions.add(handler.commands.listen(client._add));
    return client;
  }

  @override
  Stream<AudioSystemEvent> get events => _events.stream;

  @override
  Future<bool> activate() => _audioSession.setActive(true);

  @override
  Future<void> deactivate() async {
    await _audioSession.setActive(false);
  }

  @override
  Future<void> publish(AudioSystemPlaybackState state) async {
    _handler.publish(state);
  }

  @override
  Future<void> clear() async {
    _handler.clearSession();
  }

  @override
  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    _handler.clearSession();
    await _handler.disposeHandler();
    await _events.close();
  }

  void _handleInterruption(session.AudioInterruptionEvent event) {
    if (event.begin) {
      _add(
        const AudioSystemEvent(
          type: AudioSystemEventType.interruptionBegan,
        ),
      );
      return;
    }
    _add(
      AudioSystemEvent(
        type: AudioSystemEventType.interruptionEnded,
        mayResume: event.type != session.AudioInterruptionType.unknown,
      ),
    );
  }

  void _add(AudioSystemEvent event) {
    if (!_events.isClosed) _events.add(event);
  }
}

final class _RiverAudioHandler extends service.BaseAudioHandler {
  final StreamController<AudioSystemEvent> _commands =
      StreamController<AudioSystemEvent>.broadcast(sync: true);

  Stream<AudioSystemEvent> get commands => _commands.stream;

  void publish(AudioSystemPlaybackState state) {
    mediaItem.add(
      service.MediaItem(
        id: state.item.id,
        title: state.item.title,
        album: 'River',
        extras: <String, Object?>{
          'kind': state.item.kind.name,
          'sourceUri': state.item.sourceUri.toString(),
        },
      ),
    );
    final active = state.phase != AudioEnginePhase.idle &&
        state.phase != AudioEnginePhase.stopped;
    final playControl = state.phase == AudioEnginePhase.playing
        ? service.MediaControl.pause
        : service.MediaControl.play;
    final controls = active
        ? <service.MediaControl>[
            if (state.canSkipPrevious) service.MediaControl.skipToPrevious,
            playControl,
            service.MediaControl.stop,
            if (state.canSkipNext) service.MediaControl.skipToNext,
          ]
        : const <service.MediaControl>[];
    playbackState.add(
      service.PlaybackState(
        controls: controls,
        systemActions: <service.MediaAction>{
          service.MediaAction.play,
          service.MediaAction.pause,
          service.MediaAction.stop,
          if (state.canSkipNext) service.MediaAction.skipToNext,
          if (state.canSkipPrevious) service.MediaAction.skipToPrevious,
        },
        androidCompactActionIndices: <int>[
          for (var index = 0; index < controls.length && index < 3; index += 1)
            index,
        ],
        processingState: _processingState(state.phase),
        playing: state.phase == AudioEnginePhase.playing,
        updatePosition: state.position.mediaPosition ?? Duration.zero,
        speed: state.settings.rate,
      ),
    );
  }

  void clearSession() {
    mediaItem.add(null);
    playbackState.add(
      playbackState.value.copyWith(
        controls: const <service.MediaControl>[],
        systemActions: const <service.MediaAction>{},
        processingState: service.AudioProcessingState.idle,
        playing: false,
      ),
    );
  }

  Future<void> disposeHandler() => _commands.close();

  @override
  Future<void> play() async => _add(AudioSystemEventType.play);

  @override
  Future<void> pause() async => _add(AudioSystemEventType.pause);

  @override
  Future<void> stop() async => _add(AudioSystemEventType.stop);

  @override
  Future<void> skipToNext() async => _add(AudioSystemEventType.skipNext);

  @override
  Future<void> skipToPrevious() async =>
      _add(AudioSystemEventType.skipPrevious);

  void _add(AudioSystemEventType type) {
    if (!_commands.isClosed) _commands.add(AudioSystemEvent(type: type));
  }

  static service.AudioProcessingState _processingState(
    AudioEnginePhase phase,
  ) =>
      switch (phase) {
        AudioEnginePhase.idle ||
        AudioEnginePhase.stopped =>
          service.AudioProcessingState.idle,
        AudioEnginePhase.loading => service.AudioProcessingState.loading,
        AudioEnginePhase.completed => service.AudioProcessingState.completed,
        AudioEnginePhase.failed => service.AudioProcessingState.error,
        AudioEnginePhase.ready ||
        AudioEnginePhase.playing ||
        AudioEnginePhase.paused ||
        AudioEnginePhase.interrupted =>
          service.AudioProcessingState.ready,
      };
}

final class _UnavailableAudioSystemSessionClient
    implements AudioSystemSessionClient {
  const _UnavailableAudioSystemSessionClient();

  @override
  Stream<AudioSystemEvent> get events => const Stream<AudioSystemEvent>.empty();

  @override
  Future<bool> activate() async => true;

  @override
  Future<void> clear() async {}

  @override
  Future<void> deactivate() async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<void> publish(AudioSystemPlaybackState state) async {}
}
