import 'conflict_model.dart';
import 'sync_auth.dart';
import 'sync_crypto.dart';
import 'sync_payload.dart';
import 'sync_protocol.dart';
import 'version_vector.dart';

final class SyncReplicaRecord {
  SyncReplicaRecord({
    required this.envelope,
    required this.decodedPayload,
  }) {
    if (decodedPayload.objectKind != envelope.objectKind ||
        decodedPayload.objectId != envelope.objectId ||
        decodedPayload.payloadKind != envelope.payloadKind) {
      throw ArgumentError(
        'Decrypted payload metadata must match its authenticated envelope.',
      );
    }
    if (decodedPayload case DecodedSyncTombstone(:final tombstone)) {
      if (tombstone.deletedByDeviceId != envelope.authorDeviceId ||
          tombstone.deletedAt != envelope.occurredAt) {
        throw ArgumentError(
          'Tombstone author and time must match its authenticated envelope.',
        );
      }
    }
  }

  final EncryptedSyncEnvelope envelope;
  final DecodedSyncPayload decodedPayload;
}

enum SyncIncomingAction { accept, ignore, conflict }

final class SyncIncomingRecord {
  const SyncIncomingRecord({
    required this.record,
    required this.action,
  });

  final SyncReplicaRecord record;
  final SyncIncomingAction action;
}

abstract interface class SyncReplicaStore {
  Future<SyncCursor> readCursor();

  Future<SyncReplicaRecord?> readRecord(
    SyncObjectKind objectKind,
    String objectId,
  );

  /// Atomically stores the local record and appends its envelope to the outbox.
  Future<void> commitLocal(SyncReplicaRecord record);

  Future<List<EncryptedSyncEnvelope>> readOutbox({required int limit});

  /// Removes only the acknowledged mutation IDs from the durable outbox.
  Future<void> acknowledgeOutbox(Set<String> mutationIds);

  /// Atomically applies accepted records, stages conflicts, and advances cursor.
  ///
  /// Implementations must compare their current cursor with [expectedCursor]
  /// inside the same transaction and fail without partial writes on mismatch.
  Future<void> commitRemotePage({
    required SyncCursor expectedCursor,
    required SyncCursor nextCursor,
    required List<SyncIncomingRecord> records,
  });
}

final class SyncPushReceipt {
  SyncPushReceipt({required Set<String> acceptedMutationIds})
      : acceptedMutationIds = Set<String>.unmodifiable(acceptedMutationIds);

  final Set<String> acceptedMutationIds;
}

abstract interface class IncrementalSyncTransport {
  Future<SyncPushReceipt> push({
    required SyncSession session,
    required SyncPushBatch batch,
  });

  Future<SyncPullPage> pull({
    required SyncSession session,
    required SyncPullRequest request,
  });
}

enum SyncTransportFailureCode {
  offline,
  unauthorized,
  rateLimited,
  incompatibleProtocol,
  unexpected,
}

final class SyncTransportException implements Exception {
  const SyncTransportException({
    required this.code,
    this.retryAfter,
  });

  final SyncTransportFailureCode code;
  final Duration? retryAfter;

  bool get retryable => switch (code) {
        SyncTransportFailureCode.offline ||
        SyncTransportFailureCode.rateLimited ||
        SyncTransportFailureCode.unexpected =>
          true,
        SyncTransportFailureCode.unauthorized ||
        SyncTransportFailureCode.incompatibleProtocol =>
          false,
      };

  @override
  String toString() => 'SyncTransportException(${code.name})';
}

abstract interface class IncrementalSyncClock {
  DateTime now();
}

abstract interface class SyncMutationIdSource {
  String nextId();
}

enum IncrementalSyncFailureCode {
  offline,
  unauthorized,
  rateLimited,
  incompatibleProtocol,
  cryptography,
  invalidPayload,
  storage,
  unexpected,
}

