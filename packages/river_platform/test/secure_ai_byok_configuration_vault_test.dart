import 'package:flutter_test/flutter_test.dart';
import 'package:river_ai/river_ai.dart';
import 'package:river_platform/river_platform.dart';

void main() {
  test('secure AI vault round trips and clears a complete BYOK profile',
      () async {
    final store = _MemorySecureStore();
    final vault = PlatformSecureAiByokConfigurationVault(store: store);
    final configuration = _configuration();

    await vault.write(configuration);
    final restored = await vault.read();

    expect(restored?.presetId, 'openai');
    expect(restored?.baseUri, Uri.parse('https://api.openai.com/v1'));
    expect(restored?.model, 'test-model');
    expect(restored?.apiKey.reveal(), 'integration-test-secret');
    expect(
      restored?.structuredOutputMode,
      AiStructuredOutputMode.jsonSchema,
    );
    expect(
      restored?.tokenLimitParameter,
      AiTokenLimitParameter.maxCompletionTokens,
    );
    expect(store.values.values.single, contains('integration-test-secret'));
    expect(restored.toString(), isNot(contains('integration-test-secret')));

    await vault.clear();
    expect(await vault.read(), isNull);
  });

  test('unsupported schema and corrupt values fail without silent deletion',
      () async {
    final store = _MemorySecureStore();
    final vault = PlatformSecureAiByokConfigurationVault(store: store);

    store.values['river.ai.v1.byok'] = '{"schema":99}';
    await expectLater(
      vault.read(),
      throwsA(
        isA<SecureAiByokVaultException>().having(
          (failure) => failure.code,
          'code',
          SecureAiByokVaultFailureCode.unsupportedSchema,
        ),
      ),
    );
    expect(store.values, isNotEmpty);

    store.values['river.ai.v1.byok'] = '{"schema":1,"apiKey":7}';
    await expectLater(
      vault.read(),
      throwsA(
        isA<SecureAiByokVaultException>().having(
          (failure) => failure.code,
          'code',
          SecureAiByokVaultFailureCode.corruptValue,
        ),
      ),
    );
    expect(store.values, isNotEmpty);
  });

  test('plugin operations remain serialized after a failed read', () async {
    final store = _MemorySecureStore(delay: const Duration(milliseconds: 5));
    final vault = PlatformSecureAiByokConfigurationVault(store: store);
    store.values['river.ai.v1.byok'] = '{"schema":99}';

    await expectLater(vault.read(), throwsA(isA<SecureAiByokVaultException>()));
    await vault.write(_configuration());
    expect((await vault.read())?.model, 'test-model');
    expect(store.maxActive, 1);
  });
}

AiByokConfiguration _configuration() =>
    AiProviderPresetCatalog.standard().resolve('openai').configure(
          model: 'test-model',
          apiKey: OpaqueAiApiKey('integration-test-secret'),
        );

final class _MemorySecureStore implements SecureKeyValueStore {
  _MemorySecureStore({this.delay = Duration.zero});

  final Duration delay;
  final Map<String, String> values = <String, String>{};
  int active = 0;
  int maxActive = 0;

  @override
  Future<void> delete(String key) => _run(() => values.remove(key));

  @override
  Future<String?> read(String key) => _run(() => values[key]);

  @override
  Future<void> write(String key, String value) =>
      _run(() => values[key] = value);

  Future<T> _run<T>(T Function() operation) async {
    active += 1;
    if (active > maxActive) maxActive = active;
    try {
      if (delay > Duration.zero) await Future<void>.delayed(delay);
      return operation();
    } finally {
      active -= 1;
    }
  }
}
