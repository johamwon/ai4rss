import 'package:river_ai/river_ai.dart';
import 'package:test/test.dart';

void main() {
  test('provider request and response diagnostics exclude private content', () {
    final prompt = AiPrompt(
      templateId: 'test-prompt',
      version: 1,
      system: 'private system prompt',
      user: 'private article body',
      responseSchemaName: ArticleSummarySchema.name,
    );
    final request = AiProviderRequest(
      operationId: 'article-1',
      model: 'model-1',
      prompt: prompt,
      responseSchema: ArticleSummarySchema.jsonSchema,
    );
    final response = AiProviderResponse(
      output: '{"private":"model output"}',
      model: 'model-1',
      usage: AiTokenUsage(inputTokens: 10, outputTokens: 5),
      elapsed: const Duration(milliseconds: 50),
      providerRequestId: 'provider-1',
    );

    expect(request.toString(), contains('article-1'));
    expect(request.toString(), isNot(contains('private article body')));
    expect(response.toString(), isNot(contains('model output')));
    expect(response.usage.totalTokens, 15);
    expect(
      () => AiTokenUsage(inputTokens: -1, outputTokens: 0),
      throwsRangeError,
    );
    expect(
      () => AiProviderRequest(
        operationId: 'article-1',
        model: 'model-1',
        prompt: prompt,
        responseSchema: const <String, Object?>{'title': 'wrong-schema'},
      ),
      throwsArgumentError,
    );
  });

  test('provider failures expose only stable bounded recovery metadata', () {
    final failure = AiProviderFailure(
      code: AiProviderFailureCode.rateLimited,
      retryable: true,
      retryAfter: const Duration(seconds: 30),
    );

    expect(failure.toString(), contains('rateLimited'));
    expect(failure.retryAfter, const Duration(seconds: 30));
    expect(
      () => AiProviderFailure(
        code: AiProviderFailureCode.rateLimited,
        retryable: true,
        retryAfter: const Duration(hours: 2),
      ),
      throwsArgumentError,
    );
    expect(
      () => AiProviderFailure(
        code: AiProviderFailureCode.invalidRequest,
        retryable: false,
        retryAfter: const Duration(seconds: 1),
      ),
      throwsArgumentError,
    );
  });
}