sealed class IncrementalSyncResult {
  const IncrementalSyncResult();
}

final class IncrementalSyncSuccess extends IncrementalSyncResult {
  const IncrementalSyncSuccess({
    required this.pushed,
    required this.pulled,
    required this.applied,
    required this.conflicts,
    required this.hasMoreWork,
    required this.cursor,
  });

  final int pushed;
  final int pulled;
  final int applied;
  final int conflicts;
  final bool hasMoreWork;
  final SyncCursor cursor;
}

final class IncrementalSyncFailure extends IncrementalSyncResult {
  const IncrementalSyncFailure({
    required this.code,
    required this.retryable,
    required this.pushed,
    required this.pulled,
    this.retryAfter,
  });

  final IncrementalSyncFailureCode code;
  final bool retryable;
  final int pushed;
  final int pulled;
  final Duration? retryAfter;
}

final class IncrementalSyncController {
  IncrementalSyncController({
    required this.store,
    required this.transport,
    required this.crypto,
    required this.authorizer,
    required this.clock,
    required this.mutationIds,
    this.batchSize = SyncProtocol.maximumBatchItems,
    this.maximumPushPages = 20,
    this.maximumPullPages = 100,
  }) {
    if (batchSize <= 0 || batchSize > SyncProtocol.maximumBatchItems) {
      throw ArgumentError.value(batchSize, 'batchSize');
    }
    if (maximumPushPages <= 0 || maximumPullPages <= 0) {
      throw ArgumentError('Page budgets must be positive.');
    }
  }

  final SyncReplicaStore store;
  final IncrementalSyncTransport transport;
  final SyncCryptoEngine crypto;
  final SyncAuthorizer authorizer;
  final IncrementalSyncClock clock;
  final SyncMutationIdSource mutationIds;
  final int batchSize;
  final int maximumPushPages;
  final int maximumPullPages;

  Future<EncryptedSyncEnvelope> queueUpsert({
    required SyncSession session,
    required SyncDataKeyMaterial dataKey,
    required SyncObjectPayload payload,
  }) async {
    _requireActiveScope(session, dataKey);
    final occurredAt = _now();
    final previous = await store.readRecord(
      payload.objectKind,
      payload.objectId,
    );
    final vector = (previous?.envelope.versionVector ?? VersionVector())
        .incrementedBy(session.deviceId);
    final mutationId = _nextMutationId();
    final envelope = await crypto.encryptEnvelope(
      mutationId: mutationId,
      accountId: session.accountId,
      objectKind: payload.objectKind,
      objectId: payload.objectId,
      payloadKind: SyncPayloadKind.upsert,
      authorDeviceId: session.deviceId,
      versionVector: vector,
      occurredAt: occurredAt,
      clearText: SyncPayloadCodec.encodeUpsert(payload),
      dataKey: dataKey,
    );
    await store.commitLocal(
      SyncReplicaRecord(
        envelope: envelope,
        decodedPayload: DecodedSyncUpsert(payload),
      ),
    );
    return envelope;
  }

  Future<EncryptedSyncEnvelope> queueTombstone({
    required SyncSession session,
    required SyncDataKeyMaterial dataKey,
    required SyncObjectKind objectKind,
    required String objectId,
  }) async {
    _requireActiveScope(session, dataKey);
    final occurredAt = _now();
    final previous = await store.readRecord(objectKind, objectId);
    final vector = (previous?.envelope.versionVector ?? VersionVector())
        .incrementedBy(session.deviceId);
    final mutationId = _nextMutationId();
    final tombstone = SyncTombstoneBody(
      objectKind: objectKind,
      objectId: objectId,
      deletedAt: occurredAt,
      deletedByDeviceId: session.deviceId,
    );
    final envelope = await crypto.encryptEnvelope(
      mutationId: mutationId,
      accountId: session.accountId,
      objectKind: objectKind,
      objectId: objectId,
      payloadKind: SyncPayloadKind.tombstone,
      authorDeviceId: session.deviceId,
      versionVector: vector,
      occurredAt: occurredAt,
      clearText: SyncPayloadCodec.encodeTombstone(tombstone),
      dataKey: dataKey,
    );
    await store.commitLocal(
      SyncReplicaRecord(
        envelope: envelope,
        decodedPayload: DecodedSyncTombstone(tombstone),
      ),
    );
    return envelope;
  }

