import 'dart:collection';

import 'article_ranking.dart';
import 'preference_profile.dart';

const String rankingGuardrailSchema = 'river.ranking-guardrails';
const int rankingGuardrailModelVersion = 1;

enum RankingSelectionKind {
  organic,
  explorationQuota,
}

final class RankingGuardrailConfig {
  const RankingGuardrailConfig({
    this.modelVersion = rankingGuardrailModelVersion,
    this.maximumSourceShare = 0.5,
    this.minimumExplorationShare = 0.2,
    this.explorationThreshold = 0.7,
    this.strongNegativeThreshold = -3.5,
    this.maximumCandidates = 10000,
    this.maximumResults = 500,
  });

  final int modelVersion;
  final double maximumSourceShare;
  final double minimumExplorationShare;
  final double explorationThreshold;
  final double strongNegativeThreshold;
  final int maximumCandidates;
  final int maximumResults;

  void validate() {
    if (modelVersion != rankingGuardrailModelVersion ||
        !_isFiniteFraction(maximumSourceShare) ||
        maximumSourceShare <= 0 ||
        !_isFiniteFraction(minimumExplorationShare) ||
        !_isFiniteFraction(explorationThreshold) ||
        !strongNegativeThreshold.isFinite ||
        strongNegativeThreshold >= 0 ||
        maximumCandidates <= 0 ||
        maximumCandidates > 100000 ||
        maximumResults <= 0 ||
        maximumResults > maximumCandidates) {
      throw const FormatException('Invalid ranking guardrail configuration.');
    }
  }
}

final class GuardedRankedCandidate {
  const GuardedRankedCandidate({
    required this.ranked,
    required this.selectionKind,
  });

  final RankedArticleCandidate ranked;
  final RankingSelectionKind selectionKind;
}

final class GuardedRankingResult {
  GuardedRankingResult._({
    required Iterable<GuardedRankedCandidate> items,
    required this.modelVersion,
    required this.requestedLimit,
    required this.eligibleCandidateCount,
    required this.maximumItemsPerSource,
    required this.maximumSourceShare,
    required this.explorationTarget,
    required this.eligibleExplorationCount,
    required this.explorationThreshold,
    required this.filteredByBlockedTopic,
    required this.filteredByNegativeFeedback,
  }) : items = List<GuardedRankedCandidate>.unmodifiable(items);

  final List<GuardedRankedCandidate> items;
  final int modelVersion;
  final int requestedLimit;
  final int eligibleCandidateCount;
  final int maximumItemsPerSource;
  final double maximumSourceShare;
  final int explorationTarget;
  final int eligibleExplorationCount;
  final double explorationThreshold;
  final int filteredByBlockedTopic;
  final int filteredByNegativeFeedback;

  String get modelId => '$rankingGuardrailSchema/$modelVersion';

  int get explorationCount => items
      .where(
        (item) =>
            item.ranked.candidate.explorationProbability >=
            explorationThreshold,
      )
      .length;

  bool get explorationQuotaSatisfied => explorationCount >= explorationTarget;

  bool get sourceCapSatisfied {
    final counts = <String, int>{};
    for (final item in items) {
      final sourceId = item.ranked.candidate.sourceId;
      counts[sourceId] = (counts[sourceId] ?? 0) + 1;
    }
    return counts.values.every((count) => count <= maximumItemsPerSource);
  }

  double get observedMaximumSourceShare {
    if (items.isEmpty) return 0;
    final counts = <String, int>{};
    for (final item in items) {
      final sourceId = item.ranked.candidate.sourceId;
      counts[sourceId] = (counts[sourceId] ?? 0) + 1;
    }
    final maximum = counts.values.reduce((left, right) {
      return left > right ? left : right;
    });
    return maximum / items.length;
  }

  bool get sourceShareSatisfied =>
      observedMaximumSourceShare <= maximumSourceShare;

  bool get filled =>
      items.length == requestedLimit || items.length == eligibleCandidateCount;
}

final class LocalRankingGuardrails {
  const LocalRankingGuardrails({
    this.config = const RankingGuardrailConfig(),
  });

  final RankingGuardrailConfig config;

