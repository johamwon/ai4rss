import 'dart:async';
import 'dart:convert';

import 'package:river_domain/river_domain.dart';
import 'package:river_feed/river_feed.dart';

import 'job_queue.dart';
import 'podcast_download_store.dart';

typedef PodcastEpisodeLoader =
    Future<PodcastEpisodeRecord?> Function(String episodeId);

final class DurablePodcastDownloadManager implements PodcastDownloadManager {
  DurablePodcastDownloadManager({
    required PersistentJobQueue jobs,
    required DriftPodcastDownloadStore store,
    required PodcastEpisodeLoader loadEpisode,
    required PodcastTransferBackend backend,
    required NetworkMonitor network,
    required Clock clock,
    required IdGenerator ids,
    this.maxAttempts = 5,
    this.leaseDuration = const Duration(minutes: 5),
    this.retryBaseDelay = const Duration(seconds: 30),
    this.maxRetryDelay = const Duration(minutes: 15),
  }) : assert(maxAttempts > 0),
       assert(!retryBaseDelay.isNegative),
       assert(!maxRetryDelay.isNegative),
       _jobs = jobs,
       _store = store,
       _loadEpisode = loadEpisode,
       _backend = backend,
       _network = network,
       _clock = clock,
       _ids = ids;

  static const jobType = 'podcast-download/v1';
  static const _idempotencyPrefix = 'podcast-download:v1:';

  final PersistentJobQueue _jobs;
  final DriftPodcastDownloadStore _store;
  final PodcastEpisodeLoader _loadEpisode;
  final PodcastTransferBackend _backend;
  final NetworkMonitor _network;
  final Clock _clock;
  final IdGenerator _ids;
  final int maxAttempts;
  final Duration leaseDuration;
  final Duration retryBaseDelay;
  final Duration maxRetryDelay;
  final StreamController<PodcastDownloadState> _changes =
      StreamController<PodcastDownloadState>.broadcast(sync: true);
  final Set<String> _cancelledEpisodes = <String>{};

  StreamSubscription<NetworkAvailability>? _networkSubscription;
  Future<void>? _activeRun;
  Timer? _retryTimer;
  DateTime? _retryAt;
  var _startupRecovered = false;
  var _started = false;
  var _closed = false;

  Future<void> start() async {
    if (_started || _closed) return;
    _started = true;
    _networkSubscription = _network.changes.listen((availability) {
      if (availability.mayAttemptRequest) {
        unawaited(_resumeAfterConnectivity());
      }
    }, onError: (_, __) => unawaited(_resumeAfterConnectivity()));
    await resumePending();
  }

  @override
  Stream<PodcastDownloadState> watch(String episodeId) async* {
    final normalized = _normalizeEpisodeId(episodeId);
    yield await status(normalized);
    yield* _changes.stream.where((state) => state.episodeId == normalized);
  }

  @override
  Future<PodcastDownloadState> status(String episodeId) async {
    final normalized = _normalizeEpisodeId(episodeId);
    final saved = await _store.read(normalized);
    if (saved?.isAvailable ?? false) {
      final exists = await _backend.isAvailable(saved!.availablePath!);
      if (!exists) {
        await _store.remove(normalized);
        return PodcastDownloadState.notDownloaded(normalized);
      }
    }
    if (saved != null && saved.sourceUri != null) {
      final episode = await _safeLoadEpisode(normalized);
      if (episode != null && saved.sourceUri != episode.mediaUrl) {
        await _discardSaved(saved);
        await _store.remove(normalized);
        return PodcastDownloadState.notDownloaded(normalized);
      }
    }
    final job = await _jobs.findByIdempotencyKey(_idempotencyKey(normalized));
    if (job == null) {
      return saved ?? PodcastDownloadState.notDownloaded(normalized);
    }
    return _stateForJob(normalized, job, saved);
  }

