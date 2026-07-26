import 'dart:convert';

import 'version_vector.dart';

abstract final class SyncProtocol {
  static const currentVersion = 1;
  static const minimumSupportedVersion = 1;
  static const maximumBatchItems = 200;
  static const maximumEnvelopeBytes = 1024 * 1024;

  static bool supports(int version) =>
      version >= minimumSupportedVersion && version <= currentVersion;
}

enum SyncAccountStatus { active, deletionPending, deleted }

final class SyncAccount {
  SyncAccount({
    required this.id,
    required this.createdAt,
    required this.currentKeyId,
    this.status = SyncAccountStatus.active,
  }) {
    _requireIdentifier(id, 'id');
    _requireIdentifier(currentKeyId, 'currentKeyId');
    _requireUtc(createdAt, 'createdAt');
  }

  final String id;
  final DateTime createdAt;
  final String currentKeyId;
  final SyncAccountStatus status;
}

enum SyncDeviceStatus { active, pendingApproval, revoked }

enum DeviceKeyAgreementAlgorithm { x25519 }

final class SyncDeviceRegistration {
  SyncDeviceRegistration({
    required this.requestedDeviceId,
    required this.displayName,
    required this.publicKeyId,
    required this.publicKeyBase64,
    this.keyAgreementAlgorithm = DeviceKeyAgreementAlgorithm.x25519,
  }) {
    _requireIdentifier(requestedDeviceId, 'requestedDeviceId');
    _requireIdentifier(publicKeyId, 'publicKeyId');
    if (displayName.isEmpty || displayName.length > 120) {
      throw ArgumentError.value(
        displayName,
        'displayName',
        'Device name must contain 1 to 120 characters.',
      );
    }
    _requireDecodedLength(publicKeyBase64, 32, 'publicKeyBase64');
  }

  final String requestedDeviceId;
  final String displayName;
  final String publicKeyId;
  final String publicKeyBase64;
  final DeviceKeyAgreementAlgorithm keyAgreementAlgorithm;
}

final class SyncDevice {
  SyncDevice({
    required this.id,
    required this.accountId,
    required this.displayName,
    required this.registeredAt,
    required this.publicKeyId,
    required this.publicKeyBase64,
    this.keyAgreementAlgorithm = DeviceKeyAgreementAlgorithm.x25519,
    this.status = SyncDeviceStatus.active,
    this.revokedAt,
  }) {
    _requireIdentifier(id, 'id');
    _requireIdentifier(accountId, 'accountId');
    _requireIdentifier(publicKeyId, 'publicKeyId');
    if (displayName.isEmpty || displayName.length > 120) {
      throw ArgumentError.value(
        displayName,
        'displayName',
        'Device name must contain 1 to 120 characters.',
      );
    }
    _requireUtc(registeredAt, 'registeredAt');
    _requireDecodedLength(publicKeyBase64, 32, 'publicKeyBase64');
    if (status == SyncDeviceStatus.revoked && revokedAt == null) {
      throw ArgumentError('A revoked device requires revokedAt.');
    }
    if (status != SyncDeviceStatus.revoked && revokedAt != null) {
      throw ArgumentError('Only a revoked device may have revokedAt.');
    }
    if (revokedAt != null) {
      _requireUtc(revokedAt!, 'revokedAt');
      if (revokedAt!.isBefore(registeredAt)) {
        throw ArgumentError('revokedAt cannot precede registeredAt.');
      }
    }
  }

  final String id;
  final String accountId;
  final String displayName;
  final DateTime registeredAt;
  final String publicKeyId;
  final String publicKeyBase64;
  final DeviceKeyAgreementAlgorithm keyAgreementAlgorithm;
  final SyncDeviceStatus status;
  final DateTime? revokedAt;

  bool get canSync => status == SyncDeviceStatus.active;
}

enum SyncDataKeyAlgorithm { aes256Gcm }

