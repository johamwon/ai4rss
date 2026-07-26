import 'dart:async';

import 'package:river_domain/river_domain.dart';

import 'audio_segment_prefetcher.dart';

abstract interface class AudioTimerHandle {
  bool get isActive;
  void cancel();
}

abstract interface class AudioScheduler {
  AudioTimerHandle schedule(Duration delay, void Function() callback);
}

final class DartAudioScheduler implements AudioScheduler {
  const DartAudioScheduler();

  @override
  AudioTimerHandle schedule(Duration delay, void Function() callback) =>
      _DartAudioTimerHandle(Timer(delay, callback));
}

final class _DartAudioTimerHandle implements AudioTimerHandle {
  _DartAudioTimerHandle(this._timer);

  final Timer _timer;

  @override
  bool get isActive => _timer.isActive;

  @override
  void cancel() => _timer.cancel();
}

final class AudioPlaybackState {
  AudioPlaybackState({
    this.phase = AudioEnginePhase.idle,
    this.request,
    this.position,
    this.settings = const AudioPlaybackSettings(),
    this.capabilities,
    List<AudioVoice> voices = const <AudioVoice>[],
    this.sleepDeadline,
    this.failureCode,
    this.restoring = false,
  }) : voices = List<AudioVoice>.unmodifiable(voices);

  const AudioPlaybackState.initial()
      : phase = AudioEnginePhase.idle,
        request = null,
        position = null,
        settings = const AudioPlaybackSettings(),
        capabilities = null,
        voices = const <AudioVoice>[],
        sleepDeadline = null,
        failureCode = null,
        restoring = false;

  final AudioEnginePhase phase;
  final AudioLoadRequest? request;
  final AudioPlaybackPosition? position;
  final AudioPlaybackSettings settings;
  final AudioEngineCapabilities? capabilities;
  final List<AudioVoice> voices;
  final DateTime? sleepDeadline;
  final String? failureCode;
  final bool restoring;

  AudioItem? get item => request?.item;

  SpeechSegment? get currentSpeechSegment {
    final segments = request?.speechSegments;
    final index = position?.segmentIndex;
    if (segments == null ||
        index == null ||
        index < 0 ||
        index >= segments.length) {
      return null;
    }
    return segments[index];
  }

  bool get canSkipPrevious =>
      request?.item.kind == AudioKind.articleTts &&
      (position?.segmentIndex ?? 0) > 0;

  bool get canSkipNext {
    final segments = request?.speechSegments;
    final index = position?.segmentIndex;
    return segments != null &&
        index != null &&
        index >= 0 &&
        index + 1 < segments.length;
  }

  AudioPlaybackState copyWith({
    AudioEnginePhase? phase,
    AudioLoadRequest? request,
    bool clearRequest = false,
    AudioPlaybackPosition? position,
    bool clearPosition = false,
    AudioPlaybackSettings? settings,
    AudioEngineCapabilities? capabilities,
    List<AudioVoice>? voices,
    DateTime? sleepDeadline,
    bool clearSleepDeadline = false,
    String? failureCode,
    bool clearFailure = false,
    bool? restoring,
  }) =>
      AudioPlaybackState(
        phase: phase ?? this.phase,
        request: clearRequest ? null : request ?? this.request,
        position: clearPosition ? null : position ?? this.position,
        settings: settings ?? this.settings,
        capabilities: capabilities ?? this.capabilities,
        voices: voices ?? this.voices,
        sleepDeadline:
            clearSleepDeadline ? null : sleepDeadline ?? this.sleepDeadline,
        failureCode: clearFailure ? null : failureCode ?? this.failureCode,
        restoring: restoring ?? this.restoring,
      );
}

final class AudioPlaybackController {
  AudioPlaybackController({
    required AudioEngine engine,
    required AudioPlaybackRepository repository,
    required Clock clock,
    AudioSystemSession systemSession = const UnavailableAudioSystemSession(),
    AudioSegmentPrefetcher segmentPrefetcher =
        const UnavailableAudioSegmentPrefetcher(),
    AudioScheduler scheduler = const DartAudioScheduler(),
    this.persistenceDelay = const Duration(milliseconds: 400),
  })  : _engine = engine,
        _repository = repository,
        _clock = clock,
        _systemSession = systemSession,
        _segmentPrefetcher = segmentPrefetcher,
        _scheduler = scheduler {
    _engineSubscription = _engine.events.listen(
      _handleEngineEvent,
      onError: (Object error, StackTrace stackTrace) {
        _fail('audio_event_stream_failed');
      },
    );
    _systemSubscription = _systemSession.events.listen(
      _handleSystemEvent,
      onError: (Object error, StackTrace stackTrace) {
        _emit(_state.copyWith(failureCode: 'audio_system_events_failed'));
      },
    );
  }

