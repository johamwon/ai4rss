enum ByokMediaCapability { tts, podcastTranscription }

enum ByokAuthScheme { bearer, xApiKey }

enum ByokAudioFormat { mp3, wav, opus, aac, flac }

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
  }) {
    if (!RegExp(r'^[a-z][a-z0-9-]{1,63}$').hasMatch(providerId)) {
      throw ArgumentError.value(providerId, 'providerId');
    }
    _requireLabel(displayName, 'displayName', 128);
    _requireLabel(model, 'model', 200);
    if (voice != null) _requireLabel(voice!, 'voice', 200);
    _requireBaseUri(baseUri);
    if (capability == ByokMediaCapability.tts && voice == null) {
      throw ArgumentError('TTS configuration requires a voice');
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

  Uri get modelsUri => _append('models');
  Uri get speechUri => _append('audio/speech');
  Uri get transcriptionsUri => _append('audio/transcriptions');

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
      'audioFormat: ${audioFormat.name}, apiKey: <redacted>)';
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
