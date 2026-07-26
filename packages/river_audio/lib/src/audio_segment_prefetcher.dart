import 'dart:async';

import 'package:river_domain/river_domain.dart';

final class AudioPrefetchCancelledException implements Exception {
  const AudioPrefetchCancelledException();
}

final class AudioPrefetchCancellation {
  var _cancelled = false;
  final Completer<void> _whenCancelled = Completer<void>();

  bool get isCancelled => _cancelled;
  Future<void> get whenCancelled => _whenCancelled.future;

  void throwIfCancelled() {
    if (_cancelled) throw const AudioPrefetchCancelledException();
  }

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    _whenCancelled.complete();
  }
}

final class AudioSegmentPreparationRequest {
  const AudioSegmentPreparationRequest({
    required this.item,
    required this.contentRevision,
    required this.segment,
    required this.settings,
  });

  final AudioItem item;
  final String contentRevision;
  final SpeechSegment segment;
  final AudioPlaybackSettings settings;
}

abstract interface class PreparedAudioSegment {
  int get segmentIndex;
  int get retainedBytes;
  Future<void> release();
}

abstract interface class AudioSegmentPreparationBackend {
  Future<PreparedAudioSegment> prepare(
    AudioSegmentPreparationRequest request,
    AudioPrefetchCancellation cancellation,
  );
}

abstract interface class AudioSegmentPrefetcher {
  Future<void> update({
    required AudioLoadRequest request,
    required int currentSegmentIndex,
    required AudioPlaybackSettings settings,
  });

  Future<void> cancel();
  Future<void> dispose();
}

final class UnavailableAudioSegmentPrefetcher
    implements AudioSegmentPrefetcher {
  const UnavailableAudioSegmentPrefetcher();

  @override
  Future<void> cancel() async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<void> update({
    required AudioLoadRequest request,
    required int currentSegmentIndex,
    required AudioPlaybackSettings settings,
  }) async {}
}

enum AudioSegmentPrefetchPhase { idle, preparing, ready, degraded, disposed }

final class AudioSegmentPrefetchState {
  AudioSegmentPrefetchState({
    required this.phase,
    required this.itemId,
    required this.contentRevision,
    required Set<int> preparing,
    required Set<int> prepared,
    required this.retainedBytes,
    this.failureCode,
  })  : preparing = Set<int>.unmodifiable(preparing),
        prepared = Set<int>.unmodifiable(prepared);

  const AudioSegmentPrefetchState.idle()
      : phase = AudioSegmentPrefetchPhase.idle,
        itemId = null,
        contentRevision = null,
        preparing = const <int>{},
        prepared = const <int>{},
        retainedBytes = 0,
        failureCode = null;

  final AudioSegmentPrefetchPhase phase;
  final String? itemId;
  final String? contentRevision;
  final Set<int> preparing;
  final Set<int> prepared;
  final int retainedBytes;
  final String? failureCode;
}

final class BoundedAudioSegmentPrefetcher implements AudioSegmentPrefetcher {
  BoundedAudioSegmentPrefetcher({
    required AudioSegmentPreparationBackend backend,
    this.lookAheadSegments = 3,
    this.maxConcurrentPreparations = 2,
    this.maxRetainedBytes = 8 * 1024 * 1024,
  })  : assert(lookAheadSegments >= 0 && lookAheadSegments <= 16),
        assert(
          maxConcurrentPreparations >= 1 && maxConcurrentPreparations <= 4,
        ),
        assert(maxRetainedBytes >= 64 * 1024),
        _backend = backend;

