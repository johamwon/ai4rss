import 'dart:async';

import 'package:river_ai/river_ai.dart';
import 'package:test/test.dart';

void main() {
  test('remote media rejects unsafe schemes, credentials, and local addresses',
      () {
    for (final uri in <String>[
      'http://media.example/episode.mp3',
      'https://user:pass@media.example/episode.mp3',
      'https://127.0.0.1/episode.mp3',
      'https://169.254.169.254/latest',
      'https://[::1]/episode.mp3',
      'https://[fd00::1]/episode.mp3',
    ]) {
      expect(
        () => PodcastRemoteMediaSource(uri: Uri.parse(uri)),
        throwsArgumentError,
        reason: uri,
      );
    }
  });

  test('six-hour audio produces bounded transcript, chapters and exact usage',
      () async {
    final ledger = MemoryPodcastCloudUsageLedger();
    final service = _service(ledger: ledger);
    final result = await service.run(
      _request(),
      PodcastTaskCancellation(),
    );

    expect(result.fromCompletedCache, isFalse);
    expect(result.artifact.transcript.segments, hasLength(2));
    expect(result.artifact.chapters, hasLength(2));
    expect(result.artifact.summary?.keyPoints, hasLength(3));
    expect(ledger.records, hasLength(2));
    expect(
      ledger.records
          .where(
            (record) => record.stage == PodcastCloudUsageStage.transcription,
          )
          .single
          .billableDuration,
      const Duration(hours: 6),
    );
    expect(
      ledger.records.fold<int>(0, (sum, record) => sum + record.costMicros),
      1400,
    );
  });

  test('format and declaration mismatches stop before transcription', () async {
    final transcriber = _Transcriber();
    final invalidFormat = _service(
      ingestor: _Ingestor(asset: _asset(mediaType: 'application/octet-stream')),
      transcriber: transcriber,
    );
    await _expectFailure(
      invalidFormat,
      _request(),
      PodcastTranscriptionFailureCode.invalidMedia,
    );

    final mismatch = _service(
      ingestor: _Ingestor(asset: _asset(bytes: 1001)),
      transcriber: transcriber,
    );
    await _expectFailure(
      mismatch,
      _request(),
      PodcastTranscriptionFailureCode.invalidMedia,
    );
    expect(transcriber.calls, 0);
  });

  test('interrupted intelligence resumes after ingest and transcription',
      () async {
    final ingestor = _Ingestor();
    final transcriber = _Transcriber();
    final checkpoints = MemoryPodcastTranscriptionCheckpointStore();
    final artifacts = MemoryPodcastTranscriptionArtifactStore();
    final ledger = MemoryPodcastCloudUsageLedger();
    final failing = _Analyzer()..fail = true;
    final first = _service(
      ingestor: ingestor,
      transcriber: transcriber,
      analyzer: failing,
      checkpoints: checkpoints,
      artifacts: artifacts,
      ledger: ledger,
    );

    await _expectFailure(
      first,
      _request(),
      PodcastTranscriptionFailureCode.intelligenceFailure,
    );
    expect((await checkpoints.read('podcast-job-1'))?.transcript, isNotNull);

    final resumedAnalyzer = _Analyzer();
    final resumed = await _service(
      ingestor: ingestor,
      transcriber: transcriber,
      analyzer: resumedAnalyzer,
      checkpoints: checkpoints,
      artifacts: artifacts,
      ledger: ledger,
    ).run(_request(), PodcastTaskCancellation());

    expect(resumed.resumedAfterIngest, isTrue);
    expect(resumed.resumedAfterTranscription, isTrue);
    expect(ingestor.calls, 1);
    expect(transcriber.calls, 1);
    expect(resumedAnalyzer.calls, 1);
    expect(ledger.records, hasLength(2));
  });

  test('concurrent and completed duplicates never repeat cloud stages',
      () async {
    final ingestor = _Ingestor(delay: true);
    final transcriber = _Transcriber();
    final analyzer = _Analyzer();
    final service = _service(
      ingestor: ingestor,
      transcriber: transcriber,
      analyzer: analyzer,
    );
    final first = service.run(_request(), PodcastTaskCancellation());
    final second = service.run(_request(), PodcastTaskCancellation());
    await _flush();
    ingestor.complete();
    final results = await Future.wait(<Future<PodcastTranscriptionRunResult>>[
      first,
      second,
    ]);
    final cached = await service.run(_request(), PodcastTaskCancellation());

    expect(
      results.map((result) => result.artifact.fingerprint).toSet(),
      hasLength(1),
    );
    expect(cached.fromCompletedCache, isTrue);
    expect(ingestor.calls, 1);
    expect(transcriber.calls, 1);
    expect(analyzer.calls, 1);
  });

  test('last waiter cancellation propagates and keeps resumable checkpoint',
      () async {
    final transcriber = _Transcriber(pending: true);
    final checkpoints = MemoryPodcastTranscriptionCheckpointStore();
    final analyzer = _Analyzer();
    final service = _service(
      transcriber: transcriber,
      analyzer: analyzer,
      checkpoints: checkpoints,
    );
    final cancellation = PodcastTaskCancellation();
    final run = service.run(_request(), cancellation);
    await _flush();
    cancellation.cancel();

    await expectLater(run, throwsA(isA<PodcastTaskCancelledException>()));
    expect(transcriber.cancellations.single.isCancelled, isTrue);
    transcriber.complete();
    await _flush();
    await _flush();
    final checkpoint = await checkpoints.read('podcast-job-1');
    expect(checkpoint?.asset, isNotNull);
    expect(checkpoint?.transcript, isNotNull);
    expect(analyzer.calls, 0);
  });

  test('same job with changed source is an idempotency conflict', () async {
    final service = _service();
    await service.run(_request(), PodcastTaskCancellation());

    await _expectFailure(
      service,
      _request(uploadId: 'upload-changed'),
      PodcastTranscriptionFailureCode.idempotencyConflict,
    );
  });

  test('invalid transcript and intelligence outputs fail closed', () async {
    final badTranscript = PodcastTranscript(
      language: 'en-US',
      providerVersion: 'v1',
      segments: const <PodcastTranscriptSegment>[
        PodcastTranscriptSegment(
          index: 0,
          start: Duration(seconds: 10),
          end: Duration(seconds: 5),
          text: 'invalid',
        ),
      ],
    );
    await _expectFailure(
      _service(transcriber: _Transcriber(transcript: badTranscript)),
      _request(),
      PodcastTranscriptionFailureCode.invalidTranscript,
    );

    final invalidAnalyzer = _Analyzer()
      ..result = PodcastIntelligenceProviderResult(
        chapters: const <PodcastGeneratedChapter>[
          PodcastGeneratedChapter(
            start: Duration.zero,
            title: '',
            summary: 'missing title',
          ),
        ],
        summary: _summary(),
        costMicros: 200,
      );
    await _expectFailure(
      _service(analyzer: invalidAnalyzer),
      _request(),
      PodcastTranscriptionFailureCode.invalidIntelligence,
    );
  });

  test('privacy deletion removes asset, checkpoint, artifact, and usage',
      () async {
    final ingestor = _Ingestor();
    final checkpoints = MemoryPodcastTranscriptionCheckpointStore();
    final artifacts = MemoryPodcastTranscriptionArtifactStore();
    final ledger = MemoryPodcastCloudUsageLedger();
    final service = _service(
      ingestor: ingestor,
      checkpoints: checkpoints,
      artifacts: artifacts,
      ledger: ledger,
    );
    final result = await service.run(_request(), PodcastTaskCancellation());
    final diagnostics = <Object>[
      _request(),
      result.artifact,
      ...ledger.records,
    ].join('\n');
    expect(diagnostics, isNot(contains('upload-secret')));
    expect(diagnostics, isNot(contains('PRIVATE TRANSCRIPT')));

    await service.delete('podcast-job-1');
    expect(ingestor.deleted, <String>['asset-1']);
    expect(await checkpoints.read('podcast-job-1'), isNull);
    expect(await artifacts.read('podcast-job-1'), isNull);
    expect(ledger.records, isEmpty);
  });
}