  Future<IncrementalSyncResult> synchronize({
    required SyncSession session,
    required SyncDataKeyMaterial dataKey,
  }) async {
    var pushed = 0;
    var pulled = 0;
    try {
      final authorization = await authorizer.authorizeSync();
      if (authorization
          case SyncAuthFailure<SyncSession>(
            :final code,
            :final retryable,
            :final retryAfter,
          )) {
        return IncrementalSyncFailure(
          code: _mapAuthFailure(code),
          retryable: retryable,
          retryAfter: retryAfter,
          pushed: 0,
          pulled: 0,
        );
      }
      final activeSession =
          (authorization as SyncAuthSuccess<SyncSession>).value;
      if (activeSession.accountId != session.accountId ||
          activeSession.deviceId != session.deviceId) {
        return const IncrementalSyncFailure(
          code: IncrementalSyncFailureCode.unauthorized,
          retryable: false,
          pushed: 0,
          pulled: 0,
        );
      }
      _requireActiveScope(activeSession, dataKey);
      var pushBudgetExhausted = false;
      for (var pageIndex = 0; pageIndex < maximumPushPages; pageIndex += 1) {
        final pending = await store.readOutbox(limit: batchSize);
        if (pending.isEmpty) break;
        final expectedIds = pending.map((item) => item.mutationId).toSet();
        if (expectedIds.length != pending.length) {
          throw const _SyncProtocolViolation();
        }
        final cursor = await store.readCursor();
        final receipt = await transport.push(
          session: activeSession,
          batch: SyncPushBatch(
            accountId: activeSession.accountId,
            deviceId: activeSession.deviceId,
            baseCursor: cursor,
            envelopes: pending,
          ),
        );
        if (!_sameSet(expectedIds, receipt.acceptedMutationIds)) {
          throw const _SyncProtocolViolation();
        }
        await store.acknowledgeOutbox(receipt.acceptedMutationIds);
        pushed += pending.length;
        if (pageIndex == maximumPushPages - 1) {
          pushBudgetExhausted = (await store.readOutbox(limit: 1)).isNotEmpty;
        }
      }

      var cursor = await store.readCursor();
      var applied = 0;
      var conflicts = 0;
      var pullBudgetExhausted = false;
      for (var pageIndex = 0; pageIndex < maximumPullPages; pageIndex += 1) {
        final page = await transport.pull(
          session: activeSession,
          request: SyncPullRequest(
            accountId: activeSession.accountId,
            deviceId: activeSession.deviceId,
            cursor: cursor,
            limit: batchSize,
          ),
        );
        if (!_sameCursor(page.previousCursor, cursor) ||
            (page.envelopes.isNotEmpty &&
                page.nextCursor.serverSequence <= cursor.serverSequence) ||
            (page.hasMore &&
                page.nextCursor.serverSequence <= cursor.serverSequence)) {
          throw const _SyncProtocolViolation();
        }
        final incoming = await _decodePage(
          accountId: activeSession.accountId,
          dataKey: dataKey,
          envelopes: page.envelopes,
        );
        pulled += incoming.length;
        applied += incoming
            .where((item) => item.action == SyncIncomingAction.accept)
            .length;
        conflicts += incoming
            .where((item) => item.action == SyncIncomingAction.conflict)
            .length;
        await store.commitRemotePage(
          expectedCursor: cursor,
          nextCursor: page.nextCursor,
          records: incoming,
        );
        cursor = page.nextCursor;
        if (!page.hasMore) break;
        if (pageIndex == maximumPullPages - 1) {
          pullBudgetExhausted = true;
        }
      }

      return IncrementalSyncSuccess(
        pushed: pushed,
        pulled: pulled,
        applied: applied,
        conflicts: conflicts,
        hasMoreWork: pushBudgetExhausted || pullBudgetExhausted,
        cursor: cursor,
      );
    } on SyncTransportException catch (error) {
      return IncrementalSyncFailure(
        code: _mapTransportFailure(error.code),
        retryable: error.retryable,
        retryAfter: error.retryAfter,
        pushed: pushed,
        pulled: pulled,
      );
    } on SyncCryptoException {
      return IncrementalSyncFailure(
        code: IncrementalSyncFailureCode.cryptography,
        retryable: false,
        pushed: pushed,
        pulled: pulled,
      );
    } on SyncPayloadException {
      return IncrementalSyncFailure(
        code: IncrementalSyncFailureCode.invalidPayload,
        retryable: false,
        pushed: pushed,
        pulled: pulled,
      );
    } on _SyncProtocolViolation {
      return IncrementalSyncFailure(
        code: IncrementalSyncFailureCode.incompatibleProtocol,
        retryable: false,
        pushed: pushed,
        pulled: pulled,
      );
    } on StateError {
      return IncrementalSyncFailure(
        code: IncrementalSyncFailureCode.storage,
        retryable: true,
        pushed: pushed,
        pulled: pulled,
      );
    } on Object {
      return IncrementalSyncFailure(
        code: IncrementalSyncFailureCode.unexpected,
        retryable: true,
        pushed: pushed,
        pulled: pulled,
      );
    }
  }