  @override
  Future<void> enqueue(String episodeId) async {
    final normalized = _normalizeEpisodeId(episodeId);
    _cancelledEpisodes.remove(normalized);
    final episode = await _safeLoadEpisode(normalized);
    if (episode == null) {
      throw ArgumentError.value(
        episodeId,
        'episodeId',
        'Podcast episode is missing.',
      );
    }
    var saved = await _store.read(normalized);
    if (saved != null && saved.sourceUri != episode.mediaUrl) {
      await _discardSaved(saved);
      await _store.remove(normalized);
      saved = null;
    }
    if (saved?.isAvailable ?? false) {
      _emit(saved!);
      return;
    }
    final now = _clock.now().toUtc();
    await _store.queue(
      episodeId: normalized,
      sourceUri: episode.mediaUrl,
      updatedAt: now,
      resume: saved,
    );
    final inserted = await _jobs.enqueue(
      NewDurableJob(
        id: _ids.next(),
        type: jobType,
        idempotencyKey: _idempotencyKey(normalized),
        payloadJson: jsonEncode(<String, String>{'episodeId': normalized}),
        availableAt: now,
        maxAttempts: maxAttempts,
      ),
      now,
    );
    if (!inserted) {
      await _jobs.requeue(
        idempotencyKey: _idempotencyKey(normalized),
        now: now,
      );
    }
    _emit((await _store.read(normalized))!);
    unawaited(resumePending());
  }

  @override
  Future<void> retry(String episodeId) => enqueue(episodeId);

  @override
  Future<void> remove(String episodeId) async {
    final normalized = _normalizeEpisodeId(episodeId);
    _cancelledEpisodes.add(normalized);
    await _jobs.cancelByIdempotencyKey(
      idempotencyKey: _idempotencyKey(normalized),
      now: _clock.now().toUtc(),
    );
    final saved = await _store.remove(normalized);
    if (saved != null) await _discardSaved(saved);
    _emit(PodcastDownloadState.notDownloaded(normalized));
  }

  @override
  Future<void> resumePending() {
    if (_closed) return Future<void>.value();
    final active = _activeRun;
    if (active != null) return active;
    late final Future<void> tracked;
    tracked = _resumePending().whenComplete(() {
      if (identical(_activeRun, tracked)) _activeRun = null;
    });
    _activeRun = tracked;
    return tracked;
  }

  Future<void> _resumePending() async {
    final availability = await _safeAvailability();
    if (availability.isOffline || _closed) return;
    var now = _clock.now().toUtc();
    await _jobs.recoverExpiredLeases(
      now,
      typePrefix: jobType,
      includeUnexpired: !_startupRecovered,
    );
    _startupRecovered = true;
    while (!_closed) {
      final claimed = await _jobs.claimNext(
        now: now,
        leaseDuration: leaseDuration,
        type: jobType,
      );
      if (claimed == null) return;
      await _process(claimed);
      now = _clock.now().toUtc();
    }
  }