PodcastTranscriptionService _service({
  _Ingestor? ingestor,
  _Transcriber? transcriber,
  _Analyzer? analyzer,
  MemoryPodcastTranscriptionCheckpointStore? checkpoints,
  MemoryPodcastTranscriptionArtifactStore? artifacts,
  MemoryPodcastCloudUsageLedger? ledger,
}) =>
    PodcastTranscriptionService(
      ingestor: ingestor ?? _Ingestor(),
      transcriptionProvider: transcriber ?? _Transcriber(),
      intelligenceProvider: analyzer ?? _Analyzer(),
      checkpoints: checkpoints ?? MemoryPodcastTranscriptionCheckpointStore(),
      artifacts: artifacts ?? MemoryPodcastTranscriptionArtifactStore(),
      usageLedger: ledger ?? MemoryPodcastCloudUsageLedger(),
      clock: const _Clock(),
    );

PodcastTranscriptionRequest _request({String uploadId = 'upload-secret'}) =>
    PodcastTranscriptionRequest(
      jobId: 'podcast-job-1',
      source: PodcastUploadedMediaSource(
        uploadId: uploadId,
        mediaType: 'audio/mpeg',
        bytes: 1000,
        duration: const Duration(hours: 6),
      ),
      outputLanguage: 'en-US',
    );