  Future<List<SyncIncomingRecord>> _decodePage({
    required String accountId,
    required SyncDataKeyMaterial dataKey,
    required List<EncryptedSyncEnvelope> envelopes,
  }) async {
    final actions = <SyncIncomingRecord>[];
    final shadow = <_SyncObjectKey, SyncReplicaRecord?>{};
    for (final envelope in envelopes) {
      if (envelope.accountId != accountId) {
        throw const _SyncProtocolViolation();
      }
      final clearText = await crypto.decryptEnvelope(
        envelope: envelope,
        dataKey: dataKey,
      );
      try {
        final record = SyncReplicaRecord(
          envelope: envelope,
          decodedPayload: SyncPayloadCodec.decode(clearText),
        );
        final key = _SyncObjectKey(
          objectKind: envelope.objectKind,
          objectId: envelope.objectId,
        );
        final local = shadow.containsKey(key)
            ? shadow[key]
            : await store.readRecord(key.objectKind, key.objectId);
        final action = _classify(local: local, remote: record);
        actions.add(SyncIncomingRecord(record: record, action: action));
        if (action == SyncIncomingAction.accept) shadow[key] = record;
        if (!shadow.containsKey(key)) shadow[key] = local;
      } finally {
        _erase(clearText);
      }
    }
    return List<SyncIncomingRecord>.unmodifiable(actions);
  }

  SyncIncomingAction _classify({
    required SyncReplicaRecord? local,
    required SyncReplicaRecord remote,
  }) {
    if (local == null) return SyncIncomingAction.accept;
    final conflict = classifyEnvelopeConflict(
      local: local.envelope,
      remote: remote.envelope,
    );
    if (conflict.relation == VersionVectorRelation.equal &&
        local.envelope.mutationId != remote.envelope.mutationId) {
      return SyncIncomingAction.conflict;
    }
    return switch (conflict.decision) {
      SyncEnvelopeDecision.identical ||
      SyncEnvelopeDecision.keepLocal =>
        SyncIncomingAction.ignore,
      SyncEnvelopeDecision.acceptRemote => SyncIncomingAction.accept,
      SyncEnvelopeDecision.mergeConcurrentPayloads =>
        SyncIncomingAction.conflict,
      SyncEnvelopeDecision.keepTombstone =>
        identical(conflict.winner, remote.envelope)
            ? SyncIncomingAction.accept
            : SyncIncomingAction.ignore,
    };
  }

