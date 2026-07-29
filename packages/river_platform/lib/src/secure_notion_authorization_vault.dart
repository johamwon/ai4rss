import 'dart:async';
import 'dart:convert';

import 'package:river_knowledge/river_knowledge.dart';

import 'secure_sync_vault.dart';

enum SecureNotionVaultFailureCode { corruptValue, unsupportedSchema }

final class SecureNotionVaultException implements Exception {
  const SecureNotionVaultException(this.code);

  final SecureNotionVaultFailureCode code;

  @override
  String toString() => 'SecureNotionVaultException(${code.name})';
}

final class PlatformSecureNotionAuthorizationVault
    implements NotionAuthorizationVault {
  PlatformSecureNotionAuthorizationVault({
    required SecureKeyValueStore store,
  }) : _store = store;

  factory PlatformSecureNotionAuthorizationVault.standard() =>
      PlatformSecureNotionAuthorizationVault(
        store: FlutterSecureKeyValueStore(),
      );

  static const _schemaVersion = 1;
  static const _storageKey = 'river.notion.v1.authorization';

  final SecureKeyValueStore _store;
  Future<void> _tail = Future<void>.value();

  @override
  Future<NotionAuthorization?> read() => _serialized(() async {
        final encoded = await _store.read(_storageKey);
        if (encoded == null) return null;
        final value = _decode(encoded);
        if (value['schema'] != _schemaVersion) {
          throw const SecureNotionVaultException(
            SecureNotionVaultFailureCode.unsupportedSchema,
          );
        }
        try {
          final icon = value['workspaceIcon'];
          return NotionAuthorization(
            accessToken: OpaqueNotionToken(_string(value, 'accessToken')),
            refreshToken: OpaqueNotionToken(_string(value, 'refreshToken')),
            botId: _string(value, 'botId'),
            workspaceId: _string(value, 'workspaceId'),
            workspaceName: _string(value, 'workspaceName'),
            workspaceIcon: icon == null ? null : Uri.parse(icon as String),
          );
        } on SecureNotionVaultException {
          rethrow;
        } on Object {
          throw const SecureNotionVaultException(
            SecureNotionVaultFailureCode.corruptValue,
          );
        }
      });

  @override
  Future<void> write(NotionAuthorization authorization) => _serialized(
        () => _store.write(
          _storageKey,
          jsonEncode(<String, Object?>{
            'schema': _schemaVersion,
            'accessToken': authorization.accessToken.reveal(),
            'refreshToken': authorization.refreshToken.reveal(),
            'botId': authorization.botId,
            'workspaceId': authorization.workspaceId,
            'workspaceName': authorization.workspaceName,
            'workspaceIcon': authorization.workspaceIcon?.toString(),
          }),
        ),
      );

  @override
  Future<void> clear() => _serialized(() => _store.delete(_storageKey));

  Future<T> _serialized<T>(Future<T> Function() operation) {
    final result = _tail.then<T>((_) => operation());
    _tail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return result;
  }

  static Map<String, Object?> _decode(String encoded) {
    try {
      final value = jsonDecode(encoded);
      if (value is! Map) throw const FormatException();
      return Map<String, Object?>.from(value);
    } on Object {
      throw const SecureNotionVaultException(
        SecureNotionVaultFailureCode.corruptValue,
      );
    }
  }

  static String _string(Map<String, Object?> value, String key) {
    final field = value[key];
    if (field is! String || field.isEmpty) {
      throw const SecureNotionVaultException(
        SecureNotionVaultFailureCode.corruptValue,
      );
    }
    return field;
  }
}
