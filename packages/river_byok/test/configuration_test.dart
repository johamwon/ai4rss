import 'dart:convert';

import 'package:river_ai/river_ai.dart';
import 'package:river_byok/river_byok.dart';
import 'package:test/test.dart';

void main() {
  test('AI, TTS and transcription connection checks redact credentials',
      () async {
    final transport = _Transport(
      ByokHttpResponse(
        statusCode: 200,
        body: utf8.encode('{"data":[{"id":"river-model"}]}'),
      ),
    );
    final service = ByokProviderConnectionService(transport: transport);
    final ai = AiByokConfiguration(
      presetId: 'custom-provider',
      displayName: 'Custom',
      baseUri: Uri.parse('https://provider.example/v1'),
      model: 'river-model',
      apiKey: OpaqueAiApiKey('never-print-ai-key'),
      structuredOutputMode: AiStructuredOutputMode.jsonSchema,
      tokenLimitParameter: AiTokenLimitParameter.maxCompletionTokens,
    );
    final tts = _media(ByokMediaCapability.tts, key: 'never-print-tts-key');

    expect((await service.testAi(ai)).modelSeen, isTrue);
    expect((await service.testMedia(tts)).modelSeen, isTrue);
    expect(transport.requests, hasLength(2));
    expect(transport.requests.first.uri.path, '/v1/models');
    expect(
      transport.requests.first.headers['authorization'],
      'Bearer never-print-ai-key',
    );
    expect(ai.toString(), isNot(contains('never-print-ai-key')));
    expect(tts.toString(), isNot(contains('never-print-tts-key')));
    expect(transport.requests.first.toString(), isNot(contains('never-print')));
  });

  test('configuration rejects unsafe endpoints and credential injection', () {
    expect(
      () => _media(
        ByokMediaCapability.tts,
        baseUri: Uri.parse('http://provider.example/v1'),
      ),
      throwsArgumentError,
    );
    expect(
      () => _media(
        ByokMediaCapability.tts,
        baseUri: Uri.parse('https://provider.example/v1?key=secret'),
      ),
      throwsArgumentError,
    );
    expect(
      () => OpaqueByokApiKey('secret\r\ninjection'),
      throwsArgumentError,
    );
  });

  test('authentication failures expose only a stable failure code', () async {
    final service = ByokProviderConnectionService(
      transport: _Transport(ByokHttpResponse(statusCode: 401, body: const [])),
    );
    await expectLater(
      service.testMedia(_media(ByokMediaCapability.tts)),
      throwsA(
        isA<ByokConnectionFailure>().having(
          (failure) => failure.code,
          'code',
          ByokConnectionFailureCode.authenticationRejected,
        ),
      ),
    );
  });

  test('Fish Audio connection check validates the key without generating audio',
      () async {
    final transport = _Transport(
      ByokHttpResponse(statusCode: 200, body: utf8.encode('{"credit":"1"}')),
    );
    final service = ByokProviderConnectionService(transport: transport);
    final result = await service.testMedia(
      ByokMediaConfiguration(
        capability: ByokMediaCapability.tts,
        providerId: FishAudioTtsPreset.providerId,
        displayName: FishAudioTtsPreset.displayName,
        baseUri: Uri.parse(FishAudioTtsPreset.baseUrl),
        model: FishAudioTtsPreset.defaultModel,
        apiKey: OpaqueByokApiKey('fish-provider-secret'),
      ),
    );

    expect(result.providerResponded, isTrue);
    expect(result.modelSeen, isNull);
    expect(
      transport.requests.single.uri.toString(),
      'https://api.fish.audio/wallet/self/api-credit',
    );
    expect(transport.requests.single.method, 'GET');
  });

  test('Fish Audio profile rejects alternate endpoints and unknown models', () {
    ByokMediaConfiguration build({required Uri uri, required String model}) =>
        ByokMediaConfiguration(
          capability: ByokMediaCapability.tts,
          providerId: FishAudioTtsPreset.providerId,
          displayName: FishAudioTtsPreset.displayName,
          baseUri: uri,
          model: model,
          apiKey: OpaqueByokApiKey('fish-provider-secret'),
        );

    expect(
      () => build(
        uri: Uri.parse('https://proxy.example'),
        model: FishAudioTtsPreset.defaultModel,
      ),
      throwsArgumentError,
    );
    expect(
      () => build(
        uri: Uri.parse(FishAudioTtsPreset.baseUrl),
        model: 'unknown-model',
      ),
      throwsArgumentError,
    );
  });

  test('Fish Audio connection maps exhausted credit to a stable failure',
      () async {
    final service = ByokProviderConnectionService(
      transport: _Transport(
        ByokHttpResponse(
          statusCode: 402,
          body: utf8.encode('{"message":"private provider response"}'),
        ),
      ),
    );
    final configuration = ByokMediaConfiguration(
      capability: ByokMediaCapability.tts,
      providerId: FishAudioTtsPreset.providerId,
      displayName: FishAudioTtsPreset.displayName,
      baseUri: Uri.parse(FishAudioTtsPreset.baseUrl),
      model: FishAudioTtsPreset.defaultModel,
      apiKey: OpaqueByokApiKey('fish-provider-secret'),
    );

    await expectLater(
      service.testMedia(configuration),
      throwsA(
        isA<ByokConnectionFailure>()
            .having(
              (failure) => failure.code,
              'code',
              ByokConnectionFailureCode.quotaExhausted,
            )
            .having(
              (failure) => failure.toString(),
              'diagnostic',
              isNot(contains('private provider response')),
            ),
      ),
    );
  });
}

ByokMediaConfiguration _media(
  ByokMediaCapability capability, {
  Uri? baseUri,
  String key = 'provider-secret-key',
}) =>
    ByokMediaConfiguration(
      capability: capability,
      providerId: 'custom-provider',
      displayName: 'Custom',
      baseUri: baseUri ?? Uri.parse('https://provider.example/v1'),
      model: 'river-model',
      apiKey: OpaqueByokApiKey(key),
      voice: capability == ByokMediaCapability.tts ? 'alloy' : null,
    );

final class _Transport implements ByokHttpTransport {
  _Transport(this.response);

  final ByokHttpResponse response;
  final List<ByokHttpRequest> requests = <ByokHttpRequest>[];

  @override
  Future<ByokHttpResponse> send(ByokHttpRequest request) async {
    requests.add(request);
    return response;
  }
}
