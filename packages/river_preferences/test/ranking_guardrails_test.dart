import 'package:river_domain/river_domain.dart';
import 'package:river_preferences/river_preferences.dart';
import 'package:test/test.dart';

void main() {
  final now = DateTime.utc(2026, 7, 30, 12);

  test('caps a dominant source and reserves deterministic exploration quota',
      () {
    final profile = _neutralProfile(now);
    final ranked = _rank(
      now: now,
      profile: profile,
      candidates: <ArticleRankingCandidate>[
        for (var index = 0; index < 6; index += 1)
          _candidate(
            id: 'source-a-$index',
            sourceId: 'source-a',
            now: now,
            semantic: 1 - index * 0.02,
          ),
        _candidate(
          id: 'source-b-0',
          sourceId: 'source-b',
          now: now,
          semantic: 0.75,
        ),
        _candidate(
          id: 'source-b-1',
          sourceId: 'source-b',
          now: now,
          semantic: 0.70,
        ),
        _candidate(
          id: 'explore-c-0',
          sourceId: 'source-c',
          now: now,
          semantic: 0.45,
          exploration: 0.95,
        ),
        _candidate(
          id: 'explore-c-1',
          sourceId: 'source-c',
          now: now,
          semantic: 0.40,
          exploration: 0.90,
        ),
      ],
    );
    final guardrails = const LocalRankingGuardrails();
    final first = guardrails.apply(
      rankedCandidates: ranked,
      profile: profile,
      limit: 6,
    );
    final replayed = guardrails.apply(
      rankedCandidates: ranked.reversed,
      profile: profile,
      limit: 6,
    );

    expect(first.modelId, 'river.ranking-guardrails/1');
    expect(first.items, hasLength(6));
    expect(first.maximumItemsPerSource, 3);
    expect(first.sourceCapSatisfied, isTrue);
    expect(first.sourceShareSatisfied, isTrue);
    expect(first.observedMaximumSourceShare, 0.5);
    expect(first.explorationTarget, 2);
    expect(first.explorationCount, 2);
    expect(first.explorationQuotaSatisfied, isTrue);
    expect(
      first.items
          .where(
            (item) =>
                item.selectionKind == RankingSelectionKind.explorationQuota,
          )
          .map((item) => item.ranked.candidate.articleId),
      <String>['explore-c-0', 'explore-c-1'],
    );
    expect(
      replayed.items.map((item) => item.ranked.candidate.articleId),
      first.items.map((item) => item.ranked.candidate.articleId),
    );
  });

  test('strong negative evidence and explicit topic blocks filter candidates',
      () {
    final profile = _negativeProfile(now);
    final ranked = _rank(
      now: now,
      profile: profile,
      candidates: <ArticleRankingCandidate>[
        _candidate(
          id: 'bad-source',
          sourceId: 'source-bad',
          now: now,
          topics: const <String>['neutral'],
        ),
        _candidate(
          id: 'bad-topic',
          sourceId: 'source-ok',
          now: now,
          topics: const <String>['toxic'],
        ),
        _candidate(
          id: 'blocked-topic',
          sourceId: 'source-ok',
          now: now,
          topics: const <String>[' Gambling ', 'other'],
        ),
        _candidate(
          id: 'safe',
          sourceId: 'source-safe',
          now: now,
          topics: const <String>['technology'],
        ),
      ],
    );
    final result = const LocalRankingGuardrails().apply(
      rankedCandidates: ranked,
      profile: profile,
      limit: 4,
      blockedTopics: const <String>['gambling'],
    );

    expect(
      result.items.map((item) => item.ranked.candidate.articleId),
      <String>['safe'],
    );
    expect(result.filteredByBlockedTopic, 1);
    expect(result.filteredByNegativeFeedback, 2);
  });

  test('strict source cap reports when insufficient diversity cannot fill', () {
    final profile = _neutralProfile(now);
    final ranked = _rank(
      now: now,
      profile: profile,
      candidates: <ArticleRankingCandidate>[
        for (var index = 0; index < 6; index += 1)
          _candidate(
            id: 'same-$index',
            sourceId: 'only-source',
            now: now,
            semantic: 1 - index * 0.05,
          ),
      ],
    );
    final result = const LocalRankingGuardrails().apply(
      rankedCandidates: ranked,
      profile: profile,
      limit: 4,
    );

    expect(result.maximumItemsPerSource, 2);
    expect(result.items, hasLength(2));
    expect(result.sourceCapSatisfied, isTrue);
    expect(result.sourceShareSatisfied, isFalse);
    expect(result.filled, isFalse);
  });

  test('custom exploration threshold is retained in result accounting', () {
    final profile = _neutralProfile(now);
    final ranked = _rank(
      now: now,
      profile: profile,
      candidates: <ArticleRankingCandidate>[
        _candidate(
          id: 'not-high-enough',
          sourceId: 'source-a',
          now: now,
          exploration: 0.8,
        ),
        _candidate(
          id: 'high-enough',
          sourceId: 'source-b',
          now: now,
          exploration: 0.95,
        ),
      ],
    );
    final result = const LocalRankingGuardrails(
      config: RankingGuardrailConfig(explorationThreshold: 0.9),
    ).apply(rankedCandidates: ranked, profile: profile, limit: 2);

    expect(result.eligibleExplorationCount, 1);
    expect(result.explorationCount, 1);
    expect(result.explorationQuotaSatisfied, isTrue);
  });

  test('malicious sizes duplicates and configurations fail closed', () {
    final profile = _neutralProfile(now);
    final one = _rank(
      now: now,
      profile: profile,
      candidates: <ArticleRankingCandidate>[
        _candidate(id: 'one', sourceId: 'source', now: now),
      ],
    ).single;

    expect(
      () => const LocalRankingGuardrails(
        config: RankingGuardrailConfig(maximumSourceShare: double.nan),
      ).apply(
        rankedCandidates: <RankedArticleCandidate>[],
        profile: profile,
        limit: 1,
      ),
      throwsFormatException,
    );
    expect(
      () => const LocalRankingGuardrails(
        config: RankingGuardrailConfig(modelVersion: 2),
      ).apply(
        rankedCandidates: <RankedArticleCandidate>[],
        profile: profile,
        limit: 1,
      ),
      throwsFormatException,
    );
    expect(
      () => const LocalRankingGuardrails().apply(
        rankedCandidates: <RankedArticleCandidate>[one, one],
        profile: profile,
        limit: 2,
      ),
      throwsFormatException,
    );
    expect(
      () => const LocalRankingGuardrails().apply(
        rankedCandidates: <RankedArticleCandidate>[one],
        profile: profile,
        limit: 1,
        blockedTopics: <String>[
          for (var index = 0; index < 65; index += 1) 'topic-$index',
        ],
      ),
      throwsFormatException,
    );
    expect(
      () => const LocalRankingGuardrails(
        config: RankingGuardrailConfig(maximumCandidates: 1),
      ).apply(
        rankedCandidates: <RankedArticleCandidate>[one, one],
        profile: profile,
        limit: 1,
      ),
      throwsFormatException,
    );
  });
}

