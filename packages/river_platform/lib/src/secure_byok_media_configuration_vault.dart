import 'dart:async';
import 'dart:convert';

import 'package:river_byok/river_byok.dart';

import 'secure_sync_vault.dart';

enum SecureByokMediaVaultFailureCode { corruptValue, unsupportedSchema }

final class SecureByokMediaVaultException implements Exception {
  const SecureByokMediaVaultException(this.code);

  final SecureByokMediaVaultFailureCode code;

  @override
  String toString() => 'SecureByokMediaVaultException(${code.name})';
}

final class PlatformSecureByokMediaConfigurationVault
    implements ByokMediaConfigurationVault {
  PlatformSecureByokMediaConfigurationVault({
    required SecureKeyValueStore store,
  }) : _store = store;

  factory PlatformSecureByokMediaConfigurationVault.standard() =>
      PlatformSecureByokMediaConfigurationVault(
        store: FlutterSecureKeyValueStore(),
      );

  static const _schemaVersion = 1;
  static const _storagePrefix = 'river.media.v1.byok';

  final SecureKeyValueStore _store;
  Future<void> _tail = Future<void>.value();

  @override
  Future<ByokMediaConfiguration?> read(ByokMediaCapability capability) =>
      _serialized(() async {
        final encoded = await _store.read(_key(capability));
        if (encoded == null) return null;
        final value = _decode(encoded);
        if (value['schema'] != _schemaVersion) {
          throw const SecureByokMediaVaultException(
            SecureByokMediaVaultFailureCode.unsupportedSchema,
          );
        }
        try {
          final restoredCapability = ByokMediaCapability.values.byName(
            _string(value, 'capability'),
          );
          if (restoredCapability != capability) throw const FormatException();
          return ByokMediaConfiguration(
            capability: restoredCapability,
            providerId: _string(value, 'providerId'),
            displayName: _string(value, 'displayName'),
            baseUri: Uri.parse(_string(value, 'baseUri')),
            model: _string(value, 'model'),
            apiKey: OpaqueByokApiKey(_string(value, 'apiKey')),
            authScheme: ByokAuthScheme.values.byName(
              _string(value, 'authScheme'),
            ),
            voice: value['voice'] as String?,
            audioFormat: ByokAudioFormat.values.byName(
              _string(value, 'audioFormat'),
            ),
            fishAudioOptions: _fishOptions(value['fishAudioOptions']),
          );
        } on SecureByokMediaVaultException {
          rethrow;
        } on Object {
          throw const SecureByokMediaVaultException(
            SecureByokMediaVaultFailureCode.corruptValue,
          );
        }
      });

  @override
  Future<void> write(ByokMediaConfiguration configuration) => _serialized(
        () => _store.write(
          _key(configuration.capability),
          jsonEncode(<String, Object?>{
            'schema': _schemaVersion,
            'capability': configuration.capability.name,
            'providerId': configuration.providerId,
            'displayName': configuration.displayName,
            'baseUri': configuration.baseUri.toString(),
            'model': configuration.model,
            'apiKey': configuration.apiKey.reveal(),
            'authScheme': configuration.authScheme.name,
            'voice': configuration.voice,
            'audioFormat': configuration.audioFormat.name,
            if (configuration.fishAudioOptions case final options?)
              'fishAudioOptions': options.toJson(),
          }),
        ),
      );

  @override
  Future<void> clear(ByokMediaCapability capability) =>
      _serialized(() => _store.delete(_key(capability)));

  Future<T> _serialized<T>(Future<T> Function() operation) {
    final result = _tail.then<T>((_) => operation());
    _tail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return result;
  }

  static String _key(ByokMediaCapability capability) =>
      '$_storagePrefix.${capability.name}';

  static Map<String, Object?> _decode(String encoded) {
    try {
      final value = jsonDecode(encoded);
      if (value is! Map) throw const FormatException();
      return Map<String, Object?>.from(value);
    } on Object {
      throw const SecureByokMediaVaultException(
        SecureByokMediaVaultFailureCode.corruptValue,
      );
    }
  }

  static String _string(Map<String, Object?> value, String key) {
    final field = value[key];
    if (field is! String || field.isEmpty) {
      throw const SecureByokMediaVaultException(
        SecureByokMediaVaultFailureCode.corruptValue,
      );
    }
    return field;
  }

  static FishAudioTtsOptions? _fishOptions(Object? value) {
    if (value == null) return null;
    if (value is! Map) throw const FormatException();
    return FishAudioTtsOptions.fromJson(Map<String, Object?>.from(value));
  }
}