  final AudioEngine _engine;
  final AudioPlaybackRepository _repository;
  final Clock _clock;
  final AudioSystemSession _systemSession;
  final AudioSegmentPrefetcher _segmentPrefetcher;
  final AudioScheduler _scheduler;
  final Duration persistenceDelay;
  final StreamController<AudioPlaybackState> _states =
      StreamController<AudioPlaybackState>.broadcast(sync: true);
  late final StreamSubscription<AudioEngineEvent> _engineSubscription;
  late final StreamSubscription<AudioSystemEvent> _systemSubscription;
  AudioPlaybackState _state = const AudioPlaybackState.initial();
  AudioTimerHandle? _persistenceTimer;
  AudioTimerHandle? _sleepTimer;
  var _generation = 0;
  var _restoring = false;
  var _resumeAfterInterruption = false;
  (String, String?, int, double, double, String?, String?)? _lastPrefetchKey;
  var _disposed = false;

  AudioPlaybackState get state => _state;
  Stream<AudioPlaybackState> get states => _states.stream;

  Future<void> load(AudioLoadRequest request) async {
    if (_disposed) return;
    final generation = ++_generation;
    _lastPrefetchKey = null;
    try {
      await _segmentPrefetcher.cancel();
    } on Object {
      // Preparation is optional; the playback engine remains the fallback.
    }
    _cancelPersistenceTimer();
    _cancelSleepTimer(updateState: false);
    _emit(
      AudioPlaybackState(
        phase: AudioEnginePhase.loading,
        request: request,
        position: _initialPosition(request),
        settings: _state.settings,
        restoring: true,
      ),
    );

    AudioEngineCapabilities capabilities;
    try {
      capabilities = await _engine.capabilities();
    } on Object {
      _fail('audio_capabilities_failed');
      return;
    }
    if (!_isCurrent(generation, request.item.id)) return;
    final supported = switch (request.item.kind) {
      AudioKind.articleTts => capabilities.supportsArticleTts,
      AudioKind.podcastEpisode => capabilities.supportsPodcastMedia,
    };
    if (!supported) {
      _fail('audio_kind_unsupported');
      return;
    }

    List<AudioVoice> voices;
    try {
      voices = await _engine.voices();
    } on Object {
      voices = const <AudioVoice>[];
    }
    if (!_isCurrent(generation, request.item.id)) return;

    AudioPlaybackSnapshot? snapshot;
    try {
      snapshot = await _repository.read(request.item.id);
    } on Object {
      snapshot = null;
    }
    if (!_isCurrent(generation, request.item.id)) return;

    final settings = _restoredSettings(snapshot, voices);
    final restoredPosition = _restoredPosition(request, snapshot);
    _restoring = true;
    try {
      await _engine.load(request);
      if (!_isCurrent(generation, request.item.id)) return;
      await _engine.updateSettings(settings);
      if (!_isCurrent(generation, request.item.id)) return;
      if (restoredPosition != null) {
        await _engine.seek(restoredPosition);
      }
    } on Object {
      _fail('audio_load_failed');
      return;
    } finally {
      _restoring = false;
    }
    if (!_isCurrent(generation, request.item.id)) return;
    _emit(
      _state.copyWith(
        phase: AudioEnginePhase.ready,
        position: restoredPosition ?? _initialPosition(request),
        settings: settings,
        capabilities: capabilities,
        voices: List<AudioVoice>.unmodifiable(voices),
        clearFailure: true,
        restoring: false,
      ),
    );
  }

  Future<void> play() async {
    if (_disposed || _state.request == null) return;
    try {
      final activated = await _systemSession.activate();
      if (!activated) {
        _fail('audio_focus_denied');
        return;
      }
      _resumeAfterInterruption = false;
      if (_state.phase == AudioEnginePhase.completed) {
        await _engine.seek(_initialPosition(_state.request!));
      }
      if (_state.phase == AudioEnginePhase.paused) {
        await _engine.resume();
      } else {
        await _engine.play();
      }
    } on Object {
      _fail('audio_play_failed');
    }
  }

