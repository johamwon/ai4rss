import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:river_app/knowledge/notion_workspace.dart';
import 'package:river_knowledge/river_knowledge.dart';
import 'package:river_platform/river_platform.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('real platform secure storage round trips Notion tokens',
      (tester) async {
    final vault = PlatformSecureNotionAuthorizationVault.standard();
    final targetStore = SecureNotionTargetSelectionStore.standard();
    await vault.clear();
    await targetStore.clear();
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
      await targetStore.write('dataSource:integration-target');
      expect(await targetStore.read(), 'dataSource:integration-target');
    } finally {
      await vault.clear();
      await targetStore.clear();
    }
  });
}
