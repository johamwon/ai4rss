import 'dart:async';
import 'dart:convert';

import 'package:river_ai/river_ai.dart';

import 'secure_sync_vault.dart';

enum SecureAiByokVaultFailureCode { corruptValue, unsupportedSchema }

final class SecureAiByokVaultException implements Exception {
  const SecureAiByokVaultException(this.code);

  final SecureAiByokVaultFailureCode code;

  @override
  String toString() => 'SecureAiByokVaultException(${code.name})';
}

final class PlatformSecureAiByokConfigurationVault
    implements AiByokConfigurationVault {
  PlatformSecureAiByokConfigurationVault({
    required SecureKeyValueStore store,
  }) : _store = store;

  factory PlatformSecureAiByokConfigurationVault.standard() =>
      PlatformSecureAiByokConfigurationVault(
        store: FlutterSecureKeyValueStore(),
      );

  static const _schemaVersion = 1;
  static const _storageKey = 'river.ai.v1.byok';

  final SecureKeyValueStore _store;
  Future<void> _tail = Future<void>.value();

  @override
  Future<AiByokConfiguration?> read() => _serialized(() async {
        final encoded = await _store.read(_storageKey);
        if (encoded == null) return null;
        final value = _decode(encoded);
        if (value['schema'] != _schemaVersion) {
          throw const SecureAiByokVaultException(
            SecureAiByokVaultFailureCode.unsupportedSchema,
          );
        }
        try {
          return AiByokConfiguration(
            presetId: _string(value, 'presetId'),
            displayName: _string(value, 'displayName'),
            baseUri: Uri.parse(_string(value, 'baseUri')),
            model: _string(value, 'model'),
            apiKey: OpaqueAiApiKey(_string(value, 'apiKey')),
            structuredOutputMode: AiStructuredOutputMode.values.byName(
              _string(value, 'structuredOutputMode'),
            ),
            tokenLimitParameter: AiTokenLimitParameter.values.byName(
              _string(value, 'tokenLimitParameter'),
            ),
          );
        } on SecureAiByokVaultException {
          rethrow;
        } on Object {
          throw const SecureAiByokVaultException(
            SecureAiByokVaultFailureCode.corruptValue,
          );
        }
      });

  @override
  Future<void> write(AiByokConfiguration configuration) => _serialized(
        () => _store.write(
          _storageKey,
          jsonEncode(<String, Object?>{
            'schema': _schemaVersion,
            'presetId': configuration.presetId,
            'displayName': configuration.displayName,
            'baseUri': configuration.baseUri.toString(),
            'model': configuration.model,
            'apiKey': configuration.apiKey.reveal(),
            'structuredOutputMode': configuration.structuredOutputMode.name,
            'tokenLimitParameter': configuration.tokenLimitParameter.name,
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
      throw const SecureAiByokVaultException(
        SecureAiByokVaultFailureCode.corruptValue,
      );
    }
  }

  static String _string(Map<String, Object?> value, String key) {
    final field = value[key];
    if (field is! String || field.isEmpty) {
      throw const SecureAiByokVaultException(
        SecureAiByokVaultFailureCode.corruptValue,
      );
    }
    return field;
  }
}
