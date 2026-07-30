import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:river_ai/river_ai.dart';
import 'package:test/test.dart';

void main() {
  test('package HTTP adapter sends one bounded POST without redirects',
      () async {
    late http.Request captured;
    final transport = PackageHttpAiTransport(
      client: MockClient((request) async {
        captured = request;
        return http.Response(
          '{"ok":true}',
          307,
          headers: const <String, String>{'X-Request-Id': 'request-1'},
        );
      }),
    );
    final request = AiHttpRequest(
      uri: Uri.parse('https://models.example/v1/chat/completions'),
      headers: const <String, String>{
        'authorization': 'Bearer private-key',
        'content-type': 'application/json',
      },
      body: '{"model":"test"}',
      timeout: const Duration(seconds: 5),
    );

    final response = await transport.send(request);

    expect(captured.method, 'POST');
    expect(captured.followRedirects, isFalse);
    expect(captured.maxRedirects, 0);
    expect(captured.headers['authorization'], 'Bearer private-key');
    expect(captured.body, '{"model":"test"}');
    expect(response.statusCode, 307);
    expect(response.headers['x-request-id'], 'request-1');
    expect(response.toString(), isNot(contains('{"ok":true}')));
    transport.close();
  });

  test('package HTTP adapter rejects oversized and malformed responses',
      () async {
    final oversized = PackageHttpAiTransport(
      client: MockClient(
        (_) async => http.Response(List<String>.filled(1025, 'x').join(), 200),
      ),
      maxResponseBytes: 1024,
    );
    await expectLater(
      oversized.send(_request()),
      throwsA(
        isA<AiHttpTransportFailure>().having(
          (failure) => failure.code,
          'code',
          AiHttpTransportFailureCode.responseTooLarge,
        ),
      ),
    );
    oversized.close();

    final malformed = PackageHttpAiTransport(
      client: MockClient(
        (_) async => http.Response.bytes(<int>[0xc3, 0x28], 200),
      ),
    );
    await expectLater(
      malformed.send(_request()),
      throwsA(
        isA<AiHttpTransportFailure>().having(
          (failure) => failure.code,
          'code',
          AiHttpTransportFailureCode.invalidResponse,
        ),
      ),
    );
    malformed.close();
  });

  test('HTTP request bounds reject insecure endpoints and private bodies', () {
    expect(
      () => AiHttpRequest(
        uri: Uri.parse('http://models.example/chat/completions'),
        headers: const <String, String>{},
        body: '{}',
        timeout: const Duration(seconds: 5),
      ),
      throwsArgumentError,
    );
    expect(
      () => AiHttpRequest(
        uri: Uri.parse('https://models.example/chat/completions'),
        headers: const <String, String>{},
        body: utf8.decode(List<int>.filled(256 * 1024 + 1, 65)),
        timeout: const Duration(seconds: 5),
      ),
      throwsArgumentError,
    );
  });
}

AiHttpRequest _request() => AiHttpRequest(
      uri: Uri.parse('https://models.example/v1/chat/completions'),
      headers: const <String, String>{'content-type': 'application/json'},
      body: '{}',
      timeout: const Duration(seconds: 5),
    );
