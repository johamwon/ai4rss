enum ByokMediaCapability { tts, podcastTranscription }

enum ByokAuthScheme { bearer, xApiKey }

enum ByokAudioFormat { mp3, wav, opus, aac, flac }

enum FishAudioLatency { normal, balanced, low }

final class FishAudioTtsOptions {
  const FishAudioTtsOptions({
    this.temperature = 0.7,
    this.topP = 0.7,
    this.volumeDb = 0,
    this.chunkLength = 300,
    this.normalize = true,
    this.normalizeLoudness = true,
    this.latency = FishAudioLatency.normal,
    this.mp3BitrateKbps = 128,
    this.opusBitrateBps = -1000,
    this.qualityGuard = false,
  });

  factory FishAudioTtsOptions.fromJson(Map<String, Object?> value) =>
      FishAudioTtsOptions(
        temperature: _number(value, 'temperature'),
        topP: _number(value, 'topP'),
        volumeDb: _number(value, 'volumeDb'),
        chunkLength: _integer(value, 'chunkLength'),
        normalize: _boolean(value, 'normalize'),
        normalizeLoudness: _boolean(value, 'normalizeLoudness'),
        latency: FishAudioLatency.values.byName(_jsonString(value, 'latency')),
        mp3BitrateKbps: _integer(value, 'mp3BitrateKbps'),
        opusBitrateBps: _integer(value, 'opusBitrateBps'),
        qualityGuard: _boolean(value, 'qualityGuard'),
      );

  final double temperature;
  final double topP;
  final double volumeDb;
  final int chunkLength;
  final bool normalize;
  final bool normalizeLoudness;
  final FishAudioLatency latency;
  final int mp3BitrateKbps;
  final int opusBitrateBps;
  final bool qualityGuard;

  Map<String, Object?> toJson() => <String, Object?>{
        'temperature': temperature,
        'topP': topP,
        'volumeDb': volumeDb,
        'chunkLength': chunkLength,
        'normalize': normalize,
        'normalizeLoudness': normalizeLoudness,
        'latency': latency.name,
        'mp3BitrateKbps': mp3BitrateKbps,
        'opusBitrateBps': opusBitrateBps,
        'qualityGuard': qualityGuard,
      };
}

abstract final class FishAudioTtsPreset {
  static const providerId = 'fish-audio';
  static const displayName = 'Fish Audio';
  static const baseUrl = 'https://api.fish.audio';
  static const defaultModel = 's2.1-pro';
  static const developerModel = 's2.1-pro-free';
  static const supportedModels = <String>[
    defaultModel,
    developerModel,
    's2-pro',
    's1',
  ];

  static bool supportsModel(String model) => supportedModels.contains(model);
}

final class OpaqueByokApiKey {
  OpaqueByokApiKey(String value) : _value = value {
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
  String toString() => 'OpaqueByokApiKey(<redacted>)';
}

final class ByokMediaConfiguration {
  ByokMediaConfiguration({
    required this.capability,
    required this.providerId,
    required this.displayName,
    required this.baseUri,
    required this.model,
    required this.apiKey,
    this.authScheme = ByokAuthScheme.bearer,
    this.voice,
    this.audioFormat = ByokAudioFormat.mp3,
    this.fishAudioOptions,
  }) {
    if (!RegExp(r'^[a-z][a-z0-9-]{1,63}$').hasMatch(providerId)) {
      throw ArgumentError.value(providerId, 'providerId');
    }
    _requireLabel(displayName, 'displayName', 128);
    _requireLabel(model, 'model', 200);
    if (voice != null) _requireLabel(voice!, 'voice', 200);
    _requireBaseUri(baseUri);
    if (providerId == FishAudioTtsPreset.providerId &&
        (capability != ByokMediaCapability.tts ||
            baseUri.toString() != FishAudioTtsPreset.baseUrl ||
            authScheme != ByokAuthScheme.bearer ||
            !FishAudioTtsPreset.supportsModel(model) ||
            !const <ByokAudioFormat>{
              ByokAudioFormat.mp3,
              ByokAudioFormat.wav,
              ByokAudioFormat.opus,
            }.contains(audioFormat))) {
      throw ArgumentError('Invalid Fish Audio TTS profile');
    }
    if (providerId != FishAudioTtsPreset.providerId &&
        fishAudioOptions != null) {
      throw ArgumentError('Fish Audio options require a Fish Audio profile');
    }
    if (providerId == FishAudioTtsPreset.providerId) {
      _validateFishOptions(effectiveFishAudioOptions);
    }
    if (capability == ByokMediaCapability.podcastTranscription &&
        voice != null) {
      throw ArgumentError('Transcription configuration cannot declare voice');
    }
  }

