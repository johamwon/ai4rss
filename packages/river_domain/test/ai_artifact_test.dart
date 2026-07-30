import 'package:river_domain/river_domain.dart';
import 'package:test/test.dart';

void main() {
  test('AI artifact diagnostics exclude structured article output', () {
    final artifact = _artifact();

    expect(artifact.toString(), contains('structuredResultCharacters:'));
    expect(artifact.toString(), isNot(contains(artifact.structuredResult)));
    expect(artifact.toString(), isNot(contains('private summary')));
  });

  test('AI artifact rejects unsafe identity and accounting values', () {
    expect(
      () => _artifact(
        cacheKey: 'body|model|prompt|language',
      ),
      throwsArgumentError,
    );
    expect(
      () => _artifact(costUsd: double.nan),
      throwsArgumentError,
    );
    expect(
      () => _artifact(providerCalls: -1),
      throwsArgumentError,
    );
  });
}

AiArtifact _artifact({
  String cacheKey =
      'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  int providerCalls = 1,
  double costUsd = 0.001,
}) =>
    AiArtifact(
      cacheKey: cacheKey,
      articleId: 'article-1',
      type: AiArtifactType.articleSummary,
      requestModel: 'model-v1',
      resolvedModel: 'model-v1-20260730',
      promptVersion: 'article-summary@1',
      language: 'zh-CN',
      contentHash:
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      structuredResult: '{"oneLine":"private summary"}',
      inputTokens: 10,
      outputTokens: 5,
      providerCalls: providerCalls,
      costUsd: costUsd,
      createdAt: DateTime.utc(2026, 7, 30),
    );
