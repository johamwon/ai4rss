import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';

sealed class PodcastMediaSource {
  const PodcastMediaSource();
}

final class PodcastRemoteMediaSource extends PodcastMediaSource {
  PodcastRemoteMediaSource({
    required this.uri,
    this.expectedMediaType,
    this.expectedBytes,
    this.expectedDuration,
  }) {
    if (!_safeRemoteUri(uri)) {
      throw ArgumentError.value(uri, 'uri', 'Unsafe podcast media URI');
    }
    _validateDeclaredMedia(expectedMediaType, expectedBytes, expectedDuration);
  }

  final Uri uri;
  final String? expectedMediaType;
  final int? expectedBytes;
  final Duration? expectedDuration;

  @override
  String toString() => 'PodcastRemoteMediaSource('
      'scheme: ${uri.scheme}, host: [REDACTED], '
      'expectedType: $expectedMediaType, expectedBytes: $expectedBytes, '
      'expectedDurationMs: ${expectedDuration?.inMilliseconds}'
      ')';
}

final class PodcastUploadedMediaSource extends PodcastMediaSource {
  PodcastUploadedMediaSource({
    required this.uploadId,
    required this.mediaType,
    required this.bytes,
    required this.duration,
  }) {
    if (!_safeId.hasMatch(uploadId)) {
      throw ArgumentError.value(uploadId, 'uploadId');
    }
    _validateDeclaredMedia(mediaType, bytes, duration);
  }

  final String uploadId;
  final String mediaType;
  final int bytes;
  final Duration duration;

  @override
  String toString() => 'PodcastUploadedMediaSource('
      'upload: ${_shortHash(uploadId)}, mediaType: $mediaType, '
      'bytes: $bytes, durationMs: ${duration.inMilliseconds}'
      ')';
}

final class PodcastTranscriptionRequest {
  PodcastTranscriptionRequest({
    required this.jobId,
    required this.source,
    this.outputLanguage,
    this.generateChapters = true,
    this.generateSummary = true,
  }) {
    if (!_safeId.hasMatch(jobId)) {
      throw ArgumentError.value(jobId, 'jobId');
    }
    if (outputLanguage != null && !_languageTag.hasMatch(outputLanguage!)) {
      throw ArgumentError.value(outputLanguage, 'outputLanguage');
    }
  }

  final String jobId;
  final PodcastMediaSource source;
  final String? outputLanguage;
  final bool generateChapters;
  final bool generateSummary;

  String get fingerprint {
    final sourceIdentity = switch (source) {
      final PodcastRemoteMediaSource remote => <String, Object?>{
          'kind': 'remote',
          'uriHash':
              sha256.convert(utf8.encode(remote.uri.toString())).toString(),
          'expectedMediaType': remote.expectedMediaType,
          'expectedBytes': remote.expectedBytes,
          'expectedDurationMicros': remote.expectedDuration?.inMicroseconds,
        },
      final PodcastUploadedMediaSource upload => <String, Object?>{
          'kind': 'upload',
          'uploadHash': sha256.convert(utf8.encode(upload.uploadId)).toString(),
          'mediaType': upload.mediaType,
          'bytes': upload.bytes,
          'durationMicros': upload.duration.inMicroseconds,
        },
    };
    return sha256
        .convert(
          utf8.encode(
            jsonEncode(<String, Object?>{
              'schema': 'river.podcast-transcription-request.v1',
              'source': sourceIdentity,
              'outputLanguage': outputLanguage,
              'generateChapters': generateChapters,
              'generateSummary': generateSummary,
            }),
          ),
        )
        .toString();
  }

  @override
  String toString() => 'PodcastTranscriptionRequest('
      'job: ${_shortHash(jobId)}, fingerprint: ${fingerprint.substring(0, 12)}, '
      'source: ${source.runtimeType}, outputLanguage: $outputLanguage, '
      'chapters: $generateChapters, summary: $generateSummary'
      ')';
}

final class PodcastTaskCancellation {
  final Completer<void> _cancelled = Completer<void>();
  var _isCancelled = false;

  bool get isCancelled => _isCancelled;
  Future<void> get whenCancelled => _cancelled.future;

  void cancel() {
    if (_isCancelled) return;
    _isCancelled = true;
    _cancelled.complete();
  }

  void throwIfCancelled() {
    if (_isCancelled) throw const PodcastTaskCancelledException();
  }
}

final class PodcastTaskCancelledException implements Exception {
  const PodcastTaskCancelledException();
}

final class PodcastMediaAsset {
  PodcastMediaAsset({
    required this.assetId,
    required this.contentDigest,
    required this.mediaType,
    required this.bytes,
    required this.duration,
  }) {
    if (!_safeId.hasMatch(assetId) || !_sha256Pattern.hasMatch(contentDigest)) {
      throw ArgumentError('Invalid podcast media asset identity');
    }
  }

