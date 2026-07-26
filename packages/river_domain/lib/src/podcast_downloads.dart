enum PodcastDownloadPhase {
  notDownloaded,
  queued,
  downloading,
  available,
  failed,
}

abstract final class PodcastDownloadFailureCode {
  static const network = 'network';
  static const timeout = 'timeout';
  static const storageFull = 'storage_full';
  static const corruptMedia = 'corrupt_media';
  static const sourceChanged = 'source_changed';
  static const invalidResponse = 'invalid_response';
  static const episodeMissing = 'episode_missing';
  static const unavailable = 'unavailable';
  static const unexpected = 'unexpected';
}

final class PodcastDownloadState {
  const PodcastDownloadState({
    required this.episodeId,
    required this.phase,
    this.sourceUri,
    this.partialPath,
    this.availablePath,
    this.downloadedBytes = 0,
    this.totalBytes,
    this.etag,
    this.failureCode,
  })  : assert(downloadedBytes >= 0),
        assert(totalBytes == null || totalBytes >= downloadedBytes);

  const PodcastDownloadState.notDownloaded(String episodeId)
      : this(episodeId: episodeId, phase: PodcastDownloadPhase.notDownloaded);

  final String episodeId;
  final PodcastDownloadPhase phase;
  final Uri? sourceUri;
  final String? partialPath;
  final String? availablePath;
  final int downloadedBytes;
  final int? totalBytes;
  final String? etag;
  final String? failureCode;

  bool get isAvailable =>
      phase == PodcastDownloadPhase.available && availablePath != null;

  Uri? get playbackUri => isAvailable ? Uri.file(availablePath!) : null;
}

abstract interface class PodcastDownloadManager {
  Stream<PodcastDownloadState> watch(String episodeId);

  Future<PodcastDownloadState> status(String episodeId);

  Future<void> enqueue(String episodeId);

  Future<void> retry(String episodeId);

  Future<void> remove(String episodeId);

  Future<void> resumePending();
}

final class PodcastTransferRequest {
  PodcastTransferRequest({
    required this.episodeId,
    required this.sourceUri,
    this.partialPath,
    this.resumeFromBytes = 0,
    this.expectedTotalBytes,
    this.etag,
    this.expectedMimeType,
  }) {
    if (!_isSafeRemoteUri(sourceUri)) {
      throw ArgumentError.value(sourceUri, 'sourceUri', 'Unsafe media URI.');
    }
    if (resumeFromBytes < 0) {
      throw ArgumentError.value(
        resumeFromBytes,
        'resumeFromBytes',
        'Resume offset cannot be negative.',
      );
    }
    if (expectedTotalBytes != null && expectedTotalBytes! < resumeFromBytes) {
      throw ArgumentError.value(
        expectedTotalBytes,
        'expectedTotalBytes',
        'Expected length cannot be smaller than the resume offset.',
      );
    }
  }

  final String episodeId;
  final Uri sourceUri;
  final String? partialPath;
  final int resumeFromBytes;
  final int? expectedTotalBytes;
  final String? etag;
  final String? expectedMimeType;
}

final class PodcastTransferProgress {
  const PodcastTransferProgress({
    required this.partialPath,
    required this.downloadedBytes,
    this.totalBytes,
    this.etag,
  })  : assert(downloadedBytes >= 0),
        assert(totalBytes == null || totalBytes >= downloadedBytes);

  final String partialPath;
  final int downloadedBytes;
  final int? totalBytes;
  final String? etag;
}

sealed class PodcastTransferResult {
  const PodcastTransferResult();
}

final class PodcastTransferSuccess extends PodcastTransferResult {
  const PodcastTransferSuccess({
    required this.availablePath,
    required this.downloadedBytes,
    required this.totalBytes,
    this.etag,
  })  : assert(downloadedBytes >= 0),
        assert(totalBytes == downloadedBytes);

  final String availablePath;
  final int downloadedBytes;
  final int totalBytes;
  final String? etag;
}

final class PodcastTransferFailure extends PodcastTransferResult {
  const PodcastTransferFailure({
    required this.code,
    required this.retryable,
    this.partialPath,
    this.downloadedBytes = 0,
    this.totalBytes,
    this.etag,
    this.discardPartial = false,
  })  : assert(downloadedBytes >= 0),
        assert(totalBytes == null || totalBytes >= downloadedBytes);

  final String code;
  final bool retryable;
  final String? partialPath;
  final int downloadedBytes;
  final int? totalBytes;
  final String? etag;
  final bool discardPartial;
}

abstract interface class PodcastTransferBackend {
  Future<PodcastTransferResult> transfer(
    PodcastTransferRequest request, {
    required Future<void> Function(PodcastTransferProgress progress) onProgress,
  });

  Future<void> discard({
    String? partialPath,
    String? availablePath,
  });
}

final class UnavailablePodcastTransferBackend
    implements PodcastTransferBackend {
  const UnavailablePodcastTransferBackend();

  @override
  Future<void> discard({String? partialPath, String? availablePath}) async {}

  @override
  Future<PodcastTransferResult> transfer(
    PodcastTransferRequest request, {
    required Future<void> Function(PodcastTransferProgress progress) onProgress,
  }) async =>
      const PodcastTransferFailure(
        code: PodcastDownloadFailureCode.unavailable,
        retryable: false,
      );
}

bool _isSafeRemoteUri(Uri uri) =>
    (uri.scheme == 'http' || uri.scheme == 'https') &&
    uri.host.isNotEmpty &&
    uri.userInfo.isEmpty;