PodcastMediaAsset _asset({
  String mediaType = 'audio/mpeg',
  int bytes = 1000,
}) =>
    PodcastMediaAsset(
      assetId: 'asset-1',
      contentDigest: List<String>.filled(64, 'a').join(),
      mediaType: mediaType,
      bytes: bytes,
      duration: const Duration(hours: 6),
    );

PodcastTranscript _transcript() => PodcastTranscript(
      language: 'en-US',
      providerVersion: 'transcriber-v1',
      segments: const <PodcastTranscriptSegment>[
        PodcastTranscriptSegment(
          index: 0,
          start: Duration.zero,
          end: Duration(hours: 3),
          text: 'PRIVATE TRANSCRIPT first half.',
          speaker: 'Host',
        ),
        PodcastTranscriptSegment(
          index: 1,
          start: Duration(hours: 3),
          end: Duration(hours: 6),
          text: 'PRIVATE TRANSCRIPT second half.',
          speaker: 'Guest',
        ),
      ],
    );

PodcastGeneratedSummary _summary() => PodcastGeneratedSummary(
      oneLine: 'A bounded synthetic episode summary.',
      keyPoints: const <String>['One', 'Two', 'Three'],
      topics: const <String>['testing'],
      language: 'en-US',
    );

PodcastIntelligenceProviderResult _intelligence() =>
    PodcastIntelligenceProviderResult(
      chapters: const <PodcastGeneratedChapter>[
        PodcastGeneratedChapter(
          start: Duration.zero,
          title: 'Opening',
          summary: 'First synthetic section.',
        ),
        PodcastGeneratedChapter(
          start: Duration(hours: 3),
          title: 'Closing',
          summary: 'Second synthetic section.',
        ),
      ],
      summary: _summary(),
      costMicros: 200,
    );

Future<void> _expectFailure(
  PodcastTranscriptionService service,
  PodcastTranscriptionRequest request,
  PodcastTranscriptionFailureCode code,
) async {
  await expectLater(
    service.run(request, PodcastTaskCancellation()),
    throwsA(
      isA<PodcastTranscriptionFailure>().having(
        (failure) => failure.code,
        'code',
        code,
      ),
    ),
  );
}

Future<void> _flush() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

final class _Clock implements PodcastTranscriptionClock {
  const _Clock();

  @override
  DateTime now() => DateTime.utc(2026, 8, 6, 12);
}

final class _Ingestor implements PodcastMediaIngestor {
  _Ingestor({PodcastMediaAsset? asset, this.delay = false})
      : asset = asset ?? _asset();

  final PodcastMediaAsset asset;
  final bool delay;
  final Completer<void> _gate = Completer<void>();
  final List<String> deleted = <String>[];
  var calls = 0;

  @override
  Future<void> deleteAsset(String assetId) async => deleted.add(assetId);

  @override
  Future<PodcastMediaAsset> ingest(
    PodcastMediaSource source,
    PodcastTaskCancellation cancellation,
  ) async {
    calls += 1;
    if (delay) await _gate.future;
    cancellation.throwIfCancelled();
    return asset;
  }

  void complete() => _gate.complete();
}

final class _Transcriber implements PodcastTranscriptionProvider {
  _Transcriber({PodcastTranscript? transcript, this.pending = false})
      : transcript = transcript ?? _transcript();

  final PodcastTranscript transcript;
  final bool pending;
  final Completer<void> _gate = Completer<void>();
  final List<PodcastTaskCancellation> cancellations =
      <PodcastTaskCancellation>[];
  var calls = 0;

  @override
  Future<PodcastTranscriptionProviderResult> transcribe(
    PodcastMediaAsset asset, {
    required String? outputLanguage,
    required String operationId,
    required PodcastTaskCancellation cancellation,
  }) async {
    calls += 1;
    cancellations.add(cancellation);
    if (pending) await _gate.future;
    return PodcastTranscriptionProviderResult(
      transcript: transcript,
      billableDuration: const Duration(hours: 6),
      costMicros: 1200,
    );
  }

  void complete() => _gate.complete();
}

final class _Analyzer implements PodcastIntelligenceProvider {
  var calls = 0;
  var fail = false;
  PodcastIntelligenceProviderResult result = _intelligence();

  @override
  Future<PodcastIntelligenceProviderResult> analyze(
    PodcastTranscript transcript, {
    required bool generateChapters,
    required bool generateSummary,
    required String operationId,
    required PodcastTaskCancellation cancellation,
  }) async {
    calls += 1;
    cancellation.throwIfCancelled();
    if (fail) throw StateError('synthetic interruption');
    return result;
  }
}
