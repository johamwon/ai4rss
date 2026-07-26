import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:river_platform/river_platform.dart';
import 'package:river_sync/river_sync.dart';

void main() {
  test('secure vault round trips redacted session and clears only session',
      () async {
    final store = _MemorySecureStore();
    final vault = PlatformSecureSyncVault(store: store);
    final session = _session();
    final dataKey = _dataKey();
    await vault.write(session);
    await vault.writeDataKey(dataKey);

    final restored = await vault.read();
    await vault.clear();

    expect(restored?.id, session.id);
    expect(restored?.accessToken.reveal(), 'access-secret');
    expect(restored.toString(), isNot(contains('access-secret')));
    expect(await vault.read(), isNull);
    expect(await vault.readDataKey(dataKey.descriptor.id), isNotNull);
  });

  test('device and data keys round trip without ordinary public state',
      () async {
    final store = _MemorySecureStore();
    final vault = PlatformSecureSyncVault(store: store);
    final deviceKey = SyncDeviceKeyMaterial(
      keyId: 'device-key-a',
      privateKeyBytes: List<int>.filled(32, 11),
      publicKeyBytes: List<int>.filled(32, 12),
    );
    final dataKey = _dataKey();

    await vault.writeDeviceKey(deviceKey);
    await vault.writeDataKey(dataKey);
    final restoredDevice = await vault.readDeviceKey(deviceKey.keyId);
    final restoredData = await vault.readDataKey(dataKey.descriptor.id);

    expect(
      restoredDevice?.exportPrivateKeyBase64(),
      deviceKey.exportPrivateKeyBase64(),
    );
    expect(restoredData?.exportKeyBase64(), dataKey.exportKeyBase64());
    expect(store.values.values.join(), isNot(contains('article body')));
  });

  test('unsupported schema and corrupt values fail without deletion', () async {
    final store = _MemorySecureStore();
    final vault = PlatformSecureSyncVault(store: store);
    store.values['river.sync.v1.session'] = '{"schema":99}';

    await expectLater(
      vault.read(),
      throwsA(
        isA<SecureSyncVaultException>().having(
          (error) => error.code,
          'code',
          SecureSyncVaultFailureCode.unsupportedSchema,
        ),
      ),
    );
    expect(store.values, contains('river.sync.v1.session'));

    store.values['river.sync.v1.session'] = 'not-json';
    await expectLater(
      vault.read(),
      throwsA(
        isA<SecureSyncVaultException>().having(
          (error) => error.code,
          'code',
          SecureSyncVaultFailureCode.corruptValue,
        ),
      ),
    );
  });

  test('all plugin operations are serialized after success and failure',
      () async {
    final store = _MemorySecureStore(delay: const Duration(milliseconds: 5));
    final vault = PlatformSecureSyncVault(store: store);
    final first = vault.write(_session());
    final second = vault.writeDataKey(_dataKey());
    final third = vault.read();

    await Future.wait<Object?>(<Future<Object?>>[first, second, third]);

    expect(store.maximumConcurrent, 1);
  });

  test('stored key identifier must match the requested secure-storage slot',
      () async {
    final store = _MemorySecureStore();
    final vault = PlatformSecureSyncVault(store: store);
    final material = SyncDeviceKeyMaterial(
      keyId: 'device-key-a',
      privateKeyBytes: List<int>.filled(32, 1),
      publicKeyBytes: List<int>.filled(32, 2),
    );
    await vault.writeDeviceKey(material);
    final storageKey = store.values.keys.single;
    final record =
        Map<String, Object?>.from(jsonDecode(store.values[storageKey]!) as Map);
    record['keyId'] = 'device-key-b';
    store.values[storageKey] = jsonEncode(record);

    await expectLater(
      vault.readDeviceKey(material.keyId),
      throwsA(
        isA<SecureSyncVaultException>().having(
          (error) => error.code,
          'code',
          SecureSyncVaultFailureCode.corruptValue,
        ),
      ),
    );
    expect(store.values, contains(storageKey));
  });

  test('key identifiers are encoded before reaching platform storage',
      () async {
    final store = _MemorySecureStore();
    final vault = PlatformSecureSyncVault(store: store);
    final material = SyncDeviceKeyMaterial(
      keyId: 'key/with?separators',
      privateKeyBytes: List<int>.filled(32, 1),
      publicKeyBytes: List<int>.filled(32, 2),
    );

    await vault.writeDeviceKey(material);

    final storageKey = store.values.keys.single;
    expect(storageKey, isNot(contains('/')));
    expect(storageKey, isNot(contains('?')));
  });
}

SyncSession _session() => SyncSession(
      id: 'session-1',
      accountId: 'account-1',
      deviceId: 'device-a',
      accessToken: OpaqueSyncToken('access-secret'),
      refreshToken: OpaqueSyncToken('refresh-secret'),
      issuedAt: DateTime.utc(2026, 7, 27),
      expiresAt: DateTime.utc(2026, 7, 27, 1),
      deviceStatus: SyncDeviceStatus.active,
    );

SyncDataKeyMaterial _dataKey() => SyncDataKeyMaterial(
      descriptor: SyncDataKeyDescriptor(
        id: 'data-key-1',
        accountId: 'account-1',
        version: 1,
        createdAt: DateTime.utc(2026, 7, 27),
      ),
      keyBytes: List<int>.filled(32, 13),
    );

final class _MemorySecureStore implements SecureKeyValueStore {
  _MemorySecureStore({this.delay = Duration.zero});

  final Duration delay;
  final Map<String, String> values = <String, String>{};
  var concurrent = 0;
  var maximumConcurrent = 0;

  @override
  Future<void> delete(String key) => _run(() {
        values.remove(key);
      });

  @override
  Future<String?> read(String key) => _run(() => values[key]);

  @override
  Future<void> write(String key, String value) => _run(() {
        values[key] = value;
      });

  Future<T> _run<T>(T Function() operation) async {
    concurrent += 1;
    if (concurrent > maximumConcurrent) maximumConcurrent = concurrent;
    try {
      if (delay > Duration.zero) await Future<void>.delayed(delay);
      return operation();
    } finally {
      concurrent -= 1;
    }
  }
}
