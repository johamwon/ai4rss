import 'dart:async';

import 'package:river_audio/river_audio.dart';
import 'package:river_domain/river_domain.dart';
import 'package:test/test.dart';

void main() {
  test('prepares only a bounded look-ahead window with bounded concurrency',
      () async {
    final backend = _ImmediateBackend();
    final prefetcher = BoundedAudioSegmentPrefetcher(
      backend: backend,
      lookAheadSegments: 3,
      maxConcurrentPreparations: 2,
    );
    addTearDown(prefetcher.dispose);

    await prefetcher.update(
      request: _request(),
      currentSegmentIndex: 2,
      settings: const AudioPlaybackSettings(),
    );

    expect(backend.requested, <int>[2, 3, 4, 5]);
    expect(backend.maxActive, lessThanOrEqualTo(2));
    expect(prefetcher.state.prepared, <int>{2, 3, 4, 5});
    expect(prefetcher.state.phase, AudioSegmentPrefetchPhase.ready);
  });

  test('a newer window cancels work and releases stale late results', () async {
    final backend = _IgnoringCancellationBackend();
    final prefetcher = BoundedAudioSegmentPrefetcher(
      backend: backend,
      lookAheadSegments: 1,
      maxConcurrentPreparations: 2,
    );
    addTearDown(prefetcher.dispose);

    final oldUpdate = prefetcher.update(
      request: _request(),
      currentSegmentIndex: 0,
      settings: const AudioPlaybackSettings(),
    );
    await _flush();
    final oldTokens = <AudioPrefetchCancellation>[
      backend.pending[0]!.cancellation,
      backend.pending[1]!.cancellation,
    ];

    final newUpdate = prefetcher.update(
      request: _request(),
      currentSegmentIndex: 5,
      settings: const AudioPlaybackSettings(),
    );
    await _flush();
    expect(oldTokens.every((token) => token.isCancelled), isTrue);
    backend.complete(5);
    backend.complete(6);
    await newUpdate;

    backend.complete(0);
    backend.complete(1);
    await oldUpdate;

    expect(prefetcher.state.prepared, <int>{5, 6});
    expect(backend.released, containsAll(<int>[0, 1]));
  });

  test('preparation failures degrade prefetch without blocking other segments',
      () async {
    final backend = _ImmediateBackend(failingIndexes: <int>{1});
    final prefetcher = BoundedAudioSegmentPrefetcher(
      backend: backend,
      lookAheadSegments: 2,
    );
    addTearDown(prefetcher.dispose);

    await prefetcher.update(
      request: _request(),
      currentSegmentIndex: 0,
      settings: const AudioPlaybackSettings(),
    );

    expect(prefetcher.state.phase, AudioSegmentPrefetchPhase.degraded);
    expect(prefetcher.state.failureCode, 'audio_segment_prepare_failed');
    expect(prefetcher.state.prepared, <int>{0, 2});
  });

  test('retained resources never exceed the configured memory budget',
      () async {
    final backend = _ImmediateBackend(retainedBytes: 70 * 1024);
    final prefetcher = BoundedAudioSegmentPrefetcher(
      backend: backend,
      lookAheadSegments: 2,
      maxConcurrentPreparations: 1,
      maxRetainedBytes: 128 * 1024,
    );
    addTearDown(prefetcher.dispose);

    await prefetcher.update(
      request: _request(),
      currentSegmentIndex: 0,
      settings: const AudioPlaybackSettings(),
    );

    expect(prefetcher.state.retainedBytes, lessThanOrEqualTo(128 * 1024));
    expect(prefetcher.state.prepared, <int>{0});
    expect(backend.released, <int>[1, 2]);
  });

  test('an oversized resource is released with a stable degraded state',
      () async {
    final backend = _ImmediateBackend(retainedBytes: 256 * 1024);
    final prefetcher = BoundedAudioSegmentPrefetcher(
      backend: backend,
      lookAheadSegments: 0,
      maxRetainedBytes: 128 * 1024,
    );
    addTearDown(prefetcher.dispose);

    await prefetcher.update(
      request: _request(),
      currentSegmentIndex: 4,
      settings: const AudioPlaybackSettings(),
    );

    expect(prefetcher.state.prepared, isEmpty);
    expect(prefetcher.state.retainedBytes, 0);
    expect(
      prefetcher.state.failureCode,
      'audio_prefetch_resource_too_large',
    );
    expect(backend.released, <int>[4]);
  });

  test('settings changes invalidate resources and dispose releases everything',
      () async {
    final backend = _ImmediateBackend();
    final prefetcher = BoundedAudioSegmentPrefetcher(
      backend: backend,
      lookAheadSegments: 1,
    );
    await prefetcher.update(
      request: _request(),
      currentSegmentIndex: 0,
      settings: const AudioPlaybackSettings(),
    );

    await prefetcher.update(
      request: _request(),
      currentSegmentIndex: 0,
      settings: const AudioPlaybackSettings(rate: 1.5),
    );
    expect(backend.released, containsAll(<int>[0, 1]));

    final retainedBeforeDispose = prefetcher.state.prepared.toSet();
    await prefetcher.dispose();

    expect(
      backend.released.toSet(),
      containsAll(retainedBeforeDispose),
    );
    expect(prefetcher.state.phase, AudioSegmentPrefetchPhase.disposed);
  });

  test('dispose cancels in-flight work and releases a backend late result',
      () async {
    final backend = _IgnoringCancellationBackend();
    final prefetcher = BoundedAudioSegmentPrefetcher(
      backend: backend,
      lookAheadSegments: 0,
    );
    final update = prefetcher.update(
      request: _request(),
      currentSegmentIndex: 3,
      settings: const AudioPlaybackSettings(),
    );
    await _flush();
    final cancellation = backend.pending[3]!.cancellation;

    await prefetcher.dispose();
    expect(cancellation.isCancelled, isTrue);
    backend.complete(3);
    await update;

    expect(backend.released, <int>[3]);
    expect(prefetcher.state.retainedBytes, 0);
  });
}

