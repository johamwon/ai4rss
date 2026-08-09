import 'dart:async';
import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:river_commerce/river_commerce.dart';

import 'secure_sync_vault.dart';

enum SecureEntitlementStoreFailureCode { corruptValue, unsupportedSchema }

final class SecureEntitlementStoreException implements Exception {
  const SecureEntitlementStoreException(this.code);

  final SecureEntitlementStoreFailureCode code;

  @override
  String toString() => 'SecureEntitlementStoreException(${code.name})';
}

final class PlatformSecureEntitlementSnapshotStore
    implements EntitlementSnapshotStore {
  PlatformSecureEntitlementSnapshotStore({required SecureKeyValueStore store})
      : _store = store;

  factory PlatformSecureEntitlementSnapshotStore.standard() =>
      PlatformSecureEntitlementSnapshotStore(
        store: FlutterSecureKeyValueStore(),
      );

  static const _schemaVersion = 1;
  static const _storageKey = 'river.commerce.v1.entitlements';

  final SecureKeyValueStore _store;
  Future<void> _tail = Future<void>.value();

  @override
  Future<void> clear() => _serialized(() => _store.delete(_storageKey));

  @override
  Future<EntitlementSnapshot?> read() => _serialized(() async {
        final encoded = await _store.read(_storageKey);
        if (encoded == null) return null;
        final value = _decode(encoded);
        if (value['schema'] != _schemaVersion) {
          throw const SecureEntitlementStoreException(
            SecureEntitlementStoreFailureCode.unsupportedSchema,
          );
        }
        try {
          final grantedNames = _strings(value, 'granted');
          if (grantedNames.toSet().length != grantedNames.length) {
            throw const FormatException('Duplicate entitlement');
          }
          return EntitlementSnapshot(
            revision: _integer(value, 'revision'),
            subjectHash: _string(value, 'subjectHash'),
            plan: EntitlementPlan.values.byName(_string(value, 'plan')),
            granted: grantedNames.map(EntitlementKey.values.byName),
            issuedAt: _utc(value, 'issuedAt'),
            refreshAfter: _utc(value, 'refreshAfter'),
            validUntil: _utc(value, 'validUntil'),
            signature: _string(value, 'signature'),
          );
        } on SecureEntitlementStoreException {
          rethrow;
        } on Object {
          throw const SecureEntitlementStoreException(
            SecureEntitlementStoreFailureCode.corruptValue,
          );
        }
      });

  @override
  Future<void> write(EntitlementSnapshot snapshot) => _serialized(
        () => _store.write(
          _storageKey,
          jsonEncode(<String, Object>{
            'schema': _schemaVersion,
            'revision': snapshot.revision,
            'subjectHash': snapshot.subjectHash,
            'plan': snapshot.plan.name,
            'granted': snapshot.granted.map((key) => key.name).toList()..sort(),
            'issuedAt': snapshot.issuedAt.toIso8601String(),
            'refreshAfter': snapshot.refreshAfter.toIso8601String(),
            'validUntil': snapshot.validUntil.toIso8601String(),
            'signature': snapshot.signature,
          }),
        ),
      );

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
      throw const SecureEntitlementStoreException(
        SecureEntitlementStoreFailureCode.corruptValue,
      );
    }
  }

  static String _string(Map<String, Object?> value, String key) {
    final field = value[key];
    if (field is! String || field.isEmpty) {
      throw const SecureEntitlementStoreException(
        SecureEntitlementStoreFailureCode.corruptValue,
      );
    }
    return field;
  }

  static int _integer(Map<String, Object?> value, String key) {
    final field = value[key];
    if (field is! int) {
      throw const SecureEntitlementStoreException(
        SecureEntitlementStoreFailureCode.corruptValue,
      );
    }
    return field;
  }

  static List<String> _strings(Map<String, Object?> value, String key) {
    final field = value[key];
    if (field is! List || field.any((item) => item is! String)) {
      throw const SecureEntitlementStoreException(
        SecureEntitlementStoreFailureCode.corruptValue,
      );
    }
    return field.cast<String>();
  }

  static DateTime _utc(Map<String, Object?> value, String key) {
    final encoded = _string(value, key);
    final parsed = DateTime.parse(encoded);
    if (!parsed.isUtc || parsed.toIso8601String() != encoded) {
      throw const SecureEntitlementStoreException(
        SecureEntitlementStoreFailureCode.corruptValue,
      );
    }
    return parsed;
  }
}

final class Ed25519EntitlementSnapshotVerifier
    implements EntitlementSnapshotVerifier {
  Ed25519EntitlementSnapshotVerifier({
    required List<int> publicKeyBytes,
    Ed25519? algorithm,
  })  : _algorithm = algorithm ?? Ed25519(),
        _publicKey = SimplePublicKey(
          List<int>.unmodifiable(publicKeyBytes),
          type: KeyPairType.ed25519,
        ) {
    if (publicKeyBytes.length != 32) {
      throw ArgumentError.value(publicKeyBytes.length, 'publicKeyBytes.length');
    }
  }

  final Ed25519 _algorithm;
  final SimplePublicKey _publicKey;

  @override
  Future<bool> verify(String canonicalPayload, String signature) async {
    try {
      final padded = signature.padRight((signature.length + 3) ~/ 4 * 4, '=');
      final bytes = base64Url.decode(padded);
      if (base64Url.encode(bytes).replaceAll('=', '') != signature ||
          bytes.length != 64) {
        return false;
      }
      return _algorithm.verify(
        utf8.encode(canonicalPayload),
        signature: Signature(bytes, publicKey: _publicKey),
      );
    } on Object {
      return false;
    }
  }
}
