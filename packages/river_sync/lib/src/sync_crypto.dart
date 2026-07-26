import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'sync_protocol.dart';
import 'version_vector.dart';

abstract interface class SyncCryptoRandomSource {
  List<int> nextBytes(int length);
}

final class DartSyncCryptoRandomSource implements SyncCryptoRandomSource {
  DartSyncCryptoRandomSource(Random random) : _random = random;

  final Random _random;

  @override
  List<int> nextBytes(int length) {
    if (length <= 0) throw ArgumentError.value(length, 'length');
    return List<int>.generate(length, (_) => _random.nextInt(256));
  }
}

final class SyncDeviceKeyMaterial {
  SyncDeviceKeyMaterial({
    required this.keyId,
    required List<int> privateKeyBytes,
    required List<int> publicKeyBytes,
  })  : _privateKeyBytes = _copyExact(privateKeyBytes, 32, 'privateKeyBytes'),
        _publicKeyBytes = _copyExact(publicKeyBytes, 32, 'publicKeyBytes') {
    _requireIdentifier(keyId, 'keyId');
  }

  factory SyncDeviceKeyMaterial.fromBase64({
    required String keyId,
    required String privateKeyBase64,
    required String publicKeyBase64,
  }) =>
      SyncDeviceKeyMaterial(
        keyId: keyId,
        privateKeyBytes: _decodeCanonicalBase64(privateKeyBase64),
        publicKeyBytes: _decodeCanonicalBase64(publicKeyBase64),
      );

  final String keyId;
  final Uint8List _privateKeyBytes;
  final Uint8List _publicKeyBytes;
  var _destroyed = false;

  bool get isDestroyed => _destroyed;
  List<int> get publicKeyBytes => Uint8List.fromList(_publicKeyBytes);
  String get publicKeyBase64 => base64.encode(_publicKeyBytes);

  String exportPrivateKeyBase64() {
    _ensureAlive();
    return base64.encode(_privateKeyBytes);
  }

  List<int> copyPrivateKeyBytes() {
    _ensureAlive();
    return Uint8List.fromList(_privateKeyBytes);
  }

  void destroy() {
    if (_destroyed) return;
    _privateKeyBytes.fillRange(0, _privateKeyBytes.length, 0);
    _destroyed = true;
  }

  void _ensureAlive() {
    if (_destroyed) throw StateError('Device key material was destroyed.');
  }

  @override
  String toString() =>
      'SyncDeviceKeyMaterial(keyId: $keyId, privateKey: [REDACTED], '
      'publicKey: $publicKeyBase64, destroyed: $_destroyed)';
}

final class SyncDataKeyMaterial {
  SyncDataKeyMaterial({
    required this.descriptor,
    required List<int> keyBytes,
  }) : _keyBytes = _copyExact(keyBytes, 32, 'keyBytes');

  factory SyncDataKeyMaterial.fromBase64({
    required SyncDataKeyDescriptor descriptor,
    required String keyBase64,
  }) =>
      SyncDataKeyMaterial(
        descriptor: descriptor,
        keyBytes: _decodeCanonicalBase64(keyBase64),
      );

  final SyncDataKeyDescriptor descriptor;
  final Uint8List _keyBytes;
  var _destroyed = false;

  bool get isDestroyed => _destroyed;

  String exportKeyBase64() {
    _ensureAlive();
    return base64.encode(_keyBytes);
  }

  List<int> copyKeyBytes() {
    _ensureAlive();
    return Uint8List.fromList(_keyBytes);
  }

  void destroy() {
    if (_destroyed) return;
    _keyBytes.fillRange(0, _keyBytes.length, 0);
    _destroyed = true;
  }

  void _ensureAlive() {
    if (_destroyed) throw StateError('Data key material was destroyed.');
  }

  @override
  String toString() =>
      'SyncDataKeyMaterial(keyId: ${descriptor.id}, key: [REDACTED], '
      'destroyed: $_destroyed)';
}

final class SyncRecoverySecret {
  SyncRecoverySecret(List<int> bytes)
      : _bytes = _copyExact(bytes, 32, 'recoverySecret');

