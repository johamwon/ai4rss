import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:river_ai/river_ai.dart';
import 'package:river_platform/river_platform.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('real platform secure storage round trips a BYOK profile',
      (tester) async {
    final vault = PlatformSecureAiByokConfigurationVault.standard();
    await vault.clear();
    final configuration =
        AiProviderPresetCatalog.standard().resolve('openai').configure(
              model: 'integration-model',
              apiKey: OpaqueAiApiKey('integration-ai-key'),
            );

    await vault.write(configuration);
    final restored = await vault.read();

    expect(restored?.presetId, 'openai');
    expect(restored?.model, 'integration-model');
    expect(restored?.apiKey.reveal(), 'integration-ai-key');
    expect(restored.toString(), isNot(contains('integration-ai-key')));

    await vault.clear();
    expect(await vault.read(), isNull);
  });
}
