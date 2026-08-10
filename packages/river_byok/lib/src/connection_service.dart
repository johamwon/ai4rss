import 'dart:convert';

import 'package:river_ai/river_ai.dart';

import 'configuration.dart';
import 'http_transport.dart';

enum ByokConnectionFailureCode {
  authenticationRejected,
  quotaExhausted,
  rateLimited,
  unavailable,
  invalidResponse,
}

final class ByokConnectionFailure implements Exception {
  const ByokConnectionFailure(this.code, {required this.retryable});

  final ByokConnectionFailureCode code;
  final bool retryable;

  @override
  String toString() =>
      'ByokConnectionFailure(${code.name}, retryable: $retryable)';
}

final class ByokConnectionResult {
  const ByokConnectionResult({required this.providerResponded, this.modelSeen});

  final bool providerResponded;
  final bool? modelSeen;
}

final class ByokProviderConnectionService {
  const ByokProviderConnectionService({required ByokHttpTransport transport})
      : _transport = transport;

  final ByokHttpTransport _transport;

  Future<ByokConnectionResult> testAi(AiByokConfiguration configuration) =>
      _test(
        modelsUri: _append(configuration.baseUri, 'models'),
        model: configuration.model,
        headers: <String, String>{
          'authorization': 'Bearer ${configuration.apiKey.reveal()}',
        },
      );

  Future<ByokConnectionResult> testMedia(
    ByokMediaConfiguration configuration,
  ) =>
      configuration.providerId == FishAudioTtsPreset.providerId
          ? _test(
              modelsUri: configuration.fishAudioCreditUri,
              model: null,
              headers: configuration.authorizationHeaders(),
            )
          : _test(
              modelsUri: configuration.modelsUri,
              model: configuration.model,
              headers: configuration.authorizationHeaders(),
            );

  Future<ByokConnectionResult> _test({
    required Uri modelsUri,
    required String? model,
    required Map<String, String> headers,
  }) async {
    ByokHttpResponse response;
    try {
      response = await _transport.send(
        ByokHttpRequest(
          method: 'GET',
          uri: modelsUri,
          headers: <String, String>{
            'accept': 'application/json',
            ...headers,
            'user-agent': 'River/0.1',
          },
          timeout: const Duration(seconds: 15),
          maximumResponseBytes: 512 * 1024,
        ),
      );
    } on ByokHttpFailure catch (failure) {
      throw ByokConnectionFailure(
        failure.code == ByokHttpFailureCode.invalidResponse ||
                failure.code == ByokHttpFailureCode.responseTooLarge
            ? ByokConnectionFailureCode.invalidResponse
            : ByokConnectionFailureCode.unavailable,
        retryable: failure.code != ByokHttpFailureCode.invalidResponse,
      );
    }
    switch (response.statusCode) {
      case 200:
        return ByokConnectionResult(
          providerResponded: true,
          modelSeen: model == null ? null : _modelSeen(response.body, model),
        );
      case 401:
      case 403:
        throw const ByokConnectionFailure(
          ByokConnectionFailureCode.authenticationRejected,
          retryable: false,
        );
      case 402:
        throw const ByokConnectionFailure(
          ByokConnectionFailureCode.quotaExhausted,
          retryable: false,
        );
      case 429:
        throw const ByokConnectionFailure(
          ByokConnectionFailureCode.rateLimited,
          retryable: true,
        );
      default:
        throw ByokConnectionFailure(
          response.statusCode >= 500
              ? ByokConnectionFailureCode.unavailable
              : ByokConnectionFailureCode.invalidResponse,
          retryable: response.statusCode >= 500,
        );
    }
  }

  bool? _modelSeen(List<int> bytes, String model) {
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map || decoded['data'] is! List) return null;
      final models = decoded['data'] as List<Object?>;
      return models.any((entry) => entry is Map && entry['id'] == model);
    } on Object {
      return null;
    }
  }
}

Uri _append(Uri baseUri, String suffix) {
  final base = baseUri.toString().replaceFirst(RegExp(r'/+$'), '');
  return Uri.parse('$base/$suffix');
}