  void _requireActiveScope(
    SyncSession session,
    SyncDataKeyMaterial dataKey,
  ) {
    if (session.deviceStatus != SyncDeviceStatus.active ||
        session.isExpiredAt(_now())) {
      throw const SyncTransportException(
        code: SyncTransportFailureCode.unauthorized,
      );
    }
    if (dataKey.descriptor.accountId != session.accountId ||
        dataKey.descriptor.retiredAt != null) {
      throw const SyncCryptoException(SyncCryptoFailureCode.scopeMismatch);
    }
  }

  DateTime _now() {
    final value = clock.now();
    if (!value.isUtc) {
      throw StateError('Incremental sync clock must return UTC.');
    }
    return value;
  }

  String _nextMutationId() {
    final value = mutationIds.nextId();
    if (value.isEmpty || value.trim() != value || value.length > 256) {
      throw StateError('Mutation ID source returned an invalid ID.');
    }
    return value;
  }
}

final class _SyncObjectKey {
  const _SyncObjectKey({
    required this.objectKind,
    required this.objectId,
  });

  final SyncObjectKind objectKind;
  final String objectId;

  @override
  bool operator ==(Object other) =>
      other is _SyncObjectKey &&
      other.objectKind == objectKind &&
      other.objectId == objectId;

  @override
  int get hashCode => Object.hash(objectKind, objectId);
}

final class _SyncProtocolViolation implements Exception {
  const _SyncProtocolViolation();
}

IncrementalSyncFailureCode _mapTransportFailure(
  SyncTransportFailureCode code,
) =>
    switch (code) {
      SyncTransportFailureCode.offline => IncrementalSyncFailureCode.offline,
      SyncTransportFailureCode.unauthorized =>
        IncrementalSyncFailureCode.unauthorized,
      SyncTransportFailureCode.rateLimited =>
        IncrementalSyncFailureCode.rateLimited,
      SyncTransportFailureCode.incompatibleProtocol =>
        IncrementalSyncFailureCode.incompatibleProtocol,
      SyncTransportFailureCode.unexpected =>
        IncrementalSyncFailureCode.unexpected,
    };

IncrementalSyncFailureCode _mapAuthFailure(SyncAuthFailureCode code) =>
    switch (code) {
      SyncAuthFailureCode.offline => IncrementalSyncFailureCode.offline,
      SyncAuthFailureCode.rateLimited => IncrementalSyncFailureCode.rateLimited,
      SyncAuthFailureCode.signedOut ||
      SyncAuthFailureCode.sessionExpired ||
      SyncAuthFailureCode.devicePendingApproval ||
      SyncAuthFailureCode.deviceRevoked ||
      SyncAuthFailureCode.unauthorized =>
        IncrementalSyncFailureCode.unauthorized,
      SyncAuthFailureCode.invalidChallenge ||
      SyncAuthFailureCode.challengeExpired ||
      SyncAuthFailureCode.proofRejected ||
      SyncAuthFailureCode.approvalExpired ||
      SyncAuthFailureCode.cannotRevokeLastDevice ||
      SyncAuthFailureCode.unavailable ||
      SyncAuthFailureCode.unexpected =>
        IncrementalSyncFailureCode.unexpected,
    };

bool _sameSet(Set<String> left, Set<String> right) =>
    left.length == right.length && left.containsAll(right);

bool _sameCursor(SyncCursor left, SyncCursor right) =>
    left.protocolVersion == right.protocolVersion &&
    left.serverSequence == right.serverSequence &&
    left.opaqueToken == right.opaqueToken;

void _erase(List<int> bytes) {
  for (var index = 0; index < bytes.length; index += 1) {
    bytes[index] = 0;
  }
}
