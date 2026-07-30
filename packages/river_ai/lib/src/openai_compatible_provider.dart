import 'dart:convert';

import 'ai_http.dart';
import 'byok_configuration.dart';
import 'provider.dart';

abstract interface class AiMonotonicClock {
  Duration elapsed();
}

final class StopwatchAiMonotonicClock implements AiMonotonicClock {
  StopwatchAiMonotonicClock() : _stopwatch = Stopwatch()..start();

  final Stopwatch _stopwatch;

  @override
  Duration elapsed() => _stopwatch.elapsed;
}

final class OpenAiCompatibleProvider implements AiProvider {
  OpenAiCompatibleProvider({
    required AiByokConfiguration configuration,
    required AiHttpTransport transport,
    required AiMonotonicClock clock,
  })  : _configuration = configuration,
        _transport = transport,
        _clock = clock;

  final AiByokConfiguration _configuration;
  final AiHttpTransport _transport;
  final AiMonotonicClock _clock;

  @override
  String get id => 'openai-compatible:${_configuration.presetId}';

  @override
  Future<AiProviderResponse> complete(AiProviderRequest request) async {
    if (request.model != _configuration.model) {
      throw AiProviderFailure(
        code: AiProviderFailureCode.invalidRequest,
        retryable: false,
      );
    }
    final started = _clock.elapsed();
    try {
      final response = await _transport.send(
        AiHttpRequest(
          uri: _configuration.chatCompletionsUri,
          headers: <String, String>{
            'accept': 'application/json',
            'authorization': 'Bearer ${_configuration.apiKey.reveal()}',
            'content-type': 'application/json',
            'user-agent': 'River/0.1',
          },
          body: jsonEncode(_requestBody(request)),
          timeout: request.timeout,
        ),
      );
      if (response.statusCode != 200) {
        throw _httpFailure(response);
      }
      return _parseResponse(
        response,
        request,
        elapsed: _clock.elapsed() - started,
      );
    } on AiProviderFailure {
      rethrow;
    } on ArgumentError {
      throw AiProviderFailure(
        code: AiProviderFailureCode.invalidRequest,
        retryable: false,
      );
    } on AiHttpTransportFailure catch (failure) {
      throw switch (failure.code) {
        AiHttpTransportFailureCode.timeout => AiProviderFailure(
            code: AiProviderFailureCode.timeout,
            retryable: true,
          ),
        AiHttpTransportFailureCode.offline => AiProviderFailure(
            code: AiProviderFailureCode.unavailable,
            retryable: true,
          ),
        AiHttpTransportFailureCode.responseTooLarge ||
        AiHttpTransportFailureCode.invalidResponse =>
          AiProviderFailure(
            code: AiProviderFailureCode.invalidRequest,
            retryable: false,
          ),
      };
    } on Object {
      throw AiProviderFailure(
        code: AiProviderFailureCode.unavailable,
        retryable: true,
      );
    }
  }

  Map<String, Object?> _requestBody(AiProviderRequest request) {
    final value = <String, Object?>{
      'model': request.model,
      'messages': <Map<String, String>>[
        <String, String>{'role': 'system', 'content': request.prompt.system},
        <String, String>{'role': 'user', 'content': request.prompt.user},
      ],
      'stream': false,
      switch (_configuration.tokenLimitParameter) {
        AiTokenLimitParameter.maxCompletionTokens => 'max_completion_tokens',
        AiTokenLimitParameter.maxTokens => 'max_tokens',
      }: request.maxOutputTokens,
    };
    switch (_configuration.structuredOutputMode) {
      case AiStructuredOutputMode.jsonSchema:
        value['response_format'] = <String, Object?>{
          'type': 'json_schema',
          'json_schema': <String, Object?>{
            'name': _schemaIdentifier(request.prompt.responseSchemaName),
            'schema': request.responseSchema,
            'strict': true,
          },
        };
      case AiStructuredOutputMode.jsonObject:
        value['response_format'] = <String, Object?>{'type': 'json_object'};
      case AiStructuredOutputMode.promptOnly:
        break;
    }
    return value;
  }

  AiProviderResponse _parseResponse(
    AiHttpResponse response,
    AiProviderRequest request, {
    required Duration elapsed,
  }) {
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) throw const FormatException();
    final value = Map<String, Object?>.from(decoded);
    final choices = value['choices'];
    if (choices is! List<Object?> || choices.length != 1) {
      throw const FormatException();
    }
    final choice = choices.single;
    if (choice is! Map) throw const FormatException();
    final choiceValue = Map<String, Object?>.from(choice);
    final finishReason = choiceValue['finish_reason'];
    if (finishReason == 'length' || finishReason == 'content_filter') {
      throw AiProviderFailure(
        code: AiProviderFailureCode.invalidRequest,
        retryable: false,
      );
    }
    final message = choiceValue['message'];
    if (message is! Map) throw const FormatException();
    final output = message['content'];
    if (output is! String || output.isEmpty) {
      throw const FormatException();
    }
    final usage = value['usage'];
    if (usage is! Map) throw const FormatException();
    final inputTokens = usage['prompt_tokens'];
    final outputTokens = usage['completion_tokens'];
    if (inputTokens is! int ||
        inputTokens < 0 ||
        outputTokens is! int ||
        outputTokens < 0) {
      throw const FormatException();
    }
    final resolvedModel = value['model'];
    final requestId = value['id'] ?? response.headers['x-request-id'];
    return AiProviderResponse(
      output: output,
      model: resolvedModel is String && resolvedModel.isNotEmpty
          ? resolvedModel
          : request.model,
      usage: AiTokenUsage(
        inputTokens: inputTokens,
        outputTokens: outputTokens,
      ),
      elapsed: elapsed,
      providerRequestId:
          requestId is String && requestId.isNotEmpty ? requestId : null,
    );
  }

  AiProviderFailure _httpFailure(AiHttpResponse response) {
    final retryAfter = _retryAfter(response.headers['retry-after']);
    return switch (response.statusCode) {
      401 || 403 => AiProviderFailure(
          code: AiProviderFailureCode.authenticationRequired,
          retryable: false,
        ),
      402 => AiProviderFailure(
          code: AiProviderFailureCode.quotaExceeded,
          retryable: false,
        ),
      408 => AiProviderFailure(
          code: AiProviderFailureCode.timeout,
          retryable: true,
        ),
      429 => AiProviderFailure(
          code: AiProviderFailureCode.rateLimited,
          retryable: true,
          retryAfter: retryAfter,
        ),
      >= 500 && <= 599 => AiProviderFailure(
          code: AiProviderFailureCode.unavailable,
          retryable: true,
          retryAfter: retryAfter,
        ),
      _ => AiProviderFailure(
          code: AiProviderFailureCode.invalidRequest,
          retryable: false,
        ),
    };
  }
}

String _schemaIdentifier(String value) {
  final normalized = value.replaceAll(RegExp('[^A-Za-z0-9_-]'), '_');
  return normalized.length <= 64 ? normalized : normalized.substring(0, 64);
}

Duration? _retryAfter(String? value) {
  final seconds = int.tryParse(value ?? '');
  if (seconds == null || seconds < 0) return null;
  return Duration(seconds: seconds > 3600 ? 3600 : seconds);
}
