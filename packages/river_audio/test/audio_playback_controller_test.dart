import 'dart:async';

import 'package:river_audio/river_audio.dart';
import 'package:river_domain/river_domain.dart';
import 'package:test/test.dart';

void main() {
  test('restores matching article progress settings and installed voice',
      () async {
    final engine = _FakeAudioEngine();
    final repository = _MemoryAudioPlaybackRepository();
    final clock = _MutableClock(DateTime.utc(2026, 7, 26));
    repository.snapshots['article-1'] = AudioPlaybackSnapshot(
      item: _articleItem('article-1'),
      position: const AudioPlaybackPosition.speech(
        segmentIndex: 1,
        characterOffset: 3,
      ),
      settings: const AudioPlaybackSettings(
        rate: 1.5,
        pitch: 0.9,
        voiceId: 'voice-1',
        languageTag: 'en-US',
      ),
      contentRevision: 'revision-1',
      updatedAt: clock.now(),
    );
    final controller = AudioPlaybackController(
      engine: engine,
      repository: repository,
      clock: clock,
    );
    addTearDown(controller.dispose);

    await controller.load(_request(revision: 'revision-1'));

    expect(engine.seeks.single.segmentIndex, 1);
    expect(engine.seeks.single.characterOffset, 3);
    expect(engine.settings.single.rate, 1.5);
    expect(engine.settings.single.voiceId, 'voice-1');
    expect(controller.state.phase, AudioEnginePhase.ready);
    expect(controller.state.position?.segmentIndex, 1);
    expect(controller.state.restoring, isFalse);
  });

  test('content changes reset position and removed voices fall back safely',
      () async {
    final engine = _FakeAudioEngine()..availableVoices = const <AudioVoice>[];
    final repository = _MemoryAudioPlaybackRepository();
    final clock = _MutableClock(DateTime.utc(2026, 7, 26));
    repository.snapshots['article-1'] = AudioPlaybackSnapshot(
      item: _articleItem('article-1'),
      position: const AudioPlaybackPosition.speech(
        segmentIndex: 1,
        characterOffset: 3,
      ),
      settings: const AudioPlaybackSettings(
        rate: 1.75,
        voiceId: 'removed-voice',
      ),
      contentRevision: 'old-revision',
      updatedAt: clock.now(),
    );
    final controller = AudioPlaybackController(
      engine: engine,
      repository: repository,
      clock: clock,
    );
    addTearDown(controller.dispose);

    await controller.load(_request(revision: 'new-revision'));

    expect(engine.seeks, isEmpty);
    expect(controller.state.position?.segmentIndex, 0);
    expect(controller.state.settings.rate, 1.75);
    expect(controller.state.settings.voiceId, isNull);
  });

  test('segment completion advances and final completion clears restart state',
      () async {
    final engine = _FakeAudioEngine();
    final repository = _MemoryAudioPlaybackRepository();
    final controller = AudioPlaybackController(
      engine: engine,
      repository: repository,
      clock: _MutableClock(DateTime.utc(2026, 7, 26)),
    );
    addTearDown(controller.dispose);
    await controller.load(_request());
    await controller.play();

    engine.emit(
      const AudioEngineEvent(
        phase: AudioEnginePhase.completed,
        itemId: 'article-1',
        position: AudioPlaybackPosition.speech(
          segmentIndex: 0,
          characterOffset: 15,
        ),
      ),
    );
    await _flushMicrotasks();

    expect(engine.seeks.last.segmentIndex, 1);
    expect(engine.playCalls, 2);
    expect(controller.state.phase, AudioEnginePhase.playing);

    engine.emit(
      const AudioEngineEvent(
        phase: AudioEnginePhase.completed,
        itemId: 'article-1',
        position: AudioPlaybackPosition.speech(
          segmentIndex: 1,
          characterOffset: 16,
        ),
      ),
    );
    await _flushMicrotasks();

    expect(repository.cleared, <String>['article-1']);
    expect(controller.state.phase, AudioEnginePhase.completed);
  });

  test('sentence skips preserve active playback', () async {
    final engine = _FakeAudioEngine();
    final controller = AudioPlaybackController(
      engine: engine,
      repository: _MemoryAudioPlaybackRepository(),
      clock: _MutableClock(DateTime.utc(2026, 7, 26)),
    );
    addTearDown(controller.dispose);
    await controller.load(_request());
    await controller.play();

    await controller.skipNext();
    await controller.skipPrevious();

    expect(
      engine.seeks.map((position) => position.segmentIndex),
      <int?>[1, 0],
    );
    expect(engine.playCalls, 3);
    expect(controller.state.position?.segmentIndex, 0);
  });

  test('playing progress is debounced while pause flushes immediately',
      () async {
    final engine = _FakeAudioEngine();
    final repository = _MemoryAudioPlaybackRepository();
    final scheduler = _ManualAudioScheduler();
    final clock = _MutableClock(DateTime.utc(2026, 7, 26));
    final controller = AudioPlaybackController(
      engine: engine,
      repository: repository,
      clock: clock,
      scheduler: scheduler,
    );
    addTearDown(controller.dispose);
    await controller.load(_request());
    await controller.play();
    engine.emit(
      const AudioEngineEvent(
        phase: AudioEnginePhase.playing,
        itemId: 'article-1',
        position: AudioPlaybackPosition.speech(
          segmentIndex: 0,
          characterOffset: 4,
        ),
      ),
    );

    expect(repository.saved, isEmpty);
    scheduler.elapse(const Duration(milliseconds: 400));
    await _flushMicrotasks();
    expect(repository.saved.single.position.characterOffset, 4);

    clock.value = clock.value.add(const Duration(seconds: 1));
    engine.emit(
      const AudioEngineEvent(
        phase: AudioEnginePhase.playing,
        itemId: 'article-1',
        position: AudioPlaybackPosition.speech(
          segmentIndex: 0,
          characterOffset: 7,
        ),
      ),
    );
    await controller.pause();

    expect(repository.saved.last.position.characterOffset, 7);
    expect(repository.saved.last.updatedAt, clock.value);
  });

  test('sleep timer pauses once and removes its deadline', () async {
    final engine = _FakeAudioEngine();
    final scheduler = _ManualAudioScheduler();
    final clock = _MutableClock(DateTime.utc(2026, 7, 26, 12));
    final controller = AudioPlaybackController(
      engine: engine,
      repository: _MemoryAudioPlaybackRepository(),
      clock: clock,
      scheduler: scheduler,
    );
    addTearDown(controller.dispose);
    await controller.load(_request());
    await controller.play();

    controller.setSleepTimer(const Duration(minutes: 30));
    expect(
      controller.state.sleepDeadline,
      DateTime.utc(2026, 7, 26, 12, 30),
    );

    scheduler.elapse(const Duration(minutes: 30));
    await _flushMicrotasks();

    expect(engine.pauseCalls, 1);
    expect(controller.state.phase, AudioEnginePhase.paused);
    expect(controller.state.sleepDeadline, isNull);
  });

  test('invalid voice is rejected without disturbing current playback',
      () async {
    final engine = _FakeAudioEngine();
    final controller = AudioPlaybackController(
      engine: engine,
      repository: _MemoryAudioPlaybackRepository(),
      clock: _MutableClock(DateTime.utc(2026, 7, 26)),
    );
    addTearDown(controller.dispose);
    await controller.load(_request());
    await controller.play();

    await controller.updateSettings(
      const AudioPlaybackSettings(voiceId: 'missing-voice'),
    );

    expect(controller.state.phase, AudioEnginePhase.playing);
    expect(controller.state.failureCode, 'audio_voice_unavailable');
    expect(engine.settings, hasLength(1));
  });

  test('events from a previously loaded item are ignored', () async {
    final engine = _FakeAudioEngine();
    final controller = AudioPlaybackController(
      engine: engine,
      repository: _MemoryAudioPlaybackRepository(),
      clock: _MutableClock(DateTime.utc(2026, 7, 26)),
    );
    addTearDown(controller.dispose);
    await controller.load(_request(itemId: 'article-1'));
    await controller.load(_request(itemId: 'article-2'));

    engine.emit(
      const AudioEngineEvent(
        phase: AudioEnginePhase.failed,
        itemId: 'article-1',
        failureCode: 'stale_failure',
      ),
    );

    expect(controller.state.item?.id, 'article-2');
    expect(controller.state.phase, AudioEnginePhase.ready);
    expect(controller.state.failureCode, isNull);
  });

  test('refuses playback when the operating system denies audio focus',
      () async {
    final engine = _FakeAudioEngine();
    final systemSession = _FakeAudioSystemSession()..activationAllowed = false;
    final controller = AudioPlaybackController(
      engine: engine,
      repository: _MemoryAudioPlaybackRepository(),
      systemSession: systemSession,
      clock: _MutableClock(DateTime.utc(2026, 7, 26)),
    );
    addTearDown(controller.dispose);
    await controller.load(_request());

    await controller.play();

    expect(systemSession.activateCalls, 1);
    expect(engine.playCalls, 0);
    expect(controller.state.phase, AudioEnginePhase.failed);
    expect(controller.state.failureCode, 'audio_focus_denied');
  });

  test('routes system media commands and publishes skip capabilities',
      () async {
    final engine = _FakeAudioEngine();
    final systemSession = _FakeAudioSystemSession();
    final controller = AudioPlaybackController(
      engine: engine,
      repository: _MemoryAudioPlaybackRepository(),
      systemSession: systemSession,
      clock: _MutableClock(DateTime.utc(2026, 7, 26)),
    );
    addTearDown(controller.dispose);
    await controller.load(_request());
    await controller.play();

    systemSession.emit(AudioSystemEventType.skipNext);
    await _flushMicrotasks();
    expect(controller.state.position?.segmentIndex, 1);
    expect(systemSession.published.last.canSkipPrevious, isTrue);
    expect(systemSession.published.last.canSkipNext, isFalse);

    systemSession.emit(AudioSystemEventType.pause);
    await _flushMicrotasks();
    expect(controller.state.phase, AudioEnginePhase.paused);
    expect(systemSession.deactivateCalls, 1);

    systemSession.emit(AudioSystemEventType.play);
    await _flushMicrotasks();
    expect(controller.state.phase, AudioEnginePhase.playing);
    expect(systemSession.activateCalls, 2);

    systemSession.emit(AudioSystemEventType.stop);
    await _flushMicrotasks();
    expect(controller.state.phase, AudioEnginePhase.stopped);
    expect(engine.stopCalls, 1);
  });

  test('resumes only an active playback interrupted with system permission',
      () async {
    final engine = _FakeAudioEngine();
    final systemSession = _FakeAudioSystemSession();
    final controller = AudioPlaybackController(
      engine: engine,
      repository: _MemoryAudioPlaybackRepository(),
      systemSession: systemSession,
      clock: _MutableClock(DateTime.utc(2026, 7, 26)),
    );
    addTearDown(controller.dispose);
    await controller.load(_request());
    await controller.play();

    systemSession.emit(AudioSystemEventType.interruptionBegan);
    await _flushMicrotasks();
    expect(controller.state.phase, AudioEnginePhase.interrupted);
    expect(engine.pauseCalls, 1);

    systemSession.emit(
      AudioSystemEventType.interruptionEnded,
      mayResume: true,
    );
    await _flushMicrotasks();
    expect(controller.state.phase, AudioEnginePhase.playing);
    expect(engine.playCalls, 2);

    systemSession.emit(AudioSystemEventType.interruptionBegan);
    await _flushMicrotasks();
    systemSession.emit(AudioSystemEventType.interruptionEnded);
    await _flushMicrotasks();
    expect(controller.state.phase, AudioEnginePhase.interrupted);
    expect(engine.playCalls, 2);
  });

  test('becoming noisy pauses and cannot trigger a later automatic resume',
      () async {
    final engine = _FakeAudioEngine();
    final systemSession = _FakeAudioSystemSession();
    final controller = AudioPlaybackController(
      engine: engine,
      repository: _MemoryAudioPlaybackRepository(),
      systemSession: systemSession,
      clock: _MutableClock(DateTime.utc(2026, 7, 26)),
    );
    addTearDown(controller.dispose);
    await controller.load(_request());
    await controller.play();

    systemSession.emit(AudioSystemEventType.becomingNoisy);
    await _flushMicrotasks();
    systemSession.emit(
      AudioSystemEventType.interruptionEnded,
      mayResume: true,
    );
    await _flushMicrotasks();

    expect(controller.state.phase, AudioEnginePhase.paused);
    expect(engine.pauseCalls, 1);
    expect(engine.playCalls, 1);
  });

  test('moves a bounded preparation window without coupling playback to it',
      () async {
    final engine = _FakeAudioEngine();
    final prefetcher = _FakeAudioSegmentPrefetcher();
    final controller = AudioPlaybackController(
      engine: engine,
      repository: _MemoryAudioPlaybackRepository(),
      segmentPrefetcher: prefetcher,
      clock: _MutableClock(DateTime.utc(2026, 7, 26)),
    );
    await controller.load(_request());

    expect(prefetcher.updates.single.segmentIndex, 0);
    engine.emit(
      const AudioEngineEvent(
        phase: AudioEnginePhase.ready,
        itemId: 'article-1',
        position: AudioPlaybackPosition.speech(
          segmentIndex: 0,
          characterOffset: 4,
        ),
      ),
    );
    expect(prefetcher.updates, hasLength(1));

    await controller.skipNext();
    expect(prefetcher.updates.last.segmentIndex, 1);
    await controller.updateSettings(
      const AudioPlaybackSettings(rate: 1.5),
    );
    expect(prefetcher.updates.last.settings.rate, 1.5);

    await controller.stop();
    expect(prefetcher.cancelCalls, greaterThanOrEqualTo(2));
    await controller.dispose();
    expect(prefetcher.disposeCalls, 1);
  });

  test('segment preparation failure never blocks local playback', () async {
    final engine = _FakeAudioEngine();
    final prefetcher = _FakeAudioSegmentPrefetcher()..failUpdates = true;
    final controller = AudioPlaybackController(
      engine: engine,
      repository: _MemoryAudioPlaybackRepository(),
      segmentPrefetcher: prefetcher,
      clock: _MutableClock(DateTime.utc(2026, 7, 26)),
    );
    addTearDown(controller.dispose);

    await controller.load(_request());
    await _flushMicrotasks();
    await controller.play();

    expect(prefetcher.updates, hasLength(1));
    expect(engine.playCalls, 1);
    expect(controller.state.phase, AudioEnginePhase.playing);
    expect(controller.state.failureCode, isNull);
  });
}

