import 'dart:async';

import 'package:river_audio/river_audio.dart';
import 'package:river_domain/river_domain.dart';
import 'package:test/test.dart';

void main() {
  test('persistent queue deduplicates and selects across source kinds',
      () async {
    final repository = _MemoryQueueRepository();
    final queue = PersistentAudioQueue(
      repository: repository,
      clock: const _Clock(),
    );

    expect(
      await queue.enqueue(_article, contentRevision: 'revision-1'),
      isTrue,
    );
    expect(await queue.enqueue(_podcast), isTrue);
    expect(
      await queue.enqueue(_article, contentRevision: 'revision-2'),
      isFalse,
    );
    expect((await queue.read()).current?.item.id, _article.id);

    expect((await queue.selectNext())?.item.id, _podcast.id);
    expect((await queue.read()).current?.item.id, _podcast.id);
    expect(await queue.selectNext(), isNull);
    expect((await queue.selectPrevious())?.item.id, _article.id);
  });

  test('completion consumes current and continuously plays the mixed queue',
      () async {
    final repository = _MemoryQueueRepository();
    final queue = PersistentAudioQueue(
      repository: repository,
      clock: const _Clock(),
    );
    await queue.enqueue(_podcast);
    await queue.enqueue(_article, contentRevision: 'revision-1');

    final engine = _Engine();
    final playback = AudioPlaybackController(
      engine: engine,
      repository: const UnavailableAudioPlaybackRepository(),
      clock: const _Clock(),
    );
    final coordinator = AudioQueuePlaybackCoordinator(
      queue: queue,
      playback: playback,
      resolve: (entry) async => switch (entry.item.kind) {
        AudioKind.podcastEpisode => ResolvedAudioQueueItem(
            request: AudioLoadRequest(item: entry.item),
            settings: const AudioPlaybackSettings(rate: 1.5),
          ),
        AudioKind.articleTts => ResolvedAudioQueueItem(
            request: AudioLoadRequest(
              item: entry.item,
              speechSegments: const <SpeechSegment>[
                SpeechSegment(
                  index: 0,
                  text: 'Article sentence.',
                  sourceStart: 0,
                  sourceEnd: 17,
                ),
              ],
              contentRevision: entry.contentRevision,
            ),
          ),
      },
    );

    expect(await coordinator.playCurrent(), isTrue);
    expect(engine.loads.map((request) => request.item.id), <String>[
      _podcast.id,
    ]);
    expect(engine.settings.last.rate, 1.5);

    engine.complete();
    await _until(() => engine.loads.length == 2);
    expect(engine.loads.last.item.id, _article.id);
    expect((await queue.read()).current?.item.id, _article.id);
    expect((await queue.read()).entries, hasLength(1));

    engine.complete();
    await _until(() async => (await queue.read()).entries.isEmpty);
    expect((await queue.read()).entries, isEmpty);

    await coordinator.dispose();
    await playback.dispose();
    await engine.close();
  });

  test('an unresolved item remains selected for explicit recovery', () async {
    final repository = _MemoryQueueRepository();
    final queue = PersistentAudioQueue(
      repository: repository,
      clock: const _Clock(),
    );
    await queue.enqueue(_podcast);
    final engine = _Engine();
    final playback = AudioPlaybackController(
      engine: engine,
      repository: const UnavailableAudioPlaybackRepository(),
      clock: const _Clock(),
    );
    final coordinator = AudioQueuePlaybackCoordinator(
      queue: queue,
      playback: playback,
      resolve: (_) async => null,
    );

    expect(await coordinator.playCurrent(), isFalse);
    expect((await queue.read()).current?.item.id, _podcast.id);
    expect(engine.loads, isEmpty);

    await coordinator.dispose();
    await playback.dispose();
    await engine.close();
  });
}

final class _MemoryQueueRepository implements AudioQueueRepository {
  final List<AudioQueueEntry> _entries = <AudioQueueEntry>[];

  @override
  Future<void> clear() async => _entries.clear();

  @override
  Future<AudioQueueEntry?> consumeCurrent({
    required DateTime updatedAt,
  }) async {
    final currentIndex = _currentIndex;
    if (currentIndex < 0) return null;
    final consumed = _entries.removeAt(currentIndex);
    _normalize(
      currentId: _entries.isEmpty
          ? null
          : _entries[currentIndex.clamp(0, _entries.length - 1)].item.id,
      updatedAt: updatedAt,
    );
    return consumed;
  }

  @override
  Future<bool> enqueue({
    required AudioItem item,
    required String? contentRevision,
    required DateTime enqueuedAt,
  }) async {
    if (_entries.any((entry) => entry.item.id == item.id)) return false;
    _entries.add(
      AudioQueueEntry(
        item: item,
        position: _entries.length,
        isCurrent: _entries.isEmpty,
        contentRevision: contentRevision,
        enqueuedAt: enqueuedAt,
        updatedAt: enqueuedAt,
      ),
    );
    return true;
  }