enum SyncKeyWrappingAlgorithm { x25519HkdfSha256Aes256Gcm }

final class SyncDataKeyDescriptor {
  SyncDataKeyDescriptor({
    required this.id,
    required this.accountId,
    required this.version,
    required this.createdAt,
    this.algorithm = SyncDataKeyAlgorithm.aes256Gcm,
    this.retiredAt,
  }) {
    _requireIdentifier(id, 'id');
    _requireIdentifier(accountId, 'accountId');
    if (version <= 0) {
      throw ArgumentError.value(version, 'version', 'Must be positive.');
    }
    _requireUtc(createdAt, 'createdAt');
    if (retiredAt != null) {
      _requireUtc(retiredAt!, 'retiredAt');
      if (retiredAt!.isBefore(createdAt)) {
        throw ArgumentError('retiredAt cannot precede createdAt.');
      }
    }
  }

  final String id;
  final String accountId;
  final int version;
  final DateTime createdAt;
  final SyncDataKeyAlgorithm algorithm;
  final DateTime? retiredAt;
}

final class WrappedSyncDataKey {
  WrappedSyncDataKey({
    required this.accountId,
    required this.dataKeyId,
    required this.recipientDeviceId,
    required this.senderDeviceId,
    required this.ephemeralPublicKeyBase64,
    required this.nonceBase64,
    required this.ciphertextBase64,
    required this.authenticationTagBase64,
    this.protocolVersion = SyncProtocol.currentVersion,
    this.algorithm = SyncKeyWrappingAlgorithm.x25519HkdfSha256Aes256Gcm,
  }) {
    if (!SyncProtocol.supports(protocolVersion)) {
      throw ArgumentError.value(protocolVersion, 'protocolVersion');
    }
    _requireIdentifier(accountId, 'accountId');
    _requireIdentifier(dataKeyId, 'dataKeyId');
    _requireIdentifier(recipientDeviceId, 'recipientDeviceId');
    _requireIdentifier(senderDeviceId, 'senderDeviceId');
    _requireDecodedLength(
      ephemeralPublicKeyBase64,
      32,
      'ephemeralPublicKeyBase64',
    );
    _requireDecodedLength(nonceBase64, 12, 'nonceBase64');
    _requireNonEmptyBase64(ciphertextBase64, 'ciphertextBase64');
    _requireDecodedLength(
      authenticationTagBase64,
      16,
      'authenticationTagBase64',
    );
  }

  final int protocolVersion;
  final String accountId;
  final String dataKeyId;
  final String recipientDeviceId;
  final String senderDeviceId;
  final String ephemeralPublicKeyBase64;
  final String nonceBase64;
  final String ciphertextBase64;
  final String authenticationTagBase64;
  final SyncKeyWrappingAlgorithm algorithm;

  String get associatedData => <String>[
        'river-sync-key-wrap-v$protocolVersion',
        _canonicalPart(accountId),
        _canonicalPart(dataKeyId),
        _canonicalPart(recipientDeviceId),
        _canonicalPart(senderDeviceId),
        algorithm.name,
        ephemeralPublicKeyBase64,
      ].join('|');
}

enum SyncObjectKind {
  subscription,
  folder,
  articleState,
  readerSettings,
  audioProgress,
  knowledgeMetadata,
}

enum SyncPayloadKind { upsert, tombstone }

