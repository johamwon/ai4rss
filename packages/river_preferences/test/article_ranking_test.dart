import 'dart:math' as math;

import 'package:river_domain/river_domain.dart';
import 'package:river_preferences/river_preferences.dart';
import 'package:test/test.dart';

void main() {
  final now = DateTime.utc(2026, 7, 30, 12);

  test('fixed candidates rank deterministically with exact explanations', () {
    final profile = _profile(now);
    final candidates = _fixedCandidates(now);
    final ranked = const LocalArticleRanker().rank(
      candidates: candidates,
      profile: profile,
      now: now,
    );
    final replayed = const LocalArticleRanker().rank(
      candidates: candidates.reversed,
      profile: profile,
      now: now,
    );

    expect(
      ranked.map((item) => item.candidate.articleId),
      <String>['article-tech', 'article-noise', 'article-explore'],
    );
    expect(
      replayed.map((item) => item.candidate.articleId),
      ranked.map((item) => item.candidate.articleId),
    );
    expect(ranked[0].score, closeTo(0.7542857142857143, 1e-12));
    expect(ranked[1].score, closeTo(0.695, 1e-12));
    expect(ranked[2].score, closeTo(0.692, 1e-12));

    for (final item in ranked) {
      expect(item.explanation.modelId, 'river.article-ranking/1');
      expect(item.explanation.factors, hasLength(RankingFactor.values.length));
      expect(
        item.explanation.factors.map((factor) => factor.factor).toSet(),
        RankingFactor.values.toSet(),
      );
      expect(
        item.explanation.factors.fold<double>(
          0,
          (sum, factor) => sum + factor.contribution,
        ),
        item.score,
      );
    }
  });

  test('source topic freshness and exploration components remain independent',
      () {
    final profile = _profile(now);
    final candidates = _fixedCandidates(now);
    final ranked = const LocalArticleRanker().rank(
      candidates: candidates,
      profile: profile,
      now: now,
    );
    final byId = <String, RankedArticleCandidate>{
      for (final item in ranked) item.candidate.articleId: item,
    };
    final tech = byId['article-tech']!;
    final noise = byId['article-noise']!;
    final explore = byId['article-explore']!;

    expect(
      tech.explanation.factor(RankingFactor.source).value,
      closeTo(5 / 7, 1e-12),
    );
    expect(
      tech.explanation.factor(RankingFactor.topic).value,
      closeTo(5 / 7, 1e-12),
    );
    expect(
      noise.explanation.factor(RankingFactor.source).value,
      closeTo(0.25, 1e-12),
    );
    expect(
      noise.explanation.factor(RankingFactor.topic).value,
      closeTo(0.25, 1e-12),
    );
    expect(
      explore.explanation.factor(RankingFactor.freshness).value,
      closeTo(0.5, 1e-12),
    );
    expect(
      explore.explanation.factor(RankingFactor.exploration).value,
      0.8,
    );
  });

  test('topic affinity averages normalized topics without tag amplification',
      () {
    final profile = _profile(now);
    final singleTopic = ArticleRankingCandidate(
      articleId: 'single',
      sourceId: 'neutral',
      publishedAt: now,
      semanticSimilarity: 0.5,
      completionProbability: 0.5,
      explorationProbability: 0.5,
      topics: const <String>['flutter'],
    );
    final repeatedAndMixedCase = ArticleRankingCandidate(
      articleId: 'repeated',
      sourceId: 'neutral',
      publishedAt: now,
      semanticSimilarity: 0.5,
      completionProbability: 0.5,
      explorationProbability: 0.5,
      topics: const <String>[' Flutter ', 'flutter', 'FLUTTER'],
    );
    final ranked = const LocalArticleRanker().rank(
      candidates: <ArticleRankingCandidate>[
        singleTopic,
        repeatedAndMixedCase,
      ],
      profile: profile,
      now: now,
    );

    expect(repeatedAndMixedCase.topics, const <String>['flutter']);
    expect(ranked[0].score, ranked[1].score);
    expect(
      ranked.map((item) => item.candidate.articleId),
      <String>['repeated', 'single'],
    );
  });

  test('exact ties use newer publication then stable article identity', () {
    final profile = _profile(now);
    ArticleRankingCandidate candidate(String articleId, DateTime publishedAt) =>
        ArticleRankingCandidate(
          articleId: articleId,
          sourceId: 'neutral',
          publishedAt: publishedAt,
          semanticSimilarity: 0.5,
          completionProbability: 0.5,
          explorationProbability: 0.5,
        );
    final ranked = const LocalArticleRanker(
      config: ArticleRankingConfig(
        semanticWeight: 0.45,
        freshnessWeight: 0,
      ),
    ).rank(
      candidates: <ArticleRankingCandidate>[
        candidate('older', now.subtract(const Duration(hours: 1))),
        candidate('newer-b', now),
        candidate('newer-a', now),
      ],
      profile: profile,
      now: now,
    );

    expect(
      ranked.map((item) => item.candidate.articleId),
      <String>['newer-a', 'newer-b', 'older'],
    );
  });

  test('one thousand candidates remain bounded deterministic and input-stable',
      () {
    final random = math.Random(20260730);
    final profile = _profile(now);
    final candidates = <ArticleRankingCandidate>[
      for (var index = 0; index < 1000; index += 1)
        ArticleRankingCandidate(
          articleId: 'article-${index.toString().padLeft(4, '0')}',
          sourceId: index.isEven ? 'source-tech' : 'source-noise',
          publishedAt: now.subtract(Duration(minutes: index)),
          semanticSimilarity: random.nextDouble(),
          completionProbability: random.nextDouble(),
          explorationProbability: random.nextDouble(),
          topics: <String>[index.isEven ? 'flutter' : 'gossip'],
        ),
    ];
    final first = const LocalArticleRanker().rank(
      candidates: candidates,
      profile: profile,
      now: now,
    );
    final second = const LocalArticleRanker().rank(
      candidates: candidates.reversed,
      profile: profile,
      now: now,
    );

    expect(first, hasLength(1000));
    expect(first.every((item) => item.score >= 0 && item.score <= 1), isTrue);
    expect(
      second.map((item) => item.candidate.articleId),
      first.map((item) => item.candidate.articleId),
    );
    for (var index = 1; index < first.length; index += 1) {
      expect(first[index - 1].score >= first[index].score, isTrue);
    }
  });

  test('invalid models candidates duplicates and future time fail closed', () {
    final profile = _profile(now);
    final candidate = _fixedCandidates(now).first;

    expect(
      () => const LocalArticleRanker(
        config: ArticleRankingConfig(semanticWeight: 0.31),
      ).rank(
        candidates: <ArticleRankingCandidate>[],
        profile: profile,
        now: now,
      ),
      throwsFormatException,
    );
    expect(
      () => ArticleRankingCandidate(
        articleId: 'invalid',
        sourceId: 'source',
        publishedAt: now,
        semanticSimilarity: double.nan,
        completionProbability: 0.5,
        explorationProbability: 0.5,
      ),
      throwsFormatException,
    );
    expect(
      () => const LocalArticleRanker().rank(
        candidates: <ArticleRankingCandidate>[candidate, candidate],
        profile: profile,
        now: now,
      ),
      throwsFormatException,
    );
    expect(
      () => const LocalArticleRanker().rank(
        candidates: <ArticleRankingCandidate>[
          ArticleRankingCandidate(
            articleId: 'future',
            sourceId: 'source',
            publishedAt: now.add(const Duration(microseconds: 1)),
            semanticSimilarity: 0.5,
            completionProbability: 0.5,
            explorationProbability: 0.5,
          ),
        ],
        profile: profile,
        now: now,
      ),
      throwsFormatException,
    );
  });

  test('freshness has an exact configurable half-life', () {
    expect(
      rankingFreshness(
        publishedAt: now.subtract(const Duration(hours: 72)),
        now: now,
      ),
      closeTo(0.5, 1e-12),
    );
    expect(
      () => rankingFreshness(
        publishedAt: now.add(const Duration(microseconds: 1)),
        now: now,
      ),
      throwsFormatException,
    );
    expect(
      () => rankingFreshness(
        publishedAt: now,
        now: now,
        halfLifeHours: 0,
      ),
      throwsFormatException,
    );
  });
}