  final ByokMediaCapability capability;
  final String providerId;
  final String displayName;
  final Uri baseUri;
  final String model;
  final OpaqueByokApiKey apiKey;
  final ByokAuthScheme authScheme;
  final String? voice;
  final ByokAudioFormat audioFormat;
  final FishAudioTtsOptions? fishAudioOptions;

  FishAudioTtsOptions get effectiveFishAudioOptions =>
      fishAudioOptions ?? const FishAudioTtsOptions();

  Uri get modelsUri => _append('models');
  Uri get speechUri => _append('audio/speech');
  Uri get transcriptionsUri => _append('audio/transcriptions');
  Uri get fishAudioSpeechUri => _append('v1/tts');
  Uri get fishAudioCreditUri => _append('wallet/self/api-credit');

  Map<String, String> authorizationHeaders() => switch (authScheme) {
        ByokAuthScheme.bearer => <String, String>{
            'authorization': 'Bearer ${apiKey.reveal()}',
          },
        ByokAuthScheme.xApiKey => <String, String>{
            'x-api-key': apiKey.reveal(),
          },
      };

  Uri _append(String suffix) {
    final base = baseUri.toString().replaceFirst(RegExp(r'/+$'), '');
    return Uri.parse('$base/$suffix');
  }

  @override
  String toString() => 'ByokMediaConfiguration('
      'capability: ${capability.name}, providerId: $providerId, '
      'model: $model, voiceConfigured: ${voice != null}, '
      'audioFormat: ${audioFormat.name}, '
      'fishOptionsConfigured: ${fishAudioOptions != null}, '
      'apiKey: <redacted>)';
}

double _number(Map<String, Object?> value, String key) {
  final field = value[key];
  if (field is! num || !field.isFinite) throw const FormatException();
  return field.toDouble();
}

int _integer(Map<String, Object?> value, String key) {
  final field = value[key];
  if (field is! int) throw const FormatException();
  return field;
}

bool _boolean(Map<String, Object?> value, String key) {
  final field = value[key];
  if (field is! bool) throw const FormatException();
  return field;
}

String _jsonString(Map<String, Object?> value, String key) {
  final field = value[key];
  if (field is! String || field.isEmpty) throw const FormatException();
  return field;
}

void _validateFishOptions(FishAudioTtsOptions value) {
  if (!value.temperature.isFinite ||
      value.temperature < 0 ||
      value.temperature > 1 ||
      !value.topP.isFinite ||
      value.topP < 0 ||
      value.topP > 1 ||
      !value.volumeDb.isFinite ||
      value.volumeDb < -20 ||
      value.volumeDb > 20 ||
      value.chunkLength < 100 ||
      value.chunkLength > 300 ||
      !const <int>{64, 128, 192}.contains(value.mp3BitrateKbps) ||
      !const <int>{-1000, 24000, 32000, 48000, 64000}
          .contains(value.opusBitrateBps)) {
    throw ArgumentError('Invalid Fish Audio parameter profile');
  }
}

abstract interface class ByokMediaConfigurationVault {
  Future<ByokMediaConfiguration?> read(ByokMediaCapability capability);
  Future<void> write(ByokMediaConfiguration configuration);
  Future<void> clear(ByokMediaCapability capability);
}

void _requireLabel(String value, String name, int maximumLength) {
  if (value.trim() != value || value.isEmpty || value.length > maximumLength) {
    throw ArgumentError.value(value, name);
  }
}

void _requireBaseUri(Uri value) {
  if (value.scheme != 'https' ||
      value.host.isEmpty ||
      value.userInfo.isNotEmpty ||
      value.hasQuery ||
      value.hasFragment ||
      value.port != 443) {
    throw ArgumentError.value(value, 'baseUri');
  }
}