  Future<void> pause() async {
    if (_disposed || _state.request == null) return;
    _resumeAfterInterruption = false;
    try {
      await _engine.pause();
      await _persistNow();
      await _systemSession.deactivate();
    } on Object {
      _fail('audio_pause_failed');
    }
  }

  Future<void> stop() async {
    if (_disposed || _state.request == null) return;
    _resumeAfterInterruption = false;
    try {
      await _engine.stop();
      await _persistNow();
      await _systemSession.deactivate();
    } on Object {
      _fail('audio_stop_failed');
    }
    _lastPrefetchKey = null;
    try {
      await _segmentPrefetcher.cancel();
    } on Object {
      // Stopping playback must not depend on optional prepared resources.
    }
  }

  Future<void> skipNext() async {
    final index = _state.position?.segmentIndex;
    if (index == null || !_state.canSkipNext) return;
    await seekToSegment(index + 1);
  }

  Future<void> skipPrevious() async {
    final index = _state.position?.segmentIndex;
    if (index == null || index <= 0) return;
    await seekToSegment(index - 1);
  }

  Future<void> restartCurrentSegment() async {
    final index = _state.position?.segmentIndex;
    if (index == null) return;
    await seekToSegment(index);
  }

  Future<void> seekToSegment(
    int segmentIndex, {
    int characterOffset = 0,
  }) async {
    final request = _state.request;
    if (_disposed ||
        request == null ||
        request.item.kind != AudioKind.articleTts ||
        segmentIndex < 0 ||
        segmentIndex >= request.speechSegments.length ||
        characterOffset < 0 ||
        characterOffset > request.speechSegments[segmentIndex].text.length) {
      return;
    }
    final wasPlaying = _state.phase == AudioEnginePhase.playing;
    try {
      await _engine.seek(
        AudioPlaybackPosition.speech(
          segmentIndex: segmentIndex,
          characterOffset: characterOffset,
        ),
      );
      await _persistNow();
      if (wasPlaying) await _engine.play();
    } on Object {
      _fail('audio_seek_failed');
    }
  }

  Future<void> updateSettings(AudioPlaybackSettings settings) async {
    if (_disposed) return;
    final voiceId = settings.voiceId;
    if (voiceId != null && !_state.voices.any((voice) => voice.id == voiceId)) {
      _emit(_state.copyWith(failureCode: 'audio_voice_unavailable'));
      return;
    }
    try {
      await _engine.updateSettings(settings);
      _emit(_state.copyWith(settings: settings, clearFailure: true));
      await _persistNow();
    } on Object {
      _emit(_state.copyWith(failureCode: 'audio_settings_failed'));
    }
  }

  void setSleepTimer(Duration? duration) {
    if (_disposed) return;
    if (duration == null) {
      _cancelSleepTimer();
      return;
    }
    if (duration <= Duration.zero || duration > const Duration(hours: 2)) {
      _emit(_state.copyWith(failureCode: 'audio_invalid_sleep_timer'));
      return;
    }
    _cancelSleepTimer(updateState: false);
    final deadline = _clock.now().add(duration);
    _sleepTimer = _scheduler.schedule(duration, () {
      _sleepTimer = null;
      if (_disposed) return;
      _emit(_state.copyWith(clearSleepDeadline: true));
      unawaited(pause());
    });
    _emit(
      _state.copyWith(
        sleepDeadline: deadline,
        clearFailure: true,
      ),
    );
  }

  void clearFailure() {
    if (_disposed || _state.failureCode == null) return;
    _emit(_state.copyWith(clearFailure: true));
  }

