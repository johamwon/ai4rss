import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:river_byok/river_byok.dart';
import 'package:river_platform/river_platform.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('real platform secure storage isolates media BYOK profiles',
      (tester) async {
    final vault = PlatformSecureByokMediaConfigurationVault.standard();
    await vault.clear(ByokMediaCapability.tts);
    await vault.clear(ByokMediaCapability.podcastTranscription);
    final configuration = ByokMediaConfiguration(
      capability: ByokMediaCapability.tts,
      providerId: 'integration-provider',
      displayName: 'Integration Provider',
      baseUri: Uri.parse('https://provider.example/v1'),
      model: 'integration-tts-model',
      apiKey: OpaqueByokApiKey('integration-media-key'),
      voice: 'alloy',
    );

    await vault.write(configuration);
    final restored = await vault.read(ByokMediaCapability.tts);

    expect(restored?.model, 'integration-tts-model');
    expect(restored?.apiKey.reveal(), 'integration-media-key');
    expect(restored.toString(), isNot(contains('integration-media-key')));
    expect(
      await vault.read(ByokMediaCapability.podcastTranscription),
      isNull,
    );

    await vault.clear(ByokMediaCapability.tts);
    expect(await vault.read(ByokMediaCapability.tts), isNull);
  });
}
