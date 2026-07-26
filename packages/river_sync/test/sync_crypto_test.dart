import 'dart:convert';

import 'package:river_sync/river_sync.dart';
import 'package:test/test.dart';

void main() {
  test('AES-256-GCM protocol vector is stable and decrypts', () async {
    final engine = SyncCryptoEngine(
      random: _SequenceRandom(<List<int>>[
        List<int>.filled(12, 0),
      ]),
    );
    final dataKey = _dataKey(List<int>.filled(32, 0));

    final envelope = await engine.encryptEnvelope(
      mutationId: 'mutation-1',
      accountId: 'account-1',
      objectKind: SyncObjectKind.articleState,
      objectId: 'article-1',
      payloadKind: SyncPayloadKind.upsert,
      authorDeviceId: 'device-a',
      versionVector: VersionVector(<String, int>{'device-a': 1}),
      occurredAt: DateTime.utc(2026, 7, 27, 1),
      clearText: utf8.encode('known vector'),
      dataKey: dataKey,
    );

    expect(
      _hex(base64.decode(envelope.ciphertextBase64)),
      'a5c92f4a23401d0b643aaaa1',
    );
    expect(
      _hex(base64.decode(envelope.authenticationTagBase64)),
      '4d7a3a1b0adb994ea5893d6908011ebf',
    );
    expect(
      utf8.decode(
        await engine.decryptEnvelope(envelope: envelope, dataKey: dataKey),
      ),
      'known vector',
    );
  });

  test('ciphertext contains no plaintext and AAD tampering is rejected',
      () async {
    final engine = SyncCryptoEngine(
      random: _SequenceRandom(<List<int>>[
        List<int>.generate(12, (index) => index + 1),
      ]),
    );
    final dataKey = _dataKey(List<int>.generate(32, (index) => index));
    final clearText = utf8.encode('private article state');
    final envelope = await _envelope(
      engine: engine,
      dataKey: dataKey,
      clearText: clearText,
    );

    expect(
      base64.decode(envelope.ciphertextBase64),
      isNot(containsAllInOrder(clearText)),
    );
    final tampered = EncryptedSyncEnvelope(
      protocolVersion: envelope.protocolVersion,
      mutationId: envelope.mutationId,
      accountId: envelope.accountId,
      objectKind: envelope.objectKind,
      objectId: 'another-article',
      payloadKind: envelope.payloadKind,
      dataKeyId: envelope.dataKeyId,
      authorDeviceId: envelope.authorDeviceId,
      versionVector: envelope.versionVector,
      occurredAt: envelope.occurredAt,
      nonceBase64: envelope.nonceBase64,
      ciphertextBase64: envelope.ciphertextBase64,
      authenticationTagBase64: envelope.authenticationTagBase64,
    );

    await expectLater(
      engine.decryptEnvelope(envelope: tampered, dataKey: dataKey),
      throwsA(
        isA<SyncCryptoException>().having(
          (error) => error.code,
          'code',
          SyncCryptoFailureCode.authenticationFailed,
        ),
      ),
    );
  });

  test('wrong and destroyed data keys fail closed', () async {
    final engine = SyncCryptoEngine(
      random: _SequenceRandom(<List<int>>[
        List<int>.filled(12, 8),
      ]),
    );
    final dataKey = _dataKey(List<int>.filled(32, 1));
    final envelope = await _envelope(
      engine: engine,
      dataKey: dataKey,
      clearText: utf8.encode('secret'),
    );
    final wrong = _dataKey(List<int>.filled(32, 2));

    await expectLater(
      engine.decryptEnvelope(envelope: envelope, dataKey: wrong),
      throwsA(
        isA<SyncCryptoException>().having(
          (error) => error.code,
          'code',
          SyncCryptoFailureCode.authenticationFailed,
        ),
      ),
    );
    dataKey.destroy();
    expect(
      dataKey.toString(),
      isNot(contains(base64.encode(List.filled(32, 1)))),
    );
    await expectLater(
      engine.decryptEnvelope(envelope: envelope, dataKey: dataKey),
      throwsA(
        isA<SyncCryptoException>().having(
          (error) => error.code,
          'code',
          SyncCryptoFailureCode.destroyedKey,
        ),
      ),
    );
  });

  test('X25519 HKDF wrapping round trips only for the recipient', () async {
    final engine = SyncCryptoEngine(
      random: _SequenceRandom(<List<int>>[
        List<int>.generate(32, (index) => index + 1),
        List<int>.generate(32, (index) => 100 + index),
        List<int>.filled(32, 9),
        List<int>.filled(12, 10),
      ]),
    );
    final recipientKey = await engine.generateDeviceKey(keyId: 'device-key-b');
    final recipient = SyncDevice(
      id: 'device-b',
      accountId: 'account-1',
      displayName: 'Phone',
      registeredAt: DateTime.utc(2026, 7, 27),
      publicKeyId: recipientKey.keyId,
      publicKeyBase64: recipientKey.publicKeyBase64,
      status: SyncDeviceStatus.pendingApproval,
    );
    final dataKey = _dataKey(List<int>.generate(32, (index) => 200 - index));

    final wrapped = await engine.wrapDataKey(
      dataKey: dataKey,
      recipient: recipient,
      senderDeviceId: 'device-a',
    );
    final recovered = await engine.unwrapDataKey(
      wrapped: wrapped,
      descriptor: dataKey.descriptor,
      recipientDeviceId: recipient.id,
      recipientKey: recipientKey,
    );

    expect(recovered.exportKeyBase64(), dataKey.exportKeyBase64());
    expect(wrapped.ciphertextBase64, isNot(dataKey.exportKeyBase64()));

    final wrongEngine = SyncCryptoEngine(
      random: _SequenceRandom(<List<int>>[
        List<int>.filled(32, 77),
      ]),
    );
    final wrongRecipient =
        await wrongEngine.generateDeviceKey(keyId: 'wrong-key');
    await expectLater(
      engine.unwrapDataKey(
        wrapped: wrapped,
        descriptor: dataKey.descriptor,
        recipientDeviceId: recipient.id,
        recipientKey: wrongRecipient,
      ),
      throwsA(
        isA<SyncCryptoException>().having(
          (error) => error.code,
          'code',
          SyncCryptoFailureCode.authenticationFailed,
        ),
      ),
    );

    final revokedRecipient = SyncDevice(
      id: recipient.id,
      accountId: recipient.accountId,
      displayName: recipient.displayName,
      registeredAt: recipient.registeredAt,
      publicKeyId: recipient.publicKeyId,
      publicKeyBase64: recipient.publicKeyBase64,
      status: SyncDeviceStatus.revoked,
      revokedAt: DateTime.utc(2026, 7, 28),
    );
    await expectLater(
      engine.wrapDataKey(
        dataKey: dataKey,
        recipient: revokedRecipient,
        senderDeviceId: 'device-a',
      ),
      throwsA(
        isA<SyncCryptoException>().having(
          (error) => error.code,
          'code',
          SyncCryptoFailureCode.scopeMismatch,
        ),
      ),
    );
  });

  test('generated and restored key material is fixed-size and redacted',
      () async {
    final engine = SyncCryptoEngine(
      random: _SequenceRandom(<List<int>>[
        List<int>.generate(32, (index) => index + 10),
        List<int>.generate(32, (index) => index + 20),
      ]),
    );
    final deviceKey = await engine.generateDeviceKey(keyId: 'device-key-a');
    final dataKey = engine.generateDataKey(
      keyId: 'data-key-2',
      accountId: 'account-1',
      version: 2,
      createdAt: DateTime.utc(2026, 7, 27),
    );
    final restoredDevice = SyncDeviceKeyMaterial.fromBase64(
      keyId: deviceKey.keyId,
      privateKeyBase64: deviceKey.exportPrivateKeyBase64(),
      publicKeyBase64: deviceKey.publicKeyBase64,
    );
    final restoredData = SyncDataKeyMaterial.fromBase64(
      descriptor: dataKey.descriptor,
      keyBase64: dataKey.exportKeyBase64(),
    );

    expect(restoredDevice.publicKeyBase64, deviceKey.publicKeyBase64);
    expect(restoredData.exportKeyBase64(), dataKey.exportKeyBase64());
    expect(deviceKey.toString(), contains('[REDACTED]'));
    expect(dataKey.toString(), contains('[REDACTED]'));

    deviceKey.destroy();
    expect(() => deviceKey.exportPrivateKeyBase64(), throwsStateError);
  });

  test('key rotation gives a new version that cannot read old-key ciphertext',
      () async {
    final engine = SyncCryptoEngine(
      random: _SequenceRandom(<List<int>>[
        List<int>.filled(32, 1),
        List<int>.filled(32, 2),
        List<int>.filled(12, 3),
      ]),
    );
    final oldKey = engine.generateDataKey(
      keyId: 'data-key-1',
      accountId: 'account-1',
      version: 1,
      createdAt: DateTime.utc(2026, 7, 26),
    );
    final newKey = engine.generateDataKey(
      keyId: 'data-key-2',
      accountId: 'account-1',
      version: 2,
      createdAt: DateTime.utc(2026, 7, 27),
    );
    final envelope = await _envelope(
      engine: engine,
      dataKey: newKey,
      clearText: utf8.encode('future state'),
    );

    expect(newKey.descriptor.version, greaterThan(oldKey.descriptor.version));
    await expectLater(
      engine.decryptEnvelope(envelope: envelope, dataKey: oldKey),
      throwsA(
        isA<SyncCryptoException>().having(
          (error) => error.code,
          'code',
          SyncCryptoFailureCode.scopeMismatch,
        ),
      ),
    );
  });

  test('recovery code restores a data key while the bundle reveals no secret',
      () async {
    final engine = SyncCryptoEngine(
      random: _SequenceRandom(<List<int>>[
        List<int>.generate(32, (index) => 30 + index),
        List<int>.filled(32, 14),
        List<int>.filled(12, 15),
      ]),
    );
    final dataKey = _dataKey(List<int>.generate(32, (index) => 90 + index));

    final kit = await engine.createRecoveryKit(dataKey: dataKey);
    final copiedSecret = SyncRecoverySecret.fromCode(kit.secret.revealCode());
    final recovered = await engine.recoverDataKey(
      bundle: kit.bundle,
      recoverySecret: copiedSecret,
      descriptor: dataKey.descriptor,
    );

    expect(recovered.exportKeyBase64(), dataKey.exportKeyBase64());
    expect(kit.bundle.ciphertextBase64, isNot(dataKey.exportKeyBase64()));
    expect(kit.bundle.toString(), isNot(contains(kit.secret.revealCode())));
    expect(kit.secret.toString(), contains('[REDACTED]'));
  });

  test('wrong recovery code fails authentication without returning key bytes',
      () async {
    final engine = SyncCryptoEngine(
      random: _SequenceRandom(<List<int>>[
        List<int>.filled(32, 16),
        List<int>.filled(32, 17),
        List<int>.filled(12, 18),
      ]),
    );
    final dataKey = _dataKey(List<int>.filled(32, 19));
    final kit = await engine.createRecoveryKit(dataKey: dataKey);
    final wrong = SyncRecoverySecret(List<int>.filled(32, 20));

    await expectLater(
      engine.recoverDataKey(
        bundle: kit.bundle,
        recoverySecret: wrong,
        descriptor: dataKey.descriptor,
      ),
      throwsA(
        isA<SyncCryptoException>().having(
          (error) => error.code,
          'code',
          SyncCryptoFailureCode.authenticationFailed,
        ),
      ),
    );
  });
}