  final String assetId;
  final String contentDigest;
  final String mediaType;
  final int bytes;
  final Duration duration;

  @override
  String toString() => 'PodcastMediaAsset('
      'asset: ${_shortHash(assetId)}, digest: ${contentDigest.substring(0, 12)}, '
      'mediaType: $mediaType, bytes: $bytes, '
      'durationMs: ${duration.inMilliseconds}'
      ')';
}

/// A remote implementation must pin public DNS answers, disable automatic
/// redirects, revalidate each hop, stream with byte limits, and never expose
/// internal addresses. Upload implementations must bind opaque upload IDs to
/// the authenticated account and verify the declared size and media type.
abstract interface class PodcastMediaIngestor {
  Future<PodcastMediaAsset> ingest(
    PodcastMediaSource source,
    PodcastTaskCancellation cancellation,
  );

  Future<void> deleteAsset(String assetId);
}

final class PodcastTranscriptSegment {
  const PodcastTranscriptSegment({
    required this.index,
    required this.start,
    required this.end,
    required this.text,
    this.speaker,
  });

  final int index;
  final Duration start;
  final Duration end;
  final String text;
  final String? speaker;
}

final class PodcastTranscript {
  PodcastTranscript({
    required this.language,
    required List<PodcastTranscriptSegment> segments,
    required this.providerVersion,
  }) : segments = List<PodcastTranscriptSegment>.unmodifiable(segments);

  final String language;
  final List<PodcastTranscriptSegment> segments;
  final String providerVersion;

  int get characterCount =>
      segments.fold<int>(0, (sum, segment) => sum + segment.text.length);

  @override
  String toString() => 'PodcastTranscript('
      'language: $language, segments: ${segments.length}, '
      'characters: $characterCount, providerVersion: $providerVersion'
      ')';
}

final class PodcastTranscriptionProviderResult {
  const PodcastTranscriptionProviderResult({
    required this.transcript,
    required this.billableDuration,
    required this.costMicros,
  });

  final PodcastTranscript transcript;
  final Duration billableDuration;
  final int costMicros;
}

abstract interface class PodcastTranscriptionProvider {
  Future<PodcastTranscriptionProviderResult> transcribe(
    PodcastMediaAsset asset, {
    required String? outputLanguage,
    required String operationId,
    required PodcastTaskCancellation cancellation,
  });
}

final class PodcastGeneratedChapter {
  const PodcastGeneratedChapter({
    required this.start,
    required this.title,
    required this.summary,
  });

  final Duration start;
  final String title;
  final String summary;
}

final class PodcastGeneratedSummary {
  PodcastGeneratedSummary({
    required this.oneLine,
    required List<String> keyPoints,
    required List<String> topics,
    required this.language,
  })  : keyPoints = List<String>.unmodifiable(keyPoints),
        topics = List<String>.unmodifiable(topics);

  final String oneLine;
  final List<String> keyPoints;
  final List<String> topics;
  final String language;
}

final class PodcastIntelligenceProviderResult {
  PodcastIntelligenceProviderResult({
    required List<PodcastGeneratedChapter> chapters,
    required this.summary,
    required this.costMicros,
  }) : chapters = List<PodcastGeneratedChapter>.unmodifiable(chapters);

  final List<PodcastGeneratedChapter> chapters;
  final PodcastGeneratedSummary? summary;
  final int costMicros;
}

abstract interface class PodcastIntelligenceProvider {
  Future<PodcastIntelligenceProviderResult> analyze(
    PodcastTranscript transcript, {
    required bool generateChapters,
    required bool generateSummary,
    required String operationId,
    required PodcastTaskCancellation cancellation,
  });
}

enum PodcastCloudUsageStage { transcription, intelligence }

final class PodcastCloudUsageRecord {
  const PodcastCloudUsageRecord({
    required this.jobHash,
    required this.operationId,
    required this.stage,
    required this.billableDuration,
    required this.costMicros,
    required this.recordedAt,
  });

  final String jobHash;
  final String operationId;
  final PodcastCloudUsageStage stage;
  final Duration billableDuration;
  final int costMicros;
  final DateTime recordedAt;

  @override
  String toString() => 'PodcastCloudUsageRecord('
      'job: ${jobHash.substring(0, 12)}, '
      'operation: ${_shortHash(operationId)}, stage: ${stage.name}, '
      'billableMs: ${billableDuration.inMilliseconds}, costMicros: $costMicros'
      ')';
}

abstract interface class PodcastCloudUsageLedger {
  Future<void> recordOnce(PodcastCloudUsageRecord record);
  Future<void> deleteJob(String jobHash);
}

