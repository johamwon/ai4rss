import 'dart:convert';

import 'sync_protocol.dart';
import 'version_vector.dart';

abstract final class SyncWireCodec {
  static const schemaVersion = 1;

  static String encodeEnvelope(EncryptedSyncEnvelope envelope) => jsonEncode(
        <String, Object?>{
          'schema': schemaVersion,
          'protocolVersion': envelope.protocolVersion,
          'mutationId': envelope.mutationId,
          'accountId': envelope.accountId,
          'objectKind': envelope.objectKind.name,
          'objectId': envelope.objectId,
          'payloadKind': envelope.payloadKind.name,
          'dataKeyId': envelope.dataKeyId,
          'authorDeviceId': envelope.authorDeviceId,
          'versionVector': envelope.versionVector.counters,
          'occurredAt': envelope.occurredAt.toIso8601String(),
          'nonce': envelope.nonceBase64,
          'ciphertext': envelope.ciphertextBase64,
          'authenticationTag': envelope.authenticationTagBase64,
        },
      );

  static EncryptedSyncEnvelope decodeEnvelope(String encoded) {
    if (encoded.isEmpty ||
        utf8.encode(encoded).length > SyncProtocol.maximumEnvelopeBytes * 2) {
      throw const SyncWireException(SyncWireFailureCode.invalidSize);
    }
    try {
      final value = jsonDecode(encoded);
      if (value is! Map<String, Object?> || value['schema'] != schemaVersion) {
        throw const SyncWireException(
          SyncWireFailureCode.unsupportedSchema,
        );
      }
      _requireKeys(
        value,
        const <String>{
          'schema',
          'protocolVersion',
          'mutationId',
          'accountId',
          'objectKind',
          'objectId',
          'payloadKind',
          'dataKeyId',
          'authorDeviceId',
          'versionVector',
          'occurredAt',
          'nonce',
          'ciphertext',
          'authenticationTag',
        },
      );
      final counters = value['versionVector'];
      if (counters is! Map<String, Object?>) {
        throw const SyncWireException(SyncWireFailureCode.invalidShape);
      }
      return EncryptedSyncEnvelope(
        protocolVersion: _integer(value, 'protocolVersion'),
        mutationId: _string(value, 'mutationId'),
        accountId: _string(value, 'accountId'),
        objectKind: SyncObjectKind.values.byName(
          _string(value, 'objectKind'),
        ),
        objectId: _string(value, 'objectId'),
        payloadKind: SyncPayloadKind.values.byName(
          _string(value, 'payloadKind'),
        ),
        dataKeyId: _string(value, 'dataKeyId'),
        authorDeviceId: _string(value, 'authorDeviceId'),
        versionVector: VersionVector(
          counters.map(
            (deviceId, counter) => MapEntry<String, int>(
              deviceId,
              counter is int ? counter : throw const FormatException(),
            ),
          ),
        ),
        occurredAt: DateTime.parse(_string(value, 'occurredAt')),
        nonceBase64: _string(value, 'nonce'),
        ciphertextBase64: _string(value, 'ciphertext'),
        authenticationTagBase64: _string(value, 'authenticationTag'),
      );
    } on SyncWireException {
      rethrow;
    } on Object {
      throw const SyncWireException(SyncWireFailureCode.invalidShape);
    }
  }
}

enum SyncWireFailureCode { invalidSize, invalidShape, unsupportedSchema }

final class SyncWireException implements Exception {
  const SyncWireException(this.code);

  final SyncWireFailureCode code;

  @override
  String toString() => 'SyncWireException(${code.name})';
}

String _string(Map<String, Object?> value, String key) {
  final field = value[key];
  if (field is! String || field.isEmpty) {
    throw const SyncWireException(SyncWireFailureCode.invalidShape);
  }
  return field;
}

int _integer(Map<String, Object?> value, String key) {
  final field = value[key];
  if (field is! int) {
    throw const SyncWireException(SyncWireFailureCode.invalidShape);
  }
  return field;
}

void _requireKeys(Map<String, Object?> value, Set<String> expected) {
  if (value.length != expected.length ||
      !value.keys.toSet().containsAll(expected)) {
    throw const SyncWireException(SyncWireFailureCode.invalidShape);
  }
}
