import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:river_domain/river_domain.dart';
import 'package:river_platform/river_platform.dart';

void main() {
  test('uses Range and If-Range to resume a verified partial file', () async {
    final directory = await Directory.systemTemp.createTemp(
      'river-podcast-range-',
    );
    final partial = File(
      '${directory.path}${Platform.pathSeparator}episode.mp3.part',
    );
    await partial.writeAsBytes(_audioBytes.take(4).toList());
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() async {
      await server.close(force: true);
      await directory.delete(recursive: true);
    });
    server.listen((request) async {
      expect(request.headers.value(HttpHeaders.rangeHeader), 'bytes=4-');
      expect(request.headers.value(HttpHeaders.ifRangeHeader), '"v1"');
      request.response
        ..statusCode = HttpStatus.partialContent
        ..headers.contentType = ContentType('audio', 'mpeg')
        ..headers.set(HttpHeaders.contentRangeHeader, 'bytes 4-7/8')
        ..headers.set(HttpHeaders.etagHeader, '"v1"')
        ..contentLength = 4
        ..add(_audioBytes.skip(4).toList());
      await request.response.close();
    });
    final progress = <PodcastTransferProgress>[];
    final result = await _backend(directory).transfer(
      PodcastTransferRequest(
        episodeId: 'episode-1',
        sourceUri: _serverUri(server),
        partialPath: partial.path,
        resumeFromBytes: 4,
        expectedTotalBytes: 8,
        etag: '"v1"',
        expectedMimeType: 'audio/mpeg',
      ),
      onProgress: (value) async => progress.add(value),
    );

    expect(result, isA<PodcastTransferSuccess>());
    final success = result as PodcastTransferSuccess;
    expect(await File(success.availablePath).readAsBytes(), _audioBytes);
    expect(success.totalBytes, 8);
    expect(progress.last.downloadedBytes, 8);
  });

  test('a server that ignores Range restarts from zero without duplication',
      () async {
    final directory = await Directory.systemTemp.createTemp(
      'river-podcast-range-reset-',
    );
    final partial = File(
      '${directory.path}${Platform.pathSeparator}episode.mp3.part',
    );
    await partial.writeAsBytes(_audioBytes.take(4).toList());
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() async {
      await server.close(force: true);
      await directory.delete(recursive: true);
    });
    server.listen((request) async {
      expect(request.headers.value(HttpHeaders.rangeHeader), 'bytes=4-');
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType('audio', 'mpeg')
        ..contentLength = _audioBytes.length
        ..add(_audioBytes);
      await request.response.close();
    });

    final result = await _backend(directory).transfer(
      PodcastTransferRequest(
        episodeId: 'episode-1',
        sourceUri: _serverUri(server),
        partialPath: partial.path,
        resumeFromBytes: 4,
        expectedTotalBytes: 8,
        expectedMimeType: 'audio/mpeg',
      ),
      onProgress: (_) async {},
    );

    expect(result, isA<PodcastTransferSuccess>());
    final success = result as PodcastTransferSuccess;
    expect(await File(success.availablePath).readAsBytes(), _audioBytes);
    expect(await File(success.availablePath).length(), 8);
  });

  test('rejects a length-correct body that is not playable audio', () async {
    final directory = await Directory.systemTemp.createTemp(
      'river-podcast-corrupt-',
    );
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() async {
      await server.close(force: true);
      await directory.delete(recursive: true);
    });
    server.listen((request) async {
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType('audio', 'mpeg')
        ..contentLength = 8
        ..add(List<int>.filled(8, 0));
      await request.response.close();
    });

    final result = await _backend(directory).transfer(
      PodcastTransferRequest(
        episodeId: 'episode-1',
        sourceUri: _serverUri(server),
        expectedTotalBytes: 8,
        expectedMimeType: 'audio/mpeg',
      ),
      onProgress: (_) async {},
    );

    expect(result, isA<PodcastTransferFailure>());
    final failure = result as PodcastTransferFailure;
    expect(failure.code, PodcastDownloadFailureCode.corruptMedia);
    expect(failure.retryable, isFalse);
    expect(failure.discardPartial, isTrue);
  });

  test('rejects redirect targets containing credentials', () async {
    final directory = await Directory.systemTemp.createTemp(
      'river-podcast-redirect-',
    );
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() async {
      await server.close(force: true);
      await directory.delete(recursive: true);
    });
    server.listen((request) async {
      request.response
        ..statusCode = HttpStatus.found
        ..headers.set(
          HttpHeaders.locationHeader,
          'http://user:secret@127.0.0.1/private.mp3',
        );
      await request.response.close();
    });

    final result = await _backend(directory).transfer(
      PodcastTransferRequest(
        episodeId: 'episode-1',
        sourceUri: _serverUri(server),
        expectedMimeType: 'audio/mpeg',
      ),
      onProgress: (_) async {},
    );

    expect(result, isA<PodcastTransferFailure>());
    expect(
      (result as PodcastTransferFailure).code,
      PodcastDownloadFailureCode.invalidResponse,
    );
    expect(result.retryable, isFalse);
  });
}

IoPodcastTransferBackend _backend(Directory directory) =>
    IoPodcastTransferBackend(
      directoryProvider: () async => directory,
      requestTimeout: const Duration(seconds: 2),
      progressIntervalBytes: 1,
    );

Uri _serverUri(HttpServer server) =>
    Uri.parse('http://127.0.0.1:${server.port}/episode.mp3');

const _audioBytes = <int>[0x49, 0x44, 0x33, 0x04, 0x00, 0x00, 0x00, 0x00];