final class MemoryPodcastCloudUsageLedger implements PodcastCloudUsageLedger {
  final Map<String, PodcastCloudUsageRecord> _records =
      <String, PodcastCloudUsageRecord>{};

  List<PodcastCloudUsageRecord> get records =>
      List<PodcastCloudUsageRecord>.unmodifiable(_records.values);

  @override
  Future<void> deleteJob(String jobHash) async {
    _records.removeWhere((_, record) => record.jobHash == jobHash);
  }

  @override
  Future<void> recordOnce(PodcastCloudUsageRecord record) async {
    final existing = _records[record.operationId];
    if (existing == null) {
      _records[record.operationId] = record;
      return;
    }
    if (existing.jobHash != record.jobHash ||
        existing.stage != record.stage ||
        existing.billableDuration != record.billableDuration ||
        existing.costMicros != record.costMicros) {
      throw StateError('Podcast usage idempotency conflict');
    }
  }
}

final class PodcastTranscriptionCheckpoint {
  const PodcastTranscriptionCheckpoint({
    required this.jobId,
    required this.fingerprint,
    this.asset,
    this.transcript,
  });

  final String jobId;
  final String fingerprint;
  final PodcastMediaAsset? asset;
  final PodcastTranscript? transcript;

  PodcastTranscriptionCheckpoint copyWith({
    PodcastMediaAsset? asset,
    PodcastTranscript? transcript,
  }) =>
      PodcastTranscriptionCheckpoint(
        jobId: jobId,
        fingerprint: fingerprint,
        asset: asset ?? this.asset,
        transcript: transcript ?? this.transcript,
      );

  @override
  String toString() => 'PodcastTranscriptionCheckpoint('
      'job: ${_shortHash(jobId)}, fingerprint: ${fingerprint.substring(0, 12)}, '
      'hasAsset: ${asset != null}, hasTranscript: ${transcript != null}'
      ')';
}

abstract interface class PodcastTranscriptionCheckpointStore {
  Future<PodcastTranscriptionCheckpoint?> read(String jobId);
  Future<void> write(PodcastTranscriptionCheckpoint checkpoint);
  Future<void> delete(String jobId);
}

final class MemoryPodcastTranscriptionCheckpointStore
    implements PodcastTranscriptionCheckpointStore {
  final Map<String, PodcastTranscriptionCheckpoint> _values =
      <String, PodcastTranscriptionCheckpoint>{};

  @override
  Future<void> delete(String jobId) async => _values.remove(jobId);

  @override
  Future<PodcastTranscriptionCheckpoint?> read(String jobId) async =>
      _values[jobId];

  @override
  Future<void> write(PodcastTranscriptionCheckpoint checkpoint) async {
    _values[checkpoint.jobId] = checkpoint;
  }
}

final class PodcastTranscriptionArtifact {
  PodcastTranscriptionArtifact({
    required this.jobId,
    required this.fingerprint,
    required this.assetDigest,
    required this.transcript,
    required List<PodcastGeneratedChapter> chapters,
    required this.summary,
    required this.createdAt,
  }) : chapters = List<PodcastGeneratedChapter>.unmodifiable(chapters);

  final String jobId;
  final String fingerprint;
  final String assetDigest;
  final PodcastTranscript transcript;
  final List<PodcastGeneratedChapter> chapters;
  final PodcastGeneratedSummary? summary;
  final DateTime createdAt;

  @override
  String toString() => 'PodcastTranscriptionArtifact('
      'job: ${_shortHash(jobId)}, fingerprint: ${fingerprint.substring(0, 12)}, '
      'assetDigest: ${assetDigest.substring(0, 12)}, '
      'segments: ${transcript.segments.length}, chapters: ${chapters.length}, '
      'hasSummary: ${summary != null}, createdAt: $createdAt'
      ')';
}

abstract interface class PodcastTranscriptionArtifactStore {
  Future<PodcastTranscriptionArtifact?> read(String jobId);
  Future<void> write(PodcastTranscriptionArtifact artifact);
  Future<void> delete(String jobId);
}

final class MemoryPodcastTranscriptionArtifactStore
    implements PodcastTranscriptionArtifactStore {
  final Map<String, PodcastTranscriptionArtifact> _values =
      <String, PodcastTranscriptionArtifact>{};

  @override
  Future<void> delete(String jobId) async => _values.remove(jobId);

  @override
  Future<PodcastTranscriptionArtifact?> read(String jobId) async =>
      _values[jobId];

  @override
  Future<void> write(PodcastTranscriptionArtifact artifact) async {
    _values[artifact.jobId] = artifact;
  }
}

abstract interface class PodcastTranscriptionClock {
  DateTime now();
}