SyncDataKeyMaterial _dataKey(List<int> bytes) => SyncDataKeyMaterial(
      descriptor: SyncDataKeyDescriptor(
        id: 'data-key-1',
        accountId: 'account-1',
        version: 1,
        createdAt: DateTime.utc(2026, 7, 27),
      ),
      keyBytes: bytes,
    );

Future<EncryptedSyncEnvelope> _envelope({
  required SyncCryptoEngine engine,
  required SyncDataKeyMaterial dataKey,
  required List<int> clearText,
}) =>
    engine.encryptEnvelope(
      mutationId: 'mutation-1',
      accountId: 'account-1',
      objectKind: SyncObjectKind.articleState,
      objectId: 'article-1',
      payloadKind: SyncPayloadKind.upsert,
      authorDeviceId: 'device-a',
      versionVector: VersionVector(<String, int>{'device-a': 1}),
      occurredAt: DateTime.utc(2026, 7, 27, 1),
      clearText: clearText,
      dataKey: dataKey,
    );

String _hex(List<int> bytes) =>
    bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();

final class _SequenceRandom implements SyncCryptoRandomSource {
  _SequenceRandom(this.values);

  final List<List<int>> values;
  var index = 0;

  @override
  List<int> nextBytes(int length) {
    if (index >= values.length) {
      throw StateError('No deterministic bytes left for length $length.');
    }
    final value = values[index];
    index += 1;
    if (value.length != length) {
      throw StateError('Expected $length bytes, got ${value.length}.');
    }
    return List<int>.from(value);
  }
}
