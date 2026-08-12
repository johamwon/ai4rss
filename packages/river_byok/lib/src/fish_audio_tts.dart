import 'dart:convert';
import 'dart:math';

import 'package:river_audio/river_audio.dart';

import 'configuration.dart';
import 'http_transport.dart';
import 'openai_compatible_tts.dart';
import 'tts_audio_validation.dart';

final class FishAudioTtsSynthesizer implements CloudTtsSynthesizer {
  FishAudioTtsSynthesizer({
    required ByokMediaConfiguration configuration,
    required ByokHttpTransport transport,
  })  : _configuration = configuration,
        _transport = transport {
    if (configuration.capability != ByokMediaCapability.tts ||
        configuration.providerId != FishAudioTtsPreset.providerId) {
      throw ArgumentError('Fish Audio requires its TTS provider profile');
    }
    if (configuration.authScheme != ByokAuthScheme.bearer ||
        !FishAudioTtsPreset.supportsModel(configuration.model) ||
        !const <ByokAudioFormat>{
          ByokAudioFormat.mp3,
          ByokAudioFormat.wav,
          ByokAudioFormat.opus,
        }.contains(configuration.audioFormat)) {
      throw ArgumentError('Unsupported Fish Audio TTS configuration');
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
    final referenceId = _configuration.voice;
    final options = _configuration.effectiveFishAudioOptions;
    final synthesisRate = request.settings.rate.clamp(0.5, 2.0).toDouble();
    final body = utf8.encode(
      jsonEncode(<String, Object?>{
        'text': request.text,
        if (referenceId != null) 'reference_id': referenceId,
        'temperature': options.temperature,
        'top_p': options.topP,
        'format': _configuration.audioFormat.name,
        'chunk_length': options.chunkLength,
        'normalize': options.normalize,
        'latency': options.latency.name,
        if (_configuration.audioFormat == ByokAudioFormat.mp3)
          'mp3_bitrate': options.mp3BitrateKbps,
        if (_configuration.audioFormat == ByokAudioFormat.opus)
          'opus_bitrate': options.opusBitrateBps,
        if (options.qualityGuard) 'features': <String>['quality-guard'],
        'prosody': <String, Object?>{
          'speed': synthesisRate,
          'volume': options.volumeDb,
          'normalize_loudness': options.normalizeLoudness,
        },
      }),
    );

    late ByokHttpResponse response;
    try {
      response = await _raceCancellation(
        _transport.send(
          ByokHttpRequest(
            method: 'POST',
            uri: _configuration.fishAudioSpeechUri,
            headers: <String, String>{
              'accept': expectedTtsMediaType(_configuration.audioFormat),
              ..._configuration.authorizationHeaders(),
              'content-type': 'application/json',
              'model': _configuration.model,
              'user-agent': 'River/0.1',
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
    final reportedMediaType = response.headers['content-type']
            ?.split(';')
            .first
            .trim()
            .toLowerCase() ??
        expectedTtsMediaType(_configuration.audioFormat);
    final mediaType = reportedMediaType == 'application/octet-stream'
        ? expectedTtsMediaType(_configuration.audioFormat)
        : reportedMediaType;
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

    final duration = _estimatedDuration(request);
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

  Duration _estimatedDuration(CloudTtsSynthesisRequest request) {
    final rate = request.settings.rate.clamp(0.5, 2.0);
    final seconds = request.text.runes.length / (5 * rate);
    return Duration(milliseconds: max(1000, (seconds * 1000).ceil()));
  }

  CloudTtsFailure _failure(int statusCode) => switch (statusCode) {
        401 || 403 || 402 => const CloudTtsFailure(
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

CloudTtsSynthesizer createByokTtsSynthesizer({
  required ByokMediaConfiguration configuration,
  required ByokHttpTransport transport,
}) =>
    configuration.providerId == FishAudioTtsPreset.providerId
        ? FishAudioTtsSynthesizer(
            configuration: configuration,
            transport: transport,
          )
        : OpenAiCompatibleTtsSynthesizer(
            configuration: configuration,
            transport: transport,
          );