final class SystemPodcastTranscriptionClock
    implements PodcastTranscriptionClock {
  const SystemPodcastTranscriptionClock();

  @override
  DateTime now() => DateTime.now().toUtc();
}

final class PodcastTranscriptionPolicy {
  const PodcastTranscriptionPolicy({
    this.maximumMediaBytes = 2 * 1024 * 1024 * 1024,
    this.maximumMediaDuration = const Duration(hours: 6),
    this.maximumSegments = 20000,
    this.maximumTranscriptCharacters = 2000000,
    this.maximumChapters = 500,
    this.maximumStageCostMicros = 50000000,
    this.ingestTimeout = const Duration(minutes: 10),
    this.transcriptionTimeout = const Duration(hours: 2),
    this.intelligenceTimeout = const Duration(minutes: 5),
  })  : assert(maximumMediaBytes >= 1024),
        assert(maximumSegments >= 1),
        assert(maximumTranscriptCharacters >= 1),
        assert(maximumChapters >= 1),
        assert(maximumStageCostMicros >= 0);

  final int maximumMediaBytes;
  final Duration maximumMediaDuration;
  final int maximumSegments;
  final int maximumTranscriptCharacters;
  final int maximumChapters;
  final int maximumStageCostMicros;
  final Duration ingestTimeout;
  final Duration transcriptionTimeout;
  final Duration intelligenceTimeout;
}

enum PodcastTranscriptionFailureCode {
  idempotencyConflict,
  invalidMedia,
  mediaTooLarge,
  mediaTooLong,
  ingestTimeout,
  ingestFailure,
  transcriptionTimeout,
  transcriptionFailure,
  invalidTranscript,
  intelligenceTimeout,
  intelligenceFailure,
  invalidIntelligence,
  meteringFailure,
  persistenceFailure,
  deleteFailure,
}

final class PodcastTranscriptionFailure implements Exception {
  const PodcastTranscriptionFailure({
    required this.code,
    required this.retryable,
  });

  final PodcastTranscriptionFailureCode code;
  final bool retryable;

  @override
  String toString() => 'PodcastTranscriptionFailure('
      'code: ${code.name}, retryable: $retryable'
      ')';
}

final class PodcastTranscriptionRunResult {
  const PodcastTranscriptionRunResult({
    required this.artifact,
    required this.fromCompletedCache,
    required this.resumedAfterIngest,
    required this.resumedAfterTranscription,
  });

  final PodcastTranscriptionArtifact artifact;
  final bool fromCompletedCache;
  final bool resumedAfterIngest;
  final bool resumedAfterTranscription;
}

final class PodcastTranscriptionService {
  PodcastTranscriptionService({
    required PodcastMediaIngestor ingestor,
    required PodcastTranscriptionProvider transcriptionProvider,
    required PodcastIntelligenceProvider intelligenceProvider,
    required PodcastTranscriptionCheckpointStore checkpoints,
    required PodcastTranscriptionArtifactStore artifacts,
    required PodcastCloudUsageLedger usageLedger,
    PodcastTranscriptionClock clock = const SystemPodcastTranscriptionClock(),
    this.policy = const PodcastTranscriptionPolicy(),
  })  : assert(policy.maximumMediaDuration > Duration.zero),
        _ingestor = ingestor,
        _transcriptionProvider = transcriptionProvider,
        _intelligenceProvider = intelligenceProvider,
        _checkpoints = checkpoints,
        _artifacts = artifacts,
        _usageLedger = usageLedger,
        _clock = clock;

  final PodcastMediaIngestor _ingestor;
  final PodcastTranscriptionProvider _transcriptionProvider;
  final PodcastIntelligenceProvider _intelligenceProvider;
  final PodcastTranscriptionCheckpointStore _checkpoints;
  final PodcastTranscriptionArtifactStore _artifacts;
  final PodcastCloudUsageLedger _usageLedger;
  final PodcastTranscriptionClock _clock;
  final PodcastTranscriptionPolicy policy;
  final Map<String, _PodcastOperation> _operations =
      <String, _PodcastOperation>{};

  Future<PodcastTranscriptionRunResult> run(
    PodcastTranscriptionRequest request,
    PodcastTaskCancellation cancellation,
  ) async {
    cancellation.throwIfCancelled();
    var operation = _operations[request.jobId];
    if (operation != null && operation.fingerprint != request.fingerprint) {
      throw const PodcastTranscriptionFailure(
        code: PodcastTranscriptionFailureCode.idempotencyConflict,
        retryable: false,
      );
    }
    operation ??= _start(request);
    _operations[request.jobId] = operation;
    operation.waiters += 1;
    try {
      return await Future.any<PodcastTranscriptionRunResult>(
        <Future<PodcastTranscriptionRunResult>>[
          operation.future,
          cancellation.whenCancelled.then<PodcastTranscriptionRunResult>((_) {
            throw const PodcastTaskCancelledException();
          }),
        ],
      );
    } finally {
      operation.waiters -= 1;
      if (operation.waiters == 0 && !operation.completed) {
        operation.cancellation.cancel();
      }
    }
  }