  Future<void> _process(ClaimedDurableJob job) async {
    final episodeId = _decodeEpisodeId(job.payloadJson);
    if (episodeId == null) {
      await _jobs.failPermanently(
        id: job.id,
        errorCode: 'invalid_payload',
        now: _clock.now().toUtc(),
      );
      return;
    }
    if (_cancelledEpisodes.contains(episodeId)) return;

    PodcastEpisodeRecord? episode;
    try {
      episode = await _loadEpisode(episodeId);
    } on Object {
      await _failBeforeEpisode(
        job,
        episodeId,
        PodcastDownloadFailureCode.unexpected,
      );
      return;
    }
    if (episode == null) {
      await _failPermanently(
        job,
        episodeId,
        PodcastDownloadFailureCode.episodeMissing,
      );
      return;
    }
    final currentEpisode = episode;

    var saved = await _store.read(episodeId);
    if (saved != null && saved.sourceUri != currentEpisode.mediaUrl) {
      await _discardSaved(saved);
      await _store.remove(episodeId);
      saved = null;
    }
    await _store.progress(
      episodeId: episodeId,
      sourceUri: currentEpisode.mediaUrl,
      phase: PodcastDownloadPhase.downloading,
      partialPath: saved?.partialPath,
      downloadedBytes: saved?.downloadedBytes ?? 0,
      totalBytes: saved?.totalBytes ?? currentEpisode.mediaLengthBytes,
      etag: saved?.etag,
      updatedAt: _clock.now().toUtc(),
    );
    _emit((await _store.read(episodeId))!);

    PodcastTransferResult result;
    try {
      result = await _backend.transfer(
        PodcastTransferRequest(
          episodeId: episodeId,
          sourceUri: currentEpisode.mediaUrl,
          partialPath: saved?.partialPath,
          resumeFromBytes: saved?.downloadedBytes ?? 0,
          expectedTotalBytes:
              saved?.totalBytes ?? currentEpisode.mediaLengthBytes,
          etag: saved?.etag,
          expectedMimeType: currentEpisode.mediaMimeType,
        ),
        onProgress: (progress) async {
          if (_closed || _cancelledEpisodes.contains(episodeId)) return;
          await _store.progress(
            episodeId: episodeId,
            sourceUri: currentEpisode.mediaUrl,
            phase: PodcastDownloadPhase.downloading,
            partialPath: progress.partialPath,
            downloadedBytes: progress.downloadedBytes,
            totalBytes: progress.totalBytes,
            etag: progress.etag,
            updatedAt: _clock.now().toUtc(),
          );
          _emit((await _store.read(episodeId))!);
        },
      );
    } on Object {
      result = PodcastTransferFailure(
        code: PodcastDownloadFailureCode.unexpected,
        retryable: true,
        partialPath: saved?.partialPath,
        downloadedBytes: saved?.downloadedBytes ?? 0,
        totalBytes: saved?.totalBytes,
        etag: saved?.etag,
      );
    }

    if (_cancelledEpisodes.contains(episodeId)) {
      if (result case PodcastTransferSuccess(:final availablePath)) {
        await _backend.discard(availablePath: availablePath);
      }
      return;
    }

    switch (result) {
      case PodcastTransferSuccess():
        PodcastEpisodeRecord? latest;
        try {
          latest = await _loadEpisode(episodeId);
        } on Object {
          latest = currentEpisode;
        }
        if (latest == null || latest.mediaUrl != currentEpisode.mediaUrl) {
          await _backend.discard(availablePath: result.availablePath);
          final now = _clock.now().toUtc();
          await _jobs.failPermanently(
            id: job.id,
            errorCode: PodcastDownloadFailureCode.sourceChanged,
            now: now,
          );
          if (latest != null) {
            await _jobs.requeue(
              idempotencyKey: _idempotencyKey(episodeId),
              now: now,
            );
            await _store.queue(
              episodeId: episodeId,
              sourceUri: latest.mediaUrl,
              updatedAt: now,
            );
          }
          return;
        }
        await _store.available(
          episodeId: episodeId,
          sourceUri: currentEpisode.mediaUrl,
          availablePath: result.availablePath,
          totalBytes: result.totalBytes,
          etag: result.etag,
          updatedAt: _clock.now().toUtc(),
        );
        await _jobs.complete(job.id, _clock.now().toUtc());
        _emit((await _store.read(episodeId))!);
      case PodcastTransferFailure():
        await _acceptFailure(job, currentEpisode, result);
    }
  }

  Future<void> _acceptFailure(
    ClaimedDurableJob job,
    PodcastEpisodeRecord episode,
    PodcastTransferFailure failure,
  ) async {
    var partialPath = failure.partialPath;
    var downloadedBytes = failure.downloadedBytes;
    var totalBytes = failure.totalBytes;
    var etag = failure.etag;
    if (failure.discardPartial) {
      await _backend.discard(partialPath: partialPath);
      partialPath = null;
      downloadedBytes = 0;
      totalBytes = null;
      etag = null;
    }
    final now = _clock.now().toUtc();
    if (failure.retryable) {
      final delay = _retryDelay(job.attempt);
      final next = await _jobs.failOrRetry(
        id: job.id,
        errorCode: failure.code,
        now: now,
        retryDelay: delay,
      );
      if (next == DurableJobStatus.queued) {
        await _store.progress(
          episodeId: episode.id,
          sourceUri: episode.mediaUrl,
          phase: PodcastDownloadPhase.queued,
          partialPath: partialPath,
          downloadedBytes: downloadedBytes,
          totalBytes: totalBytes,
          etag: etag,
          failureCode: failure.code,
          updatedAt: now,
        );
        _scheduleRetry(delay);
        _emit((await _store.read(episode.id))!);
        return;
      }
    } else {
      await _jobs.failPermanently(
        id: job.id,
        errorCode: failure.code,
        now: now,
      );
    }
    await _store.failed(
      episodeId: episode.id,
      sourceUri: episode.mediaUrl,
      failureCode: failure.code,
      partialPath: partialPath,
      downloadedBytes: downloadedBytes,
      totalBytes: totalBytes,
      etag: etag,
      updatedAt: now,
    );
    _emit((await _store.read(episode.id))!);
  }

