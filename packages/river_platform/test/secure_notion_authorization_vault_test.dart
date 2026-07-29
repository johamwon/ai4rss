import 'package:flutter_test/flutter_test.dart';
import 'package:river_knowledge/river_knowledge.dart';
import 'package:river_platform/river_platform.dart';

void main() {
  test('round trips Notion authorization without exposing token in toString',
      () async {
    final store = _Store();
    final vault = PlatformSecureNotionAuthorizationVault(store: store);
    final authorization = NotionAuthorization(
      accessToken: OpaqueNotionToken('access-token-value'),
      refreshToken: OpaqueNotionToken('refresh-token-value'),
      botId: 'bot-1',
      workspaceId: 'workspace-1',
      workspaceName: 'River Lab',
      workspaceIcon: Uri.parse('https://example.com/icon.png'),
    );

    await vault.write(authorization);
    final restored = await vault.read();

    expect(restored?.accessToken.reveal(), 'access-token-value');
    expect(restored?.refreshToken.reveal(), 'refresh-token-value');
    expect(restored?.workspaceName, 'River Lab');
    expect(
      authorization.accessToken.toString(),
      isNot(contains('access-token')),
    );
    await vault.clear();
    expect(await vault.read(), isNull);
  });

  test('rejects corrupt and future values without deleting them', () async {
    final store = _Store()
      ..values['river.notion.v1.authorization'] = '{"schema":2}';
    final vault = PlatformSecureNotionAuthorizationVault(store: store);

    await expectLater(
      vault.read(),
      throwsA(
        isA<SecureNotionVaultException>().having(
          (failure) => failure.code,
          'code',
          SecureNotionVaultFailureCode.unsupportedSchema,
        ),
      ),
    );
    expect(store.values, isNotEmpty);

    store.values['river.notion.v1.authorization'] = 'not-json';
    await expectLater(
      vault.read(),
      throwsA(
        isA<SecureNotionVaultException>().having(
          (failure) => failure.code,
          'code',
          SecureNotionVaultFailureCode.corruptValue,
        ),
      ),
    );
    expect(store.values, isNotEmpty);
  });
}

final class _Store implements SecureKeyValueStore {
  final Map<String, String> values = <String, String>{};

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}
