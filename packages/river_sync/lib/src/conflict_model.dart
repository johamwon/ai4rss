import 'sync_protocol.dart';
import 'version_vector.dart';

enum ConcurrentUpdatePolicy {
  fieldWiseLastWriterWins,
  semanticArticleStateMerge,
  lastWriterWins,
  furthestProgress,
}

enum ConcurrentTombstonePolicy { tombstoneWins, updateWins, manualResolution }

final class SyncObjectConflictRule {
  const SyncObjectConflictRule({
    required this.concurrentUpdates,
    required this.concurrentTombstone,
  });

  final ConcurrentUpdatePolicy concurrentUpdates;
  final ConcurrentTombstonePolicy concurrentTombstone;
}

abstract final class SyncConflictModel {
  static const Map<SyncObjectKind, SyncObjectConflictRule> rules =
      <SyncObjectKind, SyncObjectConflictRule>{
    SyncObjectKind.subscription: SyncObjectConflictRule(
      concurrentUpdates: ConcurrentUpdatePolicy.fieldWiseLastWriterWins,
      concurrentTombstone: ConcurrentTombstonePolicy.tombstoneWins,
    ),
    SyncObjectKind.folder: SyncObjectConflictRule(
      concurrentUpdates: ConcurrentUpdatePolicy.fieldWiseLastWriterWins,
      concurrentTombstone: ConcurrentTombstonePolicy.tombstoneWins,
    ),
    SyncObjectKind.articleState: SyncObjectConflictRule(
      concurrentUpdates: ConcurrentUpdatePolicy.semanticArticleStateMerge,
      concurrentTombstone: ConcurrentTombstonePolicy.updateWins,
    ),
    SyncObjectKind.readerSettings: SyncObjectConflictRule(
      concurrentUpdates: ConcurrentUpdatePolicy.lastWriterWins,
      concurrentTombstone: ConcurrentTombstonePolicy.updateWins,
    ),
    SyncObjectKind.audioProgress: SyncObjectConflictRule(
      concurrentUpdates: ConcurrentUpdatePolicy.furthestProgress,
      concurrentTombstone: ConcurrentTombstonePolicy.updateWins,
    ),
    SyncObjectKind.knowledgeMetadata: SyncObjectConflictRule(
      concurrentUpdates: ConcurrentUpdatePolicy.fieldWiseLastWriterWins,
      concurrentTombstone: ConcurrentTombstonePolicy.tombstoneWins,
    ),
  };

  static SyncObjectConflictRule ruleFor(SyncObjectKind kind) => rules[kind]!;
}

enum SyncEnvelopeDecision {
  identical,
  keepLocal,
  acceptRemote,
  mergeConcurrentPayloads,
  keepTombstone,
}

final class SyncEnvelopeConflict {
  const SyncEnvelopeConflict({
    required this.relation,
    required this.decision,
    required this.rule,
    required this.winner,
  }) : assert(
          decision == SyncEnvelopeDecision.mergeConcurrentPayloads
              ? winner == null
              : winner != null,
        );

  final VersionVectorRelation relation;
  final SyncEnvelopeDecision decision;
  final SyncObjectConflictRule rule;
  final EncryptedSyncEnvelope? winner;
}

SyncEnvelopeConflict classifyEnvelopeConflict({
  required EncryptedSyncEnvelope local,
  required EncryptedSyncEnvelope remote,
}) {
  if (local.accountId != remote.accountId ||
      local.objectKind != remote.objectKind ||
      local.objectId != remote.objectId) {
    throw ArgumentError('Only versions of the same sync object can conflict.');
  }
  final rule = SyncConflictModel.ruleFor(local.objectKind);
  final relation = local.versionVector.relationTo(remote.versionVector);
  switch (relation) {
    case VersionVectorRelation.dominates:
      return SyncEnvelopeConflict(
        relation: relation,
        decision: SyncEnvelopeDecision.keepLocal,
        rule: rule,
        winner: local,
      );
    case VersionVectorRelation.dominatedBy:
      return SyncEnvelopeConflict(
        relation: relation,
        decision: SyncEnvelopeDecision.acceptRemote,
        rule: rule,
        winner: remote,
      );
    case VersionVectorRelation.equal:
      if (local.mutationId == remote.mutationId) {
        return SyncEnvelopeConflict(
          relation: relation,
          decision: SyncEnvelopeDecision.identical,
          rule: rule,
          winner: local,
        );
      }
      final winner = _lastWriter(local, remote);
      return SyncEnvelopeConflict(
        relation: relation,
        decision: identical(winner, local)
            ? SyncEnvelopeDecision.keepLocal
            : SyncEnvelopeDecision.acceptRemote,
        rule: rule,
        winner: winner,
      );
    case VersionVectorRelation.concurrent:
      final tombstoneResult = _classifyConcurrentTombstone(
        local: local,
        remote: remote,
        rule: rule,
      );
      return SyncEnvelopeConflict(
        relation: relation,
        decision: tombstoneResult?.decision ??
            SyncEnvelopeDecision.mergeConcurrentPayloads,
        rule: rule,
        winner: tombstoneResult?.winner,
      );
  }
}

EncryptedSyncEnvelope deterministicLastWriter(
  EncryptedSyncEnvelope left,
  EncryptedSyncEnvelope right,
) =>
    _lastWriter(left, right);

({SyncEnvelopeDecision decision, EncryptedSyncEnvelope winner})?
    _classifyConcurrentTombstone({
  required EncryptedSyncEnvelope local,
  required EncryptedSyncEnvelope remote,
  required SyncObjectConflictRule rule,
}) {
  if (local.payloadKind == remote.payloadKind) return null;
  final tombstone =
      local.payloadKind == SyncPayloadKind.tombstone ? local : remote;
  final update = identical(tombstone, local) ? remote : local;
  switch (rule.concurrentTombstone) {
    case ConcurrentTombstonePolicy.tombstoneWins:
      return (
        decision: SyncEnvelopeDecision.keepTombstone,
        winner: tombstone,
      );
    case ConcurrentTombstonePolicy.updateWins:
      return (
        decision: identical(update, local)
            ? SyncEnvelopeDecision.keepLocal
            : SyncEnvelopeDecision.acceptRemote,
        winner: update,
      );
    case ConcurrentTombstonePolicy.manualResolution:
      return null;
  }
}

EncryptedSyncEnvelope _lastWriter(
  EncryptedSyncEnvelope left,
  EncryptedSyncEnvelope right,
) {
  final timestamp = left.occurredAt.compareTo(right.occurredAt);
  if (timestamp > 0) return left;
  if (timestamp < 0) return right;
  final device = left.authorDeviceId.compareTo(right.authorDeviceId);
  if (device > 0) return left;
  if (device < 0) return right;
  return left.mutationId.compareTo(right.mutationId) >= 0 ? left : right;
}
