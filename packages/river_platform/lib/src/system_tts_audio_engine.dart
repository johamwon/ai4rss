import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:river_domain/river_domain.dart';

typedef TtsVoidCallback = void Function();
typedef TtsProgressCallback = void Function(int start, int end);
typedef TtsErrorCallback = void Function();

final class SystemTtsCallbacks {
  const SystemTtsCallbacks({
    required this.onStarted,
    required this.onCompleted,
    required this.onPaused,
    required this.onContinued,
    required this.onCancelled,
    required this.onProgress,
    required this.onError,
  });

  final TtsVoidCallback onStarted;
  final TtsVoidCallback onCompleted;
  final TtsVoidCallback onPaused;
  final TtsVoidCallback onContinued;
  final TtsVoidCallback onCancelled;
  final TtsProgressCallback onProgress;
  final TtsErrorCallback onError;
}

abstract interface class SystemTtsClient {
  void configure(SystemTtsCallbacks callbacks);

  Future<List<Map<String, Object?>>> voices();
  Future<void> speak(String text);
  Future<void> pause();
  Future<void> stop();
  Future<void> setRate(double rate);
  Future<void> setPitch(double pitch);
  Future<void> setLanguage(String languageTag);
  Future<void> setVoice(Map<String, String> voice);
  Future<void> clearVoice();
}

final class FlutterTtsSystemClient implements SystemTtsClient {
  FlutterTtsSystemClient({FlutterTts? delegate})
      : _delegate = delegate ?? FlutterTts();

  final FlutterTts _delegate;

  @override
  void configure(SystemTtsCallbacks callbacks) {
    _delegate
      ..setStartHandler(callbacks.onStarted)
      ..setCompletionHandler(callbacks.onCompleted)
      ..setPauseHandler(callbacks.onPaused)
      ..setContinueHandler(callbacks.onContinued)
      ..setCancelHandler(callbacks.onCancelled)
      ..setProgressHandler(
        (text, start, end, word) => callbacks.onProgress(start, end),
      )
      ..setErrorHandler((message) => callbacks.onError());
  }

  @override
  Future<void> clearVoice() async {
    await _delegate.clearVoice();
  }

  @override
  Future<void> pause() async {
    await _delegate.pause();
  }

  @override
  Future<void> setLanguage(String languageTag) async {
    await _delegate.setLanguage(languageTag);
  }

  @override
  Future<void> setPitch(double pitch) async {
    await _delegate.setPitch(pitch);
  }

  @override
  Future<void> setRate(double rate) async {
    await _delegate.setSpeechRate(rate);
  }

  @override
  Future<void> setVoice(Map<String, String> voice) async {
    await _delegate.setVoice(voice);
  }

  @override
  Future<void> speak(String text) async {
    await _delegate.speak(text, focus: true);
  }

  @override
  Future<void> stop() async {
    await _delegate.stop();
  }

  @override
  Future<List<Map<String, Object?>>> voices() async {
    final value = await _delegate.getVoices;
    if (value is! List<Object?>) return const <Map<String, Object?>>[];
    return value
        .whereType<Map<Object?, Object?>>()
        .map(
          (voice) => <String, Object?>{
            for (final entry in voice.entries)
              entry.key.toString(): entry.value,
          },
        )
        .toList(growable: false);
  }
}

final class SystemTtsAudioEngine implements AudioEngine {
  SystemTtsAudioEngine({
    SystemTtsClient? client,
    TargetPlatform? platform,
  })  : _client = client ?? FlutterTtsSystemClient(),
        _platform = platform ?? defaultTargetPlatform {
    _client.configure(
      SystemTtsCallbacks(
        onStarted: _handleStarted,
        onCompleted: _handleCompleted,
        onPaused: _handlePaused,
        onContinued: _handleStarted,
        onCancelled: _handleStopped,
        onProgress: _handleProgress,
        onError: _handleError,
      ),
    );
  }

  final SystemTtsClient _client;
  final TargetPlatform _platform;
  final StreamController<AudioEngineEvent> _events =
      StreamController<AudioEngineEvent>.broadcast(sync: true);
  AudioLoadRequest? _request;
  AudioPlaybackSettings _settings = const AudioPlaybackSettings();
  Map<String, Map<String, String>> _nativeVoices =
      const <String, Map<String, String>>{};
  var _segmentIndex = 0;
  var _characterOffset = 0;
  var _spokenBaseOffset = 0;
  String? _selectedVoiceId;
  AudioEngineEvent? _lastEvent;
  var _paused = false;
  var _disposed = false;

  @override
  Stream<AudioEngineEvent> get events => _events.stream;