final class EncryptedSyncEnvelope {
  EncryptedSyncEnvelope({
    required this.mutationId,
    required this.accountId,
    required this.objectKind,
    required this.objectId,
    required this.payloadKind,
    required this.dataKeyId,
    required this.authorDeviceId,
    required this.versionVector,
    required this.occurredAt,
    required this.nonceBase64,
    required this.ciphertextBase64,
    required this.authenticationTagBase64,
    this.protocolVersion = SyncProtocol.currentVersion,
  }) {
    if (!SyncProtocol.supports(protocolVersion)) {
      throw ArgumentError.value(
        protocolVersion,
        'protocolVersion',
        'Unsupported sync protocol version.',
      );
    }
    _requireIdentifier(mutationId, 'mutationId');
    _requireIdentifier(accountId, 'accountId');
    _requireIdentifier(objectId, 'objectId');
    _requireIdentifier(dataKeyId, 'dataKeyId');
    _requireIdentifier(authorDeviceId, 'authorDeviceId');
    _requireUtc(occurredAt, 'occurredAt');
    if (versionVector.counterFor(authorDeviceId) <= 0) {
      throw ArgumentError(
        'The version vector must include the author device.',
      );
    }
    _requireDecodedLength(nonceBase64, 12, 'nonceBase64');
    _requireNonEmptyBase64(ciphertextBase64, 'ciphertextBase64');
    _requireDecodedLength(
      authenticationTagBase64,
      16,
      'authenticationTagBase64',
    );
    if (estimatedEncodedBytes > SyncProtocol.maximumEnvelopeBytes) {
      throw ArgumentError('Encrypted envelope exceeds the protocol limit.');
    }
  }

  final int protocolVersion;
  final String mutationId;
  final String accountId;
  final SyncObjectKind objectKind;
  final String objectId;
  final SyncPayloadKind payloadKind;
  final String dataKeyId;
  final String authorDeviceId;
  final VersionVector versionVector;
  final DateTime occurredAt;
  final String nonceBase64;
  final String ciphertextBase64;
  final String authenticationTagBase64;

  int get estimatedEncodedBytes =>
      utf8.encode(associatedData).length +
      base64.decode(nonceBase64).length +
      base64.decode(ciphertextBase64).length +
      base64.decode(authenticationTagBase64).length;

  String get associatedData => <String>[
        'river-sync-v$protocolVersion',
        _canonicalPart(accountId),
        objectKind.name,
        _canonicalPart(objectId),
        payloadKind.name,
        _canonicalPart(dataKeyId),
        _canonicalPart(authorDeviceId),
        versionVector.toCanonicalString(),
        occurredAt.toIso8601String(),
        _canonicalPart(mutationId),
      ].join('|');
}

final class SyncTombstone {
  SyncTombstone({
    required this.objectKind,
    required this.objectId,
    required this.deletedAt,
    required this.deletedByDeviceId,
    required this.versionVector,
  }) {
    _requireIdentifier(objectId, 'objectId');
    _requireIdentifier(deletedByDeviceId, 'deletedByDeviceId');
    _requireUtc(deletedAt, 'deletedAt');
    if (versionVector.counterFor(deletedByDeviceId) <= 0) {
      throw ArgumentError(
        'The tombstone vector must include the deleting device.',
      );
    }
  }

  final SyncObjectKind objectKind;
  final String objectId;
  final DateTime deletedAt;
  final String deletedByDeviceId;
  final VersionVector versionVector;
}

final class SyncCursor {
  SyncCursor({
    required this.serverSequence,
    required this.opaqueToken,
    this.protocolVersion = SyncProtocol.currentVersion,
  }) {
    if (!SyncProtocol.supports(protocolVersion)) {
      throw ArgumentError.value(protocolVersion, 'protocolVersion');
    }
    if (serverSequence < 0) {
      throw ArgumentError.value(serverSequence, 'serverSequence');
    }
    if (opaqueToken.length > 4096) {
      throw ArgumentError.value(opaqueToken, 'opaqueToken', 'Token too long.');
    }
  }

  factory SyncCursor.initial() =>
      SyncCursor(serverSequence: 0, opaqueToken: '');

  final int protocolVersion;
  final int serverSequence;
  final String opaqueToken;

  bool canAdvanceTo(SyncCursor next) =>
      protocolVersion == next.protocolVersion &&
      next.serverSequence >= serverSequence;
}