  Future<void> delete(String jobId) async {
    if (!_safeId.hasMatch(jobId)) {
      throw ArgumentError.value(jobId, 'jobId');
    }
    final operation = _operations[jobId];
    operation?.cancellation.cancel();
    try {
      final checkpoint = await _checkpoints.read(jobId);
      final artifact = await _artifacts.read(jobId);
      final assetId = checkpoint?.asset?.assetId;
      if (assetId != null) await _ingestor.deleteAsset(assetId);
      await _artifacts.delete(jobId);
      await _checkpoints.delete(jobId);
      await _usageLedger.deleteJob(_jobHash(jobId));
      if (artifact != null && assetId == null) {
        // A complete artifact without a checkpoint is corrupt but still deleted.
      }
    } on Object {
      throw const PodcastTranscriptionFailure(
        code: PodcastTranscriptionFailureCode.deleteFailure,
        retryable: true,
      );
    }
  }

  _PodcastOperation _start(PodcastTranscriptionRequest request) {
    final operation = _PodcastOperation(request.fingerprint);
    operation.future =
        _execute(request, operation.cancellation).whenComplete(() {
      operation.completed = true;
      if (identical(_operations[request.jobId], operation)) {
        _operations.remove(request.jobId);
      }
    });
    unawaited(
      operation.future.then<void>(
        (_) {},
        onError: (Object _, StackTrace __) {},
      ),
    );
    return operation;
  }

  Future<PodcastTranscriptionRunResult> _execute(
    PodcastTranscriptionRequest request,
    PodcastTaskCancellation cancellation,
  ) async {
    final fingerprint = request.fingerprint;
    final completed = await _artifacts.read(request.jobId);
    if (completed != null) {
      if (completed.fingerprint != fingerprint) {
        throw const PodcastTranscriptionFailure(
          code: PodcastTranscriptionFailureCode.idempotencyConflict,
          retryable: false,
        );
      }
      return PodcastTranscriptionRunResult(
        artifact: completed,
        fromCompletedCache: true,
        resumedAfterIngest: false,
        resumedAfterTranscription: false,
      );
    }
    var checkpoint = await _checkpoints.read(request.jobId);
    if (checkpoint != null && checkpoint.fingerprint != fingerprint) {
      throw const PodcastTranscriptionFailure(
        code: PodcastTranscriptionFailureCode.idempotencyConflict,
        retryable: false,
      );
    }
    checkpoint ??= PodcastTranscriptionCheckpoint(
      jobId: request.jobId,
      fingerprint: fingerprint,
    );
    _validateSourceBounds(request.source);
    final resumedAfterIngest = checkpoint.asset != null;
    final resumedAfterTranscription = checkpoint.transcript != null;
    cancellation.throwIfCancelled();

    var asset = checkpoint.asset;
    if (asset == null) {
      asset = await _ingest(request.source, cancellation);
      _validateAsset(asset, request.source);
      checkpoint = checkpoint.copyWith(asset: asset);
      await _writeCheckpoint(checkpoint);
    } else {
      _validateAsset(asset, request.source);
    }
    cancellation.throwIfCancelled();

    var transcript = checkpoint.transcript;
    if (transcript == null) {
      final operationId = 'podcast-transcribe:${fingerprint.substring(0, 48)}';
      final result = await _transcribe(
        asset,
        outputLanguage: request.outputLanguage,
        operationId: operationId,
        cancellation: cancellation,
      );
      _validateTranscript(result.transcript, asset.duration);
      if (request.outputLanguage != null &&
          result.transcript.language != request.outputLanguage) {
        throw const PodcastTranscriptionFailure(
          code: PodcastTranscriptionFailureCode.invalidTranscript,
          retryable: false,
        );
      }
      await _recordUsage(
        request.jobId,
        operationId,
        PodcastCloudUsageStage.transcription,
        result.billableDuration,
        result.costMicros,
      );
      transcript = result.transcript;
      checkpoint = checkpoint.copyWith(transcript: transcript);
      await _writeCheckpoint(checkpoint);
    } else {
      _validateTranscript(transcript, asset.duration);
      if (request.outputLanguage != null &&
          transcript.language != request.outputLanguage) {
        throw const PodcastTranscriptionFailure(
          code: PodcastTranscriptionFailureCode.invalidTranscript,
          retryable: false,
        );
      }
    }
    cancellation.throwIfCancelled();

    final intelligenceOperation =
        'podcast-intelligence:${fingerprint.substring(0, 48)}';
    final intelligence = await _analyze(
      transcript,
      request: request,
      operationId: intelligenceOperation,
      cancellation: cancellation,
    );
    _validateIntelligence(intelligence, asset.duration, request);
    await _recordUsage(
      request.jobId,
      intelligenceOperation,
      PodcastCloudUsageStage.intelligence,
      Duration.zero,
      intelligence.costMicros,
    );
    cancellation.throwIfCancelled();
    final artifact = PodcastTranscriptionArtifact(
      jobId: request.jobId,
      fingerprint: fingerprint,
      assetDigest: asset.contentDigest,
      transcript: transcript,
      chapters: intelligence.chapters,
      summary: intelligence.summary,
      createdAt: _utcNow(),
    );
    try {
      await _artifacts.write(artifact);
    } on Object {
      throw const PodcastTranscriptionFailure(
        code: PodcastTranscriptionFailureCode.persistenceFailure,
        retryable: true,
      );
    }
    return PodcastTranscriptionRunResult(
      artifact: artifact,
      fromCompletedCache: false,
      resumedAfterIngest: resumedAfterIngest,
      resumedAfterTranscription: resumedAfterTranscription,
    );
  }

