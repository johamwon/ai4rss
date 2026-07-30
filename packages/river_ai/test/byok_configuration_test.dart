import 'package:river_ai/river_ai.dart';
import 'package:test/test.dart';

void main() {
  test('standard catalog exposes bounded official compatibility templates', () {
    final catalog = AiProviderPresetCatalog.standard();

    expect(
      catalog.presets.map((preset) => preset.id),
      <String>['openai', 'anthropic', 'gemini', 'deepseek', 'qwen'],
    );
    expect(
      catalog.resolve('openai').baseUri,
      Uri.parse('https://api.openai.com/v1'),
    );
    expect(
      catalog.resolve('anthropic').structuredOutputMode,
      AiStructuredOutputMode.promptOnly,
    );
    expect(
      catalog.resolve('gemini').chatUri,
      Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/openai/'
        'chat/completions',
      ),
    );
    expect(
      catalog.resolve('deepseek').tokenLimitParameter,
      AiTokenLimitParameter.maxTokens,
    );
    expect(
      catalog.resolve('qwen').baseUri.host,
      'dashscope.aliyuncs.com',
    );
  });

  test('configuration and key diagnostics are always redacted', () {
    final configuration =
        AiProviderPresetCatalog.standard().resolve('openai').configure(
              model: 'test-model',
              apiKey: OpaqueAiApiKey('super-secret-key'),
            );

    expect(configuration.chatCompletionsUri.path, '/v1/chat/completions');
    expect(configuration.toString(), isNot(contains('super-secret-key')));
    expect(
      configuration.apiKey.toString(),
      isNot(contains('super-secret-key')),
    );
    expect(configuration.apiKey.toString(), contains('<redacted>'));
    expect(
      () => OpaqueAiApiKey('secret-key\r\ninjected'),
      throwsArgumentError,
    );
  });

  test('custom configurations require credential-safe HTTPS base URLs', () {
    AiByokConfiguration configuration(Uri baseUri) => AiByokConfiguration(
          presetId: 'custom',
          displayName: 'Custom',
          baseUri: baseUri,
          model: 'custom-model',
          apiKey: OpaqueAiApiKey('custom-secret-key'),
          structuredOutputMode: AiStructuredOutputMode.jsonObject,
          tokenLimitParameter: AiTokenLimitParameter.maxTokens,
        );

    expect(
      () => configuration(Uri.parse('http://models.example/v1')),
      throwsArgumentError,
    );
    expect(
      () => configuration(Uri.parse('https://token@models.example/v1')),
      throwsArgumentError,
    );
    expect(
      () => configuration(Uri.parse('https://models.example/v1?key=value')),
      throwsArgumentError,
    );
    expect(
      configuration(Uri.parse('https://models.example/v1')).chatCompletionsUri,
      Uri.parse('https://models.example/v1/chat/completions'),
    );
    final pathSecret = configuration(
      Uri.parse('https://models.example/private-route-token'),
    );
    expect(pathSecret.toString(), isNot(contains('private-route-token')));
  });

  test('unknown and duplicate preset identifiers are rejected', () {
    expect(
      () => AiProviderPresetCatalog.standard().resolve('missing'),
      throwsStateError,
    );
    final preset = AiProviderPreset(
      id: 'same',
      displayName: 'Same',
      baseUri: Uri.parse('https://models.example/v1'),
      structuredOutputMode: AiStructuredOutputMode.promptOnly,
      tokenLimitParameter: AiTokenLimitParameter.maxTokens,
    );
    expect(
      () => AiProviderPresetCatalog(<AiProviderPreset>[preset, preset]),
      throwsArgumentError,
    );
  });
}

extension on AiProviderPreset {
  Uri get chatUri => configure(
        model: 'test-model',
        apiKey: OpaqueAiApiKey('test-secret-key'),
      ).chatCompletionsUri;
}
