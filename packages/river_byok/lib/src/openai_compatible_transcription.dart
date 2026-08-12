import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:river_ai/river_ai.dart';

import 'configuration.dart';
import 'http_transport.dart';

final class PodcastMediaBytes {
  PodcastMediaBytes({
    required List<int> bytes,
    required this.fileName,
    required this.mediaType,
  }) : bytes = List<int>.unmodifiable(bytes) {
    if (bytes.isEmpty || bytes.length > 100 * 1024 * 1024) {
      throw ArgumentError.value(bytes.length, 'bytes.length');
    }
    if (!RegExp(r'^[A-Za-z0-9._-]{1,128}$').hasMatch(fileName)) {
      throw ArgumentError.value(fileName, 'fileName');
    }
    if (!RegExp(r'^[a-z0-9.+-]+/[a-z0-9.+-]+$').hasMatch(mediaType)) {
      throw ArgumentError.value(mediaType, 'mediaType');
    }
  }

  final List<int> bytes;
  final String fileName;
  final String mediaType;
}

abstract interface class PodcastMediaAssetReader {
  Future<PodcastMediaBytes> read(String assetId);
}

final class OpenAiCompatiblePodcastTranscriptionProvider
    implements PodcastTranscriptionProvider {
  OpenAiCompatiblePodcastTranscriptionProvider({
    required ByokMediaConfiguration configuration,
    required ByokHttpTransport transport,
    required PodcastMediaAssetReader assets,
  })  : _configuration = configuration,
        _transport = transport,
        _assets = assets {
    if (configuration.capability != ByokMediaCapability.podcastTranscription) {
      throw ArgumentError(
        'Podcast transcriber requires a transcription configuration',
      );
    }
  }

  final ByokMediaConfiguration _configuration;
  final ByokHttpTransport _transport;
  final PodcastMediaAssetReader _assets;

  @override
  Future<PodcastTranscriptionProviderResult> transcribe(
    PodcastMediaAsset asset, {
    required String? outputLanguage,
    required String operationId,
    required PodcastTaskCancellation cancellation,
  }) async {
    cancellation.throwIfCancelled();
    final media = await _assets.read(asset.assetId);
    cancellation.throwIfCancelled();
    if (media.bytes.length != asset.bytes ||
        media.mediaType != asset.mediaType ||
        sha256.convert(media.bytes).toString() != asset.contentDigest) {
      throw const PodcastTranscriptionFailure(
        code: PodcastTranscriptionFailureCode.invalidMedia,
        retryable: false,
      );
    }
    final multipart = _multipart(
      operationId: operationId,
      media: media,
      language: outputLanguage,
    );
    late ByokHttpResponse response;
    try {
      response = await Future.any<ByokHttpResponse>(
        <Future<ByokHttpResponse>>[
          _transport.send(
            ByokHttpRequest(
              method: 'POST',
              uri: _configuration.transcriptionsUri,
              headers: <String, String>{
                'accept': 'application/json',
                ..._configuration.authorizationHeaders(),
                'content-type':
                    'multipart/form-data; boundary=${multipart.boundary}',
                'user-agent': 'River/0.1',
                'idempotency-key': operationId,
              },
              body: multipart.bytes,
              timeout: const Duration(minutes: 15),
              maximumResponseBytes: 8 * 1024 * 1024,
            ),
          ),
          cancellation.whenCancelled.then<ByokHttpResponse>(
            (_) => throw const PodcastTaskCancelledException(),
          ),
        ],
      );
    } on PodcastTaskCancelledException {
      rethrow;
    } on ByokHttpFailure catch (failure) {
      throw PodcastTranscriptionFailure(
        code: failure.code == ByokHttpFailureCode.timeout
            ? PodcastTranscriptionFailureCode.transcriptionTimeout
            : PodcastTranscriptionFailureCode.transcriptionFailure,
        retryable: failure.code != ByokHttpFailureCode.invalidResponse &&
            failure.code != ByokHttpFailureCode.responseTooLarge,
      );
    }
    cancellation.throwIfCancelled();
    if (response.statusCode != 200) throw _failure(response.statusCode);
    return PodcastTranscriptionProviderResult(
      transcript: _parse(response.body, outputLanguage),
      billableDuration: asset.duration,
      costMicros: 0,
    );
  }

  _MultipartBody _multipart({
    required String operationId,
    required PodcastMediaBytes media,
    required String? language,
  }) {
    final boundary =
        'river-${sha256.convert(utf8.encode(operationId))}'.substring(0, 38);
    final builder = BytesBuilder(copy: false);
    void field(String name, String value) {
      builder.add(utf8.encode('--$boundary\r\n'));
      builder.add(
        utf8.encode(
          'Content-Disposition: form-data; name="$name"\r\n\r\n$value\r\n',
        ),
      );
    }

    field('model', _configuration.model);
    field('response_format', 'verbose_json');
    field('timestamp_granularities[]', 'segment');
    if (language != null && language.isNotEmpty) field('language', language);
    builder.add(utf8.encode('--$boundary\r\n'));
    builder.add(
      utf8.encode(
        'Content-Disposition: form-data; name="file"; '
        'filename="${media.fileName}"\r\n'
        'Content-Type: ${media.mediaType}\r\n\r\n',
      ),
    );
    builder.add(media.bytes);
    builder.add(utf8.encode('\r\n--$boundary--\r\n'));
    return _MultipartBody(boundary: boundary, bytes: builder.takeBytes());
  }

  PodcastTranscript _parse(List<int> bytes, String? requestedLanguage) {
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map || decoded['segments'] is! List) {
        throw const FormatException();
      }
      final values = decoded['segments'] as List<Object?>;
      if (values.isEmpty || values.length > 20000) {
        throw const FormatException();
      }
      final segments = <PodcastTranscriptSegment>[];
      var characters = 0;
      for (var index = 0; index < values.length; index += 1) {
        final raw = values[index];
        if (raw is! Map) throw const FormatException();
        final start = raw['start'];
        final end = raw['end'];
        final text = raw['text'];
        if (start is! num ||
            end is! num ||
            !start.isFinite ||
            !end.isFinite ||
            start < 0 ||
            end <= start ||
            text is! String ||
            text.trim().isEmpty) {
          throw const FormatException();
        }
        characters += text.length;
        if (characters > 2000000) throw const FormatException();
        segments.add(
          PodcastTranscriptSegment(
            index: index,
            start: Duration(milliseconds: (start * 1000).round()),
            end: Duration(milliseconds: (end * 1000).round()),
            text: text.trim(),
          ),
        );
      }
      final language = decoded['language'];
      return PodcastTranscript(
        language: language is String && language.trim().isNotEmpty
            ? language.trim()
            : requestedLanguage ?? 'und',
        segments: segments,
        providerVersion: _configuration.model,
      );
    } on PodcastTranscriptionFailure {
      rethrow;
    } on Object {
      throw const PodcastTranscriptionFailure(
        code: PodcastTranscriptionFailureCode.invalidTranscript,
        retryable: false,
      );
    }
  }

  PodcastTranscriptionFailure _failure(int statusCode) =>
      PodcastTranscriptionFailure(
        code: statusCode == 408
            ? PodcastTranscriptionFailureCode.transcriptionTimeout
            : PodcastTranscriptionFailureCode.transcriptionFailure,
        retryable: statusCode == 408 || statusCode == 429 || statusCode >= 500,
      );
}

final class _MultipartBody {
  const _MultipartBody({required this.boundary, required this.bytes});

  final String boundary;
  final List<int> bytes;
}