  Future<PodcastMediaAsset> _ingest(
    PodcastMediaSource source,
    PodcastTaskCancellation cancellation,
  ) async {
    try {
      return await _ingestor.ingest(source, cancellation).timeout(
        policy.ingestTimeout,
        onTimeout: () {
          cancellation.cancel();
          throw const PodcastTranscriptionFailure(
            code: PodcastTranscriptionFailureCode.ingestTimeout,
            retryable: true,
          );
        },
      );
    } on PodcastTaskCancelledException {
      rethrow;
    } on PodcastTranscriptionFailure {
      rethrow;
    } on Object {
      throw const PodcastTranscriptionFailure(
        code: PodcastTranscriptionFailureCode.ingestFailure,
        retryable: true,
      );
    }
  }

  Future<PodcastTranscriptionProviderResult> _transcribe(
    PodcastMediaAsset asset, {
    required String? outputLanguage,
    required String operationId,
    required PodcastTaskCancellation cancellation,
  }) async {
    try {
      return await _transcriptionProvider
          .transcribe(
        asset,
        outputLanguage: outputLanguage,
        operationId: operationId,
        cancellation: cancellation,
      )
          .timeout(
        policy.transcriptionTimeout,
        onTimeout: () {
          cancellation.cancel();
          throw const PodcastTranscriptionFailure(
            code: PodcastTranscriptionFailureCode.transcriptionTimeout,
            retryable: true,
          );
        },
      );
    } on PodcastTaskCancelledException {
      rethrow;
    } on PodcastTranscriptionFailure {
      rethrow;
    } on Object {
      throw const PodcastTranscriptionFailure(
        code: PodcastTranscriptionFailureCode.transcriptionFailure,
        retryable: true,
      );
    }
  }

  Future<PodcastIntelligenceProviderResult> _analyze(
    PodcastTranscript transcript, {
    required PodcastTranscriptionRequest request,
    required String operationId,
    required PodcastTaskCancellation cancellation,
  }) async {
    try {
      return await _intelligenceProvider
          .analyze(
        transcript,
        generateChapters: request.generateChapters,
        generateSummary: request.generateSummary,
        operationId: operationId,
        cancellation: cancellation,
      )
          .timeout(
        policy.intelligenceTimeout,
        onTimeout: () {
          cancellation.cancel();
          throw const PodcastTranscriptionFailure(
            code: PodcastTranscriptionFailureCode.intelligenceTimeout,
            retryable: true,
          );
        },
      );
    } on PodcastTaskCancelledException {
      rethrow;
    } on PodcastTranscriptionFailure {
      rethrow;
    } on Object {
      throw const PodcastTranscriptionFailure(
        code: PodcastTranscriptionFailureCode.intelligenceFailure,
        retryable: true,
      );
    }
  }

