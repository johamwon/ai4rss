import 'dart:async';

import 'package:flutter/material.dart';
import 'package:river_ai/river_ai.dart';
import 'package:river_byok/river_byok.dart';

final class ByokProviderSettingsPage extends StatefulWidget {
  const ByokProviderSettingsPage({
    required this.aiVault,
    required this.mediaVault,
    required this.connections,
    super.key,
  });

  final AiByokConfigurationVault aiVault;
  final ByokMediaConfigurationVault mediaVault;
  final ByokProviderConnectionService connections;

  @override
  State<ByokProviderSettingsPage> createState() =>
      _ByokProviderSettingsPageState();
}

final class _ByokProviderSettingsPageState
    extends State<ByokProviderSettingsPage> {
  late final Map<_ProviderKind, _ProviderDraft> _drafts =
      <_ProviderKind, _ProviderDraft>{
    _ProviderKind.ai: _ProviderDraft(
      defaultModel: 'gpt-4.1-mini',
    ),
    _ProviderKind.tts: _ProviderDraft(
      defaultModel: 'gpt-4o-mini-tts',
      defaultVoice: 'alloy',
    ),
    _ProviderKind.transcription: _ProviderDraft(
      defaultModel: 'gpt-4o-mini-transcribe',
    ),
  };
  var _loading = true;
  _ProviderKind? _busy;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    for (final draft in _drafts.values) {
      draft.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final values = await Future.wait<Object?>(<Future<Object?>>[
        widget.aiVault.read(),
        widget.mediaVault.read(ByokMediaCapability.tts),
        widget.mediaVault.read(ByokMediaCapability.podcastTranscription),
      ]);
      if (!mounted) return;
      _drafts[_ProviderKind.ai]!.loadAi(values[0] as AiByokConfiguration?);
      _drafts[_ProviderKind.tts]!
          .loadMedia(values[1] as ByokMediaConfiguration?);
      _drafts[_ProviderKind.transcription]!
          .loadMedia(values[2] as ByokMediaConfiguration?);
    } on Object {
      if (mounted) _message('无法读取安全配置，请检查系统凭据存储');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save(_ProviderKind kind) async {
    setState(() => _busy = kind);
    try {
      switch (kind) {
        case _ProviderKind.ai:
          final configuration = _drafts[kind]!.buildAi();
          await widget.aiVault.write(configuration);
          _drafts[kind]!.rememberKey(configuration.apiKey.reveal());
        case _ProviderKind.tts:
        case _ProviderKind.transcription:
          final configuration = _drafts[kind]!.buildMedia(kind);
          await widget.mediaVault.write(configuration);
          _drafts[kind]!.rememberKey(configuration.apiKey.reveal());
      }
      if (mounted) _message('${kind.label}配置已安全保存');
    } on Object {
      if (mounted) _message('配置无效：请检查 HTTPS API、模型和 API Key');
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _test(_ProviderKind kind) async {
    setState(() => _busy = kind);
    try {
      final result = switch (kind) {
        _ProviderKind.ai =>
          await widget.connections.testAi(_drafts[kind]!.buildAi()),
        _ProviderKind.tts ||
        _ProviderKind.transcription =>
          await widget.connections.testMedia(_drafts[kind]!.buildMedia(kind)),
      };
      if (!mounted) return;
      _message(
        result.modelSeen == false ? 'API 连接成功，但模型列表中未发现当前模型' : 'API 与 Key 验证成功',
      );
    } on ByokConnectionFailure catch (failure) {
      if (!mounted) return;
      _message(
        switch (failure.code) {
          ByokConnectionFailureCode.quotaExhausted => '供应商额度不足，请充值或更换模型',
          ByokConnectionFailureCode.authenticationRejected => '供应商拒绝了 API Key',
          ByokConnectionFailureCode.rateLimited => '供应商限流，请稍后再试',
          ByokConnectionFailureCode.unavailable => '暂时无法连接供应商',
          ByokConnectionFailureCode.invalidResponse => '供应商 API 不兼容',
        },
      );
    } on Object {
      if (mounted) _message('配置无效：请检查 HTTPS API、模型和 API Key');
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _clear(_ProviderKind kind) async {
    setState(() => _busy = kind);
    try {
      switch (kind) {
        case _ProviderKind.ai:
          await widget.aiVault.clear();
        case _ProviderKind.tts:
          await widget.mediaVault.clear(ByokMediaCapability.tts);
        case _ProviderKind.transcription:
          await widget.mediaVault.clear(
            ByokMediaCapability.podcastTranscription,
          );
      }
      _drafts[kind]!.forgetKey();
      if (mounted) _message('${kind.label}凭据已删除');
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  void _message(String value) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI 与音频供应商')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'API Key 只保存在本机系统安全存储中。River 客户端直接请求你配置的供应商，'
                      '不会把 Key 写入数据库、日志或 River 云端。仅支持 HTTPS 的 '
                      'OpenAI-compatible API。',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                for (final kind in _ProviderKind.values) ...<Widget>[
                  _ProviderEditor(
                    kind: kind,
                    draft: _drafts[kind]!,
                    busy: _busy == kind,
                    blocked: _busy != null,
                    onSave: () => unawaited(_save(kind)),
                    onTest: () => unawaited(_test(kind)),
                    onClear: () => unawaited(_clear(kind)),
                    onDraftChanged: () => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
    );
  }
}

enum _ProviderKind {
  ai('AI 摘要', Icons.auto_awesome_outlined),
  tts('云端 TTS', Icons.record_voice_over_outlined),
  transcription('播客转录', Icons.graphic_eq_outlined);

  const _ProviderKind(this.label, this.icon);

  final String label;
  final IconData icon;
}

final class _ProviderEditor extends StatelessWidget {
  const _ProviderEditor({
    required this.kind,
    required this.draft,
    required this.busy,
    required this.blocked,
    required this.onSave,
    required this.onTest,
    required this.onClear,
    required this.onDraftChanged,
  });

  final _ProviderKind kind;
  final _ProviderDraft draft;
  final bool busy;
  final bool blocked;
  final VoidCallback onSave;
  final VoidCallback onTest;
  final VoidCallback onClear;
  final VoidCallback onDraftChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(kind.icon),
                const SizedBox(width: 12),
                Text(
                  kind.label,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                if (draft.hasSavedKey) const Chip(label: Text('已保存 Key')),
              ],
            ),
            const SizedBox(height: 12),
            if (kind == _ProviderKind.tts) ...<Widget>[
              DropdownButtonFormField<String>(
                key: const ValueKey<String>('tts-provider-type'),
                initialValue: draft.providerId,
                decoration: const InputDecoration(
                  labelText: 'TTS 服务商类型',
                  border: OutlineInputBorder(),
                ),
                items: const <DropdownMenuItem<String>>[
                  DropdownMenuItem<String>(
                    value: 'custom-provider',
                    child: Text('OpenAI-compatible / 自定义'),
                  ),
                  DropdownMenuItem<String>(
                    value: FishAudioTtsPreset.providerId,
                    child: Text('Fish Audio'),
                  ),
                ],
                onChanged: blocked
                    ? null
                    : (value) {
                        if (value == null) return;
                        draft.selectTtsProvider(value);
                        onDraftChanged();
                      },
              ),
              if (draft.isFishAudio) ...<Widget>[
                const SizedBox(height: 8),
                const Text(
                  '在 fish.audio/app/api-keys 创建 API Key。可使用默认音色，'
                  '也可从 Fish Audio 音色页面复制 Voice Model ID。'
                  '切换服务商后需要重新输入对应的 Key。',
                ),
              ],
              const SizedBox(height: 12),
            ],
            TextField(
              controller: draft.displayName,
              decoration: const InputDecoration(
                labelText: '供应商名称',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: draft.baseUrl,
              readOnly: kind == _ProviderKind.tts && draft.isFishAudio,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'API Base URL',
                hintText: 'https://api.example.com/v1',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            if (kind == _ProviderKind.tts && draft.isFishAudio)
              DropdownButtonFormField<String>(
                key: const ValueKey<String>('fish-audio-model'),
                initialValue: draft.model.text,
                decoration: const InputDecoration(
                  labelText: 'Fish Audio 模型',
                  border: OutlineInputBorder(),
                ),
                items: FishAudioTtsPreset.supportedModels
                    .map(
                      (model) => DropdownMenuItem<String>(
                        value: model,
                        child: Text(
                          model == FishAudioTtsPreset.developerModel
                              ? '$model（开发者免费层）'
                              : model,
                        ),
                      ),
                    )
                    .toList(growable: false),
                onChanged: blocked
                    ? null
                    : (value) {
                        if (value == null) return;
                        draft.model.text = value;
                        onDraftChanged();
                      },
              )
            else
              TextField(
                controller: draft.model,
                decoration: const InputDecoration(
                  labelText: '模型',
                  border: OutlineInputBorder(),
                ),
              ),
            if (kind == _ProviderKind.tts) ...<Widget>[
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey<String>('tts-voice'),
                controller: draft.voice,
                decoration: const InputDecoration(
                  labelText: '音色 Voice',
                  border: OutlineInputBorder(),
                ),
              ),
              if (draft.isFishAudio) ...<Widget>[
                const SizedBox(height: 4),
                const Text(
                  'Voice 字段可留空使用默认音色；也可填写 Voice Model ID。',
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<ByokAudioFormat>(
                  key: const ValueKey<String>('fish-audio-format'),
                  initialValue: draft.audioFormat,
                  decoration: const InputDecoration(
                    labelText: '输出格式',
                    border: OutlineInputBorder(),
                  ),
                  items: const <ByokAudioFormat>[
                    ByokAudioFormat.mp3,
                    ByokAudioFormat.wav,
                    ByokAudioFormat.opus,
                  ]
                      .map(
                        (format) => DropdownMenuItem<ByokAudioFormat>(
                          value: format,
                          child: Text(format.name.toUpperCase()),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: blocked
                      ? null
                      : (value) {
                          if (value == null) return;
                          draft.audioFormat = value;
                          onDraftChanged();
                        },
                ),
                const SizedBox(height: 8),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('Fish Audio 高级参数'),
                  subtitle: const Text('参数已按官方范围校验；阅读倍速会限制在 0.5–2.0 倍'),
                  children: <Widget>[
                    DropdownButtonFormField<FishAudioLatency>(
                      initialValue: draft.fishLatency,
                      decoration: const InputDecoration(
                        labelText: '延迟与质量',
                        border: OutlineInputBorder(),
                      ),
                      items: FishAudioLatency.values
                          .map(
                            (value) => DropdownMenuItem<FishAudioLatency>(
                              value: value,
                              child: Text(
                                switch (value) {
                                  FishAudioLatency.normal => '最佳质量（normal）',
                                  FishAudioLatency.balanced => '平衡（balanced）',
                                  FishAudioLatency.low => '最低延迟（low）',
                                },
                              ),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: blocked
                          ? null
                          : (value) {
                              if (value == null) return;
                              draft.fishLatency = value;
                              onDraftChanged();
                            },
                    ),
                    const SizedBox(height: 12),
                    _ParameterSlider(
                      label: '表现力 temperature',
                      value: draft.fishTemperature,
                      minimum: 0,
                      maximum: 1,
                      divisions: 20,
                      onChanged: blocked
                          ? null
                          : (value) {
                              draft.fishTemperature = value;
                              onDraftChanged();
                            },
                    ),
                    _ParameterSlider(
                      label: '多样性 top_p',
                      value: draft.fishTopP,
                      minimum: 0,
                      maximum: 1,
                      divisions: 20,
                      onChanged: blocked
                          ? null
                          : (value) {
                              draft.fishTopP = value;
                              onDraftChanged();
                            },
                    ),
                    _ParameterSlider(
                      label: '音量（dB）',
                      value: draft.fishVolumeDb,
                      minimum: -20,
                      maximum: 20,
                      divisions: 40,
                      onChanged: blocked
                          ? null
                          : (value) {
                              draft.fishVolumeDb = value;
                              onDraftChanged();
                            },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('分块长度'),
                      subtitle: Slider(
                        value: draft.fishChunkLength.toDouble(),
                        min: 100,
                        max: 300,
                        divisions: 20,
                        label: '${draft.fishChunkLength}',
                        onChanged: blocked
                            ? null
                            : (value) {
                                draft.fishChunkLength = value.round();
                                onDraftChanged();
                              },
                      ),
                      trailing: Text('${draft.fishChunkLength}'),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('中英文文本规范化'),
                      value: draft.fishNormalize,
                      onChanged: blocked
                          ? null
                          : (value) {
                              draft.fishNormalize = value;
                              onDraftChanged();
                            },
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('响度规范化'),
                      value: draft.fishNormalizeLoudness,
                      onChanged: blocked
                          ? null
                          : (value) {
                              draft.fishNormalizeLoudness = value;
                              onDraftChanged();
                            },
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('质量保护（quality-guard）'),
                      subtitle: const Text('仅在当前模型支持该特性时开启'),
                      value: draft.fishQualityGuard,
                      onChanged: blocked
                          ? null
                          : (value) {
                              draft.fishQualityGuard = value;
                              onDraftChanged();
                            },
                    ),
                  ],
                ),
              ],
            ],
            const SizedBox(height: 12),
            TextField(
              key: ValueKey<String>('${kind.name}-api-key'),
              controller: draft.apiKey,
              obscureText: true,
              enableSuggestions: false,
              autocorrect: false,
              decoration: InputDecoration(
                labelText:
                    draft.hasSavedKey ? 'API Key（留空则保留原 Key）' : 'API Key',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                FilledButton(
                  key: ValueKey<String>('${kind.name}-save'),
                  onPressed: blocked ? null : onSave,
                  child: busy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('保存'),
                ),
                OutlinedButton(
                  onPressed: blocked ? null : onTest,
                  child: const Text('测试连接'),
                ),
                TextButton(
                  onPressed: blocked || !draft.hasSavedKey ? null : onClear,
                  child: const Text('删除凭据'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

final class _ParameterSlider extends StatelessWidget {
  const _ParameterSlider({
    required this.label,
    required this.value,
    required this.minimum,
    required this.maximum,
    required this.divisions,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double minimum;
  final double maximum;
  final int divisions;
  final ValueChanged<double>? onChanged;

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        subtitle: Slider(
          value: value,
          min: minimum,
          max: maximum,
          divisions: divisions,
          label: value.toStringAsFixed(2),
          onChanged: onChanged,
        ),
        trailing: Text(value.toStringAsFixed(2)),
      );
}

final class _ProviderDraft {
  _ProviderDraft({required String defaultModel, String? defaultVoice})
      : displayName = TextEditingController(text: 'OpenAI-compatible'),
        baseUrl = TextEditingController(text: 'https://api.openai.com/v1'),
        model = TextEditingController(text: defaultModel),
        voice = TextEditingController(text: defaultVoice),
        apiKey = TextEditingController();

  final TextEditingController displayName;
  final TextEditingController baseUrl;
  final TextEditingController model;
  final TextEditingController voice;
  final TextEditingController apiKey;
  String providerId = 'custom-provider';
  ByokAudioFormat audioFormat = ByokAudioFormat.mp3;
  FishAudioLatency fishLatency = FishAudioLatency.normal;
  double fishTemperature = 0.7;
  double fishTopP = 0.7;
  double fishVolumeDb = 0;
  int fishChunkLength = 300;
  bool fishNormalize = true;
  bool fishNormalizeLoudness = true;
  bool fishQualityGuard = false;
  String? _savedKey;
  AiStructuredOutputMode _structuredOutputMode =
      AiStructuredOutputMode.jsonObject;
  AiTokenLimitParameter _tokenLimitParameter = AiTokenLimitParameter.maxTokens;

  bool get hasSavedKey => _savedKey != null;
  bool get isFishAudio => providerId == FishAudioTtsPreset.providerId;

  void selectTtsProvider(String value) {
    if (value == providerId) return;
    providerId = value;
    _savedKey = null;
    apiKey.clear();
    if (isFishAudio) {
      displayName.text = FishAudioTtsPreset.displayName;
      baseUrl.text = FishAudioTtsPreset.baseUrl;
      model.text = FishAudioTtsPreset.defaultModel;
      voice.clear();
      _loadFishOptions(const FishAudioTtsOptions());
    } else {
      displayName.text = 'OpenAI-compatible';
      baseUrl.text = 'https://api.openai.com/v1';
      model.text = 'gpt-4o-mini-tts';
      voice.text = 'alloy';
    }
  }

  void loadAi(AiByokConfiguration? value) {
    if (value == null) return;
    displayName.text = value.displayName;
    baseUrl.text = value.baseUri.toString();
    model.text = value.model;
    _savedKey = value.apiKey.reveal();
    _structuredOutputMode = value.structuredOutputMode;
    _tokenLimitParameter = value.tokenLimitParameter;
  }

  void loadMedia(ByokMediaConfiguration? value) {
    if (value == null) return;
    providerId = value.providerId;
    displayName.text = value.displayName;
    baseUrl.text = value.baseUri.toString();
    model.text = value.model;
    voice.text = value.voice ?? '';
    audioFormat = value.audioFormat;
    if (value.providerId == FishAudioTtsPreset.providerId) {
      _loadFishOptions(value.effectiveFishAudioOptions);
    }
    _savedKey = value.apiKey.reveal();
  }

  AiByokConfiguration buildAi() => AiByokConfiguration(
        presetId: 'custom-provider',
        displayName: displayName.text.trim(),
        baseUri: Uri.parse(baseUrl.text.trim()),
        model: model.text.trim(),
        apiKey: OpaqueAiApiKey(_key()),
        structuredOutputMode: _structuredOutputMode,
        tokenLimitParameter: _tokenLimitParameter,
      );

  ByokMediaConfiguration buildMedia(_ProviderKind kind) {
    final isTts = kind == _ProviderKind.tts;
    final voiceValue = voice.text.trim();
    if (isTts && !isFishAudio && voiceValue.isEmpty) {
      throw ArgumentError('OpenAI-compatible TTS requires a voice');
    }
    return ByokMediaConfiguration(
      capability: isTts
          ? ByokMediaCapability.tts
          : ByokMediaCapability.podcastTranscription,
      providerId: isTts ? providerId : 'custom-provider',
      displayName: displayName.text.trim(),
      baseUri: Uri.parse(baseUrl.text.trim()),
      model: model.text.trim(),
      apiKey: OpaqueByokApiKey(_key()),
      voice: isTts && voiceValue.isNotEmpty ? voiceValue : null,
      audioFormat: isTts ? audioFormat : ByokAudioFormat.mp3,
      fishAudioOptions: isTts && isFishAudio
          ? FishAudioTtsOptions(
              temperature: fishTemperature,
              topP: fishTopP,
              volumeDb: fishVolumeDb,
              chunkLength: fishChunkLength,
              normalize: fishNormalize,
              normalizeLoudness: fishNormalizeLoudness,
              latency: fishLatency,
              qualityGuard: fishQualityGuard,
            )
          : null,
    );
  }

  void _loadFishOptions(FishAudioTtsOptions value) {
    fishTemperature = value.temperature;
    fishTopP = value.topP;
    fishVolumeDb = value.volumeDb;
    fishChunkLength = value.chunkLength;
    fishNormalize = value.normalize;
    fishNormalizeLoudness = value.normalizeLoudness;
    fishLatency = value.latency;
    fishQualityGuard = value.qualityGuard;
  }

  String _key() {
    final typed = apiKey.text;
    if (typed.isNotEmpty) return typed;
    final saved = _savedKey;
    if (saved == null) throw StateError('API key required');
    return saved;
  }

  void rememberKey(String value) {
    _savedKey = value;
    apiKey.clear();
  }

  void forgetKey() {
    _savedKey = null;
    apiKey.clear();
  }

  void dispose() {
    displayName.dispose();
    baseUrl.dispose();
    model.dispose();
    voice.dispose();
    apiKey.dispose();
  }
}
