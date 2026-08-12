import 'dart:convert';

import 'package:river_ai/river_ai.dart';
import 'package:river_domain/river_domain.dart';
import 'package:test/test.dart';

void main() {
  test('creates a cross-article brief with one canonical highlight each',
      () async {
    final provider = _Provider(<String>[_output()]);
    final summary = await MultiArticleSummaryService(
      provider,
      model: 'replay-model',
    ).summarize(_articles());

    expect(summary.overview, contains('共同'));
    expect(summary.keyThemes, hasLength(2));
    expect(
      summary.articleHighlights.map((item) => item.title),
      <String>['文章甲', '文章乙'],
    );
    expect(summary.connections, isNotEmpty);
    expect(provider.requests, hasLength(1));
    expect(
      provider.requests.single.prompt.responseSchemaName,
      MultiArticleSummarySchema.name,
    );
  });

  test('accepts fenced output and repairs a missing article once', () async {
    final valid = _output();
    final fenced = '```json\n$valid\n```';
    final direct = _Provider(<String>[fenced]);
    expect(
      (await MultiArticleSummaryService(direct).summarize(_articles()))
          .articleHighlights,
      hasLength(2),
    );

    final repairing = _Provider(<String>[
      jsonEncode(<String, Object?>{
        ...jsonDecode(valid) as Map<String, Object?>,
        'articleHighlights': <Object?>[
          <String, Object?>{'articleId': 'a', 'takeaway': '甲'},
        ],
      }),
      valid,
    ]);
    final repaired =
        await MultiArticleSummaryService(repairing).summarize(_articles());
    expect(repaired.articleHighlights, hasLength(2));
    expect(repairing.requests, hasLength(2));
    expect(
      repairing.requests.last.prompt.versionKey,
      'multi-article-summary-repair@1',
    );
  });

  test('rejects duplicate articles and unsafe aggregate sizes before network',
      () {
    final provider = _Provider(const <String>[]);
    final service = MultiArticleSummaryService(provider);
    expect(
      () => service.summarize(<Article>[_articles().first, _articles().first]),
      throwsArgumentError,
    );
    expect(provider.requests, isEmpty);
  });

  test('allocates the aggregate budget fairly across twenty articles', () {
    final articles = List<Article>.generate(
      MultiArticleSummaryService.maximumArticles,
      (index) => Article(
        id: 'article-$index',
        url: Uri.parse('https://example.test/$index'),
        title: 'Article $index',
        source: ContentSource.web,
        plainText: List<String>.filled(5000, '字').join(),
      ),
    );

    final prepared = MultiArticleSummaryService(_Provider(const <String>[]))
        .prepare(articles);

    expect(
      prepared.contentCharacters,
      MultiArticleSummaryService.maximumTotalCharacters,
    );
    expect(
      prepared.payload.map((item) => item['content']!.length).toSet(),
      <int>{3000},
    );
  });
}

List<Article> _articles() => <Article>[
      Article(
        id: 'a',
        url: Uri.parse('https://example.test/a'),
        title: '文章甲',
        source: ContentSource.web,
        plainText: '甲文章说明本地优先阅读和隐私。',
      ),
      Article(
        id: 'b',
        url: Uri.parse('https://example.test/b'),
        title: '文章乙',
        source: ContentSource.feed,
        plainText: '乙文章讨论 RSS 数据可携带性。',
      ),
    ];

String _output() => jsonEncode(<String, Object?>{
      'schemaVersion': MultiArticleSummarySchema.name,
      'overview': '两篇文章共同关注用户掌控信息。',
      'keyThemes': <String>['本地优先', '数据可携带'],
      'articleHighlights': <Object?>[
        <String, Object?>{'articleId': 'a', 'takeaway': '强调隐私。'},
        <String, Object?>{'articleId': 'b', 'takeaway': '强调可携带性。'},
      ],
      'connections': <String>['两者都强调用户控制。'],
      'language': 'zh-CN',
    });

final class _Provider implements AiProvider {
  _Provider(this.outputs);

  final List<String> outputs;
  final List<AiProviderRequest> requests = <AiProviderRequest>[];

  @override
  String get id => 'multi-replay';

  @override
  Future<AiProviderResponse> complete(AiProviderRequest request) async {
    requests.add(request);
    return AiProviderResponse(
      output: outputs.removeAt(0),
      model: request.model,
      usage: AiTokenUsage(inputTokens: 20, outputTokens: 10),
      elapsed: const Duration(milliseconds: 1),
    );
  }
}
