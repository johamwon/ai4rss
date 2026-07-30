import 'dart:collection';
import 'dart:math' as math;

import 'preference_profile.dart';

const String articleRankingSchema = 'river.article-ranking';
const int articleRankingModelVersion = 1;

enum RankingFactor {
  semantic,
  source,
  topic,
  completion,
  freshness,
  exploration,
}

final class ArticleRankingConfig {
  const ArticleRankingConfig({
    this.modelVersion = articleRankingModelVersion,
    this.semanticWeight = 0.30,
    this.sourceWeight = 0.15,
    this.topicWeight = 0.15,
    this.completionWeight = 0.20,
    this.freshnessWeight = 0.15,
    this.explorationWeight = 0.05,
    this.freshnessHalfLifeHours = 72,
    this.preferenceScale = 4,
  });

  final int modelVersion;
  final double semanticWeight;
  final double sourceWeight;
  final double topicWeight;
  final double completionWeight;
  final double freshnessWeight;
  final double explorationWeight;
  final double freshnessHalfLifeHours;
  final double preferenceScale;

  String get modelId => '$articleRankingSchema/$modelVersion';

  Map<RankingFactor, double> get weights =>
      Map<RankingFactor, double>.unmodifiable(
        <RankingFactor, double>{
          RankingFactor.semantic: semanticWeight,
          RankingFactor.source: sourceWeight,
          RankingFactor.topic: topicWeight,
          RankingFactor.completion: completionWeight,
          RankingFactor.freshness: freshnessWeight,
          RankingFactor.exploration: explorationWeight,
        },
      );

  void validate() {
    final values = weights.values;
    final total = values.fold<double>(0, (sum, value) => sum + value);
    if (modelVersion != articleRankingModelVersion ||
        values.any((value) => !value.isFinite || value < 0) ||
        (total - 1).abs() > 1e-12 ||
        !freshnessHalfLifeHours.isFinite ||
        freshnessHalfLifeHours <= 0 ||
        !preferenceScale.isFinite ||
        preferenceScale <= 0) {
      throw const FormatException('Invalid article ranking configuration.');
    }
  }
}

final class ArticleRankingCandidate {
  ArticleRankingCandidate({
    required String articleId,
    required String sourceId,
    required DateTime publishedAt,
    required this.semanticSimilarity,
    required this.completionProbability,
    required this.explorationProbability,
    Iterable<String> topics = const <String>[],
  })  : articleId = articleId.trim(),
        sourceId = sourceId.trim(),
        publishedAt = publishedAt.toUtc(),
        topics = List<String>.unmodifiable(_normalizeRankingTopics(topics)) {
    validate();
  }

  final String articleId;
  final String sourceId;
  final DateTime publishedAt;
  final double semanticSimilarity;
  final double completionProbability;
  final double explorationProbability;
  final List<String> topics;

  void validate() {
    if (articleId.isEmpty ||
        articleId.length > 256 ||
        sourceId.isEmpty ||
        sourceId.length > 256 ||
        topics.length > 16 ||
        topics.any((topic) => topic.isEmpty || topic.length > 64) ||
        !_isProbability(semanticSimilarity) ||
        !_isProbability(completionProbability) ||
        !_isProbability(explorationProbability)) {
      throw const FormatException('Invalid article ranking candidate.');
    }
  }
}

final class RankingFactorScore {
  const RankingFactorScore({
    required this.factor,
    required this.value,
    required this.weight,
  });

  final RankingFactor factor;
  final double value;
  final double weight;

  double get contribution => value * weight;
}

final class ArticleRankingExplanation {
  ArticleRankingExplanation._({
    required this.modelVersion,
    required Iterable<RankingFactorScore> factors,
  }) : factors = List<RankingFactorScore>.unmodifiable(factors);

  final int modelVersion;
  final List<RankingFactorScore> factors;

  String get modelId => '$articleRankingSchema/$modelVersion';

  double get score =>
      factors.fold<double>(0, (sum, factor) => sum + factor.contribution);

  RankingFactorScore factor(RankingFactor factor) =>
      factors.singleWhere((item) => item.factor == factor);
}

final class RankedArticleCandidate {
  const RankedArticleCandidate({
    required this.candidate,
    required this.explanation,
  });

  final ArticleRankingCandidate candidate;
  final ArticleRankingExplanation explanation;

  double get score => explanation.score;
}