  void _validateAsset(PodcastMediaAsset asset, PodcastMediaSource source) {
    if (!_allowedMediaTypes.contains(asset.mediaType)) {
      throw const PodcastTranscriptionFailure(
        code: PodcastTranscriptionFailureCode.invalidMedia,
        retryable: false,
      );
    }
    if (asset.bytes <= 0 || asset.bytes > policy.maximumMediaBytes) {
      throw const PodcastTranscriptionFailure(
        code: PodcastTranscriptionFailureCode.mediaTooLarge,
        retryable: false,
      );
    }
    if (asset.duration <= Duration.zero ||
        asset.duration > policy.maximumMediaDuration) {
      throw const PodcastTranscriptionFailure(
        code: PodcastTranscriptionFailureCode.mediaTooLong,
        retryable: false,
      );
    }
    final matchesDeclaration = switch (source) {
      final PodcastRemoteMediaSource remote =>
        (remote.expectedMediaType == null ||
                remote.expectedMediaType == asset.mediaType) &&
            (remote.expectedBytes == null ||
                remote.expectedBytes == asset.bytes) &&
            (remote.expectedDuration == null ||
                remote.expectedDuration == asset.duration),
      final PodcastUploadedMediaSource upload =>
        upload.mediaType == asset.mediaType &&
            upload.bytes == asset.bytes &&
            upload.duration == asset.duration,
    };
    if (!matchesDeclaration) {
      throw const PodcastTranscriptionFailure(
        code: PodcastTranscriptionFailureCode.invalidMedia,
        retryable: false,
      );
    }
  }

  void _validateSourceBounds(PodcastMediaSource source) {
    final (bytes, duration) = switch (source) {
      final PodcastRemoteMediaSource remote => (
          remote.expectedBytes,
          remote.expectedDuration
        ),
      final PodcastUploadedMediaSource upload => (
          upload.bytes,
          upload.duration
        ),
    };
    if (bytes != null && bytes > policy.maximumMediaBytes) {
      throw const PodcastTranscriptionFailure(
        code: PodcastTranscriptionFailureCode.mediaTooLarge,
        retryable: false,
      );
    }
    if (duration != null && duration > policy.maximumMediaDuration) {
      throw const PodcastTranscriptionFailure(
        code: PodcastTranscriptionFailureCode.mediaTooLong,
        retryable: false,
      );
    }
  }

  void _validateTranscript(PodcastTranscript transcript, Duration duration) {
    if (!_languageTag.hasMatch(transcript.language) ||
        !_safeVersion.hasMatch(transcript.providerVersion) ||
        transcript.segments.isEmpty ||
        transcript.segments.length > policy.maximumSegments ||
        transcript.characterCount > policy.maximumTranscriptCharacters) {
      throw const PodcastTranscriptionFailure(
        code: PodcastTranscriptionFailureCode.invalidTranscript,
        retryable: false,
      );
    }
    var priorEnd = Duration.zero;
    for (final entry in transcript.segments.indexed) {
      final segment = entry.$2;
      if (segment.index != entry.$1 ||
          segment.start < priorEnd ||
          segment.end <= segment.start ||
          segment.end > duration ||
          segment.text.trim().isEmpty ||
          segment.text.length > 4000 ||
          (segment.speaker?.length ?? 0) > 120) {
        throw const PodcastTranscriptionFailure(
          code: PodcastTranscriptionFailureCode.invalidTranscript,
          retryable: false,
        );
      }
      priorEnd = segment.end;
    }
  }

  void _validateIntelligence(
    PodcastIntelligenceProviderResult result,
    Duration duration,
    PodcastTranscriptionRequest request,
  ) {
    if (result.costMicros < 0 ||
        result.costMicros > policy.maximumStageCostMicros ||
        (!request.generateChapters && result.chapters.isNotEmpty) ||
        (!request.generateSummary && result.summary != null) ||
        (request.generateSummary && result.summary == null) ||
        result.chapters.length > policy.maximumChapters) {
      throw const PodcastTranscriptionFailure(
        code: PodcastTranscriptionFailureCode.invalidIntelligence,
        retryable: false,
      );
    }
    var prior = Duration.zero;
    for (final chapter in result.chapters) {
      if (chapter.start < prior ||
          chapter.start >= duration ||
          chapter.title.trim().isEmpty ||
          chapter.title.length > 200 ||
          chapter.summary.trim().isEmpty ||
          chapter.summary.length > 1000) {
        throw const PodcastTranscriptionFailure(
          code: PodcastTranscriptionFailureCode.invalidIntelligence,
          retryable: false,
        );
      }
      prior = chapter.start;
    }
    final summary = result.summary;
    if (summary != null &&
        (summary.oneLine.trim().isEmpty ||
            summary.oneLine.length > 500 ||
            summary.keyPoints.isEmpty ||
            summary.keyPoints.length > 10 ||
            summary.keyPoints.any(
              (value) => value.trim().isEmpty || value.length > 600,
            ) ||
            summary.keyPoints.toSet().length != summary.keyPoints.length ||
            summary.topics.length > 20 ||
            summary.topics.any(
              (value) => value.trim().isEmpty || value.length > 100,
            ) ||
            summary.topics.toSet().length != summary.topics.length ||
            !_languageTag.hasMatch(summary.language))) {
      throw const PodcastTranscriptionFailure(
        code: PodcastTranscriptionFailureCode.invalidIntelligence,
        retryable: false,
      );
    }
  }

