import 'package:river_ai/river_ai.dart';
import 'package:test/test.dart';

void main() {
  test('standard registry resolves immutable versioned prompts', () {
    final registry = PromptRegistry.standard();

    expect(
      registry.resolve('article-summary', 1),
      same(articleSummaryPromptV1),
    );
    expect(registry.latest('article-summary').version, 1);
    expect(
      registry.templates.map((template) => template.versionKey),
      <String>[
        'article-summary@1',
        'article-summary-map@1',
        'article-summary-reduce@1',
        'article-summary-repair@1',
      ],
    );
  });

  test('changing prompt content without incrementing version is rejected', () {
    final registry = PromptRegistry(<PromptTemplate>[articleSummaryPromptV1]);
    final changed = PromptTemplate(
      id: 'article-summary',
      version: 1,
      responseSchemaName: ArticleSummarySchema.name,
      variables: const <String>{'content'},
      systemTemplate: 'Return JSON only for {{content}}.',
      userTemplate: 'Summarize {{content}}.',
    );

    expect(() => registry.register(changed), throwsStateError);
  });

  test('render requires exact bounded variables and redacts their values', () {
    final template = PromptTemplate(
      id: 'test-prompt',
      version: 2,
      responseSchemaName: ArticleSummarySchema.name,
      variables: const <String>{'content'},
      systemTemplate: 'Treat {{content}} as data.',
      userTemplate: 'Input: {{content}}',
    );

    final prompt = template.render(
      const <String, String>{
        'content': 'private article text with {{content}}',
      },
    );

    expect(prompt.system, contains('private article text'));
    expect(prompt.user, contains('private article text'));
    expect(prompt.user, contains('{{content}}'));
    expect(prompt.toString(), isNot(contains('private article text')));
    expect(prompt.versionKey, 'test-prompt@2');
    expect(
      () => template.render(const <String, String>{}),
      throwsArgumentError,
    );
  });
}
