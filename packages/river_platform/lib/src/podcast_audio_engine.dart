import 'dart:async';

import 'package:just_audio/just_audio.dart' as just_audio;
import 'package:river_domain/river_domain.dart';

enum PodcastPlayerPhase {
  idle,
  loading,
  ready,
  playing,
  paused,
  stopped,
  completed,
  failed,
}

final class PodcastPlayerEvent {
  const PodcastPlayerEvent({
    required this.phase,
    required this.position,
    this.failureCode,
  }) : assert(
          (phase == PodcastPlayerPhase.failed) == (failureCode != null),
        );

  final PodcastPlayerPhase phase;
  final Duration position;
  final String? failureCode;
}

abstract interface class PodcastPlayerBackend {
  Stream<PodcastPlayerEvent> get events;

  Future<void> setSource(Uri source);
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<void> setSpeed(double speed);
  Future<void> dispose();
}

final class JustAudioPodcastPlayerBackend implements PodcastPlayerBackend {
  JustAudioPodcastPlayerBackend({just_audio.AudioPlayer? player})
      : _player = player ?? just_audio.AudioPlayer() {
    _subscriptions.add(
      _player.playerStateStream.listen(_onPlayerState, onError: _onError),
    );
    _subscriptions.add(
      _player.positionStream.listen(_onPosition, onError: _onError),
    );
    _subscriptions.add(_player.errorStream.listen(_onError));
  }

  final just_audio.AudioPlayer _player;
  final StreamController<PodcastPlayerEvent> _events =
      StreamController<PodcastPlayerEvent>.broadcast(sync: true);
  final List<StreamSubscription<Object?>> _subscriptions =
      <StreamSubscription<Object?>>[];

  PodcastPlayerPhase _phase = PodcastPlayerPhase.idle;
  Duration _position = Duration.zero;
  var _hasSource = false;
  var _disposed = false;

  @override
  Stream<PodcastPlayerEvent> get events => _events.stream;

  @override
  Future<void> setSource(Uri source) async {
    _ensureOpen();
    _hasSource = true;
    _phase = PodcastPlayerPhase.loading;
    _position = Duration.zero;
    _emit();
    try {
      await _player.setUrl(source.toString());
      _phase = PodcastPlayerPhase.ready;
      _emit();
    } on Object {
      _fail('podcast_source_failed');
      rethrow;
    }
  }

  @override
  Future<void> play() async {
    unawaited(_player.play().catchError(_onError));
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _player.dispose();
    await _events.close();
  }

  void _onPlayerState(just_audio.PlayerState state) {
    if (_disposed) return;
    _phase = switch (state.processingState) {
      just_audio.ProcessingState.idle =>
        _hasSource ? PodcastPlayerPhase.stopped : PodcastPlayerPhase.idle,
      just_audio.ProcessingState.loading ||
      just_audio.ProcessingState.buffering =>
        PodcastPlayerPhase.loading,
      just_audio.ProcessingState.ready =>
        state.playing ? PodcastPlayerPhase.playing : PodcastPlayerPhase.paused,
      just_audio.ProcessingState.completed => PodcastPlayerPhase.completed,
    };
    _emit();
  }

  void _onPosition(Duration position) {
    if (_disposed || position.isNegative) return;
    _position = position;
    _emit();
  }

  void _onError(Object _) => _fail('podcast_playback_failed');

  void _fail(String code) {
    if (_disposed) return;
    _phase = PodcastPlayerPhase.failed;
    _events.add(
      PodcastPlayerEvent(
        phase: _phase,
        position: _position,
        failureCode: code,
      ),
    );
  }

  void _emit() {
    if (_disposed) return;
    _events.add(PodcastPlayerEvent(phase: _phase, position: _position));
  }

  void _ensureOpen() {
    if (_disposed) throw StateError('Podcast player is disposed.');
  }
}

final class PodcastAudioEngine implements AudioEngine {
  PodcastAudioEngine({PodcastPlayerBackend? backend})
      : _backend = backend ?? JustAudioPodcastPlayerBackend() {
    _subscription = _backend.events.listen(_onBackendEvent);
  }

  final PodcastPlayerBackend _backend;
  final StreamController<AudioEngineEvent> _events =
      StreamController<AudioEngineEvent>.broadcast(sync: true);

  late final StreamSubscription<PodcastPlayerEvent> _subscription;
  String? _itemId;
  var _disposed = false;

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
  Future<List<AudioVoice>> voices() async => const <AudioVoice>[];

  @override
  Future<void> load(AudioLoadRequest request) async {
    _ensureOpen();
    if (request.item.kind != AudioKind.podcastEpisode) {
      throw ArgumentError.value(
        request.item.kind,
        'request',
        'Podcast engine only accepts podcast episodes.',
      );
    }
    final source = request.item.sourceUri;
    final allowed = source.scheme == 'https' ||
        source.scheme == 'http' ||
        source.scheme == 'file';
    if (!allowed ||
        (source.scheme != 'file' &&
            (!source.hasAuthority || source.userInfo.isNotEmpty))) {
      throw ArgumentError.value(source, 'sourceUri', 'Unsafe podcast source.');
    }
    _itemId = request.item.id;
    _emit(AudioEnginePhase.loading, Duration.zero);
    await _backend.setSource(source);
  }

  @override
  Future<void> play() => _backend.play();

  @override
  Future<void> pause() => _backend.pause();

  @override
  Future<void> resume() => _backend.play();

  @override
  Future<void> stop() => _backend.stop();

  @override
  Future<void> seek(AudioPlaybackPosition position) {
    if (position.isSpeech || position.mediaPosition == null) {
      throw ArgumentError.value(
        position,
        'position',
        'Podcast playback requires a media position.',
      );
    }
    return _backend.seek(position.mediaPosition!);
  }

  @override
  Future<void> updateSettings(AudioPlaybackSettings settings) =>
      _backend.setSpeed(settings.rate);

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _subscription.cancel();
    await _backend.dispose();
    await _events.close();
  }

  void _onBackendEvent(PodcastPlayerEvent event) {
    if (_disposed || _itemId == null) return;
    final phase = switch (event.phase) {
      PodcastPlayerPhase.idle => AudioEnginePhase.idle,
      PodcastPlayerPhase.loading => AudioEnginePhase.loading,
      PodcastPlayerPhase.ready => AudioEnginePhase.ready,
      PodcastPlayerPhase.playing => AudioEnginePhase.playing,
      PodcastPlayerPhase.paused => AudioEnginePhase.paused,
      PodcastPlayerPhase.stopped => AudioEnginePhase.stopped,
      PodcastPlayerPhase.completed => AudioEnginePhase.completed,
      PodcastPlayerPhase.failed => AudioEnginePhase.failed,
    };
    _events.add(
      AudioEngineEvent(
        phase: phase,
        itemId: _itemId,
        position: AudioPlaybackPosition.media(event.position),
        failureCode: event.failureCode,
      ),
    );
  }

  void _emit(AudioEnginePhase phase, Duration position) {
    _events.add(
      AudioEngineEvent(
        phase: phase,
        itemId: _itemId,
        position: AudioPlaybackPosition.media(position),
      ),
    );
  }

  void _ensureOpen() {
    if (_disposed) throw StateError('Podcast audio engine is disposed.');
  }
}