  void _handleEngineEvent(AudioEngineEvent event) {
    if (_disposed) return;
    final request = _state.request;
    if (request == null) return;
    if (event.itemId != null && event.itemId != request.item.id) return;

    if (event.phase == AudioEnginePhase.completed &&
        request.item.kind == AudioKind.articleTts) {
      final completedIndex =
          event.position?.segmentIndex ?? _state.position?.segmentIndex ?? 0;
      if (completedIndex + 1 < request.speechSegments.length) {
        _emit(
          _state.copyWith(
            phase: AudioEnginePhase.ready,
            position: event.position,
            clearFailure: true,
          ),
        );
        unawaited(
          Future<void>.microtask(
            () => _advanceAfterCompletion(completedIndex + 1, request),
          ),
        );
        return;
      }
    }

    _emit(
      _state.copyWith(
        phase: event.phase,
        position: event.position,
        failureCode: event.failureCode,
        clearFailure: event.failureCode == null,
        restoring: _restoring,
      ),
    );
    if (_restoring) return;
    switch (event.phase) {
      case AudioEnginePhase.playing:
        _schedulePersistence();
      case AudioEnginePhase.paused ||
            AudioEnginePhase.stopped ||
            AudioEnginePhase.interrupted ||
            AudioEnginePhase.failed:
        unawaited(_persistNow());
      case AudioEnginePhase.completed:
        _cancelPersistenceTimer();
        _cancelSleepTimer();
        _lastPrefetchKey = null;
        unawaited(_segmentPrefetcher.cancel().catchError((_) {}));
        unawaited(_systemSession.deactivate().catchError((_) {}));
        unawaited(_repository.clear(request.item.id).catchError((_) {}));
      case AudioEnginePhase.idle ||
            AudioEnginePhase.loading ||
            AudioEnginePhase.ready:
        break;
    }
  }

  void _handleSystemEvent(AudioSystemEvent event) {
    if (_disposed) return;
    switch (event.type) {
      case AudioSystemEventType.play:
        unawaited(play());
      case AudioSystemEventType.pause:
        unawaited(pause());
      case AudioSystemEventType.stop:
        unawaited(stop());
      case AudioSystemEventType.skipNext:
        unawaited(skipNext());
      case AudioSystemEventType.skipPrevious:
        unawaited(skipPrevious());
      case AudioSystemEventType.interruptionBegan:
        unawaited(_pauseForInterruption());
      case AudioSystemEventType.interruptionEnded:
        if (_resumeAfterInterruption && event.mayResume) {
          _resumeAfterInterruption = false;
          unawaited(play());
        } else {
          _resumeAfterInterruption = false;
        }
      case AudioSystemEventType.becomingNoisy:
        _resumeAfterInterruption = false;
        unawaited(pause());
    }
  }

  Future<void> _pauseForInterruption() async {
    if (_state.phase != AudioEnginePhase.playing) return;
    _resumeAfterInterruption = true;
    try {
      await _engine.pause();
      await _persistNow();
      await _systemSession.deactivate();
      _emit(
        _state.copyWith(
          phase: AudioEnginePhase.interrupted,
          clearFailure: true,
        ),
      );
    } on Object {
      _resumeAfterInterruption = false;
      _fail('audio_interruption_pause_failed');
    }
  }

  Future<void> _advanceAfterCompletion(
    int nextSegmentIndex,
    AudioLoadRequest request,
  ) async {
    final generation = _generation;
    try {
      await _engine.seek(
        AudioPlaybackPosition.speech(segmentIndex: nextSegmentIndex),
      );
      if (!_isCurrent(generation, request.item.id)) return;
      await _engine.play();
    } on Object {
      _fail('audio_segment_advance_failed');
    }
  }

  AudioPlaybackSettings _restoredSettings(
    AudioPlaybackSnapshot? snapshot,
    List<AudioVoice> voices,
  ) {
    final stored = snapshot?.settings ?? _state.settings;
    final voiceId = stored.voiceId;
    if (voiceId == null || voices.any((voice) => voice.id == voiceId)) {
      return stored;
    }
    return AudioPlaybackSettings(
      rate: stored.rate,
      pitch: stored.pitch,
      languageTag: stored.languageTag,
    );
  }

  AudioPlaybackPosition? _restoredPosition(
    AudioLoadRequest request,
    AudioPlaybackSnapshot? snapshot,
  ) {
    if (snapshot == null || snapshot.item.kind != request.item.kind)
      return null;
    if (request.item.kind == AudioKind.articleTts &&
        snapshot.contentRevision != request.contentRevision) {
      return null;
    }
    final position = snapshot.position;
    if (request.item.kind == AudioKind.podcastEpisode) {
      return position.isSpeech ? null : position;
    }
    final index = position.segmentIndex;
    final offset = position.characterOffset;
    if (index == null ||
        offset == null ||
        index < 0 ||
        index >= request.speechSegments.length ||
        offset < 0 ||
        offset > request.speechSegments[index].text.length) {
      return null;
    }
    return position;
  }

  AudioPlaybackPosition _initialPosition(AudioLoadRequest request) =>
      request.item.kind == AudioKind.articleTts
          ? const AudioPlaybackPosition.speech(segmentIndex: 0)
          : AudioPlaybackPosition.media(Duration.zero);

