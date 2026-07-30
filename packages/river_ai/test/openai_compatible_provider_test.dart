import 'dart:convert';

import 'package:river_ai/river_ai.dart';
import 'package:test/test.dart';

void main() {
  group('OpenAiCompatibleProvider', () {
    test('sends strict schema without leaking key or content diagnostics',
        () async {
      final transport = _Transport(
        response: _successResponse(),
        onSend: (request) {},
      );
      final clock = _Clock()..advance(const Duration(milliseconds: 10));
      final provider = _provider(
        transport: transport,
        clock: clock,
        presetId: 'openai',
      );

      final future = provider.complete(_request());
      clock.advance(const Duration(milliseconds: 125));
      final response = await future;
      final sent = transport.requests.single;
      final body = _object(jsonDecode(sent.body));
      final format = _object(body['response_format']);
      final schema = _object(format['json_schema']);

      expect(sent.uri, Uri.parse('https://api.openai.com/v1/chat/completions'));
      expect(sent.headers['authorization'], 'Bearer unit-test-secret');
      expect(sent.toString(), isNot(contains('unit-test-secret')));
      expect(sent.toString(), isNot(contains('Untrusted article body')));
      expect(format['type'], 'json_schema');
      expect(schema['name'], 'river_article-summary_v1');
      expect(schema['strict'], isTrue);
      expect(body['max_completion_tokens'], 1600);
      expect(body, isNot(contains('max_tokens')));
      expect(response.output, _summaryOutput);
      expect(response.model, 'resolved-model');
      expect(response.usage.totalTokens, 16);
      expect(response.providerRequestId, 'request-1');
      expect(response.toString(), isNot(contains(_summaryOutput)));
    });

    test('uses provider-compatible JSON object and legacy token parameter',
        () async {
      final transport = _Transport(response: _successResponse());
      final provider = _provider(
        transport: transport,
        presetId: 'deepseek',
      );

      await provider.complete(_request(model: 'test-model'));

      final body = _object(jsonDecode(transport.requests.single.body));
      expect(body['response_format'], <String, Object?>{'type': 'json_object'});
      expect(body['max_tokens'], 1600);
      expect(body, isNot(contains('max_completion_tokens')));
    });

    test('omits unsupported response_format for Anthropic compatibility',
        () async {
      final transport = _Transport(response: _successResponse());
      final provider = _provider(
        transport: transport,
        presetId: 'anthropic',
      );

      await provider.complete(_request());

      final body = _object(jsonDecode(transport.requests.single.body));
      expect(body, isNot(contains('response_format')));
      expect(body['max_completion_tokens'], 1600);
    });

    test('maps bounded status failures without exposing remote error body',
        () async {
      final cases = <int, AiProviderFailureCode>{
        401: AiProviderFailureCode.authenticationRequired,
        402: AiProviderFailureCode.quotaExceeded,
        400: AiProviderFailureCode.invalidRequest,
        429: AiProviderFailureCode.rateLimited,
        503: AiProviderFailureCode.unavailable,
      };
      for (final entry in cases.entries) {
        final provider = _provider(
          transport: _Transport(
            response: AiHttpResponse(
              statusCode: entry.key,
              body: '{"error":"remote-secret-error"}',
              headers: const <String, String>{'Retry-After': '99999'},
            ),
          ),
        );

        try {
          await provider.complete(_request());
          fail('Expected status ${entry.key} to fail');
        } on AiProviderFailure catch (failure) {
          expect(failure.code, entry.value);
          expect(failure.toString(), isNot(contains('remote-secret-error')));
          if (entry.key == 429 || entry.key == 503) {
            expect(failure.retryAfter, const Duration(hours: 1));
          } else {
            expect(failure.retryAfter, isNull);
          }
        }
      }
    });

    test('maps transport failures and malformed envelopes to stable failures',
        () async {
      for (final code in AiHttpTransportFailureCode.values) {
        final provider = _provider(transport: _Transport(failure: code));
        try {
          await provider.complete(_request());
          fail('Expected $code to fail');
        } on AiProviderFailure catch (failure) {
          expect(
            failure.code,
            code == AiHttpTransportFailureCode.timeout
                ? AiProviderFailureCode.timeout
                : code == AiHttpTransportFailureCode.offline
                    ? AiProviderFailureCode.unavailable
                    : AiProviderFailureCode.invalidRequest,
          );
        }
      }

      final provider = _provider(
        transport: _Transport(
          response: AiHttpResponse(statusCode: 200, body: '{"choices":[]}'),
        ),
      );
      await expectLater(
        provider.complete(_request()),
        throwsA(
          isA<AiProviderFailure>().having(
            (failure) => failure.code,
            'code',
            AiProviderFailureCode.unavailable,
          ),
        ),
      );
    });

    test('rejects truncation, filtered content, and mismatched models',
        () async {
      for (final reason in <String>['length', 'content_filter']) {
        final response = _successResponse(finishReason: reason);
        final provider = _provider(transport: _Transport(response: response));
        await expectLater(
          provider.complete(_request()),
          throwsA(
            isA<AiProviderFailure>().having(
              (failure) => failure.code,
              'code',
              AiProviderFailureCode.invalidRequest,
            ),
          ),
        );
      }
      final provider =
          _provider(transport: _Transport(response: _successResponse()));
      await expectLater(
        provider.complete(_request(model: 'different-model')),
        throwsA(isA<AiProviderFailure>()),
      );
      expect(provider.id, 'openai-compatible:openai');
    });

    test('maps an oversized encoded request to a non-retryable input failure',
        () async {
      final provider =
          _provider(transport: _Transport(response: _successResponse()));
      final prompt = AiPrompt(
        templateId: 'large-prompt',
        version: 1,
        system: 'Summarize the article.',
        user: List<String>.filled(100000, '界').join(),
        responseSchemaName: 'river.article-summary.v1',
      );

      await expectLater(
        provider.complete(
          AiProviderRequest(
            operationId: 'large-operation',
            model: 'test-model',
            prompt: prompt,
            responseSchema: ArticleSummarySchema.jsonSchema,
          ),
        ),
        throwsA(
          isA<AiProviderFailure>()
              .having(
                (failure) => failure.code,
                'code',
                AiProviderFailureCode.invalidRequest,
              )
              .having((failure) => failure.retryable, 'retryable', isFalse),
        ),
      );
    });
  });

  test('PackageHttp request and response diagnostics are body-safe', () {
    final request = AiHttpRequest(
      uri: Uri.parse('https://models.example/v1/chat/completions'),
      headers: const <String, String>{
        'authorization': 'Bearer secret-key',
      },
      body: '{"content":"private article"}',
      timeout: const Duration(seconds: 10),
    );
    final response = AiHttpResponse(
      statusCode: 200,
      body: '{"content":"private output"}',
      headers: const <String, String>{'x-request-id': 'request-1'},
    );

    expect(request.toString(), isNot(contains('secret-key')));
    expect(request.toString(), isNot(contains('private article')));
    expect(request.toString(), isNot(contains('/v1/chat/completions')));
    expect(response.toString(), isNot(contains('private output')));
  });
}

