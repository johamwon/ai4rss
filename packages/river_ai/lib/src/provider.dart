import 'prompt_registry.dart';

abstract interface class AiProvider {
  String get id;

  Future<AiProviderResponse> complete(AiProviderRequest request);
}

final class AiProviderRequest {
  AiProviderRequest({
    required this.operationId,
    required this.model,
    required this.prompt,
    required Map<String, Object?> responseSchema,
    this.maxOutputTokens = 1600,
    this.timeout = const Duration(seconds: 45),
  }) : responseSchema = Map<String, Object?>.unmodifiable(responseSchema) {
    if (operationId.trim().isEmpty || operationId.length > 256) {
      throw ArgumentError.value(operationId, 'operationId');
    }
    if (model.trim().isEmpty || model.length > 200) {
      throw ArgumentError.value(model, 'model');
    }
    if (prompt.responseSchemaName.trim().isEmpty) {
      throw ArgumentError.value(
        prompt.responseSchemaName,
        'prompt.responseSchemaName',
      );
    }
    if (prompt.system.trim().isEmpty ||
        prompt.system.length > 32000 ||
        prompt.user.trim().isEmpty ||
        prompt.user.length > 160000) {
      throw ArgumentError('Rendered prompt is empty or exceeds its bound');
    }
    if (responseSchema.isEmpty) {
      throw ArgumentError.value(responseSchema, 'responseSchema');
    }
    if (responseSchema['title'] != prompt.responseSchemaName) {
      throw ArgumentError(
        'Response schema title must match prompt.responseSchemaName',
      );
    }
    if (maxOutputTokens < 1 || maxOutputTokens > 32768) {
      throw RangeError.range(maxOutputTokens, 1, 32768, 'maxOutputTokens');
    }
    if (timeout < const Duration(seconds: 1) ||
        timeout > const Duration(minutes: 2)) {
      throw RangeError.range(
        timeout.inMilliseconds,
        const Duration(seconds: 1).inMilliseconds,
        const Duration(minutes: 2).inMilliseconds,
        'timeout',
      );
    }
  }

  final String operationId;
  final String model;
  final AiPrompt prompt;
  final Map<String, Object?> responseSchema;
  final int maxOutputTokens;
  final Duration timeout;

  @override
  String toString() => 'AiProviderRequest('
      'operationId: $operationId, '
      'model: $model, '
      'prompt: ${prompt.versionKey}, '
      'schema: ${prompt.responseSchemaName}, '
      'maxOutputTokens: $maxOutputTokens, '
      'timeout: ${timeout.inSeconds}s'
      ')';
}

final class AiProviderResponse {
  AiProviderResponse({
    required this.output,
    required this.model,
    required this.usage,
    required this.elapsed,
    this.providerRequestId,
  }) {
    if (output.isEmpty || output.length > 120000) {
      throw ArgumentError.value(output.length, 'output.length');
    }
    if (model.trim().isEmpty || model.length > 200) {
      throw ArgumentError.value(model, 'model');
    }
    if (providerRequestId != null &&
        (providerRequestId!.trim().isEmpty ||
            providerRequestId!.length > 256)) {
      throw ArgumentError.value(providerRequestId, 'providerRequestId');
    }
    if (elapsed.isNegative || elapsed > const Duration(minutes: 2)) {
      throw ArgumentError.value(elapsed, 'elapsed');
    }
  }

  final String output;
  final String model;
  final AiTokenUsage usage;
  final Duration elapsed;
  final String? providerRequestId;

  @override
  String toString() => 'AiProviderResponse('
      'model: $model, '
      'usage: $usage, '
      'elapsed: ${elapsed.inMilliseconds}ms, '
      'hasProviderRequestId: ${providerRequestId != null}'
      ')';
}

final class AiTokenUsage {
  AiTokenUsage({
    required this.inputTokens,
    required this.outputTokens,
  }) {
    if (inputTokens < 0) {
      throw RangeError.value(inputTokens, 'inputTokens');
    }
    if (outputTokens < 0) {
      throw RangeError.value(outputTokens, 'outputTokens');
    }
  }

  final int inputTokens;
  final int outputTokens;

  int get totalTokens => inputTokens + outputTokens;

  @override
  String toString() => 'AiTokenUsage('
      'inputTokens: $inputTokens, '
      'outputTokens: $outputTokens'
      ')';
}

enum AiProviderFailureCode {
  authenticationRequired,
  quotaExceeded,
  rateLimited,
  timeout,
  unavailable,
  invalidRequest,
  cancelled,
}

final class AiProviderFailure implements Exception {
  AiProviderFailure({
    required this.code,
    required this.retryable,
    this.retryAfter,
  }) {
    if (!retryable && retryAfter != null) {
      throw ArgumentError(
        'A non-retryable failure cannot declare retryAfter',
      );
    }
    if (retryAfter != null &&
        (retryAfter!.isNegative || retryAfter! > const Duration(hours: 1))) {
      throw ArgumentError.value(retryAfter, 'retryAfter');
    }
  }

  final AiProviderFailureCode code;
  final bool retryable;
  final Duration? retryAfter;

  @override
  String toString() => 'AiProviderFailure('
      'code: ${code.name}, '
      'retryable: $retryable, '
      'retryAfterSeconds: ${retryAfter?.inSeconds}'
      ')';
}