  @override
  Future<AudioEngineCapabilities> capabilities() async =>
      AudioEngineCapabilities(
        supportsArticleTts: _isSupportedPlatform,
        supportsPodcastMedia: false,
        canPause: _isSupportedPlatform,
        canResume: _isSupportedPlatform,
        canSeek: _isSupportedPlatform,
        canSetRate: _isSupportedPlatform,
        canSetPitch: _isSupportedPlatform,
        canSelectVoice: _isSupportedPlatform,
      );

  bool get _isSupportedPlatform =>
      _platform == TargetPlatform.android ||
      _platform == TargetPlatform.iOS ||
      _platform == TargetPlatform.windows;

  @override
  Future<List<AudioVoice>> voices() async {
    if (!_isSupportedPlatform || _disposed) return const <AudioVoice>[];
    try {
      final nativeVoices = await _client.voices();
      final descriptors = <String, Map<String, String>>{};
      final voices = <AudioVoice>[];
      for (final native in nativeVoices) {
        final name = native['name']?.toString().trim() ?? '';
        final locale = native['locale']?.toString().trim() ?? '';
        if (name.isEmpty || locale.isEmpty) continue;
        final identifier = native['identifier']?.toString().trim();
        final id = identifier == null || identifier.isEmpty
            ? '$locale::$name'
            : identifier;
        final descriptor = <String, String>{
          'name': name,
          'locale': locale,
          if (identifier != null && identifier.isNotEmpty)
            'identifier': identifier,
        };
        descriptors[id] = descriptor;
        voices.add(
          AudioVoice(
            id: id,
            name: name,
            languageTag: locale,
            isLocal: !_isTrue(native['network_required']),
          ),
        );
      }
      _nativeVoices = Map<String, Map<String, String>>.unmodifiable(
        descriptors,
      );
      return List<AudioVoice>.unmodifiable(voices);
    } on Object {
      _emitFailure('tts_voices_unavailable');
      return const <AudioVoice>[];
    }
  }

  @override
  Future<void> load(AudioLoadRequest request) async {
    if (!_ensureAvailable()) return;
    if (request.item.kind != AudioKind.articleTts) {
      try {
        await _client.stop();
      } on Object {
        // Replacing an unsupported source still clears the previous request.
      }
      _request = null;
      _segmentIndex = 0;
      _characterOffset = 0;
      _paused = false;
      _emitFailure('tts_unsupported_audio_kind', itemId: request.item.id);
      return;
    }
    _emit(AudioEnginePhase.loading, itemId: request.item.id);
    try {
      await _client.stop();
      _request = request;
      _segmentIndex = 0;
      _characterOffset = 0;
      _spokenBaseOffset = 0;
      _paused = false;
      _emit(
        AudioEnginePhase.ready,
        position: const AudioPlaybackPosition.speech(segmentIndex: 0),
      );
    } on Object {
      _emitFailure('tts_load_failed', itemId: request.item.id);
    }
  }

  @override
  Future<void> play() => _speakCurrentSegment(resuming: _paused);

  @override
  Future<void> resume() => _speakCurrentSegment(resuming: true);

  Future<void> _speakCurrentSegment({required bool resuming}) async {
    if (!_ensureAvailable()) return;
    final request = _request;
    if (request == null) {
      _emitFailure('tts_not_loaded');
      return;
    }
    final segment = request.speechSegments[_segmentIndex];
    final offset = _characterOffset.clamp(0, segment.text.length).toInt();
    if (offset == segment.text.length) {
      _emit(
        AudioEnginePhase.completed,
        position: AudioPlaybackPosition.speech(
          segmentIndex: _segmentIndex,
          characterOffset: offset,
        ),
      );
      return;
    }
    try {
      final language = _settings.languageTag ?? segment.languageTag;
      if (language != null) await _client.setLanguage(language);
      final continuesNativeUtterance =
          resuming && _paused && _platform != TargetPlatform.android;
      _spokenBaseOffset = continuesNativeUtterance ? 0 : offset;
      await _client.speak(
        continuesNativeUtterance
            ? segment.text
            : segment.text.substring(offset),
      );
    } on Object {
      _emitFailure('tts_speak_failed');
    }
  }

  @override
  Future<void> pause() async {
    if (!_ensureAvailable()) return;
    if (_request == null) {
      _emitFailure('tts_not_loaded');
      return;
    }
    try {
      await _client.pause();
      _handlePaused();
    } on Object {
      _emitFailure('tts_pause_failed');
    }
  }

  @override
  Future<void> stop() async {
    if (_disposed) return;
    try {
      await _client.stop();
      _handleStopped();
    } on Object {
      _emitFailure('tts_stop_failed');
    }
  }

