import 'dart:convert';

import 'conflict_model.dart';
import 'sync_payload.dart';
import 'sync_protocol.dart';
import 'version_vector.dart';

enum SyncConflictResolutionKind { local, remote, merged, unresolved }

final class SyncPayloadConflictResolution {
  const SyncPayloadConflictResolution._({
    required this.kind,
    this.mergedPayload,
  }) : assert(
          kind == SyncConflictResolutionKind.merged
              ? mergedPayload != null
              : mergedPayload == null,
        );

  const SyncPayloadConflictResolution.local()
      : this._(kind: SyncConflictResolutionKind.local);

  const SyncPayloadConflictResolution.remote()
      : this._(kind: SyncConflictResolutionKind.remote);

  const SyncPayloadConflictResolution.merged(
    DecodedSyncPayload payload,
  ) : this._(
          kind: SyncConflictResolutionKind.merged,
          mergedPayload: payload,
        );

  const SyncPayloadConflictResolution.unresolved()
      : this._(kind: SyncConflictResolutionKind.unresolved);

  final SyncConflictResolutionKind kind;
  final DecodedSyncPayload? mergedPayload;
}

final class SyncPayloadConflictResolver {
  const SyncPayloadConflictResolver();

  SyncPayloadConflictResolution resolve({
    required EncryptedSyncEnvelope localEnvelope,
    required DecodedSyncPayload localPayload,
    required EncryptedSyncEnvelope remoteEnvelope,
    required DecodedSyncPayload remotePayload,
  }) {
    _requireSameObject(
      localEnvelope: localEnvelope,
      localPayload: localPayload,
      remoteEnvelope: remoteEnvelope,
      remotePayload: remotePayload,
    );
    final relation =
        localEnvelope.versionVector.relationTo(remoteEnvelope.versionVector);
    if (relation != VersionVectorRelation.concurrent) {
      final winner = deterministicLastWriter(localEnvelope, remoteEnvelope);
      return identical(winner, localEnvelope)
          ? const SyncPayloadConflictResolution.local()
          : const SyncPayloadConflictResolution.remote();
    }
    if (localPayload.payloadKind != remotePayload.payloadKind) {
      return _resolveTombstone(
        localEnvelope: localEnvelope,
        localPayload: localPayload,
        remoteEnvelope: remoteEnvelope,
        remotePayload: remotePayload,
      );
    }
    if (localPayload is DecodedSyncTombstone &&
        remotePayload is DecodedSyncTombstone) {
      final winner = deterministicLastWriter(localEnvelope, remoteEnvelope);
      return identical(winner, localEnvelope)
          ? const SyncPayloadConflictResolution.local()
          : const SyncPayloadConflictResolution.remote();
    }
    if (localPayload is! DecodedSyncUpsert ||
        remotePayload is! DecodedSyncUpsert) {
      return const SyncPayloadConflictResolution.unresolved();
    }
    return switch (localEnvelope.objectKind) {
      SyncObjectKind.subscription ||
      SyncObjectKind.folder ||
      SyncObjectKind.knowledgeMetadata =>
        _fieldWise(
          localEnvelope: localEnvelope,
          local: localPayload.payload,
          remoteEnvelope: remoteEnvelope,
          remote: remotePayload.payload,
        ),
      SyncObjectKind.articleState => _articleState(
          localEnvelope: localEnvelope,
          local: localPayload.payload,
          remoteEnvelope: remoteEnvelope,
          remote: remotePayload.payload,
        ),
      SyncObjectKind.readerSettings => _recordWinner(
          localEnvelope,
          remoteEnvelope,
        ),
      SyncObjectKind.audioProgress => _audioProgress(
          localEnvelope: localEnvelope,
          local: localPayload.payload,
          remoteEnvelope: remoteEnvelope,
          remote: remotePayload.payload,
        ),
    };
  }

  SyncPayloadConflictResolution _resolveTombstone({
    required EncryptedSyncEnvelope localEnvelope,
    required DecodedSyncPayload localPayload,
    required EncryptedSyncEnvelope remoteEnvelope,
    required DecodedSyncPayload remotePayload,
  }) {
    final rule = SyncConflictModel.ruleFor(localEnvelope.objectKind);
    final tombstoneIsLocal =
        localPayload.payloadKind == SyncPayloadKind.tombstone;
    return switch (rule.concurrentTombstone) {
      ConcurrentTombstonePolicy.tombstoneWins => tombstoneIsLocal
          ? const SyncPayloadConflictResolution.local()
          : const SyncPayloadConflictResolution.remote(),
      ConcurrentTombstonePolicy.updateWins => tombstoneIsLocal
          ? const SyncPayloadConflictResolution.remote()
          : const SyncPayloadConflictResolution.local(),
      ConcurrentTombstonePolicy.manualResolution =>
        const SyncPayloadConflictResolution.unresolved(),
    };
  }

