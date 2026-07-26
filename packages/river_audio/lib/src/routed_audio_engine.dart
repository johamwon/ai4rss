import 'dart:async';

import 'package:river_domain/river_domain.dart';

final class RoutedAudioEngine implements AudioEngine {
  RoutedAudioEngine({
    required AudioEngine articleEngine,
    required AudioEngine podcastEngine,
  })  : _articleEngine = articleEngine,
        _podcastEngine = podcastEngine {
    _subscriptions.add(
      _articleEngine.events.listen(_events.add, onError: _events.addError),
    );
    if (!identical(_articleEngine, _podcastEngine)) {
      _subscriptions.add(
        _podcastEngine.events.listen(_events.add, onError: _events.addError),
      );
    }
  }

  final AudioEngine _articleEngine;
  final AudioEngine _podcastEngine;
  final StreamController<AudioEngineEvent> _events =
      StreamController<AudioEngineEvent>.broadcast(sync: true);
  final List<StreamSubscription<AudioEngineEvent>> _subscriptions =
      <StreamSubscription<AudioEngineEvent>>[];

  AudioEngine? _activeEngine;
  var _disposed = false;

  @override
  Stream<AudioEngineEvent> get events => _events.stream;

  @override
  Future<AudioEngineCapabilities> capabilities() async {
    final results = await Future.wait<
        AudioEngineCapabilities>(<Future<AudioEngineCapabilities>>[
      _articleEngine.capabilities(),
      _podcastEngine.capabilities(),
    ]);
    final article = results[0];
    final podcast = results[1];
    return AudioEngineCapabilities(
      supportsArticleTts: article.supportsArticleTts,
      supportsPodcastMedia: podcast.supportsPodcastMedia,
      canPause: article.canPause && podcast.canPause,
      canResume: article.canResume && podcast.canResume,
      canSeek: article.canSeek && podcast.canSeek,
      canSetRate: article.canSetRate && podcast.canSetRate,
      canSetPitch: article.canSetPitch,
      canSelectVoice: article.canSelectVoice,
    );
  }

  @override
  Future<List<AudioVoice>> voices() => _articleEngine.voices();

  @override
  Future<void> load(AudioLoadRequest request) async {
    _ensureOpen();
    final next = switch (request.item.kind) {
      AudioKind.articleTts => _articleEngine,
      AudioKind.podcastEpisode => _podcastEngine,
    };
    final previous = _activeEngine;
    if (previous != null && !identical(previous, next)) {
      await previous.stop();
    }
    _activeEngine = next;
    await next.load(request);
  }

  @override
  Future<void> pause() => _active().pause();

  @override
  Future<void> play() => _active().play();

  @override
  Future<void> resume() => _active().resume();

  @override
  Future<void> seek(AudioPlaybackPosition position) => _active().seek(position);

  @override
  Future<void> stop() => _active().stop();

  @override
  Future<void> updateSettings(AudioPlaybackSettings settings) =>
      _active().updateSettings(settings);

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _articleEngine.dispose();
    if (!identical(_articleEngine, _podcastEngine)) {
      await _podcastEngine.dispose();
    }
    await _events.close();
  }

  AudioEngine _active() {
    _ensureOpen();
    final active = _activeEngine;
    if (active == null) {
      throw StateError('No audio item has been loaded.');
    }
    return active;
  }

  void _ensureOpen() {
    if (_disposed) {
      throw StateError('Audio engine is disposed.');
    }
  }
}
