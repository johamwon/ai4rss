import 'package:river_preferences/river_preferences.dart';
import 'package:test/test.dart';

void main() {
  test('explanation uses exact ranking factors and identifies exploration', () {
    final now = DateTime.utc(2026, 8, 3, 12);
    final profile = const LocalPreferenceProfileModel().build(
      evidence: const <PreferenceEvidence>[],
      now: now,
    );
    final ranked = const LocalArticleRanker().rank(
      candidates: <ArticleRankingCandidate>[
        ArticleRankingCandidate(
          articleId: 'article-1',
          sourceId: 'feed-1',
          publishedAt: now,
          semanticSimilarity: 0.9,
          completionProbability: 0.8,
          explorationProbability: 0.9,
        ),
      ],
      profile: profile,
      now: now,
    );
    final guarded = const LocalRankingGuardrails().apply(
      rankedCandidates: ranked,
      profile: profile,
      limit: 1,
    );

    final explanation = const LocalRecommendationExplainer().explain(
      item: guarded.items.single,
      guardrailModelVersion: guarded.modelVersion,
    );

    expect(explanation.modelId, 'river.recommendation-explanation/1');
    expect(explanation.score, closeTo(ranked.single.score, 1e-12));
    expect(
      explanation.reasons.first.kind,
      RecommendationReasonKind.exploration,
    );
    for (final reason in explanation.reasons) {
      final factor = ranked.single.explanation.factor(reason.factor);
      expect(reason.value, factor.value);
      expect(reason.weight, factor.weight);
      expect(reason.contribution, factor.contribution);
    }
  });

  test('explanation falls back to the strongest exact factor', () {
    final now = DateTime.utc(2026, 8, 3, 12);
    final profile = const LocalPreferenceProfileModel().build(
      evidence: const <PreferenceEvidence>[],
      now: now,
    );
    final ranked = const LocalArticleRanker().rank(
      candidates: <ArticleRankingCandidate>[
        ArticleRankingCandidate(
          articleId: 'article-old',
          sourceId: 'feed-1',
          publishedAt: DateTime.utc(2025),
          semanticSimilarity: 0,
          completionProbability: 0,
          explorationProbability: 0,
        ),
      ],
      profile: profile,
      now: now,
    );
    final guarded = const LocalRankingGuardrails().apply(
      rankedCandidates: ranked,
      profile: profile,
      limit: 1,
    );

    final explanation = const LocalRecommendationExplainer().explain(
      item: guarded.items.single,
      guardrailModelVersion: guarded.modelVersion,
    );

    expect(explanation.reasons, hasLength(1));
    expect(explanation.reasons.single.factor, RankingFactor.source);
    expect(
      explanation.reasons.single.contribution,
      ranked.single.explanation.factor(RankingFactor.source).contribution,
    );
  });
}