  SyncPayloadConflictResolution _fieldWise({
    required EncryptedSyncEnvelope localEnvelope,
    required SyncObjectPayload local,
    required EncryptedSyncEnvelope remoteEnvelope,
    required SyncObjectPayload remote,
  }) {
    final fields = <String, Object?>{};
    final versions = <String, SyncFieldVersion>{};
    for (final field in local.fields.keys) {
      final winner = _chooseLater(
        localValue: local.fields[field],
        localVersion: _version(local, field, localEnvelope),
        remoteValue: remote.fields[field],
        remoteVersion: _version(remote, field, remoteEnvelope),
      );
      fields[field] = winner.value;
      versions[field] = winner.version;
    }
    return _mergedOrExisting(
      local: local,
      remote: remote,
      merged: SyncObjectPayload.fromFields(
        objectKind: local.objectKind,
        objectId: local.objectId,
        fields: fields,
        fieldVersions: versions,
      ),
    );
  }

  SyncPayloadConflictResolution _articleState({
    required EncryptedSyncEnvelope localEnvelope,
    required SyncObjectPayload local,
    required EncryptedSyncEnvelope remoteEnvelope,
    required SyncObjectPayload remote,
  }) {
    final fields = <String, Object?>{};
    final versions = <String, SyncFieldVersion>{};
    void chooseLater(String field) {
      final winner = _chooseLater(
        localValue: local.fields[field],
        localVersion: _version(local, field, localEnvelope),
        remoteValue: remote.fields[field],
        remoteVersion: _version(remote, field, remoteEnvelope),
      );
      fields[field] = winner.value;
      versions[field] = winner.version;
    }

    void chooseMaximum(String field) {
      final localValue = local.fields[field]! as num;
      final remoteValue = remote.fields[field]! as num;
      final winner = localValue > remoteValue
          ? (
              value: local.fields[field],
              version: _version(local, field, localEnvelope),
            )
          : remoteValue > localValue
              ? (
                  value: remote.fields[field],
                  version: _version(remote, field, remoteEnvelope),
                )
              : _chooseLater(
                  localValue: local.fields[field],
                  localVersion: _version(local, field, localEnvelope),
                  remoteValue: remote.fields[field],
                  remoteVersion: _version(remote, field, remoteEnvelope),
                );
      fields[field] = winner.value;
      versions[field] = winner.version;
    }

    final localRead = local.fields['read']! as bool;
    final remoteRead = remote.fields['read']! as bool;
    if (localRead != remoteRead) {
      final source = localRead
          ? (
              value: localRead,
              version: _version(local, 'read', localEnvelope),
            )
          : (
              value: remoteRead,
              version: _version(remote, 'read', remoteEnvelope),
            );
      fields['read'] = source.value;
      versions['read'] = source.version;
    } else {
      chooseLater('read');
    }
    chooseLater('starred');
    chooseLater('readLater');
    chooseMaximum('activeReadSeconds');
    chooseMaximum('scrollDepth');
    final localCompleted = _date(local.fields['completedAt']);
    final remoteCompleted = _date(remote.fields['completedAt']);
    if (localCompleted == null && remoteCompleted != null) {
      fields['completedAt'] = remote.fields['completedAt'];
      versions['completedAt'] = _version(remote, 'completedAt', remoteEnvelope);
    } else if (remoteCompleted == null && localCompleted != null) {
      fields['completedAt'] = local.fields['completedAt'];
      versions['completedAt'] = _version(local, 'completedAt', localEnvelope);
    } else if (localCompleted != null &&
        remoteCompleted != null &&
        localCompleted != remoteCompleted) {
      final takeLocal = localCompleted.isAfter(remoteCompleted);
      fields['completedAt'] = takeLocal
          ? local.fields['completedAt']
          : remote.fields['completedAt'];
      versions['completedAt'] = takeLocal
          ? _version(local, 'completedAt', localEnvelope)
          : _version(remote, 'completedAt', remoteEnvelope);
    } else {
      chooseLater('completedAt');
    }
    return _mergedOrExisting(
      local: local,
      remote: remote,
      merged: SyncObjectPayload.fromFields(
        objectKind: local.objectKind,
        objectId: local.objectId,
        fields: fields,
        fieldVersions: versions,
      ),
    );
  }

  SyncPayloadConflictResolution _mergedOrExisting({
    required SyncObjectPayload local,
    required SyncObjectPayload remote,
    required SyncObjectPayload merged,
  }) {
    if (_samePayload(merged, local)) {
      return const SyncPayloadConflictResolution.local();
    }
    if (_samePayload(merged, remote)) {
      return const SyncPayloadConflictResolution.remote();
    }
    return SyncPayloadConflictResolution.merged(
      DecodedSyncUpsert(merged),
    );
  }

  SyncPayloadConflictResolution _recordWinner(
    EncryptedSyncEnvelope local,
    EncryptedSyncEnvelope remote,
  ) {
    final winner = deterministicLastWriter(local, remote);
    return identical(winner, local)
        ? const SyncPayloadConflictResolution.local()
        : const SyncPayloadConflictResolution.remote();
  }