  factory SyncRecoverySecret.fromCode(String code) {
    final trimmed = code.trim();
    try {
      final padded = trimmed.padRight((trimmed.length + 3) ~/ 4 * 4, '=');
      final bytes = base64Url.decode(padded);
      final secret = SyncRecoverySecret(bytes);
      if (secret.revealCode() != trimmed) {
        secret.destroy();
        throw const FormatException('Non-canonical recovery code.');
      }
      return secret;
    } on FormatException {
      throw const SyncCryptoException(SyncCryptoFailureCode.invalidKey);
    }
  }

  final Uint8List _bytes;
  var _destroyed = false;

  bool get isDestroyed => _destroyed;

  String revealCode() {
    _ensureAlive();
    return base64Url.encode(_bytes).replaceAll('=', '');
  }

  List<int> copyBytes() {
    _ensureAlive();
    return Uint8List.fromList(_bytes);
  }

  void destroy() {
    if (_destroyed) return;
    _bytes.fillRange(0, _bytes.length, 0);
    _destroyed = true;
  }

  void _ensureAlive() {
    if (_destroyed) throw StateError('Recovery secret was destroyed.');
  }

  @override
  String toString() => 'SyncRecoverySecret([REDACTED], destroyed: $_destroyed)';
}

final class SyncRecoveryBundle {
  SyncRecoveryBundle({
    required this.accountId,
    required this.dataKeyId,
    required this.kdfSaltBase64,
    required this.nonceBase64,
    required this.ciphertextBase64,
    required this.authenticationTagBase64,
    this.protocolVersion = SyncProtocol.currentVersion,
  }) {
    if (!SyncProtocol.supports(protocolVersion)) {
      throw ArgumentError.value(protocolVersion, 'protocolVersion');
    }
    _requireIdentifier(accountId, 'accountId');
    _requireIdentifier(dataKeyId, 'dataKeyId');
    _copyExact(_decodeCanonicalBase64(kdfSaltBase64), 32, 'kdfSaltBase64');
    _copyExact(_decodeCanonicalBase64(nonceBase64), 12, 'nonceBase64');
    _copyExact(
      _decodeCanonicalBase64(authenticationTagBase64),
      16,
      'authenticationTagBase64',
    );
    if (_decodeCanonicalBase64(ciphertextBase64).length != 32) {
      throw const SyncCryptoException(
        SyncCryptoFailureCode.malformedCiphertext,
      );
    }
  }

  final int protocolVersion;
  final String accountId;
  final String dataKeyId;
  final String kdfSaltBase64;
  final String nonceBase64;
  final String ciphertextBase64;
  final String authenticationTagBase64;

  String get associatedData => associatedDataFor(
        protocolVersion: protocolVersion,
        accountId: accountId,
        dataKeyId: dataKeyId,
        kdfSaltBase64: kdfSaltBase64,
      );

  static String associatedDataFor({
    required int protocolVersion,
    required String accountId,
    required String dataKeyId,
    required String kdfSaltBase64,
  }) =>
      'river-sync-recovery-v$protocolVersion|'
      '${Uri.encodeComponent(accountId)}|'
      '${Uri.encodeComponent(dataKeyId)}|$kdfSaltBase64';
}

final class SyncRecoveryKit {
  const SyncRecoveryKit({
    required this.secret,
    required this.bundle,
  });

  final SyncRecoverySecret secret;
  final SyncRecoveryBundle bundle;
}

abstract interface class SyncKeyMaterialVault {
  Future<SyncDeviceKeyMaterial?> readDeviceKey(String keyId);
  Future<void> writeDeviceKey(SyncDeviceKeyMaterial material);
  Future<void> deleteDeviceKey(String keyId);
  Future<SyncDataKeyMaterial?> readDataKey(String keyId);
  Future<void> writeDataKey(SyncDataKeyMaterial material);
  Future<void> deleteDataKey(String keyId);
}

enum SyncCryptoFailureCode {
  invalidKey,
  scopeMismatch,
  authenticationFailed,
  unsupportedAlgorithm,
  malformedCiphertext,
  destroyedKey,
}

final class SyncCryptoException implements Exception {
  const SyncCryptoException(this.code);

  final SyncCryptoFailureCode code;

  @override
  String toString() => 'SyncCryptoException(${code.name})';
}

final class SyncCryptoEngine {
  SyncCryptoEngine({required SyncCryptoRandomSource random}) : _random = random;