AudioLoadRequest _request() => AudioLoadRequest(
      item: AudioItem(
        id: 'article-1',
        kind: AudioKind.articleTts,
        title: 'Long article',
        sourceUri: Uri.parse('river://article/1'),
      ),
      contentRevision: 'sha256:long',
      speechSegments: <SpeechSegment>[
        for (var index = 0; index < 8; index += 1)
          SpeechSegment(
            index: index,
            text: 'Sentence $index.',
            sourceStart: index * 20,
            sourceEnd: index * 20 + 12,
          ),
      ],
    );

Future<void> _flush() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

final class _Prepared implements PreparedAudioSegment {
  _Prepared({
    required this.segmentIndex,
    required this.retainedBytes,
    required this.onRelease,
  });

  @override
  final int segmentIndex;
  @override
  final int retainedBytes;
  final void Function(int index) onRelease;
  var _released = false;

  @override
  Future<void> release() async {
    if (_released) throw StateError('resource released twice');
    _released = true;
    onRelease(segmentIndex);
  }
}

final class _ImmediateBackend implements AudioSegmentPreparationBackend {
  _ImmediateBackend({
    this.failingIndexes = const <int>{},
    this.retainedBytes = 1024,
  });

  final Set<int> failingIndexes;
  final int retainedBytes;
  final List<int> requested = <int>[];
  final List<int> released = <int>[];
  var active = 0;
  var maxActive = 0;

  @override
  Future<PreparedAudioSegment> prepare(
    AudioSegmentPreparationRequest request,
    AudioPrefetchCancellation cancellation,
  ) async {
    requested.add(request.segment.index);
    active += 1;
    if (active > maxActive) maxActive = active;
    try {
      await Future<void>.delayed(Duration.zero);
      cancellation.throwIfCancelled();
      if (failingIndexes.contains(request.segment.index)) {
        throw StateError('private backend failure');
      }
      return _Prepared(
        segmentIndex: request.segment.index,
        retainedBytes: retainedBytes,
        onRelease: released.add,
      );
    } finally {
      active -= 1;
    }
  }
}

final class _PendingPreparation {
  _PendingPreparation(this.cancellation);

  final AudioPrefetchCancellation cancellation;
  final Completer<void> gate = Completer<void>();
}

final class _IgnoringCancellationBackend
    implements AudioSegmentPreparationBackend {
  final Map<int, _PendingPreparation> pending = <int, _PendingPreparation>{};
  final List<int> released = <int>[];

  @override
  Future<PreparedAudioSegment> prepare(
    AudioSegmentPreparationRequest request,
    AudioPrefetchCancellation cancellation,
  ) async {
    final work = _PendingPreparation(cancellation);
    pending[request.segment.index] = work;
    await work.gate.future;
    return _Prepared(
      segmentIndex: request.segment.index,
      retainedBytes: 1024,
      onRelease: released.add,
    );
  }

  void complete(int index) => pending[index]!.gate.complete();
}