  @override
  Future<void> seek(AudioPlaybackPosition position) async {
    if (!_ensureAvailable()) return;
    final request = _request;
    if (request == null) {
      _emitFailure('tts_not_loaded');
      return;
    }
    final segmentIndex = position.segmentIndex;
    if (segmentIndex == null || segmentIndex >= request.speechSegments.length) {
      _emitFailure('tts_invalid_position');
      return;
    }
    final segment = request.speechSegments[segmentIndex];
    final characterOffset = position.characterOffset ?? 0;
    if (characterOffset > segment.text.length) {
      _emitFailure('tts_invalid_position');
      return;
    }
    try {
      await _client.stop();
      _segmentIndex = segmentIndex;
      _characterOffset = characterOffset;
      _spokenBaseOffset = characterOffset;
      _paused = false;
      _emit(
        AudioEnginePhase.ready,
        position: AudioPlaybackPosition.speech(
          segmentIndex: segmentIndex,
          characterOffset: characterOffset,
        ),
      );
    } on Object {
      _emitFailure('tts_seek_failed');
    }
  }

  @override
  Future<void> updateSettings(AudioPlaybackSettings settings) async {
    if (!_ensureAvailable()) return;
    try {
      await _client.setRate(_nativeRate(settings.rate));
      await _client.setPitch(settings.pitch);
      if (settings.languageTag case final language?) {
        await _client.setLanguage(language);
      }
      if (settings.voiceId case final voiceId?) {
        if (_nativeVoices.isEmpty) await voices();
        final descriptor = _nativeVoices[voiceId];
        if (descriptor == null) {
          _emitFailure('tts_voice_unavailable');
          return;
        }
        await _client.setVoice(descriptor);
        _selectedVoiceId = voiceId;
      } else if (_selectedVoiceId != null &&
          _platform != TargetPlatform.windows) {
        await _client.clearVoice();
        _selectedVoiceId = null;
      }
      _settings = settings;
    } on Object {
      _emitFailure('tts_settings_failed');
    }
  }

  double _nativeRate(double rate) =>
      rate <= 1 ? rate * 0.5 : 0.5 + ((rate - 1) * 0.25);

  void _handleStarted() {
    _paused = false;
    _emit(AudioEnginePhase.playing, position: _currentPosition);
  }

  void _handleCompleted() {
    _paused = false;
    final segment = _currentSegment;
    if (segment != null) _characterOffset = segment.text.length;
    _emit(AudioEnginePhase.completed, position: _currentPosition);
  }

  void _handlePaused() {
    _paused = true;
    _emit(
      AudioEnginePhase.paused,
      position: _request == null ? null : _currentPosition,
    );
  }

  void _handleStopped() {
    _paused = false;
    _emit(
      AudioEnginePhase.stopped,
      position: _request == null ? null : _currentPosition,
    );
  }

  void _handleProgress(int start, int end) {
    final segment = _currentSegment;
    if (segment == null) return;
    _characterOffset =
        (_spokenBaseOffset + start).clamp(0, segment.text.length).toInt();
    _emit(AudioEnginePhase.playing, position: _currentPosition);
  }

  void _handleError() {
    _paused = false;
    _emitFailure('tts_engine_error');
  }

  SpeechSegment? get _currentSegment {
    final request = _request;
    if (request == null || _segmentIndex >= request.speechSegments.length) {
      return null;
    }
    return request.speechSegments[_segmentIndex];
  }

  AudioPlaybackPosition get _currentPosition => AudioPlaybackPosition.speech(
        segmentIndex: _segmentIndex,
        characterOffset: _characterOffset,
      );

  bool _ensureAvailable() {
    if (_disposed) return false;
    if (_isSupportedPlatform) return true;
    _emitFailure('tts_platform_unsupported');
    return false;
  }

  void _emit(
    AudioEnginePhase phase, {
    String? itemId,
    AudioPlaybackPosition? position,
  }) {
    if (_disposed) return;
    _addEvent(
      AudioEngineEvent(
        phase: phase,
        itemId: itemId ?? _request?.item.id,
        position: position,
      ),
    );
  }

  void _emitFailure(String code, {String? itemId}) {
    if (_disposed) return;
    _addEvent(
      AudioEngineEvent(
        phase: AudioEnginePhase.failed,
        itemId: itemId ?? _request?.item.id,
        position: _request == null ? null : _currentPosition,
        failureCode: code,
      ),
    );
  }

  void _addEvent(AudioEngineEvent event) {
    final previous = _lastEvent;
    if (previous != null &&
        previous.phase == event.phase &&
        previous.itemId == event.itemId &&
        previous.failureCode == event.failureCode &&
        previous.position?.mediaPosition == event.position?.mediaPosition &&
        previous.position?.segmentIndex == event.position?.segmentIndex &&
        previous.position?.characterOffset == event.position?.characterOffset) {
      return;
    }
    _lastEvent = event;
    _events.add(event);
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    try {
      await _client.stop();
    } on Object {
      // Disposal is best effort and must never surface vendor errors.
    }
    await _events.close();
  }
}

bool _isTrue(Object? value) =>
    value == true || value?.toString().toLowerCase() == 'true';