AudioItem _articleItem(String id) => AudioItem(
      id: id,
      kind: AudioKind.articleTts,
      title: 'Article $id',
      sourceUri: Uri.parse('river://article/$id'),
    );

AudioLoadRequest _request({
  String itemId = 'article-1',
  String revision = 'revision-1',
}) =>
    AudioLoadRequest(
      item: _articleItem(itemId),
      contentRevision: revision,
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

Future<void> _flushMicrotasks() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

final class _MutableClock implements Clock {
  _MutableClock(this.value);

  DateTime value;

  @override
  DateTime now() => value;
}

final class _MemoryAudioPlaybackRepository implements AudioPlaybackRepository {
  final Map<String, AudioPlaybackSnapshot> snapshots =
      <String, AudioPlaybackSnapshot>{};
  final List<AudioPlaybackSnapshot> saved = <AudioPlaybackSnapshot>[];
  final List<String> cleared = <String>[];

  @override
  Future<void> clear(String itemId) async {
    cleared.add(itemId);
    snapshots.remove(itemId);
  }

  @override
  Future<AudioPlaybackSnapshot?> read(String itemId) async => snapshots[itemId];

  @override
  Future<void> save(AudioPlaybackSnapshot snapshot) async {
    saved.add(snapshot);
    snapshots[snapshot.item.id] = snapshot;
  }
}

final class _FakeAudioEngine implements AudioEngine {
  final StreamController<AudioEngineEvent> _events =
      StreamController<AudioEngineEvent>.broadcast(sync: true);
  List<AudioVoice> availableVoices = const <AudioVoice>[
    AudioVoice(
      id: 'voice-1',
      name: 'River Voice',
      languageTag: 'en-US',
      isLocal: true,
    ),
  ];
  final List<AudioPlaybackPosition> seeks = <AudioPlaybackPosition>[];
  final List<AudioPlaybackSettings> settings = <AudioPlaybackSettings>[];
  AudioLoadRequest? request;
  AudioPlaybackPosition? position;
  var playCalls = 0;
  var pauseCalls = 0;
  var stopCalls = 0;

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
  Future<void> dispose() => _events.close();

  @override
  Future<void> load(AudioLoadRequest request) async {
    this.request = request;
    position = request.item.kind == AudioKind.articleTts
        ? const AudioPlaybackPosition.speech(segmentIndex: 0)
        : AudioPlaybackPosition.media(Duration.zero);
    emit(
      AudioEngineEvent(
        phase: AudioEnginePhase.ready,
        itemId: request.item.id,
        position: position,
      ),
    );
  }

  @override
  Future<void> pause() async {
    pauseCalls += 1;
    emit(
      AudioEngineEvent(
        phase: AudioEnginePhase.paused,
        itemId: request?.item.id,
        position: position,
      ),
    );
  }

  @override
  Future<void> play() async {
    playCalls += 1;
    emit(
      AudioEngineEvent(
        phase: AudioEnginePhase.playing,
        itemId: request?.item.id,
        position: position,
      ),
    );
  }

  @override
  Future<void> resume() => play();

  @override
  Future<void> seek(AudioPlaybackPosition position) async {
    this.position = position;
    seeks.add(position);
    emit(
      AudioEngineEvent(
        phase: AudioEnginePhase.ready,
        itemId: request?.item.id,
        position: position,
      ),
    );
  }

  @override
  Future<void> stop() async {
    stopCalls += 1;
    emit(
      AudioEngineEvent(
        phase: AudioEnginePhase.stopped,
        itemId: request?.item.id,
        position: position,
      ),
    );
  }

  @override
  Future<void> updateSettings(AudioPlaybackSettings settings) async {
    this.settings.add(settings);
  }

  @override
  Future<List<AudioVoice>> voices() async => availableVoices;

  void emit(AudioEngineEvent event) {
    if (event.position != null) position = event.position;
    _events.add(event);
  }
}

final class _FakeAudioSystemSession implements AudioSystemSession {
  final StreamController<AudioSystemEvent> _events =
      StreamController<AudioSystemEvent>.broadcast(sync: true);
  final List<AudioSystemPlaybackState> published = <AudioSystemPlaybackState>[];
  var activationAllowed = true;
  var activateCalls = 0;
  var deactivateCalls = 0;
  var clearCalls = 0;

  @override
  Stream<AudioSystemEvent> get events => _events.stream;

  @override
  Future<bool> activate() async {
    activateCalls += 1;
    return activationAllowed;
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

  void emit(AudioSystemEventType type, {bool mayResume = false}) {
    _events.add(AudioSystemEvent(type: type, mayResume: mayResume));
  }
}

final class _PrefetchUpdate {
  const _PrefetchUpdate({
    required this.segmentIndex,
    required this.settings,
  });

  final int segmentIndex;
  final AudioPlaybackSettings settings;
}

final class _FakeAudioSegmentPrefetcher implements AudioSegmentPrefetcher {
  final List<_PrefetchUpdate> updates = <_PrefetchUpdate>[];
  var cancelCalls = 0;
  var disposeCalls = 0;
  var failUpdates = false;

  @override
  Future<void> cancel() async {
    cancelCalls += 1;
  }

  @override
  Future<void> dispose() async {
    disposeCalls += 1;
  }

  @override
  Future<void> update({
    required AudioLoadRequest request,
    required int currentSegmentIndex,
    required AudioPlaybackSettings settings,
  }) async {
    updates.add(
      _PrefetchUpdate(
        segmentIndex: currentSegmentIndex,
        settings: settings,
      ),
    );
    if (failUpdates) throw StateError('private preparation failure');
  }
}

final class _ManualAudioScheduler implements AudioScheduler {
  final List<_ManualAudioTimerHandle> timers = <_ManualAudioTimerHandle>[];

  @override
  AudioTimerHandle schedule(Duration delay, void Function() callback) {
    final timer = _ManualAudioTimerHandle(delay, callback);
    timers.add(timer);
    return timer;
  }

  void elapse(Duration duration) {
    final ready = timers
        .where((timer) => timer.isActive && timer.delay <= duration)
        .toList(growable: false);
    for (final timer in ready) {
      timer.fire();
    }
  }
}

final class _ManualAudioTimerHandle implements AudioTimerHandle {
  _ManualAudioTimerHandle(this.delay, this.callback);

  final Duration delay;
  final void Function() callback;
  var _active = true;

  @override
  bool get isActive => _active;

  @override
  void cancel() => _active = false;

  void fire() {
    if (!_active) return;
    _active = false;
    callback();
  }
}