  GuardedRankingResult apply({
    required Iterable<RankedArticleCandidate> rankedCandidates,
    required PreferenceProfile profile,
    required int limit,
    Iterable<String> blockedTopics = const <String>[],
  }) {
    config.validate();
    if (profile.modelVersion != preferenceProfileModelVersion ||
        limit <= 0 ||
        limit > config.maximumResults) {
      throw const FormatException('Invalid ranking guardrail input.');
    }
    final candidates = rankedCandidates.toList(growable: false);
    if (candidates.length > config.maximumCandidates) {
      throw const FormatException('Too many ranking candidates.');
    }
    final seen = <String>{};
    for (final item in candidates) {
      if (!seen.add(item.candidate.articleId)) {
        throw const FormatException('Duplicate guarded ranking candidate.');
      }
    }
    final ordered = candidates.toList()..sort(_compareGuardrailCandidates);
    final normalizedBlockedTopics = _normalizeBlockedTopics(blockedTopics);
    var blockedCount = 0;
    var negativeCount = 0;
    final eligible = <RankedArticleCandidate>[];
    for (final item in ordered) {
      final candidate = item.candidate;
      if (candidate.topics.any(normalizedBlockedTopics.contains)) {
        blockedCount += 1;
        continue;
      }
      if (profile.sourceScore(candidate.sourceId) <=
              config.strongNegativeThreshold ||
          candidate.topics.any(
            (topic) =>
                profile.topicScore(topic) <= config.strongNegativeThreshold,
          )) {
        negativeCount += 1;
        continue;
      }
      eligible.add(item);
    }

    final targetSize = limit < eligible.length ? limit : eligible.length;
    final maximumItemsPerSource = targetSize == 0
        ? 0
        : (targetSize * config.maximumSourceShare)
            .floor()
            .clamp(
              1,
              targetSize,
            )
            .toInt();
    final explorationEligible = eligible
        .where(
          (item) =>
              item.candidate.explorationProbability >=
              config.explorationThreshold,
        )
        .toList(growable: false);
    final requestedExploration =
        (targetSize * config.minimumExplorationShare).ceil();
    final explorationTarget = requestedExploration
        .clamp(
          0,
          explorationEligible.length,
        )
        .toInt();
    final selected = <String, GuardedRankedCandidate>{};
    final sourceCounts = <String, int>{};

    void select(
      RankedArticleCandidate candidate,
      RankingSelectionKind selectionKind,
    ) {
      selected[candidate.candidate.articleId] = GuardedRankedCandidate(
        ranked: candidate,
        selectionKind: selectionKind,
      );
      final sourceId = candidate.candidate.sourceId;
      sourceCounts[sourceId] = (sourceCounts[sourceId] ?? 0) + 1;
    }

    for (final candidate in explorationEligible) {
      if (selected.length >= explorationTarget) break;
      final sourceId = candidate.candidate.sourceId;
      if ((sourceCounts[sourceId] ?? 0) >= maximumItemsPerSource) continue;
      select(candidate, RankingSelectionKind.explorationQuota);
    }
    for (final candidate in eligible) {
      if (selected.length >= targetSize) break;
      if (selected.containsKey(candidate.candidate.articleId)) continue;
      final sourceId = candidate.candidate.sourceId;
      if ((sourceCounts[sourceId] ?? 0) >= maximumItemsPerSource) continue;
      select(candidate, RankingSelectionKind.organic);
    }

    final items = selected.values.toList()
      ..sort(
        (left, right) => _compareGuardrailCandidates(left.ranked, right.ranked),
      );
    return GuardedRankingResult._(
      items: items,
      modelVersion: config.modelVersion,
      requestedLimit: limit,
      eligibleCandidateCount: eligible.length,
      maximumItemsPerSource: maximumItemsPerSource,
      maximumSourceShare: config.maximumSourceShare,
      explorationTarget: explorationTarget,
      eligibleExplorationCount: explorationEligible.length,
      explorationThreshold: config.explorationThreshold,
      filteredByBlockedTopic: blockedCount,
      filteredByNegativeFeedback: negativeCount,
    );
  }
}

int _compareGuardrailCandidates(
  RankedArticleCandidate left,
  RankedArticleCandidate right,
) {
  final byScore = right.score.compareTo(left.score);
  if (byScore != 0) return byScore;
  final byPublication =
      right.candidate.publishedAt.compareTo(left.candidate.publishedAt);
  if (byPublication != 0) return byPublication;
  return left.candidate.articleId.compareTo(right.candidate.articleId);
}

Set<String> _normalizeBlockedTopics(Iterable<String> topics) {
  final normalized = SplayTreeSet<String>();
  for (final topic in topics) {
    final value = topic.trim().toLowerCase();
    if (value.isEmpty || value.length > 64) {
      throw const FormatException('Invalid blocked ranking topic.');
    }
    normalized.add(value);
    if (normalized.length > 64) {
      throw const FormatException('Invalid blocked ranking topic.');
    }
  }
  return Set<String>.unmodifiable(normalized);
}

bool _isFiniteFraction(double value) =>
    value.isFinite && value >= 0 && value <= 1;