  Future<void> _failPermanently(
    ClaimedDurableJob job,
    String episodeId,
    String code,
  ) async {
    await _jobs.failPermanently(
      id: job.id,
      errorCode: code,
      now: _clock.now().toUtc(),
    );
    _emit(
      PodcastDownloadState(
        episodeId: episodeId,
        phase: PodcastDownloadPhase.failed,
        failureCode: code,
      ),
    );
  }

  Future<void> _failBeforeEpisode(
    ClaimedDurableJob job,
    String episodeId,
    String code,
  ) async {
    final delay = _retryDelay(job.attempt);
    final next = await _jobs.failOrRetry(
      id: job.id,
      errorCode: code,
      now: _clock.now().toUtc(),
      retryDelay: delay,
    );
    _emit(
      PodcastDownloadState(
        episodeId: episodeId,
        phase: next == DurableJobStatus.queued
            ? PodcastDownloadPhase.queued
            : PodcastDownloadPhase.failed,
        failureCode: code,
      ),
    );
    if (next == DurableJobStatus.queued) _scheduleRetry(delay);
  }

  Future<void> _resumeAfterConnectivity() async {
    await _jobs.expediteQueued(
      type: jobType,
      errorCodes: const <String>{
        PodcastDownloadFailureCode.network,
        PodcastDownloadFailureCode.timeout,
      },
      now: _clock.now().toUtc(),
    );
    await resumePending();
  }

  PodcastDownloadState _stateForJob(
    String episodeId,
    DurableJobRecord job,
    PodcastDownloadState? saved,
  ) {
    final fallback = saved ?? PodcastDownloadState.notDownloaded(episodeId);
    return PodcastDownloadState(
      episodeId: episodeId,
      phase: switch (job.status) {
        DurableJobStatus.queued => PodcastDownloadPhase.queued,
        DurableJobStatus.running => PodcastDownloadPhase.downloading,
        DurableJobStatus.completed =>
          fallback.isAvailable
              ? PodcastDownloadPhase.available
              : PodcastDownloadPhase.notDownloaded,
        DurableJobStatus.failed => PodcastDownloadPhase.failed,
        DurableJobStatus.cancelled => PodcastDownloadPhase.notDownloaded,
      },
      sourceUri: fallback.sourceUri,
      partialPath: fallback.partialPath,
      availablePath: fallback.availablePath,
      downloadedBytes: fallback.downloadedBytes,
      totalBytes: fallback.totalBytes,
      etag: fallback.etag,
      failureCode: job.lastErrorCode ?? fallback.failureCode,
    );
  }

  Future<PodcastEpisodeRecord?> _safeLoadEpisode(String episodeId) async {
    try {
      return await _loadEpisode(episodeId);
    } on Object {
      return null;
    }
  }

  Future<void> _discardSaved(PodcastDownloadState saved) => _backend.discard(
    partialPath: saved.partialPath,
    availablePath: saved.availablePath,
  );

  Future<NetworkAvailability> _safeAvailability() async {
    try {
      return await _network.check();
    } on Object {
      return NetworkAvailability.unknown;
    }
  }

  Duration _retryDelay(int attempt) {
    final exponent = (attempt - 1).clamp(0, 5).toInt();
    final candidate = retryBaseDelay * (1 << exponent);
    return candidate > maxRetryDelay ? maxRetryDelay : candidate;
  }

  void _scheduleRetry(Duration delay) {
    final retryAt = _clock.now().toUtc().add(delay);
    final scheduled = _retryAt;
    if (scheduled != null && !retryAt.isBefore(scheduled)) return;
    _retryTimer?.cancel();
    _retryAt = retryAt;
    _retryTimer = Timer(delay, () {
      _retryTimer = null;
      _retryAt = null;
      unawaited(resumePending());
    });
  }

  String _normalizeEpisodeId(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty || normalized.length > 512) {
      throw ArgumentError.value(value, 'episodeId', 'Invalid episode ID.');
    }
    return normalized;
  }

  String _idempotencyKey(String episodeId) => '$_idempotencyPrefix$episodeId';

  String? _decodeEpisodeId(String payload) {
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map<String, dynamic>) return null;
      final value = decoded['episodeId'];
      if (value is! String) return null;
      return _normalizeEpisodeId(value);
    } on Object {
      return null;
    }
  }

  void _emit(PodcastDownloadState state) {
    if (!_closed) _changes.add(state);
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _retryTimer?.cancel();
    _retryTimer = null;
    _retryAt = null;
    await _networkSubscription?.cancel();
    await _activeRun;
    await _changes.close();
  }
}