  final AudioSegmentPreparationBackend _backend;
  final int lookAheadSegments;
  final int maxConcurrentPreparations;
  final int maxRetainedBytes;
  final StreamController<AudioSegmentPrefetchState> _states =
      StreamController<AudioSegmentPrefetchState>.broadcast(sync: true);
  final Map<int, PreparedAudioSegment> _prepared =
      <int, PreparedAudioSegment>{};
  final Map<int, AudioPrefetchCancellation> _preparing =
      <int, AudioPrefetchCancellation>{};
  AudioSegmentPrefetchState _state = const AudioSegmentPrefetchState.idle();
  Set<int> _desired = const <int>{};
  var _generation = 0;
  var _retainedBytes = 0;
  var _disposed = false;
  String? _itemId;
  String? _contentRevision;
  (double, double, String?, String?)? _settingsKey;
  String? _failureCode;

  AudioSegmentPrefetchState get state => _state;
  Stream<AudioSegmentPrefetchState> get states => _states.stream;

  @override
  Future<void> update({
    required AudioLoadRequest request,
    required int currentSegmentIndex,
    required AudioPlaybackSettings settings,
  }) async {
    if (_disposed ||
        request.item.kind != AudioKind.articleTts ||
        currentSegmentIndex < 0 ||
        currentSegmentIndex >= request.speechSegments.length) {
      return;
    }
    final revision = request.contentRevision;
    if (revision == null || revision.isEmpty) return;

    final settingsKey = _keyForSettings(settings);
    final identityChanged = _itemId != request.item.id ||
        _contentRevision != revision ||
        _settingsKey != settingsKey;
    final generation = ++_generation;
    _cancelPreparing();
    if (identityChanged) {
      await _releaseAllPrepared();
    }
    if (_disposed || generation != _generation) return;

    _itemId = request.item.id;
    _contentRevision = revision;
    _settingsKey = settingsKey;
    _failureCode = null;
    final end = (currentSegmentIndex + lookAheadSegments + 1)
        .clamp(0, request.speechSegments.length);
    _desired = <int>{
      for (var index = currentSegmentIndex; index < end; index += 1) index,
    };
    await _releaseUndesired();
    if (_disposed || generation != _generation) return;

    final queue = _desired
        .where((index) => !_prepared.containsKey(index))
        .toList(growable: false)
      ..sort();
    if (queue.isEmpty) {
      _emit();
      return;
    }
    _emit(preparing: true);
    var cursor = 0;
    Future<void> worker() async {
      while (!_disposed && generation == _generation) {
        if (cursor >= queue.length) return;
        final index = queue[cursor];
        cursor += 1;
        await _prepareOne(
          generation: generation,
          request: request,
          settings: settings,
          index: index,
        );
      }
    }

    await Future.wait(
      <Future<void>>[
        for (var workerIndex = 0;
            workerIndex < maxConcurrentPreparations &&
                workerIndex < queue.length;
            workerIndex += 1)
          worker(),
      ],
    );
    if (!_disposed && generation == _generation) _emit();
  }

  Future<void> _prepareOne({
    required int generation,
    required AudioLoadRequest request,
    required AudioPlaybackSettings settings,
    required int index,
  }) async {
    final cancellation = AudioPrefetchCancellation();
    _preparing[index] = cancellation;
    _emit(preparing: true);
    PreparedAudioSegment? prepared;
    try {
      prepared = await _backend.prepare(
        AudioSegmentPreparationRequest(
          item: request.item,
          contentRevision: request.contentRevision!,
          segment: request.speechSegments[index],
          settings: settings,
        ),
        cancellation,
      );
      if (prepared.segmentIndex != index || prepared.retainedBytes < 0) {
        _failureCode = 'audio_prefetch_invalid_resource';
        await _releaseDetached(prepared);
        return;
      }
      if (_disposed ||
          generation != _generation ||
          cancellation.isCancelled ||
          !_desired.contains(index)) {
        await _releaseDetached(prepared);
        return;
      }
      await _retainWithinBudget(prepared, currentIndex: _desired.first);
    } on AudioPrefetchCancelledException {
      if (prepared != null) await _releaseDetached(prepared);
    } on Object {
      if (prepared != null) await _releaseDetached(prepared);
      if (!_disposed &&
          generation == _generation &&
          !cancellation.isCancelled) {
        _failureCode = 'audio_segment_prepare_failed';
      }
    } finally {
      if (identical(_preparing[index], cancellation)) {
        _preparing.remove(index);
      }
      if (!_disposed && generation == _generation) {
        _emit(preparing: _preparing.isNotEmpty);
      }
    }
  }