  @override
  Future<void> move({
    required String itemId,
    required int targetIndex,
    required DateTime updatedAt,
  }) async {
    final from = _entries.indexWhere((entry) => entry.item.id == itemId);
    if (from < 0) return;
    final currentId = readCurrentId;
    final entry = _entries.removeAt(from);
    _entries.insert(targetIndex.clamp(0, _entries.length), entry);
    _normalize(currentId: currentId, updatedAt: updatedAt);
  }

  @override
  Future<AudioQueueSnapshot> read() async => AudioQueueSnapshot(_entries);

  @override
  Future<void> remove({
    required String itemId,
    required DateTime updatedAt,
  }) async {
    final index = _entries.indexWhere((entry) => entry.item.id == itemId);
    if (index < 0) return;
    final wasCurrent = _entries[index].isCurrent;
    _entries.removeAt(index);
    _normalize(
      currentId: wasCurrent && _entries.isNotEmpty
          ? _entries[index.clamp(0, _entries.length - 1)].item.id
          : readCurrentId,
      updatedAt: updatedAt,
    );
  }

  @override
  Future<void> select({
    required String itemId,
    required DateTime updatedAt,
  }) async {
    if (_entries.every((entry) => entry.item.id != itemId)) return;
    _normalize(currentId: itemId, updatedAt: updatedAt);
  }

  @override
  Stream<AudioQueueSnapshot> watch() =>
      Stream<AudioQueueSnapshot>.value(AudioQueueSnapshot(_entries));

  int get _currentIndex => _entries.indexWhere((entry) => entry.isCurrent);

  String? get readCurrentId =>
      _currentIndex < 0 ? null : _entries[_currentIndex].item.id;

  void _normalize({
    required String? currentId,
    required DateTime updatedAt,
  }) {
    for (var index = 0; index < _entries.length; index += 1) {
      final entry = _entries[index];
      _entries[index] = AudioQueueEntry(
        item: entry.item,
        position: index,
        isCurrent: entry.item.id == currentId,
        contentRevision: entry.contentRevision,
        enqueuedAt: entry.enqueuedAt,
        updatedAt: updatedAt,
      );
    }
  }
}

final class _Engine implements AudioEngine {
  final StreamController<AudioEngineEvent> _events =
      StreamController<AudioEngineEvent>.broadcast(sync: true);
  final List<AudioLoadRequest> loads = <AudioLoadRequest>[];
  final List<AudioPlaybackSettings> settings = <AudioPlaybackSettings>[];
  AudioLoadRequest? current;

  @override
  Stream<AudioEngineEvent> get events => _events.stream;

  @override
  Future<AudioEngineCapabilities> capabilities() async =>
      const AudioEngineCapabilities(
        supportsArticleTts: true,
        supportsPodcastMedia: true,
        canPause: true,
        canResume: true,
        canSeek: true,
        canSetRate: true,
        canSetPitch: true,
        canSelectVoice: true,
      );

  @override
  Future<List<AudioVoice>> voices() async => const <AudioVoice>[];

  @override
  Future<void> load(AudioLoadRequest request) async {
    current = request;
    loads.add(request);
  }

  @override
  Future<void> play() async {
    _events.add(
      AudioEngineEvent(
        phase: AudioEnginePhase.playing,
        itemId: current?.item.id,
        position: _position(),
      ),
    );
  }

  void complete() {
    _events.add(
      AudioEngineEvent(
        phase: AudioEnginePhase.completed,
        itemId: current?.item.id,
        position: _position(),
      ),
    );
  }

  AudioPlaybackPosition _position() =>
      current?.item.kind == AudioKind.articleTts
          ? const AudioPlaybackPosition.speech(segmentIndex: 0)
          : AudioPlaybackPosition.media(Duration.zero);

  Future<void> close() => _events.close();

  @override
  Future<void> dispose() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<void> seek(AudioPlaybackPosition position) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> updateSettings(AudioPlaybackSettings settings) async {
    this.settings.add(settings);
  }
}

Future<void> _until(FutureOr<bool> Function() condition) async {
  for (var attempt = 0; attempt < 100; attempt += 1) {
    if (await condition()) return;
    await Future<void>.delayed(Duration.zero);
  }
  fail('Condition was not reached.');
}

final class _Clock implements Clock {
  const _Clock();

  @override
  DateTime now() => DateTime.utc(2026, 7, 28, 10);
}

final _article = AudioItem(
  id: 'article-1',
  kind: AudioKind.articleTts,
  title: 'Article',
  sourceUri: Uri.parse('https://example.test/articles/1'),
);

final _podcast = AudioItem(
  id: 'podcast-1',
  kind: AudioKind.podcastEpisode,
  title: 'Podcast',
  sourceUri: Uri.parse('https://example.test/podcast/1.mp3'),
);
