enum AiStructuredOutputMode { jsonSchema, jsonObject, promptOnly }

enum AiTokenLimitParameter { maxCompletionTokens, maxTokens }

final class OpaqueAiApiKey {
  OpaqueAiApiKey(String value) : _value = value {
    if (value.trim() != value ||
        value.length < 8 ||
        value.length > 8192 ||
        value.runes.any((character) => character < 0x21 || character == 0x7f)) {
      throw ArgumentError.value('<redacted>', 'value');
    }
  }

  final String _value;

  String reveal() => _value;

  @override
  String toString() => 'OpaqueAiApiKey(<redacted>)';
}

final class AiProviderPreset {
  AiProviderPreset({
    required this.id,
    required this.displayName,
    required this.baseUri,
    required this.structuredOutputMode,
    required this.tokenLimitParameter,
    this.compatibilityNotice,
  }) {
    _requireIdentifier(id, 'id');
    _requireLabel(displayName, 'displayName');
    _requireBaseUri(baseUri);
    if (compatibilityNotice != null) {
      _requireLabel(compatibilityNotice!, 'compatibilityNotice');
    }
  }

  final String id;
  final String displayName;
  final Uri baseUri;
  final AiStructuredOutputMode structuredOutputMode;
  final AiTokenLimitParameter tokenLimitParameter;
  final String? compatibilityNotice;

  AiByokConfiguration configure({
    required String model,
    required OpaqueAiApiKey apiKey,
  }) =>
      AiByokConfiguration(
        presetId: id,
        displayName: displayName,
        baseUri: baseUri,
        model: model,
        apiKey: apiKey,
        structuredOutputMode: structuredOutputMode,
        tokenLimitParameter: tokenLimitParameter,
      );

  @override
  String toString() => 'AiProviderPreset('
      'id: $id, '
      'baseUri: $baseUri, '
      'structuredOutputMode: ${structuredOutputMode.name}, '
      'tokenLimitParameter: ${tokenLimitParameter.name}'
      ')';
}

final class AiProviderPresetCatalog {
  AiProviderPresetCatalog(Iterable<AiProviderPreset> presets)
      : _presets = Map<String, AiProviderPreset>.unmodifiable(
          <String, AiProviderPreset>{
            for (final preset in presets) preset.id: preset,
          },
        ) {
    if (_presets.isEmpty || _presets.length != presets.length) {
      throw ArgumentError('Provider preset identifiers must be unique');
    }
  }

  factory AiProviderPresetCatalog.standard() => AiProviderPresetCatalog(
        <AiProviderPreset>[
          AiProviderPreset(
            id: 'openai',
            displayName: 'OpenAI',
            baseUri: Uri.parse('https://api.openai.com/v1'),
            structuredOutputMode: AiStructuredOutputMode.jsonSchema,
            tokenLimitParameter: AiTokenLimitParameter.maxCompletionTokens,
          ),
          AiProviderPreset(
            id: 'anthropic',
            displayName: 'Anthropic',
            baseUri: Uri.parse('https://api.anthropic.com/v1'),
            structuredOutputMode: AiStructuredOutputMode.promptOnly,
            tokenLimitParameter: AiTokenLimitParameter.maxCompletionTokens,
            compatibilityNotice:
                'Anthropic OpenAI compatibility ignores response_format; '
                'River still validates and repairs the result locally.',
          ),
          AiProviderPreset(
            id: 'gemini',
            displayName: 'Google Gemini',
            baseUri: Uri.parse(
              'https://generativelanguage.googleapis.com/v1beta/openai',
            ),
            structuredOutputMode: AiStructuredOutputMode.jsonSchema,
            tokenLimitParameter: AiTokenLimitParameter.maxCompletionTokens,
          ),
          AiProviderPreset(
            id: 'deepseek',
            displayName: 'DeepSeek',
            baseUri: Uri.parse('https://api.deepseek.com'),
            structuredOutputMode: AiStructuredOutputMode.jsonObject,
            tokenLimitParameter: AiTokenLimitParameter.maxTokens,
          ),
          AiProviderPreset(
            id: 'qwen',
            displayName: '通义千问',
            baseUri: Uri.parse(
              'https://dashscope.aliyuncs.com/compatible-mode/v1',
            ),
            structuredOutputMode: AiStructuredOutputMode.jsonObject,
            tokenLimitParameter: AiTokenLimitParameter.maxTokens,
          ),
        ],
      );

  final Map<String, AiProviderPreset> _presets;

  List<AiProviderPreset> get presets =>
      List<AiProviderPreset>.unmodifiable(_presets.values);

  AiProviderPreset resolve(String id) {
    final preset = _presets[id];
    if (preset == null) throw StateError('Unknown AI provider preset: $id');
    return preset;
  }
}

final class AiByokConfiguration {
  AiByokConfiguration({
    required this.presetId,
    required this.displayName,
    required this.baseUri,
    required this.model,
    required this.apiKey,
    required this.structuredOutputMode,
    required this.tokenLimitParameter,
  }) {
    _requireIdentifier(presetId, 'presetId');
    _requireLabel(displayName, 'displayName');
    _requireBaseUri(baseUri);
    if (model.trim() != model || model.isEmpty || model.length > 200) {
      throw ArgumentError.value(model, 'model');
    }
  }

  final String presetId;
  final String displayName;
  final Uri baseUri;
  final String model;
  final OpaqueAiApiKey apiKey;
  final AiStructuredOutputMode structuredOutputMode;
  final AiTokenLimitParameter tokenLimitParameter;

  Uri get chatCompletionsUri {
    final normalized = baseUri.toString().replaceFirst(RegExp(r'/+$'), '');
    return Uri.parse('$normalized/chat/completions');
  }

  @override
  String toString() => 'AiByokConfiguration('
      'presetId: $presetId, '
      'origin: ${baseUri.origin}, '
      'pathSegments: ${baseUri.pathSegments.length}, '
      'model: $model, '
      'apiKey: <redacted>, '
      'structuredOutputMode: ${structuredOutputMode.name}, '
      'tokenLimitParameter: ${tokenLimitParameter.name}'
      ')';
}

abstract interface class AiByokConfigurationVault {
  Future<AiByokConfiguration?> read();
  Future<void> write(AiByokConfiguration configuration);
  Future<void> clear();
}

void _requireIdentifier(String value, String name) {
  if (!RegExp(r'^[a-z][a-z0-9-]{1,63}$').hasMatch(value)) {
    throw ArgumentError.value(value, name);
  }
}

void _requireLabel(String value, String name) {
  if (value.trim() != value || value.isEmpty || value.length > 512) {
    throw ArgumentError.value(value, name);
  }
}

void _requireBaseUri(Uri value) {
  if (value.scheme != 'https' ||
      value.host.isEmpty ||
      value.userInfo.isNotEmpty ||
      value.hasQuery ||
      value.hasFragment) {
    throw ArgumentError.value(value, 'baseUri');
  }
}