final class SyncPushBatch {
  SyncPushBatch({
    required this.accountId,
    required this.deviceId,
    required this.baseCursor,
    required List<EncryptedSyncEnvelope> envelopes,
  }) : envelopes = List<EncryptedSyncEnvelope>.unmodifiable(envelopes) {
    _requireIdentifier(accountId, 'accountId');
    _requireIdentifier(deviceId, 'deviceId');
    if (envelopes.isEmpty ||
        envelopes.length > SyncProtocol.maximumBatchItems) {
      throw ArgumentError.value(
        envelopes.length,
        'envelopes',
        'Batch must contain 1 to ${SyncProtocol.maximumBatchItems} items.',
      );
    }
    final mutationIds = <String>{};
    for (final envelope in envelopes) {
      if (envelope.accountId != accountId ||
          envelope.authorDeviceId != deviceId) {
        throw ArgumentError('Batch envelope scope does not match the batch.');
      }
      if (!mutationIds.add(envelope.mutationId)) {
        throw ArgumentError('Duplicate mutation id in push batch.');
      }
    }
  }

  final String accountId;
  final String deviceId;
  final SyncCursor baseCursor;
  final List<EncryptedSyncEnvelope> envelopes;
}

final class SyncPullRequest {
  SyncPullRequest({
    required this.accountId,
    required this.deviceId,
    required this.cursor,
    this.limit = SyncProtocol.maximumBatchItems,
  }) {
    _requireIdentifier(accountId, 'accountId');
    _requireIdentifier(deviceId, 'deviceId');
    if (limit <= 0 || limit > SyncProtocol.maximumBatchItems) {
      throw ArgumentError.value(limit, 'limit');
    }
  }

  final String accountId;
  final String deviceId;
  final SyncCursor cursor;
  final int limit;
}

final class SyncPullPage {
  SyncPullPage({
    required this.previousCursor,
    required this.nextCursor,
    required List<EncryptedSyncEnvelope> envelopes,
    required this.hasMore,
  }) : envelopes = List<EncryptedSyncEnvelope>.unmodifiable(envelopes) {
    if (!previousCursor.canAdvanceTo(nextCursor)) {
      throw ArgumentError('A pull page cannot move its cursor backwards.');
    }
    if (envelopes.length > SyncProtocol.maximumBatchItems) {
      throw ArgumentError('Pull page exceeds the protocol batch limit.');
    }
  }

  final SyncCursor previousCursor;
  final SyncCursor nextCursor;
  final List<EncryptedSyncEnvelope> envelopes;
  final bool hasMore;
}

void _requireIdentifier(String value, String name) {
  if (value.isEmpty || value.trim() != value || value.length > 256) {
    throw ArgumentError.value(value, name, 'Invalid identifier.');
  }
}

void _requireUtc(DateTime value, String name) {
  if (!value.isUtc) {
    throw ArgumentError.value(value, name, 'Timestamp must be UTC.');
  }
}

void _requireNonEmptyBase64(String value, String name) {
  final decoded = _decodeCanonicalBase64(value, name);
  if (decoded.isEmpty) {
    throw ArgumentError.value(value, name, 'Value must not be empty.');
  }
}

void _requireDecodedLength(String value, int length, String name) {
  final decoded = _decodeCanonicalBase64(value, name);
  if (decoded.length != length) {
    throw ArgumentError.value(
      value,
      name,
      'Decoded value must contain $length bytes.',
    );
  }
}

List<int> _decodeCanonicalBase64(String value, String name) {
  try {
    final decoded = base64.decode(value);
    if (base64.encode(decoded) != value) {
      throw ArgumentError.value(
        value,
        name,
        'Value must use canonical padded base64.',
      );
    }
    return decoded;
  } on FormatException {
    throw ArgumentError.value(value, name, 'Value must be canonical base64.');
  }
}

String _canonicalPart(String value) => Uri.encodeComponent(value);