  final SyncCryptoRandomSource _random;
  final AesGcm _aes = AesGcm.with256bits();
  final X25519 _x25519 = X25519();
  final Hkdf _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);

  Future<SyncDeviceKeyMaterial> generateDeviceKey({
    required String keyId,
  }) async {
    final seed = _nextBytes(32);
    final keyPair = await _x25519.newKeyPairFromSeed(seed);
    try {
      final privateBytes = await keyPair.extractPrivateKeyBytes();
      final publicKey = await keyPair.extractPublicKey();
      return SyncDeviceKeyMaterial(
        keyId: keyId,
        privateKeyBytes: privateBytes,
        publicKeyBytes: publicKey.bytes,
      );
    } finally {
      _erase(seed);
      keyPair.destroy();
    }
  }

  SyncDataKeyMaterial generateDataKey({
    required String keyId,
    required String accountId,
    required int version,
    required DateTime createdAt,
  }) =>
      SyncDataKeyMaterial(
        descriptor: SyncDataKeyDescriptor(
          id: keyId,
          accountId: accountId,
          version: version,
          createdAt: createdAt,
        ),
        keyBytes: _nextBytes(32),
      );

  Future<EncryptedSyncEnvelope> encryptEnvelope({
    required String mutationId,
    required String accountId,
    required SyncObjectKind objectKind,
    required String objectId,
    required SyncPayloadKind payloadKind,
    required String authorDeviceId,
    required VersionVector versionVector,
    required DateTime occurredAt,
    required List<int> clearText,
    required SyncDataKeyMaterial dataKey,
    int protocolVersion = SyncProtocol.currentVersion,
  }) async {
    if (clearText.isEmpty) {
      throw ArgumentError.value(clearText, 'clearText', 'Must not be empty.');
    }
    _requireUsableDataKey(dataKey, accountId: accountId);
    final associatedData = EncryptedSyncEnvelope.associatedDataFor(
      protocolVersion: protocolVersion,
      mutationId: mutationId,
      accountId: accountId,
      objectKind: objectKind,
      objectId: objectId,
      payloadKind: payloadKind,
      dataKeyId: dataKey.descriptor.id,
      authorDeviceId: authorDeviceId,
      versionVector: versionVector,
      occurredAt: occurredAt,
    );
    final secretKey = SecretKeyData(
      dataKey.copyKeyBytes(),
      overwriteWhenDestroyed: true,
    );
    try {
      final box = await _aes.encrypt(
        clearText,
        secretKey: secretKey,
        nonce: _nextBytes(12),
        aad: utf8.encode(associatedData),
      );
      return EncryptedSyncEnvelope(
        protocolVersion: protocolVersion,
        mutationId: mutationId,
        accountId: accountId,
        objectKind: objectKind,
        objectId: objectId,
        payloadKind: payloadKind,
        dataKeyId: dataKey.descriptor.id,
        authorDeviceId: authorDeviceId,
        versionVector: versionVector,
        occurredAt: occurredAt,
        nonceBase64: base64.encode(box.nonce),
        ciphertextBase64: base64.encode(box.cipherText),
        authenticationTagBase64: base64.encode(box.mac.bytes),
      );
    } finally {
      secretKey.destroy();
    }
  }

  Future<List<int>> decryptEnvelope({
    required EncryptedSyncEnvelope envelope,
    required SyncDataKeyMaterial dataKey,
  }) async {
    _requireUsableDataKey(dataKey, accountId: envelope.accountId);
    if (envelope.dataKeyId != dataKey.descriptor.id) {
      throw const SyncCryptoException(SyncCryptoFailureCode.scopeMismatch);
    }
    final secretKey = SecretKeyData(
      dataKey.copyKeyBytes(),
      overwriteWhenDestroyed: true,
    );
    try {
      return await _aes.decrypt(
        SecretBox(
          base64.decode(envelope.ciphertextBase64),
          nonce: base64.decode(envelope.nonceBase64),
          mac: Mac(base64.decode(envelope.authenticationTagBase64)),
        ),
        secretKey: secretKey,
        aad: utf8.encode(envelope.associatedData),
      );
    } on SecretBoxAuthenticationError {
      throw const SyncCryptoException(
        SyncCryptoFailureCode.authenticationFailed,
      );
    } on FormatException {
      throw const SyncCryptoException(
        SyncCryptoFailureCode.malformedCiphertext,
      );
    } finally {
      secretKey.destroy();
    }
  }

  Future<WrappedSyncDataKey> wrapDataKey({
    required SyncDataKeyMaterial dataKey,
    required SyncDevice recipient,
    required String senderDeviceId,
    int protocolVersion = SyncProtocol.currentVersion,
  }) async {
    _requireUsableDataKey(dataKey, accountId: recipient.accountId);
    if (recipient.status == SyncDeviceStatus.revoked) {
      throw const SyncCryptoException(SyncCryptoFailureCode.scopeMismatch);
    }
    final ephemeralSeed = _nextBytes(32);
    final kdfSalt = _nextBytes(32);
    final nonce = _nextBytes(12);
    final ephemeralKeyPair = await _x25519.newKeyPairFromSeed(ephemeralSeed);
    SecretKey? sharedSecret;
    SecretKey? wrappingKey;
    var clearDataKey = <int>[];
    try {
      final ephemeralPublicKey = await ephemeralKeyPair.extractPublicKey();
      final ephemeralPublicKeyBase64 = base64.encode(ephemeralPublicKey.bytes);
      final kdfSaltBase64 = base64.encode(kdfSalt);
      final associatedData = WrappedSyncDataKey.associatedDataFor(
        protocolVersion: protocolVersion,
        accountId: recipient.accountId,
        dataKeyId: dataKey.descriptor.id,
        recipientDeviceId: recipient.id,
        senderDeviceId: senderDeviceId,
        algorithm: SyncKeyWrappingAlgorithm.x25519HkdfSha256Aes256Gcm,
        ephemeralPublicKeyBase64: ephemeralPublicKeyBase64,
        kdfSaltBase64: kdfSaltBase64,
      );
      sharedSecret = await _x25519.sharedSecretKey(
        keyPair: ephemeralKeyPair,
        remotePublicKey: SimplePublicKey(
          base64.decode(recipient.publicKeyBase64),
          type: KeyPairType.x25519,
        ),
      );
      wrappingKey = await _hkdf.deriveKey(
        secretKey: sharedSecret,
        nonce: kdfSalt,
        info: _wrappingInfo(
          accountId: recipient.accountId,
          dataKeyId: dataKey.descriptor.id,
          recipientDeviceId: recipient.id,
        ),
      );
      clearDataKey = dataKey.copyKeyBytes();
      final box = await _aes.encrypt(
        clearDataKey,
        secretKey: wrappingKey,
        nonce: nonce,
        aad: utf8.encode(associatedData),
      );
      return WrappedSyncDataKey(
        protocolVersion: protocolVersion,
        accountId: recipient.accountId,
        dataKeyId: dataKey.descriptor.id,
        recipientDeviceId: recipient.id,
        senderDeviceId: senderDeviceId,
        ephemeralPublicKeyBase64: ephemeralPublicKeyBase64,
        kdfSaltBase64: kdfSaltBase64,
        nonceBase64: base64.encode(box.nonce),
        ciphertextBase64: base64.encode(box.cipherText),
        authenticationTagBase64: base64.encode(box.mac.bytes),
      );
    } finally {
      _erase(ephemeralSeed);
      _erase(kdfSalt);
      _erase(nonce);
      _erase(clearDataKey);
      wrappingKey?.destroy();
      sharedSecret?.destroy();
      ephemeralKeyPair.destroy();
    }
  }

  Future<SyncDataKeyMaterial> unwrapDataKey({
    required WrappedSyncDataKey wrapped,
    required SyncDataKeyDescriptor descriptor,
    required String recipientDeviceId,
    required SyncDeviceKeyMaterial recipientKey,
  }) async {
    if (recipientKey.isDestroyed) {
      throw const SyncCryptoException(SyncCryptoFailureCode.destroyedKey);
    }
    if (wrapped.algorithm !=
            SyncKeyWrappingAlgorithm.x25519HkdfSha256Aes256Gcm ||
        wrapped.accountId != descriptor.accountId ||
        wrapped.dataKeyId != descriptor.id ||
        wrapped.recipientDeviceId != recipientDeviceId) {
      throw const SyncCryptoException(SyncCryptoFailureCode.scopeMismatch);
    }
    final privateBytes = recipientKey.copyPrivateKeyBytes();
    final keyPair = SimpleKeyPairData(
      privateBytes,
      publicKey: SimplePublicKey(
        recipientKey.publicKeyBytes,
        type: KeyPairType.x25519,
      ),
      type: KeyPairType.x25519,
    );
    SecretKey? sharedSecret;
    SecretKey? wrappingKey;
    try {
      sharedSecret = await _x25519.sharedSecretKey(
        keyPair: keyPair,
        remotePublicKey: SimplePublicKey(
          base64.decode(wrapped.ephemeralPublicKeyBase64),
          type: KeyPairType.x25519,
        ),
      );
      wrappingKey = await _hkdf.deriveKey(
        secretKey: sharedSecret,
        nonce: base64.decode(wrapped.kdfSaltBase64),
        info: _wrappingInfo(
          accountId: wrapped.accountId,
          dataKeyId: wrapped.dataKeyId,
          recipientDeviceId: wrapped.recipientDeviceId,
        ),
      );
      final clearKey = await _aes.decrypt(
        SecretBox(
          base64.decode(wrapped.ciphertextBase64),
          nonce: base64.decode(wrapped.nonceBase64),
          mac: Mac(base64.decode(wrapped.authenticationTagBase64)),
        ),
        secretKey: wrappingKey,
        aad: utf8.encode(wrapped.associatedData),
      );
      try {
        return SyncDataKeyMaterial(
          descriptor: descriptor,
          keyBytes: clearKey,
        );
      } finally {
        _erase(clearKey);
      }
    } on SecretBoxAuthenticationError {
      throw const SyncCryptoException(
        SyncCryptoFailureCode.authenticationFailed,
      );
    } on FormatException {
      throw const SyncCryptoException(
        SyncCryptoFailureCode.malformedCiphertext,
      );
    } finally {
      _erase(privateBytes);
      wrappingKey?.destroy();
      sharedSecret?.destroy();
      keyPair.destroy();
    }
  }

  Future<SyncRecoveryKit> createRecoveryKit({
    required SyncDataKeyMaterial dataKey,
    int protocolVersion = SyncProtocol.currentVersion,
  }) async {
    _requireUsableDataKey(
      dataKey,
      accountId: dataKey.descriptor.accountId,
    );
    final recoverySecret = SyncRecoverySecret(_nextBytes(32));
    final kdfSalt = _nextBytes(32);
    final nonce = _nextBytes(12);
    SecretKeyData? inputKey;
    SecretKey? recoveryKey;
    var clearDataKey = <int>[];
    try {
      final kdfSaltBase64 = base64.encode(kdfSalt);
      final associatedData = SyncRecoveryBundle.associatedDataFor(
        protocolVersion: protocolVersion,
        accountId: dataKey.descriptor.accountId,
        dataKeyId: dataKey.descriptor.id,
        kdfSaltBase64: kdfSaltBase64,
      );
      inputKey = SecretKeyData(
        recoverySecret.copyBytes(),
        overwriteWhenDestroyed: true,
      );
      recoveryKey = await _hkdf.deriveKey(
        secretKey: inputKey,
        nonce: kdfSalt,
        info: _recoveryInfo(
          accountId: dataKey.descriptor.accountId,
          dataKeyId: dataKey.descriptor.id,
        ),
      );
      clearDataKey = dataKey.copyKeyBytes();
      final box = await _aes.encrypt(
        clearDataKey,
        secretKey: recoveryKey,
        nonce: nonce,
        aad: utf8.encode(associatedData),
      );
      return SyncRecoveryKit(
        secret: recoverySecret,
        bundle: SyncRecoveryBundle(
          protocolVersion: protocolVersion,
          accountId: dataKey.descriptor.accountId,
          dataKeyId: dataKey.descriptor.id,
          kdfSaltBase64: kdfSaltBase64,
          nonceBase64: base64.encode(box.nonce),
          ciphertextBase64: base64.encode(box.cipherText),
          authenticationTagBase64: base64.encode(box.mac.bytes),
        ),
      );
    } on Object {
      recoverySecret.destroy();
      rethrow;
    } finally {
      _erase(kdfSalt);
      _erase(nonce);
      _erase(clearDataKey);
      recoveryKey?.destroy();
      inputKey?.destroy();
    }
  }

  Future<SyncDataKeyMaterial> recoverDataKey({
    required SyncRecoveryBundle bundle,
    required SyncRecoverySecret recoverySecret,
    required SyncDataKeyDescriptor descriptor,
  }) async {
    if (recoverySecret.isDestroyed) {
      throw const SyncCryptoException(SyncCryptoFailureCode.destroyedKey);
    }
    if (bundle.accountId != descriptor.accountId ||
        bundle.dataKeyId != descriptor.id) {
      throw const SyncCryptoException(SyncCryptoFailureCode.scopeMismatch);
    }
    SecretKeyData? inputKey;
    SecretKey? recoveryKey;
    try {
      inputKey = SecretKeyData(
        recoverySecret.copyBytes(),
        overwriteWhenDestroyed: true,
      );
      recoveryKey = await _hkdf.deriveKey(
        secretKey: inputKey,
        nonce: base64.decode(bundle.kdfSaltBase64),
        info: _recoveryInfo(
          accountId: bundle.accountId,
          dataKeyId: bundle.dataKeyId,
        ),
      );
      final clearKey = await _aes.decrypt(
        SecretBox(
          base64.decode(bundle.ciphertextBase64),
          nonce: base64.decode(bundle.nonceBase64),
          mac: Mac(base64.decode(bundle.authenticationTagBase64)),
        ),
        secretKey: recoveryKey,
        aad: utf8.encode(bundle.associatedData),
      );
      try {
        return SyncDataKeyMaterial(
          descriptor: descriptor,
          keyBytes: clearKey,
        );
      } finally {
        _erase(clearKey);
      }
    } on SecretBoxAuthenticationError {
      throw const SyncCryptoException(
        SyncCryptoFailureCode.authenticationFailed,
      );
    } finally {
      recoveryKey?.destroy();
      inputKey?.destroy();
    }
  }

  List<int> _nextBytes(int length) {
    final bytes = _random.nextBytes(length);
    return _copyExact(bytes, length, 'randomBytes');
  }

  void _requireUsableDataKey(
    SyncDataKeyMaterial dataKey, {
    required String accountId,
  }) {
    if (dataKey.isDestroyed) {
      throw const SyncCryptoException(SyncCryptoFailureCode.destroyedKey);
    }
    if (dataKey.descriptor.algorithm != SyncDataKeyAlgorithm.aes256Gcm) {
      throw const SyncCryptoException(
        SyncCryptoFailureCode.unsupportedAlgorithm,
      );
    }
    if (dataKey.descriptor.accountId != accountId) {
      throw const SyncCryptoException(SyncCryptoFailureCode.scopeMismatch);
    }
  }

  static List<int> _wrappingInfo({
    required String accountId,
    required String dataKeyId,
    required String recipientDeviceId,
  }) =>
      utf8.encode(
        'river-sync-wrap-kdf-v1|${Uri.encodeComponent(accountId)}|'
        '${Uri.encodeComponent(dataKeyId)}|'
        '${Uri.encodeComponent(recipientDeviceId)}',
      );

  static List<int> _recoveryInfo({
    required String accountId,
    required String dataKeyId,
  }) =>
      utf8.encode(
        'river-sync-recovery-kdf-v1|${Uri.encodeComponent(accountId)}|'
        '${Uri.encodeComponent(dataKeyId)}',
      );
}

Uint8List _copyExact(List<int> bytes, int length, String name) {
  if (bytes.length != length ||
      bytes.any((value) => value < 0 || value > 255)) {
    throw ArgumentError.value(
      bytes.length,
      name,
      'Must contain $length bytes.',
    );
  }
  return Uint8List.fromList(bytes);
}

List<int> _decodeCanonicalBase64(String value) {
  try {
    final bytes = base64.decode(value);
    if (base64.encode(bytes) != value) {
      throw const FormatException('Non-canonical base64.');
    }
    return bytes;
  } on FormatException {
    throw const SyncCryptoException(SyncCryptoFailureCode.invalidKey);
  }
}

void _erase(List<int> bytes) {
  for (var index = 0; index < bytes.length; index += 1) {
    bytes[index] = 0;
  }
}

void _requireIdentifier(String value, String name) {
  if (value.isEmpty || value.trim() != value || value.length > 256) {
    throw ArgumentError.value(value, name, 'Invalid identifier.');
  }
}