  Future<void> _recordUsage(
    String jobId,
    String operationId,
    PodcastCloudUsageStage stage,
    Duration billableDuration,
    int costMicros,
  ) async {
    if (billableDuration.isNegative ||
        billableDuration > policy.maximumMediaDuration ||
        costMicros < 0 ||
        costMicros > policy.maximumStageCostMicros) {
      throw const PodcastTranscriptionFailure(
        code: PodcastTranscriptionFailureCode.meteringFailure,
        retryable: false,
      );
    }
    try {
      await _usageLedger.recordOnce(
        PodcastCloudUsageRecord(
          jobHash: _jobHash(jobId),
          operationId: operationId,
          stage: stage,
          billableDuration: billableDuration,
          costMicros: costMicros,
          recordedAt: _utcNow(),
        ),
      );
    } on PodcastTranscriptionFailure {
      rethrow;
    } on Object {
      throw const PodcastTranscriptionFailure(
        code: PodcastTranscriptionFailureCode.meteringFailure,
        retryable: true,
      );
    }
  }

  Future<void> _writeCheckpoint(
    PodcastTranscriptionCheckpoint checkpoint,
  ) async {
    try {
      await _checkpoints.write(checkpoint);
    } on Object {
      throw const PodcastTranscriptionFailure(
        code: PodcastTranscriptionFailureCode.persistenceFailure,
        retryable: true,
      );
    }
  }

  DateTime _utcNow() {
    final value = _clock.now();
    if (!value.isUtc) throw StateError('Podcast clock must return UTC');
    return value;
  }
}

final class _PodcastOperation {
  _PodcastOperation(this.fingerprint);

  final String fingerprint;
  final PodcastTaskCancellation cancellation = PodcastTaskCancellation();
  late Future<PodcastTranscriptionRunResult> future;
  var waiters = 0;
  var completed = false;
}

const _allowedMediaTypes = <String>{
  'audio/mpeg',
  'audio/mp4',
  'audio/ogg',
  'audio/wav',
  'audio/webm',
  'video/mp4',
  'video/webm',
};
final _safeId = RegExp(r'^[A-Za-z0-9._:-]{3,256}$');
final _safeVersion = RegExp(r'^[A-Za-z0-9._-]{1,128}$');
final _sha256Pattern = RegExp(r'^[a-f0-9]{64}$');
final _languageTag = RegExp(r'^[A-Za-z]{2,8}(?:-[A-Za-z0-9]{1,8})*$');

void _validateDeclaredMedia(
  String? mediaType,
  int? bytes,
  Duration? duration,
) {
  if (mediaType != null && !_allowedMediaTypes.contains(mediaType)) {
    throw ArgumentError.value(mediaType, 'mediaType');
  }
  if (bytes != null && bytes <= 0) throw ArgumentError.value(bytes, 'bytes');
  if (duration != null && duration <= Duration.zero) {
    throw ArgumentError.value(duration, 'duration');
  }
}

bool _safeRemoteUri(Uri uri) {
  if (uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.fragment.isNotEmpty ||
      (uri.hasPort && uri.port != 443) ||
      uri.toString().length > 4096) {
    return false;
  }
  final host = uri.host.toLowerCase();
  if (host == 'localhost' ||
      host.endsWith('.localhost') ||
      host.endsWith('.local') ||
      host.endsWith('.internal') ||
      host == '0.0.0.0' ||
      host == '::' ||
      host == '::1') {
    return false;
  }
  if (host.contains(':')) {
    final compact = host.replaceAll(RegExp(r'^0+'), '');
    if (compact.startsWith('fc') ||
        compact.startsWith('fd') ||
        compact.startsWith('fe8') ||
        compact.startsWith('fe9') ||
        compact.startsWith('fea') ||
        compact.startsWith('feb') ||
        compact.startsWith('ff') ||
        compact.startsWith('2001:db8')) {
      return false;
    }
  }
  final parts = host.split('.');
  if (parts.length == 4 && parts.every((part) => int.tryParse(part) != null)) {
    final values = parts.map(int.parse).toList(growable: false);
    if (values.any((value) => value < 0 || value > 255)) return false;
    final first = values[0];
    final second = values[1];
    if (first == 0 ||
        first == 10 ||
        first == 127 ||
        first >= 224 ||
        (first == 100 && second >= 64 && second <= 127) ||
        (first == 169 && second == 254) ||
        (first == 172 && second >= 16 && second <= 31) ||
        (first == 192 && second == 168)) {
      return false;
    }
  }
  return true;
}

String _jobHash(String jobId) => sha256.convert(utf8.encode(jobId)).toString();
String _shortHash(String value) =>
    sha256.convert(utf8.encode(value)).toString().substring(0, 12);