OpenAiCompatibleProvider _provider({
  required AiHttpTransport transport,
  AiMonotonicClock? clock,
  String presetId = 'openai',
}) {
  final preset = AiProviderPresetCatalog.standard().resolve(presetId);
  return OpenAiCompatibleProvider(
    configuration: preset.configure(
      model: 'test-model',
      apiKey: OpaqueAiApiKey('unit-test-secret'),
    ),
    transport: transport,
    clock: clock ?? _Clock(),
  );
}

AiProviderRequest _request({String model = 'test-model'}) {
  final prompt = articleSummaryPromptV1.render(
    const <String, String>{
      'articleId': 'article-1',
      'title': 'Test',
      'content': 'Untrusted article body.',
      'language': 'en',
    },
  );
  return AiProviderRequest(
    operationId: 'operation-1',
    model: model,
    prompt: prompt,
    responseSchema: ArticleSummarySchema.jsonSchema,
  );
}

AiHttpResponse _successResponse({String finishReason = 'stop'}) =>
    AiHttpResponse(
      statusCode: 200,
      headers: const <String, String>{'x-request-id': 'header-request'},
      body: jsonEncode(
        <String, Object?>{
          'id': 'request-1',
          'model': 'resolved-model',
          'choices': <Object?>[
            <String, Object?>{
              'finish_reason': finishReason,
              'message': <String, Object?>{'content': _summaryOutput},
            },
          ],
          'usage': <String, Object?>{
            'prompt_tokens': 10,
            'completion_tokens': 6,
            'total_tokens': 16,
          },
        },
      ),
    );

const _summaryOutput = '{"schemaVersion":"river.article-summary.v1"}';

Map<String, Object?> _object(Object? value) =>
    Map<String, Object?>.from(value! as Map);

final class _Transport implements AiHttpTransport {
  _Transport({
    this.response,
    this.failure,
    this.onSend,
  });

  final AiHttpResponse? response;
  final AiHttpTransportFailureCode? failure;
  final void Function(AiHttpRequest request)? onSend;
  final List<AiHttpRequest> requests = <AiHttpRequest>[];

  @override
  Future<AiHttpResponse> send(AiHttpRequest request) async {
    requests.add(request);
    onSend?.call(request);
    if (failure case final code?) throw AiHttpTransportFailure(code);
    return response!;
  }
}

final class _Clock implements AiMonotonicClock {
  Duration value = Duration.zero;

  void advance(Duration duration) {
    value += duration;
  }

  @override
  Duration elapsed() => value;
}