  void _schedulePersistence() {
    if (_restoring || _disposed) return;
    _persistenceTimer?.cancel();
    _persistenceTimer = _scheduler.schedule(persistenceDelay, () {
      _persistenceTimer = null;
      unawaited(_persistNow());
    });
  }

  Future<void> _persistNow() async {
    _cancelPersistenceTimer();
    final request = _state.request;
    final position = _state.position;
    if (_disposed ||
        _restoring ||
        request == null ||
        position == null ||
        !_validPosition(request, position)) {
      return;
    }
    try {
      await _repository.save(
        AudioPlaybackSnapshot(
          item: request.item,
          position: position,
          settings: _state.settings,
          contentRevision: request.contentRevision,
          updatedAt: _clock.now(),
        ),
      );
    } on Object {
      if (!_disposed) {
        _emit(_state.copyWith(failureCode: 'audio_progress_save_failed'));
      }
    }
  }

  bool _validPosition(
    AudioLoadRequest request,
    AudioPlaybackPosition position,
  ) {
    if (request.item.kind == AudioKind.podcastEpisode) {
      return !position.isSpeech;
    }
    final index = position.segmentIndex;
    final offset = position.characterOffset;
    return index != null &&
        offset != null &&
        index >= 0 &&
        index < request.speechSegments.length &&
        offset >= 0 &&
        offset <= request.speechSegments[index].text.length;
  }

  void _cancelPersistenceTimer() {
    _persistenceTimer?.cancel();
    _persistenceTimer = null;
  }

  void _cancelSleepTimer({bool updateState = true}) {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    if (updateState && _state.sleepDeadline != null) {
      _emit(_state.copyWith(clearSleepDeadline: true));
    }
  }

  void _fail(String code) {
    if (_disposed) return;
    _emit(
      _state.copyWith(
        phase: AudioEnginePhase.failed,
        failureCode: code,
        restoring: false,
      ),
    );
  }

  bool _isCurrent(int generation, String itemId) =>
      !_disposed &&
      generation == _generation &&
      _state.request?.item.id == itemId;

  void _emit(AudioPlaybackState state) {
    if (_disposed) return;
    _state = state;
    _states.add(state);
    _schedulePrefetch(state);
    final item = state.item;
    final position = state.position;
    if (item == null || position == null) {
      unawaited(_systemSession.clear().catchError((_) {}));
      return;
    }
    unawaited(
      _systemSession
          .publish(
            AudioSystemPlaybackState(
              item: item,
              phase: state.phase,
              position: position,
              settings: state.settings,
              canSkipPrevious: state.canSkipPrevious,
              canSkipNext: state.canSkipNext,
            ),
          )
          .catchError((_) {}),
    );
  }

  void _schedulePrefetch(AudioPlaybackState state) {
    if (_disposed ||
        state.restoring ||
        state.request?.item.kind != AudioKind.articleTts) {
      return;
    }
    if (state.phase != AudioEnginePhase.ready &&
        state.phase != AudioEnginePhase.playing &&
        state.phase != AudioEnginePhase.paused &&
        state.phase != AudioEnginePhase.interrupted) {
      return;
    }
    final request = state.request;
    final segmentIndex = state.position?.segmentIndex;
    if (request == null ||
        segmentIndex == null ||
        segmentIndex < 0 ||
        segmentIndex >= request.speechSegments.length) {
      return;
    }
    final settings = state.settings;
    final key = (
      request.item.id,
      request.contentRevision,
      segmentIndex,
      settings.rate,
      settings.pitch,
      settings.voiceId,
      settings.languageTag,
    );
    if (_lastPrefetchKey == key) return;
    _lastPrefetchKey = key;
    try {
      unawaited(
        _segmentPrefetcher
            .update(
              request: request,
              currentSegmentIndex: segmentIndex,
              settings: settings,
            )
            .catchError((_) {}),
      );
    } on Object {
      // A custom prefetcher may fail synchronously. Playback still continues.
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    await _persistNow();
    _disposed = true;
    _generation += 1;
    _cancelPersistenceTimer();
    _sleepTimer?.cancel();
    _sleepTimer = null;
    await _engineSubscription.cancel();
    await _systemSubscription.cancel();
    await _segmentPrefetcher.dispose().catchError((_) {});
    await _systemSession.clear().catchError((_) {});
    await _states.close();
  }
}