  SyncPayloadConflictResolution _audioProgress({
    required EncryptedSyncEnvelope localEnvelope,
    required SyncObjectPayload local,
    required EncryptedSyncEnvelope remoteEnvelope,
    required SyncObjectPayload remote,
  }) {
    if (local.fields['itemKind'] != remote.fields['itemKind'] ||
        local.fields['contentRevision'] != remote.fields['contentRevision']) {
      return _recordWinner(localEnvelope, remoteEnvelope);
    }
    final localPoint = _audioPoint(local);
    final remotePoint = _audioPoint(remote);
    final comparison = _compareAudioPoint(localPoint, remotePoint);
    if (comparison > 0) return const SyncPayloadConflictResolution.local();
    if (comparison < 0) return const SyncPayloadConflictResolution.remote();
    return _recordWinner(localEnvelope, remoteEnvelope);
  }
}

({Object? value, SyncFieldVersion version}) _chooseLater({
  required Object? localValue,
  required SyncFieldVersion localVersion,
  required Object? remoteValue,
  required SyncFieldVersion remoteVersion,
}) {
  final comparison = _compareVersion(localVersion, remoteVersion);
  if (comparison > 0) return (value: localValue, version: localVersion);
  if (comparison < 0) return (value: remoteValue, version: remoteVersion);
  final localCanonical = jsonEncode(localValue);
  final remoteCanonical = jsonEncode(remoteValue);
  return localCanonical.compareTo(remoteCanonical) >= 0
      ? (value: localValue, version: localVersion)
      : (value: remoteValue, version: remoteVersion);
}

int _compareVersion(SyncFieldVersion left, SyncFieldVersion right) {
  final timestamp = left.updatedAt.compareTo(right.updatedAt);
  if (timestamp != 0) return timestamp;
  final device = left.deviceId.compareTo(right.deviceId);
  if (device != 0) return device;
  return left.mutationId.compareTo(right.mutationId);
}

SyncFieldVersion _version(
  SyncObjectPayload payload,
  String field,
  EncryptedSyncEnvelope envelope,
) =>
    payload.fieldVersions[field] ??
    SyncFieldVersion(
      updatedAt: envelope.occurredAt,
      deviceId: envelope.authorDeviceId,
      mutationId: envelope.mutationId,
    );

bool _samePayload(SyncObjectPayload left, SyncObjectPayload right) {
  if (left.objectKind != right.objectKind ||
      left.objectId != right.objectId ||
      left.fields.length != right.fields.length ||
      left.fieldVersions.length != right.fieldVersions.length) {
    return false;
  }
  for (final field in left.fields.keys) {
    if (!_valueEquals(left.fields[field], right.fields[field]) ||
        left.fieldVersions[field] != right.fieldVersions[field]) {
      return false;
    }
  }
  return true;
}

bool _valueEquals(Object? left, Object? right) {
  if (identical(left, right) || left == right) return true;
  if (left is List<Object?> && right is List<Object?>) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index += 1) {
      if (!_valueEquals(left[index], right[index])) return false;
    }
    return true;
  }
  if (left is Map<Object?, Object?> && right is Map<Object?, Object?>) {
    if (left.length != right.length) return false;
    for (final entry in left.entries) {
      if (!right.containsKey(entry.key) ||
          !_valueEquals(entry.value, right[entry.key])) {
        return false;
      }
    }
    return true;
  }
  return false;
}

DateTime? _date(Object? value) =>
    value == null ? null : DateTime.parse(value as String);

({int segment, int character, int position}) _audioPoint(
  SyncObjectPayload payload,
) =>
    (
      segment: (payload.fields['segmentIndex'] as int?) ?? 0,
      character: (payload.fields['characterOffset'] as int?) ?? 0,
      position: payload.fields['positionMs']! as int,
    );

int _compareAudioPoint(
  ({int segment, int character, int position}) left,
  ({int segment, int character, int position}) right,
) {
  final segment = left.segment.compareTo(right.segment);
  if (segment != 0) return segment;
  final character = left.character.compareTo(right.character);
  if (character != 0) return character;
  return left.position.compareTo(right.position);
}

void _requireSameObject({
  required EncryptedSyncEnvelope localEnvelope,
  required DecodedSyncPayload localPayload,
  required EncryptedSyncEnvelope remoteEnvelope,
  required DecodedSyncPayload remotePayload,
}) {
  if (localEnvelope.accountId != remoteEnvelope.accountId ||
      localEnvelope.objectKind != remoteEnvelope.objectKind ||
      localEnvelope.objectId != remoteEnvelope.objectId ||
      localPayload.objectKind != localEnvelope.objectKind ||
      localPayload.objectId != localEnvelope.objectId ||
      remotePayload.objectKind != remoteEnvelope.objectKind ||
      remotePayload.objectId != remoteEnvelope.objectId) {
    throw ArgumentError('Conflict payloads must describe the same object.');
  }
}