  Future<void> _retainWithinBudget(
    PreparedAudioSegment prepared, {
    required int currentIndex,
  }) async {
    if (prepared.retainedBytes > maxRetainedBytes) {
      _failureCode = 'audio_prefetch_resource_too_large';
      await _releaseDetached(prepared);
      return;
    }
    while (_retainedBytes + prepared.retainedBytes > maxRetainedBytes) {
      final candidates = _prepared.keys
          .where((index) => index != currentIndex)
          .toList(growable: false)
        ..sort((left, right) => right.compareTo(left));
      if (candidates.isEmpty) {
        await _releaseDetached(prepared);
        return;
      }
      await _releasePrepared(candidates.first);
    }
    _prepared[prepared.segmentIndex] = prepared;
    _retainedBytes += prepared.retainedBytes;
  }

  @override
  Future<void> cancel() async {
    if (_disposed) return;
    _generation += 1;
    _cancelPreparing();
    _desired = const <int>{};
    await _releaseAllPrepared();
    _itemId = null;
    _contentRevision = null;
    _settingsKey = null;
    _failureCode = null;
    _emit();
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _generation += 1;
    _cancelPreparing();
    _desired = const <int>{};
    await _releaseAllPrepared();
    _state = AudioSegmentPrefetchState(
      phase: AudioSegmentPrefetchPhase.disposed,
      itemId: null,
      contentRevision: null,
      preparing: const <int>{},
      prepared: const <int>{},
      retainedBytes: 0,
    );
    await _states.close();
  }

  void _cancelPreparing() {
    for (final cancellation in _preparing.values) {
      cancellation.cancel();
    }
    _preparing.clear();
  }

  Future<void> _releaseUndesired() async {
    final stale = _prepared.keys
        .where((index) => !_desired.contains(index))
        .toList(growable: false);
    for (final index in stale) {
      await _releasePrepared(index);
    }
  }

  Future<void> _releaseAllPrepared() async {
    final indexes = _prepared.keys.toList(growable: false);
    for (final index in indexes) {
      await _releasePrepared(index);
    }
  }

  Future<void> _releasePrepared(int index) async {
    final prepared = _prepared.remove(index);
    if (prepared == null) return;
    _retainedBytes -= prepared.retainedBytes;
    try {
      await prepared.release();
    } on Object {
      _failureCode ??= 'audio_prefetch_release_failed';
    }
  }

  Future<void> _releaseDetached(PreparedAudioSegment prepared) async {
    try {
      await prepared.release();
    } on Object {
      _failureCode ??= 'audio_prefetch_release_failed';
    }
  }

  void _emit({bool preparing = false}) {
    if (_disposed) return;
    final phase = _failureCode != null
        ? AudioSegmentPrefetchPhase.degraded
        : preparing || _preparing.isNotEmpty
            ? AudioSegmentPrefetchPhase.preparing
            : _prepared.isEmpty
                ? AudioSegmentPrefetchPhase.idle
                : AudioSegmentPrefetchPhase.ready;
    _state = AudioSegmentPrefetchState(
      phase: phase,
      itemId: _itemId,
      contentRevision: _contentRevision,
      preparing: _preparing.keys.toSet(),
      prepared: _prepared.keys.toSet(),
      retainedBytes: _retainedBytes,
      failureCode: _failureCode,
    );
    _states.add(_state);
  }

  (double, double, String?, String?) _keyForSettings(
    AudioPlaybackSettings settings,
  ) =>
      (
        settings.rate,
        settings.pitch,
        settings.voiceId,
        settings.languageTag,
      );
}
