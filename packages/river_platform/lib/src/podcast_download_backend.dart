import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:river_domain/river_domain.dart';

typedef PodcastDownloadDirectoryProvider = Future<Directory> Function();

final class IoPodcastTransferBackend implements PodcastTransferBackend {
  IoPodcastTransferBackend({
    PodcastDownloadDirectoryProvider? directoryProvider,
    HttpClient Function()? clientFactory,
    this.requestTimeout = const Duration(seconds: 30),
    this.maxRedirects = 5,
    this.maximumBytes = 2 * 1024 * 1024 * 1024,
    this.progressIntervalBytes = 256 * 1024,
  })  : assert(maxRedirects >= 0),
        assert(maximumBytes > 0),
        assert(progressIntervalBytes > 0),
        _directoryProvider = directoryProvider ?? _defaultDirectory,
        _clientFactory = clientFactory ?? HttpClient.new;

  final PodcastDownloadDirectoryProvider _directoryProvider;
  final HttpClient Function() _clientFactory;
  final Duration requestTimeout;
  final int maxRedirects;
  final int maximumBytes;
  final int progressIntervalBytes;

  @override
  Future<PodcastTransferResult> transfer(
    PodcastTransferRequest request, {
    required Future<void> Function(PodcastTransferProgress progress) onProgress,
  }) async {
    Directory root;
    try {
      root = await _directoryProvider();
      await root.create(recursive: true);
    } on FileSystemException catch (error) {
      return _fileFailure(error);
    }

    final paths = await _paths(root, request);
    var partial = paths.partial;
    var offset = await _safeLength(partial);
    if (request.partialPath != null &&
        _isInside(root, File(request.partialPath!))) {
      final requestedPartial = File(request.partialPath!);
      if (await requestedPartial.exists()) {
        partial = requestedPartial;
        offset = await _safeLength(partial);
      }
    }
    if (offset > maximumBytes) {
      await _safeDelete(partial);
      return const PodcastTransferFailure(
        code: PodcastDownloadFailureCode.invalidResponse,
        retryable: false,
        discardPartial: true,
      );
    }
    if (request.expectedTotalBytes case final expected?
        when expected > 0 && offset > expected) {
      await _safeDelete(partial);
      offset = 0;
    }

    final client = _clientFactory();
    client.connectionTimeout = requestTimeout;
    try {
      var restartWithoutRange = false;
      while (true) {
        final response = await _open(
          client,
          request.sourceUri,
          offset: restartWithoutRange ? 0 : offset,
          etag: restartWithoutRange ? null : request.etag,
        );
        final status = response.statusCode;
        if (status == HttpStatus.requestedRangeNotSatisfiable &&
            offset > 0 &&
            !restartWithoutRange) {
          final total = _unsatisfiedTotal(
            response.headers.value(HttpHeaders.contentRangeHeader),
          );
          await response.drain<void>();
          if (total != null && total == offset) {
            return _finalize(
              partial: partial,
              available: paths.available,
              totalBytes: total,
              expectedMimeType: request.expectedMimeType,
              responseMimeType: null,
              etag: request.etag,
            );
          }
          await _safeDelete(partial);
          offset = 0;
          restartWithoutRange = true;
          continue;
        }
        if (status != HttpStatus.ok && status != HttpStatus.partialContent) {
          await response.drain<void>();
          return PodcastTransferFailure(
            code: PodcastDownloadFailureCode.invalidResponse,
            retryable: status == HttpStatus.requestTimeout ||
                status == HttpStatus.tooManyRequests ||
                status >= 500,
            partialPath: partial.path,
            downloadedBytes: offset,
            totalBytes: request.expectedTotalBytes,
            etag: request.etag,
          );
        }

        final acceptedRange = status == HttpStatus.partialContent &&
            offset > 0 &&
            _rangeStartsAt(
              response.headers.value(HttpHeaders.contentRangeHeader),
              offset,
            );
        if (status == HttpStatus.partialContent &&
            offset > 0 &&
            !acceptedRange) {
          await response.drain<void>();
          return PodcastTransferFailure(
            code: PodcastDownloadFailureCode.invalidResponse,
            retryable: false,
            partialPath: partial.path,
            downloadedBytes: offset,
            totalBytes: request.expectedTotalBytes,
            etag: request.etag,
            discardPartial: true,
          );
        }
        if (status == HttpStatus.ok && offset > 0) {
          await _safeDelete(partial);
          offset = 0;
        }

        final responseMimeType = response.headers.contentType?.mimeType;
        if (!_acceptsMimeType(responseMimeType, request.expectedMimeType)) {
          await response.drain<void>();
          return PodcastTransferFailure(
            code: PodcastDownloadFailureCode.corruptMedia,
            retryable: false,
            partialPath: partial.path,
            downloadedBytes: offset,
            etag: request.etag,
            discardPartial: true,
          );
        }
        final totalBytes = _totalBytes(response, offset);
        if (totalBytes != null && totalBytes > maximumBytes) {
          await response.drain<void>();
          return PodcastTransferFailure(
            code: PodcastDownloadFailureCode.invalidResponse,
            retryable: false,
            partialPath: partial.path,
            downloadedBytes: offset,
            totalBytes: totalBytes,
            discardPartial: true,
          );
        }

        final etag =
            _boundedHeader(response.headers.value(HttpHeaders.etagHeader)) ??
                request.etag;
        var downloaded = offset;
        var lastReported = downloaded;
        RandomAccessFile? output;
        try {
          output = await partial.open(
            mode: downloaded == 0 ? FileMode.write : FileMode.append,
          );
          await for (final chunk in response.timeout(requestTimeout)) {
            downloaded += chunk.length;
            if (downloaded > maximumBytes ||
                (totalBytes != null && downloaded > totalBytes)) {
              return PodcastTransferFailure(
                code: PodcastDownloadFailureCode.invalidResponse,
                retryable: false,
                partialPath: partial.path,
                downloadedBytes: downloaded,
                totalBytes: null,
                etag: etag,
                discardPartial: true,
              );
            }
            await output.writeFrom(chunk);
            if (downloaded - lastReported >= progressIntervalBytes) {
              await onProgress(
                PodcastTransferProgress(
                  partialPath: partial.path,
                  downloadedBytes: downloaded,
                  totalBytes: totalBytes,
                  etag: etag,
                ),
              );
              lastReported = downloaded;
            }
          }
        } finally {
          await output?.close();
        }
        await onProgress(
          PodcastTransferProgress(
            partialPath: partial.path,
            downloadedBytes: downloaded,
            totalBytes: totalBytes,
            etag: etag,
          ),
        );
        if (totalBytes != null && downloaded != totalBytes) {
          return PodcastTransferFailure(
            code: PodcastDownloadFailureCode.network,
            retryable: true,
            partialPath: partial.path,
            downloadedBytes: downloaded,
            totalBytes: totalBytes,
            etag: etag,
          );
        }
        if (request.expectedTotalBytes case final expected?
            when expected > 0 && downloaded != expected) {
          return PodcastTransferFailure(
            code: PodcastDownloadFailureCode.corruptMedia,
            retryable: false,
            partialPath: partial.path,
            downloadedBytes: downloaded,
            totalBytes: downloaded,
            etag: etag,
            discardPartial: true,
          );
        }
        return _finalize(
          partial: partial,
          available: paths.available,
          totalBytes: downloaded,
          expectedMimeType: request.expectedMimeType,
          responseMimeType: responseMimeType,
          etag: etag,
        );
      }
    } on _InvalidResponseException {
      return PodcastTransferFailure(
        code: PodcastDownloadFailureCode.invalidResponse,
        retryable: false,
        partialPath: offset == 0 ? null : partial.path,
        downloadedBytes: await _safeLength(partial),
        totalBytes: request.expectedTotalBytes,
        etag: request.etag,
      );
    } on TimeoutException {
      return _interrupted(
        partial,
        request,
        PodcastDownloadFailureCode.timeout,
      );
    } on SocketException {
      return _interrupted(
        partial,
        request,
        PodcastDownloadFailureCode.network,
      );
    } on HttpException {
      return _interrupted(
        partial,
        request,
        PodcastDownloadFailureCode.network,
      );
    } on FileSystemException catch (error) {
      return _fileFailure(
        error,
        partialPath: partial.path,
        downloadedBytes: await _safeLength(partial),
        totalBytes: request.expectedTotalBytes,
        etag: request.etag,
      );
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<void> discard({String? partialPath, String? availablePath}) async {
    final root = await _directoryProvider();
    for (final path in <String?>[partialPath, availablePath]) {
      if (path == null) continue;
      final file = File(path);
      if (_isInside(root, file)) await _safeDelete(file);
    }
  }

  @override
  Future<bool> isAvailable(String availablePath) async {
    final root = await _directoryProvider();
    final file = File(availablePath);
    return _isInside(root, file) &&
        await file.exists() &&
        await file.length() > 0;
  }

  Future<HttpClientResponse> _open(
    HttpClient client,
    Uri initialUri, {
    required int offset,
    String? etag,
  }) async {
    var uri = initialUri;
    for (var redirect = 0;; redirect += 1) {
      if (!_safeRemote(uri)) {
        throw const _InvalidResponseException();
      }
      final request = await client.getUrl(uri).timeout(requestTimeout)
        ..followRedirects = false
        ..headers.set(
          HttpHeaders.acceptHeader,
          'audio/*,application/octet-stream;q=0.8',
        )
        ..headers.set(HttpHeaders.userAgentHeader, 'River/0.1 Podcast');
      if (offset > 0) {
        request.headers.set(HttpHeaders.rangeHeader, 'bytes=$offset-');
        final boundedEtag = _boundedHeader(etag);
        if (boundedEtag != null) {
          request.headers.set(HttpHeaders.ifRangeHeader, boundedEtag);
        }
      }
      final response = await request.close().timeout(requestTimeout);
      if (!_isRedirect(response.statusCode)) return response;
      if (redirect >= maxRedirects) {
        await response.drain<void>();
        throw const _InvalidResponseException();
      }
      final location = response.headers.value(HttpHeaders.locationHeader);
      await response.drain<void>();
      if (location == null || location.length > 4096) {
        throw const _InvalidResponseException();
      }
      final redirected = uri.resolve(location);
      if (uri.scheme == 'https' && redirected.scheme != 'https') {
        throw const _InvalidResponseException();
      }
      uri = redirected;
    }
  }

  Future<PodcastTransferResult> _finalize({
    required File partial,
    required File available,
    required int totalBytes,
    required String? expectedMimeType,
    required String? responseMimeType,
    required String? etag,
  }) async {
    if (!await _looksPlayable(
      partial,
      expectedMimeType ?? responseMimeType,
    )) {
      return PodcastTransferFailure(
        code: PodcastDownloadFailureCode.corruptMedia,
        retryable: false,
        partialPath: partial.path,
        downloadedBytes: totalBytes,
        totalBytes: totalBytes,
        etag: etag,
        discardPartial: true,
      );
    }
    if (await available.exists()) await available.delete();
    final renamed = await partial.rename(available.path);
    return PodcastTransferSuccess(
      availablePath: renamed.path,
      downloadedBytes: totalBytes,
      totalBytes: totalBytes,
      etag: etag,
    );
  }

  Future<PodcastTransferFailure> _interrupted(
    File partial,
    PodcastTransferRequest request,
    String code,
  ) async {
    final length = await _safeLength(partial);
    return PodcastTransferFailure(
      code: code,
      retryable: true,
      partialPath: length == 0 ? null : partial.path,
      downloadedBytes: length,
      totalBytes: request.expectedTotalBytes,
      etag: request.etag,
    );
  }
}

Future<Directory> _defaultDirectory() async {
  final support = await getApplicationSupportDirectory();
  return Directory(
    '${support.path}${Platform.pathSeparator}podcast_downloads',
  );
}

Future<({File partial, File available})> _paths(
  Directory root,
  PodcastTransferRequest request,
) async {
  final digest = sha256.convert(utf8.encode(request.episodeId)).toString();
  final extension = _extension(
    request.expectedMimeType,
    request.sourceUri.path,
  );
  return (
    partial: File(
      '${root.path}${Platform.pathSeparator}$digest$extension.part',
    ),
    available: File(
      '${root.path}${Platform.pathSeparator}$digest$extension',
    ),
  );
}

String _extension(String? mimeType, String path) {
  const byMime = <String, String>{
    'audio/mpeg': '.mp3',
    'audio/mp4': '.m4a',
    'audio/x-m4a': '.m4a',
    'audio/aac': '.aac',
    'audio/ogg': '.ogg',
    'audio/opus': '.opus',
    'audio/wav': '.wav',
    'audio/x-wav': '.wav',
  };
  final normalizedMime = mimeType?.split(';').first.trim().toLowerCase();
  final fromMime = byMime[normalizedMime];
  if (fromMime != null) return fromMime;
  final dot = path.lastIndexOf('.');
  if (dot >= 0) {
    final candidate = path.substring(dot).toLowerCase();
    if (const <String>{
      '.mp3',
      '.m4a',
      '.aac',
      '.ogg',
      '.opus',
      '.wav',
    }.contains(candidate)) {
      return candidate;
    }
  }
  return '.media';
}

bool _isInside(Directory root, File file) {
  var prefix = '${root.absolute.path}${Platform.pathSeparator}';
  var candidate = file.absolute.path;
  if (Platform.isWindows) {
    prefix = prefix.toLowerCase();
    candidate = candidate.toLowerCase();
  }
  return candidate.startsWith(prefix);
}

bool _safeRemote(Uri uri) =>
    (uri.scheme == 'http' || uri.scheme == 'https') &&
    uri.host.isNotEmpty &&
    uri.userInfo.isEmpty;

bool _isRedirect(int status) =>
    status == HttpStatus.movedPermanently ||
    status == HttpStatus.found ||
    status == HttpStatus.seeOther ||
    status == HttpStatus.temporaryRedirect ||
    status == HttpStatus.permanentRedirect;

bool _rangeStartsAt(String? value, int offset) {
  if (value == null) return false;
  final match = RegExp(r'^bytes\s+(\d+)-(\d+)/(\d+|\*)$').firstMatch(value);
  return match != null && int.tryParse(match.group(1)!) == offset;
}

int? _unsatisfiedTotal(String? value) {
  if (value == null) return null;
  final match = RegExp(r'^bytes\s+\*/(\d+)$').firstMatch(value);
  return match == null ? null : int.tryParse(match.group(1)!);
}

int? _totalBytes(HttpClientResponse response, int offset) {
  final contentRange = response.headers.value(HttpHeaders.contentRangeHeader);
  final match = contentRange == null
      ? null
      : RegExp(r'^bytes\s+\d+-\d+/(\d+)$').firstMatch(contentRange);
  final ranged = match == null ? null : int.tryParse(match.group(1)!);
  if (ranged != null) return ranged;
  if (response.contentLength >= 0) return offset + response.contentLength;
  return null;
}

bool _acceptsMimeType(String? response, String? expected) {
  final actual = response?.split(';').first.trim().toLowerCase();
  final requested = expected?.split(';').first.trim().toLowerCase();
  if (actual == null) return true;
  if (actual.startsWith('audio/') || actual == 'application/octet-stream') {
    return true;
  }
  return requested != null && actual == requested;
}

Future<bool> _looksPlayable(File file, String? mimeType) async {
  final length = await _safeLength(file);
  if (length < 4) return false;
  final input = await file.open();
  try {
    final header = await input.read(16);
    final mime = mimeType?.split(';').first.trim().toLowerCase();
    if (mime == 'audio/mpeg') {
      return _startsWith(header, const <int>[0x49, 0x44, 0x33]) ||
          (header[0] == 0xff && (header[1] & 0xe0) == 0xe0);
    }
    if (mime == 'audio/mp4' || mime == 'audio/x-m4a') {
      return header.length >= 8 &&
          _matchesAt(header, 4, const <int>[0x66, 0x74, 0x79, 0x70]);
    }
    if (mime == 'audio/ogg' || mime == 'audio/opus') {
      return _startsWith(header, const <int>[0x4f, 0x67, 0x67, 0x53]);
    }
    if (mime == 'audio/wav' || mime == 'audio/x-wav') {
      return header.length >= 12 &&
          _startsWith(header, const <int>[0x52, 0x49, 0x46, 0x46]) &&
          _matchesAt(header, 8, const <int>[0x57, 0x41, 0x56, 0x45]);
    }
    return true;
  } finally {
    await input.close();
  }
}

bool _startsWith(List<int> bytes, List<int> prefix) =>
    _matchesAt(bytes, 0, prefix);

bool _matchesAt(List<int> bytes, int offset, List<int> expected) {
  if (bytes.length < offset + expected.length) return false;
  for (var index = 0; index < expected.length; index += 1) {
    if (bytes[offset + index] != expected[index]) return false;
  }
  return true;
}

String? _boundedHeader(String? value) {
  final normalized = value?.trim();
  if (normalized == null ||
      normalized.isEmpty ||
      normalized.length > 1024 ||
      normalized.contains('\r') ||
      normalized.contains('\n')) {
    return null;
  }
  return normalized;
}

Future<int> _safeLength(File file) async {
  try {
    return await file.exists() ? await file.length() : 0;
  } on FileSystemException {
    return 0;
  }
}

Future<void> _safeDelete(File file) async {
  try {
    if (await file.exists()) await file.delete();
  } on FileSystemException {
    // Best-effort cleanup is retried by the next explicit operation.
  }
}

PodcastTransferFailure _fileFailure(
  FileSystemException error, {
  String? partialPath,
  int downloadedBytes = 0,
  int? totalBytes,
  String? etag,
}) {
  final message =
      '${error.message} ${error.osError?.message ?? ''}'.toLowerCase();
  final full = error.osError?.errorCode == 28 ||
      error.osError?.errorCode == 112 ||
      message.contains('no space') ||
      message.contains('disk full');
  return PodcastTransferFailure(
    code: full
        ? PodcastDownloadFailureCode.storageFull
        : PodcastDownloadFailureCode.unavailable,
    retryable: false,
    partialPath: partialPath,
    downloadedBytes: downloadedBytes,
    totalBytes: totalBytes,
    etag: etag,
  );
}

final class _InvalidResponseException implements Exception {
  const _InvalidResponseException();
}
