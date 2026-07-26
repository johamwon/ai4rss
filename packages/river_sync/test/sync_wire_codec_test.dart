import 'dart:convert';

import 'package:river_sync/river_sync.dart';
import 'package:test/test.dart';

void main() {
  test('encrypted envelope wire representation round trips exactly', () {
    final envelope = EncryptedSyncEnvelope(
      mutationId: 'mutation-1',
      accountId: 'account-1',
      objectKind: SyncObjectKind.articleState,
      objectId: 'article-1',
      payloadKind: SyncPayloadKind.upsert,
      dataKeyId: 'data-key-1',
      authorDeviceId: 'device-a',
      versionVector: VersionVector(
        <String, int>{'device-a': 2, 'device-b': 1},
      ),
      occurredAt: DateTime.utc(2026, 7, 27, 6),
      nonceBase64: _bytes(12),
      ciphertextBase64: _bytes(64),
      authenticationTagBase64: _bytes(16),
    );

    final decoded = SyncWireCodec.decodeEnvelope(
      SyncWireCodec.encodeEnvelope(envelope),
    );

    expect(decoded.associatedData, envelope.associatedData);
    expect(decoded.ciphertextBase64, envelope.ciphertextBase64);
    expect(decoded.versionVector, envelope.versionVector);
  });

  test('wire codec rejects unknown schema and non-integer vector counters', () {
    expect(
      () => SyncWireCodec.decodeEnvelope('{"schema":99}'),
      throwsA(
        isA<SyncWireException>().having(
          (error) => error.code,
          'code',
          SyncWireFailureCode.unsupportedSchema,
        ),
      ),
    );
    final invalid = <String, Object?>{
      'schema': 1,
      'protocolVersion': 1,
      'mutationId': 'mutation-1',
      'accountId': 'account-1',
      'objectKind': 'folder',
      'objectId': 'folder-1',
      'payloadKind': 'upsert',
      'dataKeyId': 'data-key-1',
      'authorDeviceId': 'device-a',
      'versionVector': <String, Object?>{'device-a': 1.5},
      'occurredAt': DateTime.utc(2026, 7, 27).toIso8601String(),
      'nonce': _bytes(12),
      'ciphertext': _bytes(32),
      'authenticationTag': _bytes(16),
    };
    expect(
      () => SyncWireCodec.decodeEnvelope(jsonEncode(invalid)),
      throwsA(
        isA<SyncWireException>().having(
          (error) => error.code,
          'code',
          SyncWireFailureCode.invalidShape,
        ),
      ),
    );
  });
}

String _bytes(int count) =>
    base64.encode(List<int>.generate(count, (index) => index % 251));