PreferenceProfile _profile(DateTime now) =>
    const LocalPreferenceProfileModel().build(
      now: now,
      evidence: <PreferenceEvidence>[
        PreferenceEvidence(
          event: ReadingEvent(
            eventId: 'saved-tech',
            articleId: 'history-tech',
            type: ReadingEventType.savedToKnowledge,
            occurredAt: now,
          ),
          sourceId: 'source-tech',
          topics: <String>['flutter'],
        ),
        PreferenceEvidence(
          event: ReadingEvent(
            eventId: 'negative-noise',
            articleId: 'history-noise',
            type: ReadingEventType.notInterested,
            occurredAt: now,
          ),
          sourceId: 'source-noise',
          topics: <String>['gossip'],
        ),
      ],
    );

List<ArticleRankingCandidate> _fixedCandidates(DateTime now) =>
    <ArticleRankingCandidate>[
      ArticleRankingCandidate(
        articleId: 'article-tech',
        sourceId: 'source-tech',
        publishedAt: now,
        semanticSimilarity: 0.8,
        completionProbability: 0.7,
        explorationProbability: 0.2,
        topics: const <String>['flutter'],
      ),
      ArticleRankingCandidate(
        articleId: 'article-explore',
        sourceId: 'source-unknown',
        publishedAt: now.subtract(const Duration(hours: 72)),
        semanticSimilarity: 0.89,
        completionProbability: 0.8,
        explorationProbability: 0.8,
      ),
      ArticleRankingCandidate(
        articleId: 'article-noise',
        sourceId: 'source-noise',
        publishedAt: now,
        semanticSimilarity: 0.95,
        completionProbability: 0.9,
        explorationProbability: 0.1,
        topics: const <String>['gossip'],
      ),
    ];