PreferenceProfile _neutralProfile(DateTime now) =>
    const LocalPreferenceProfileModel().build(
      now: now,
      evidence: const <PreferenceEvidence>[],
    );

PreferenceProfile _negativeProfile(DateTime now) =>
    const LocalPreferenceProfileModel().build(
      now: now,
      evidence: <PreferenceEvidence>[
        PreferenceEvidence(
          event: ReadingEvent(
            eventId: 'negative',
            articleId: 'history-negative',
            type: ReadingEventType.notInterested,
            occurredAt: now,
          ),
          sourceId: 'source-bad',
          topics: <String>['toxic'],
        ),
      ],
    );

List<RankedArticleCandidate> _rank({
  required DateTime now,
  required PreferenceProfile profile,
  required List<ArticleRankingCandidate> candidates,
}) =>
    const LocalArticleRanker().rank(
      candidates: candidates,
      profile: profile,
      now: now,
    );

ArticleRankingCandidate _candidate({
  required String id,
  required String sourceId,
  required DateTime now,
  double semantic = 0.5,
  double exploration = 0,
  List<String> topics = const <String>[],
}) =>
    ArticleRankingCandidate(
      articleId: id,
      sourceId: sourceId,
      publishedAt: now,
      semanticSimilarity: semantic,
      completionProbability: 0.5,
      explorationProbability: exploration,
      topics: topics,
    );
