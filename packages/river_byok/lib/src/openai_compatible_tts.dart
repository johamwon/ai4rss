import 'dart:convert';
import 'dart:math';

import 'package:river_audio/river_audio.dart';

import 'configuration.dart';
import 'http_transport.dart';
import 'tts_audio_validation.dart';

final class OpenAiCompatibleTtsSynthesizer implements CloudTtsSynthesizer {
  OpenAiCompatibleTtsSynthesizer({
    required ByokMediaConfiguration configuration,
    required ByokHttpTransport transport,
  })  : _configuration = configuration,
        _transport = transport {
    if (configuration.capability != ByokMediaCapability.tts) {
      throw ArgumentError('TTS synthesizer requires a TTS configuration');
    }
    if (configuration.voice == null) {
      throw ArgumentError('OpenAI-compatible TTS requires a voice');
    }
  }

  final ByokMediaConfiguration _configuration;
  final ByokHttpTransport _transport;

  @override
  Future<CloudTtsSynthesisResponse> synthesize(
    CloudTtsSynthesisRequest request,
    AudioPrefetchCancellation cancellation,
  ) async {
    cancellation.throwIfCancelled();
    final body = utf8.encode(
      jsonEncode(<String, Object?>{
        'model': _configuration.model,
        'input': request.text,
        'voice': _configuration.voice,
        'response_format': _configuration.audioFormat.name,
        'speed': request.settings.rate,
      }),
    );
    late ByokHttpResponse response;
    try {
      response = await _raceCancellation(
        _transport.send(
          ByokHttpRequest(
            method: 'POST',
            uri: _configuration.speechUri,
            headers: <String, String>{
              'accept': expectedTtsMediaType(_configuration.audioFormat),
              ..._configuration.authorizationHeaders(),
              'content-type': 'application/json',
              'user-agent': 'River/0.1',
              'idempotency-key': request.operationId,
            },
            body: body,
            timeout: const Duration(seconds: 45),
            maximumResponseBytes: 8 * 1024 * 1024,
          ),
        ),
        cancellation,
      );
    } on AudioPrefetchCancelledException {
      rethrow;
    } on ByokHttpFailure catch (failure) {
      throw switch (failure.code) {
        ByokHttpFailureCode.timeout => const CloudTtsFailure(
            code: CloudTtsFailureCode.providerTimeout,
            retryable: true,
          ),
        ByokHttpFailureCode.responseTooLarge ||
        ByokHttpFailureCode.invalidResponse =>
          const CloudTtsFailure(
            code: CloudTtsFailureCode.invalidResponse,
            retryable: false,
          ),
        ByokHttpFailureCode.offline => const CloudTtsFailure(
            code: CloudTtsFailureCode.providerFailure,
            retryable: true,
          ),
      };
    }
    cancellation.throwIfCancelled();
    if (response.statusCode != 200) throw _failure(response.statusCode);
    final mediaType = response.headers['content-type']
            ?.split(';')
            .first
            .trim()
            .toLowerCase() ??
        expectedTtsMediaType(_configuration.audioFormat);
    if (!hasValidTtsAudioSignature(
          response.body,
          _configuration.audioFormat,
        ) ||
        !acceptedTtsMediaType(mediaType, _configuration.audioFormat)) {
      throw const CloudTtsFailure(
        code: CloudTtsFailureCode.invalidResponse,
        retryable: false,
      );
    }
    final duration = _duration(response, request);
    return CloudTtsSynthesisResponse(
      audioBytes: response.body,
      mediaType: mediaType,
      audioDuration: duration,
      billableDuration: duration,
      costMicros: 0,
    );
  }

  Future<T> _raceCancellation<T>(
    Future<T> operation,
    AudioPrefetchCancellation cancellation,
  ) =>
      Future.any<T>(<Future<T>>[
        operation,
        cancellation.whenCancelled.then<T>(
          (_) => throw const AudioPrefetchCancelledException(),
        ),
      ]);

  Duration _duration(
    ByokHttpResponse response,
    CloudTtsSynthesisRequest request,
  ) {
    final declared = int.tryParse(
      response.headers['x-river-audio-duration-ms'] ?? '',
    );
    if (declared != null && declared > 0 && declared <= 60 * 60 * 1000) {
      return Duration(milliseconds: declared);
    }
    final seconds = request.text.runes.length / (5 * request.settings.rate);
    return Duration(milliseconds: max(1000, (seconds * 1000).ceil()));
  }

  CloudTtsFailure _failure(int statusCode) => switch (statusCode) {
        401 || 403 => const CloudTtsFailure(
            code: CloudTtsFailureCode.providerFailure,
            retryable: false,
          ),
        408 => const CloudTtsFailure(
            code: CloudTtsFailureCode.providerTimeout,
            retryable: true,
          ),
        429 || >= 500 => const CloudTtsFailure(
            code: CloudTtsFailureCode.providerFailure,
            retryable: true,
          ),
        _ => const CloudTtsFailure(
            code: CloudTtsFailureCode.invalidRequest,
            retryable: false,
          ),
      };
}
