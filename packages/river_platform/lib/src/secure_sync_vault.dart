import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:river_sync/river_sync.dart';

abstract interface class SecureKeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

final class FlutterSecureKeyValueStore implements SecureKeyValueStore {
  FlutterSecureKeyValueStore({
    FlutterSecureStorage storage = const FlutterSecureStorage(
      aOptions: AndroidOptions(
        storageNamespace: 'river_sync_v1',
        resetOnError: false,
      ),
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device,
        synchronizable: false,
      ),
    ),
  }) : _storage = storage;

  final FlutterSecureStorage _storage;

  @override
  Future<void> delete(String key) => _storage.delete(key: key);

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
}

enum SecureSyncVaultFailureCode { corruptValue, unsupportedSchema }

final class SecureSyncVaultException implements Exception {
  const SecureSyncVaultException(this.code);

  final SecureSyncVaultFailureCode code;

  @override
  String toString() => 'SecureSyncVaultException(${code.name})';
}

final class PlatformSecureSyncVault
    implements SyncSessionVault, SyncKeyMaterialVault {
  PlatformSecureSyncVault({required SecureKeyValueStore store})
      : _store = store;

  factory PlatformSecureSyncVault.standard() => PlatformSecureSyncVault(
        store: FlutterSecureKeyValueStore(),
      );

  static const _schemaVersion = 1;
  static const _sessionKey = 'river.sync.v1.session';
  static const _devicePrefix = 'river.sync.v1.device.';
  static const _dataPrefix = 'river.sync.v1.data.';

  final SecureKeyValueStore _store;
  Future<void> _tail = Future<void>.value();

  @override
  Future<SyncSession?> read() => _serialized(() async {
        final encoded = await _store.read(_sessionKey);
        if (encoded == null) return null;
        final value = _decodeObject(encoded);
        _requireSchema(value);
        try {
          return SyncSession(
            id: _string(value, 'id'),
            accountId: _string(value, 'accountId'),
            deviceId: _string(value, 'deviceId'),
            accessToken: OpaqueSyncToken(_string(value, 'accessToken')),
            refreshToken: OpaqueSyncToken(_string(value, 'refreshToken')),
            issuedAt: DateTime.parse(_string(value, 'issuedAt')).toUtc(),
            expiresAt: DateTime.parse(_string(value, 'expiresAt')).toUtc(),
            deviceStatus: SyncDeviceStatus.values.byName(
              _string(value, 'deviceStatus'),
            ),
          );
        } on Object {
          throw const SecureSyncVaultException(
            SecureSyncVaultFailureCode.corruptValue,
          );
        }
      });

  @override
  Future<void> write(SyncSession session) => _serialized(
        () => _store.write(
          _sessionKey,
          jsonEncode(<String, Object?>{
            'schema': _schemaVersion,
            'id': session.id,
            'accountId': session.accountId,
            'deviceId': session.deviceId,
            'accessToken': session.accessToken.reveal(),
            'refreshToken': session.refreshToken.reveal(),
            'issuedAt': session.issuedAt.toIso8601String(),
            'expiresAt': session.expiresAt.toIso8601String(),
            'deviceStatus': session.deviceStatus.name,
          }),
        ),
      );

  @override
  Future<void> clear() => _serialized(() => _store.delete(_sessionKey));

  @override
  Future<SyncDeviceKeyMaterial?> readDeviceKey(String keyId) =>
      _serialized(() async {
        final encoded = await _store.read(_key(_devicePrefix, keyId));
        if (encoded == null) return null;
        final value = _decodeObject(encoded);
        _requireSchema(value);
        try {
          final storedKeyId = _string(value, 'keyId');
          if (storedKeyId != keyId) {
            throw const SecureSyncVaultException(
              SecureSyncVaultFailureCode.corruptValue,
            );
          }
          return SyncDeviceKeyMaterial.fromBase64(
            keyId: storedKeyId,
            privateKeyBase64: _string(value, 'privateKey'),
            publicKeyBase64: _string(value, 'publicKey'),
          );
        } on Object {
          throw const SecureSyncVaultException(
            SecureSyncVaultFailureCode.corruptValue,
          );
        }
      });

  @override
  Future<void> writeDeviceKey(SyncDeviceKeyMaterial material) => _serialized(
        () => _store.write(
          _key(_devicePrefix, material.keyId),
          jsonEncode(<String, Object?>{
            'schema': _schemaVersion,
            'keyId': material.keyId,
            'privateKey': material.exportPrivateKeyBase64(),
            'publicKey': material.publicKeyBase64,
          }),
        ),
      );

  @override
  Future<void> deleteDeviceKey(String keyId) =>
      _serialized(() => _store.delete(_key(_devicePrefix, keyId)));

  @override
  Future<SyncDataKeyMaterial?> readDataKey(String keyId) =>
      _serialized(() async {
        final encoded = await _store.read(_key(_dataPrefix, keyId));
        if (encoded == null) return null;
        final value = _decodeObject(encoded);
        _requireSchema(value);
        try {
          final retired = value['retiredAt'];
          final storedKeyId = _string(value, 'keyId');
          if (storedKeyId != keyId) {
            throw const SecureSyncVaultException(
              SecureSyncVaultFailureCode.corruptValue,
            );
          }
          final descriptor = SyncDataKeyDescriptor(
            id: storedKeyId,
            accountId: _string(value, 'accountId'),
            version: _integer(value, 'version'),
            createdAt: DateTime.parse(_string(value, 'createdAt')).toUtc(),
            algorithm: SyncDataKeyAlgorithm.values.byName(
              _string(value, 'algorithm'),
            ),
            retiredAt: retired == null
                ? null
                : DateTime.parse(retired as String).toUtc(),
          );
          return SyncDataKeyMaterial.fromBase64(
            descriptor: descriptor,
            keyBase64: _string(value, 'key'),
          );
        } on Object {
          throw const SecureSyncVaultException(
            SecureSyncVaultFailureCode.corruptValue,
          );
        }
      });

  @override
  Future<void> writeDataKey(SyncDataKeyMaterial material) => _serialized(
        () => _store.write(
          _key(_dataPrefix, material.descriptor.id),
          jsonEncode(<String, Object?>{
            'schema': _schemaVersion,
            'keyId': material.descriptor.id,
            'accountId': material.descriptor.accountId,
            'version': material.descriptor.version,
            'createdAt': material.descriptor.createdAt.toIso8601String(),
            'retiredAt': material.descriptor.retiredAt?.toIso8601String(),
            'algorithm': material.descriptor.algorithm.name,
            'key': material.exportKeyBase64(),
          }),
        ),
      );

  @override
  Future<void> deleteDataKey(String keyId) =>
      _serialized(() => _store.delete(_key(_dataPrefix, keyId)));

  Future<T> _serialized<T>(Future<T> Function() operation) {
    final result = _tail.then<T>((_) => operation());
    _tail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return result;
  }

  static Map<String, Object?> _decodeObject(String encoded) {
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map<String, Object?>) {
        throw const FormatException('Not an object.');
      }
      return decoded;
    } on Object {
      throw const SecureSyncVaultException(
        SecureSyncVaultFailureCode.corruptValue,
      );
    }
  }

  static void _requireSchema(Map<String, Object?> value) {
    if (value['schema'] != _schemaVersion) {
      throw const SecureSyncVaultException(
        SecureSyncVaultFailureCode.unsupportedSchema,
      );
    }
  }

  static String _string(Map<String, Object?> value, String key) {
    final field = value[key];
    if (field is! String || field.isEmpty) {
      throw const SecureSyncVaultException(
        SecureSyncVaultFailureCode.corruptValue,
      );
    }
    return field;
  }

  static int _integer(Map<String, Object?> value, String key) {
    final field = value[key];
    if (field is! int) {
      throw const SecureSyncVaultException(
        SecureSyncVaultFailureCode.corruptValue,
      );
    }
    return field;
  }

  static String _key(String prefix, String id) {
    if (id.isEmpty || id.trim() != id || id.length > 256) {
      throw ArgumentError.value(id, 'id', 'Invalid secure-storage key id.');
    }
    return '$prefix${base64Url.encode(utf8.encode(id)).replaceAll('=', '')}';
  }
}
