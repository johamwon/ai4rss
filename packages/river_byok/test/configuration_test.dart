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
