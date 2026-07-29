import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:river_knowledge/river_knowledge.dart';
import 'package:river_platform/river_platform.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('real platform secure storage round trips Notion tokens',
      (tester) async {
    final vault = PlatformSecureNotionAuthorizationVault.standard();
    await vault.clear();
    final authorization = NotionAuthorization(
      accessToken: OpaqueNotionToken('integration-notion-access'),
      refreshToken: OpaqueNotionToken('integration-notion-refresh'),
      botId: 'integration-notion-bot',
      workspaceId: 'integration-notion-workspace',
      workspaceName: 'River Integration',
    );

    try {
      await vault.write(authorization);
      final restored = await vault.read();
      expect(restored?.botId, authorization.botId);
      expect(
        restored?.accessToken.reveal(),
        authorization.accessToken.reveal(),
      );
      expect(
        restored?.refreshToken.reveal(),
        authorization.refreshToken.reveal(),
      );
    } finally {
      await vault.clear();
    }
  });
}
