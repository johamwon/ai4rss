import 'article_ranking.dart';
import 'ranking_guardrails.dart';

const String recommendationExplanationSchema =
    'river.recommendation-explanation';
const int recommendationExplanationVersion = 1;

enum RecommendationReasonKind {
  semanticMatch,
  preferredSource,
  preferredTopic,
  likelyToFinish,
  recent,
  exploration,
}

final class RecommendationReason {
  const RecommendationReason({
    required this.kind,
    required this.factor,
    required this.value,
    required this.weight,
    required this.contribution,
  });

  final RecommendationReasonKind kind;
  final RankingFactor factor;
  final double value;
  final double weight;
  final double contribution;
}

final class RecommendationExplanation {
  RecommendationExplanation({
    required this.version,
    required this.rankingModelVersion,
    required this.guardrailModelVersion,
    required this.score,
    required Iterable<RecommendationReason> reasons,
  }) : reasons = List<RecommendationReason>.unmodifiable(reasons);

  final int version;
  final int rankingModelVersion;
  final int guardrailModelVersion;
  final double score;
  final List<RecommendationReason> reasons;

  String get modelId => '$recommendationExplanationSchema/$version';
}

final class LocalRecommendationExplainer {
  const LocalRecommendationExplainer({this.maximumReasons = 3});

  final int maximumReasons;

  RecommendationExplanation explain({
    required GuardedRankedCandidate item,
    required int guardrailModelVersion,
  }) {
    if (maximumReasons < 1 || maximumReasons > 6) {
      throw const FormatException('Invalid recommendation explanation limit.');
    }
    final factors = item.ranked.explanation.factors;
    final candidates = <RecommendationReason>[
      for (final factor in factors)
        if (_isMeaningful(factor, item.selectionKind)) _reason(factor),
    ]..sort(_compareReasons);
    if (item.selectionKind == RankingSelectionKind.explorationQuota) {
      final explorationIndex = candidates.indexWhere(
        (reason) => reason.kind == RecommendationReasonKind.exploration,
      );
      if (explorationIndex > 0) {
        candidates.insert(0, candidates.removeAt(explorationIndex));
      }
    }
    if (candidates.isEmpty) {
      final strongest = factors.reduce(
        (left, right) => left.contribution >= right.contribution ? left : right,
      );
      candidates.add(_reason(strongest));
    }
    return RecommendationExplanation(
      version: recommendationExplanationVersion,
      rankingModelVersion: item.ranked.explanation.modelVersion,
      guardrailModelVersion: guardrailModelVersion,
      score: item.ranked.score,
      reasons: candidates.take(maximumReasons),
    );
  }
}

bool _isMeaningful(
  RankingFactorScore factor,
  RankingSelectionKind selectionKind,
) =>
    switch (factor.factor) {
      RankingFactor.semantic => factor.value >= 0.65,
      RankingFactor.source => factor.value > 0.5,
      RankingFactor.topic => factor.value > 0.5,
      RankingFactor.completion => factor.value >= 0.65,
      RankingFactor.freshness => factor.value >= 0.5,
      RankingFactor.exploration =>
        selectionKind == RankingSelectionKind.explorationQuota ||
            factor.value >= 0.7,
    };

RecommendationReason _reason(RankingFactorScore factor) => RecommendationReason(
      kind: switch (factor.factor) {
        RankingFactor.semantic => RecommendationReasonKind.semanticMatch,
        RankingFactor.source => RecommendationReasonKind.preferredSource,
        RankingFactor.topic => RecommendationReasonKind.preferredTopic,
        RankingFactor.completion => RecommendationReasonKind.likelyToFinish,
        RankingFactor.freshness => RecommendationReasonKind.recent,
        RankingFactor.exploration => RecommendationReasonKind.exploration,
      },
      factor: factor.factor,
      value: factor.value,
      weight: factor.weight,
      contribution: factor.contribution,
    );

int _compareReasons(RecommendationReason left, RecommendationReason right) {
  final byContribution = right.contribution.compareTo(left.contribution);
  if (byContribution != 0) return byContribution;
  return left.factor.index.compareTo(right.factor.index);
}
