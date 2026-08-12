import 'package:flutter_test/flutter_test.dart';
import 'package:river_byok/river_byok.dart';
import 'package:river_platform/river_platform.dart';

void main() {
  test('secure media vault isolates TTS and transcription profiles', () async {
    final store = _MemorySecureStore();
    final vault = PlatformSecureByokMediaConfigurationVault(store: store);
    await vault.write(_configuration(ByokMediaCapability.tts));
    await vault.write(_configuration(ByokMediaCapability.podcastTranscription));

    final tts = await vault.read(ByokMediaCapability.tts);
    final transcription =
        await vault.read(ByokMediaCapability.podcastTranscription);
    expect(tts?.voice, 'alloy');
    expect(transcription?.voice, isNull);
    expect(tts?.apiKey.reveal(), 'media-provider-secret');
    expect(tts.toString(), isNot(contains('media-provider-secret')));

    await vault.clear(ByokMediaCapability.tts);
    expect(await vault.read(ByokMediaCapability.tts), isNull);
    expect(
      await vault.read(ByokMediaCapability.podcastTranscription),
      isNotNull,
    );
  });

  test('corrupt media profile fails closed without deleting evidence',
      () async {
    final store = _MemorySecureStore();
    final vault = PlatformSecureByokMediaConfigurationVault(store: store);
    store.values['river.media.v1.byok.tts'] = '{"schema":99}';

    await expectLater(
      vault.read(ByokMediaCapability.tts),
      throwsA(
        isA<SecureByokMediaVaultException>().having(
          (failure) => failure.code,
          'code',
          SecureByokMediaVaultFailureCode.unsupportedSchema,
        ),
      ),
    );
    expect(store.values, isNotEmpty);
  });

  test('Fish Audio profile round-trips without requiring a voice ID', () async {
    final store = _MemorySecureStore();
    final vault = PlatformSecureByokMediaConfigurationVault(store: store);
    await vault.write(
      ByokMediaConfiguration(
        capability: ByokMediaCapability.tts,
        providerId: FishAudioTtsPreset.providerId,
        displayName: FishAudioTtsPreset.displayName,
        baseUri: Uri.parse(FishAudioTtsPreset.baseUrl),
        model: FishAudioTtsPreset.defaultModel,
        apiKey: OpaqueByokApiKey('fish-media-provider-secret'),
        audioFormat: ByokAudioFormat.opus,
        fishAudioOptions: const FishAudioTtsOptions(
          temperature: 0.5,
          latency: FishAudioLatency.balanced,
          opusBitrateBps: 32000,
        ),
      ),
    );

    final restored = await vault.read(ByokMediaCapability.tts);
    expect(restored?.providerId, FishAudioTtsPreset.providerId);
    expect(restored?.baseUri.toString(), FishAudioTtsPreset.baseUrl);
    expect(restored?.model, FishAudioTtsPreset.defaultModel);
    expect(restored?.voice, isNull);
    expect(restored?.audioFormat, ByokAudioFormat.opus);
    expect(restored?.effectiveFishAudioOptions.temperature, 0.5);
    expect(
      restored?.effectiveFishAudioOptions.latency,
      FishAudioLatency.balanced,
    );
    expect(restored?.effectiveFishAudioOptions.opusBitrateBps, 32000);
    expect(restored?.apiKey.reveal(), 'fish-media-provider-secret');
    expect(restored.toString(), isNot(contains('fish-media-provider-secret')));
  });

  test('legacy Fish Audio profile restores documented parameter defaults',
      () async {
    final store = _MemorySecureStore();
    store.values['river.media.v1.byok.tts'] =
        '{"schema":1,"capability":"tts","providerId":"fish-audio",'
        '"displayName":"Fish Audio","baseUri":"https://api.fish.audio",'
        '"model":"s2.1-pro","apiKey":"legacy-fish-secret",'
        '"authScheme":"bearer","voice":null,"audioFormat":"mp3"}';
    final restored = await PlatformSecureByokMediaConfigurationVault(
      store: store,
    ).read(ByokMediaCapability.tts);

    expect(restored?.fishAudioOptions, isNull);
    expect(restored?.effectiveFishAudioOptions.temperature, 0.7);
    expect(restored?.effectiveFishAudioOptions.chunkLength, 300);
    expect(
      restored?.effectiveFishAudioOptions.latency,
      FishAudioLatency.normal,
    );
  });
}

ByokMediaConfiguration _configuration(ByokMediaCapability capability) =>
    ByokMediaConfiguration(
      capability: capability,
      providerId: 'custom-provider',
      displayName: 'Custom',
      baseUri: Uri.parse('https://provider.example/v1'),
      model: 'media-model',
      apiKey: OpaqueByokApiKey('media-provider-secret'),
      voice: capability == ByokMediaCapability.tts ? 'alloy' : null,
    );

final class _MemorySecureStore implements SecureKeyValueStore {
  final Map<String, String> values = <String, String>{};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}