final class LocalArticleRanker {
  const LocalArticleRanker({
    this.config = const ArticleRankingConfig(),
  });

  final ArticleRankingConfig config;

  List<RankedArticleCandidate> rank({
    required Iterable<ArticleRankingCandidate> candidates,
    required PreferenceProfile profile,
    required DateTime now,
  }) {
    config.validate();
    if (profile.modelVersion != preferenceProfileModelVersion) {
      throw const FormatException('Unsupported preference profile version.');
    }
    final rankedAt = now.toUtc();
    final seen = <String>{};
    final ranked = <RankedArticleCandidate>[];
    for (final candidate in candidates) {
      candidate.validate();
      if (!seen.add(candidate.articleId)) {
        throw const FormatException('Duplicate article ranking candidate.');
      }
      if (candidate.publishedAt.isAfter(rankedAt)) {
        throw const FormatException(
          'Article publication cannot occur after ranking time.',
        );
      }
      ranked.add(
        RankedArticleCandidate(
          candidate: candidate,
          explanation: _explain(
            candidate: candidate,
            profile: profile,
            rankedAt: rankedAt,
          ),
        ),
      );
    }
    ranked.sort(_compareRankedCandidates);
    return List<RankedArticleCandidate>.unmodifiable(ranked);
  }

  ArticleRankingExplanation _explain({
    required ArticleRankingCandidate candidate,
    required PreferenceProfile profile,
    required DateTime rankedAt,
  }) {
    final sourceAffinity = _preferenceAffinity(
      profile.sourceScore(candidate.sourceId),
      config.preferenceScale,
    );
    final topicAffinity = candidate.topics.isEmpty
        ? 0.5
        : candidate.topics
                .map(profile.topicScore)
                .map(
                  (score) => _preferenceAffinity(score, config.preferenceScale),
                )
                .fold<double>(0, (sum, value) => sum + value) /
            candidate.topics.length;
    final factors = <RankingFactorScore>[
      RankingFactorScore(
        factor: RankingFactor.semantic,
        value: candidate.semanticSimilarity,
        weight: config.semanticWeight,
      ),
      RankingFactorScore(
        factor: RankingFactor.source,
        value: sourceAffinity,
        weight: config.sourceWeight,
      ),
      RankingFactorScore(
        factor: RankingFactor.topic,
        value: topicAffinity,
        weight: config.topicWeight,
      ),
      RankingFactorScore(
        factor: RankingFactor.completion,
        value: candidate.completionProbability,
        weight: config.completionWeight,
      ),
      RankingFactorScore(
        factor: RankingFactor.freshness,
        value: rankingFreshness(
          publishedAt: candidate.publishedAt,
          now: rankedAt,
          halfLifeHours: config.freshnessHalfLifeHours,
        ),
        weight: config.freshnessWeight,
      ),
      RankingFactorScore(
        factor: RankingFactor.exploration,
        value: candidate.explorationProbability,
        weight: config.explorationWeight,
      ),
    ];
    return ArticleRankingExplanation._(
      modelVersion: config.modelVersion,
      factors: factors,
    );
  }
}

double rankingFreshness({
  required DateTime publishedAt,
  required DateTime now,
  double halfLifeHours = 72,
}) {
  if (!halfLifeHours.isFinite || halfLifeHours <= 0) {
    throw const FormatException('Invalid ranking freshness configuration.');
  }
  final rankedAt = now.toUtc();
  final publication = publishedAt.toUtc();
  if (publication.isAfter(rankedAt)) {
    throw const FormatException(
      'Article publication cannot occur after ranking time.',
    );
  }
  if (publication == rankedAt) return 1;
  final ageHours = rankedAt.difference(publication).inMicroseconds /
      Duration.microsecondsPerHour;
  return math.pow(0.5, ageHours / halfLifeHours).toDouble();
}

double _preferenceAffinity(double score, double scale) {
  if (!score.isFinite) {
    throw const FormatException('Invalid preference profile score.');
  }
  return 0.5 + 0.5 * score / (score.abs() + scale);
}

int _compareRankedCandidates(
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

bool _isProbability(double value) => value.isFinite && value >= 0 && value <= 1;

List<String> _normalizeRankingTopics(Iterable<String> topics) {
  final normalized = SplayTreeSet<String>();
  for (final topic in topics) {
    normalized.add(topic.trim().toLowerCase());
  }
  return normalized.toList(growable: false);
}
