import 'dart:convert';

import 'package:river_ai/river_ai.dart';
import 'package:river_domain/river_domain.dart';
import 'package:test/test.dart';

final class _QueueProvider implements AiProvider {
  _QueueProvider(Iterable<String> outputs)
      : _outputs = List<String>.of(outputs);

  final List<String> _outputs;
  final List<AiProviderRequest> requests = <AiProviderRequest>[];

  @override
  String get id => 'queue';

  @override
  Future<AiProviderResponse> complete(AiProviderRequest request) async {
    requests.add(request);
    if (_outputs.isEmpty) throw StateError('No response queued');
    return AiProviderResponse(
      output: _outputs.removeAt(0),
      model: request.model,
      usage: AiTokenUsage(inputTokens: 100, outputTokens: 80),
      elapsed: const Duration(milliseconds: 20),
    );
  }
}

void main() {
  test('empty content never spends provider quota', () {
    final provider = _QueueProvider(const <String>[]);
    final service = SummaryService(provider);
    final article = Article(
      id: 'a',
      url: Uri.parse('https://example.test/a'),
      title: 'Empty',
      source: ContentSource.feed,
    );

    expect(() => service.summarize(article), throwsArgumentError);
    expect(provider.requests, isEmpty);
  });

  test('valid structured output maps every required summary field', () async {
    final provider = _QueueProvider(<String>[_validSummary()]);
    final service = SummaryService(
      provider,
      model: 'replay-v1',
      outputLanguage: 'zh-CN',
    );

    final summary = await service.summarize(_article());

    expect(summary.oneLine, 'River 是一款本地优先的 RSS 阅读器。');
    expect(summary.keyPoints, hasLength(3));
    expect(summary.whyItMatters, contains('隐私'));
    expect(summary.topics, <String>['RSS', '本地优先']);
    expect(summary.entities, <String>['River']);
    expect(summary.estimatedReadingMinutes, 4);
    expect(summary.language, 'zh-CN');
    expect(summary.model, 'replay-v1');
    expect(summary.promptVersion, 'article-summary@1');
    expect(provider.requests, hasLength(1));
    expect(
      provider.requests.single.prompt.responseSchemaName,
      ArticleSummarySchema.name,
    );
  });

  test(
    'one schema repair is allowed and keeps the original prompt version',
    () async {
      final provider = _QueueProvider(<String>[
        '{"oneLine":"not enough"}',
        _validSummary(),
      ]);
      final service = SummaryService(provider, model: 'replay-v1');

      final summary = await service.summarize(_article());

      expect(summary.promptVersion, 'article-summary@1');
      expect(provider.requests, hasLength(2));
      expect(provider.requests.first.operationId, 'article-1');
      expect(provider.requests.last.operationId, 'article-1:repair');
      expect(
        provider.requests.last.prompt.versionKey,
        'article-summary-repair@1',
      );
      expect(provider.requests.last.prompt.user, contains('missingField'));
    },
  );

  test('a second invalid response fails with a stable schema code', () async {
    final provider = _QueueProvider(const <String>[
      '{}',
      '{"schemaVersion":"wrong"}',
    ]);
    final service = SummaryService(provider);

    await expectLater(
      service.summarize(_article()),
      throwsA(
        isA<AiSchemaFailure>().having(
          (failure) => failure.code,
          'code',
          AiSchemaFailureCode.missingField,
        ),
      ),
    );
    expect(provider.requests, hasLength(2));
  });
}

Article _article() => Article(
      id: 'article-1',
      url: Uri.parse('https://example.test/article'),
      title: 'River 产品原则',
      source: ContentSource.web,
      plainText: 'River 是本地优先的 RSS 阅读工具，基础阅读不要求云端账号。',
    );

String _validSummary() => jsonEncode(
      <String, Object?>{
        'schemaVersion': ArticleSummarySchema.name,
        'oneLine': 'River 是一款本地优先的 RSS 阅读器。',
        'keyPoints': <String>[
          '基础阅读不依赖云端账号。',
          '用户可以掌控自己的订阅数据。',
          '产品优先保证可靠阅读体验。',
        ],
        'whyItMatters': '它让用户在保护隐私的同时稳定获取信息。',
        'topics': <String>['RSS', '本地优先'],
        'entities': <String>['River'],
        'estimatedReadingMinutes': 4,
        'language': 'zh-CN',
      },
    );
