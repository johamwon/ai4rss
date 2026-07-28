import 'dart:async';

import 'package:river_domain/river_domain.dart';

import 'audio_playback_controller.dart';

final class ResolvedAudioQueueItem {
  const ResolvedAudioQueueItem({
    required this.request,
    this.settings,
  });

  final AudioLoadRequest request;
  final AudioPlaybackSettings? settings;
}

typedef AudioQueueRequestResolver = Future<ResolvedAudioQueueItem?> Function(
  AudioQueueEntry entry,
);

final class PersistentAudioQueue {
  const PersistentAudioQueue({
    required AudioQueueRepository repository,
    required Clock clock,
  })  : _repository = repository,
        _clock = clock;

  final AudioQueueRepository _repository;
  final Clock _clock;

  Stream<AudioQueueSnapshot> get snapshots => _repository.watch();

  Future<AudioQueueSnapshot> read() => _repository.read();

  Future<bool> enqueue(
    AudioItem item, {
    String? contentRevision,
  }) =>
      _repository.enqueue(
        item: item,
        contentRevision: contentRevision,
        enqueuedAt: _clock.now(),
      );

  Future<void> move(String itemId, int targetIndex) => _repository.move(
        itemId: itemId,
        targetIndex: targetIndex,
        updatedAt: _clock.now(),
      );

  Future<void> select(String itemId) => _repository.select(
        itemId: itemId,
        updatedAt: _clock.now(),
      );

  Future<void> remove(String itemId) => _repository.remove(
        itemId: itemId,
        updatedAt: _clock.now(),
      );

  Future<AudioQueueEntry?> consumeCurrent() =>
      _repository.consumeCurrent(updatedAt: _clock.now());

  Future<void> clear() => _repository.clear();

  Future<AudioQueueEntry?> selectNext() => _selectRelative(1);

  Future<AudioQueueEntry?> selectPrevious() => _selectRelative(-1);

  Future<AudioQueueEntry?> _selectRelative(int delta) async {
    final snapshot = await read();
    if (snapshot.entries.isEmpty) return null;
    final currentIndex = snapshot.currentIndex < 0 ? 0 : snapshot.currentIndex;
    final targetIndex = currentIndex + delta;
    if (targetIndex < 0 || targetIndex >= snapshot.entries.length) return null;
    final target = snapshot.entries[targetIndex];
    await select(target.item.id);
    return target;
  }
}

final class AudioQueuePlaybackCoordinator {
  AudioQueuePlaybackCoordinator({
    required PersistentAudioQueue queue,
    required AudioPlaybackController playback,
    required AudioQueueRequestResolver resolve,
  })  : _queue = queue,
        _playback = playback,
        _resolve = resolve {
    _subscription = _playback.states.listen(_handlePlaybackState);
  }

  final PersistentAudioQueue _queue;
  final AudioPlaybackController _playback;
  final AudioQueueRequestResolver _resolve;
  late final StreamSubscription<AudioPlaybackState> _subscription;
  var _advancing = false;
  var _disposed = false;
  String? _handledCompletionId;

  Future<bool> playCurrent() async {
    final current = (await _queue.read()).current;
    return current != null && await _play(current);
  }

  Future<bool> play(String itemId) async {
    final snapshot = await _queue.read();
    final entry = snapshot.entries
        .where((candidate) => candidate.item.id == itemId)
        .firstOrNull;
    if (entry == null) return false;
    await _queue.select(itemId);
    return _play(entry);
  }

  Future<bool> playNext() async {
    final entry = await _queue.selectNext();
    return entry != null && await _play(entry);
  }

  Future<bool> playPrevious() async {
    final entry = await _queue.selectPrevious();
    return entry != null && await _play(entry);
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _subscription.cancel();
  }

  Future<bool> _play(AudioQueueEntry entry) async {
    if (_disposed) return false;
    ResolvedAudioQueueItem? resolved;
    try {
      resolved = await _resolve(entry);
    } on Object {
      return false;
    }
    if (_disposed ||
        resolved == null ||
        resolved.request.item.id != entry.item.id) {
      return false;
    }
    _handledCompletionId = null;
    await _playback.load(resolved.request);
    if (_playback.state.phase == AudioEnginePhase.failed) return false;
    if (resolved.settings case final settings?) {
      await _playback.updateSettings(settings);
      if (_playback.state.phase == AudioEnginePhase.failed) return false;
    }
    await _playback.play();
    return _playback.state.phase != AudioEnginePhase.failed;
  }

  void _handlePlaybackState(AudioPlaybackState state) {
    if (_disposed ||
        state.phase != AudioEnginePhase.completed ||
        state.item == null ||
        _handledCompletionId == state.item!.id) {
      return;
    }
    _handledCompletionId = state.item!.id;
    unawaited(_advance(state.item!.id));
  }

  Future<void> _advance(String completedItemId) async {
    if (_advancing || _disposed) return;
    _advancing = true;
    try {
      final snapshot = await _queue.read();
      if (snapshot.current?.item.id != completedItemId) return;
      await _queue.consumeCurrent();
      if (_disposed) return;
      final next = (await _queue.read()).current;
      if (next != null) await _play(next);
    } finally {
      _advancing = false;
    }
  }
}
