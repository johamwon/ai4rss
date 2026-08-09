import 'dart:collection';
import 'dart:math' as math;

import 'package:river_domain/river_domain.dart';
import 'package:river_feed/river_feed.dart';
import 'package:river_preferences/river_preferences.dart';

final class PersonalizedArticleListSnapshot {
  PersonalizedArticleListSnapshot({
    required Iterable<FeedArticleRecord> articles,
    required Map<String, RecommendationExplanation> explanations,
    required this.personalized,
    this.filteredByBlockedSource = 0,
  })  : articles = List<FeedArticleRecord>.unmodifiable(articles),
        explanations = Map<String, RecommendationExplanation>.unmodifiable(
          explanations,
        );

  factory PersonalizedArticleListSnapshot.chronological(
    Iterable<FeedArticleRecord> articles,
  ) =>
      PersonalizedArticleListSnapshot(
        articles: articles,
        explanations: const <String, RecommendationExplanation>{},
        personalized: false,
      );

  final List<FeedArticleRecord> articles;
  final Map<String, RecommendationExplanation> explanations;
  final bool personalized;
  final int filteredByBlockedSource;
}

final class PreferenceProfileDimension {
  const PreferenceProfileDimension({
    required this.id,
    required this.label,
    required this.learnedScore,
    required this.adjustment,
    required this.blocked,
  });

  final String id;
  final String label;
  final double learnedScore;
  final double adjustment;
  final bool blocked;

  double get score => learnedScore + adjustment;
}

final class PreferenceProfileSnapshot {
  PreferenceProfileSnapshot({
    required this.settings,
    required this.evidenceCount,
    required Iterable<PreferenceProfileDimension> sources,
    required Iterable<PreferenceProfileDimension> topics,
  })  : sources = List<PreferenceProfileDimension>.unmodifiable(sources),
        topics = List<PreferenceProfileDimension>.unmodifiable(topics);

  final ReadingBehaviorSettings settings;
  final int evidenceCount;
  final List<PreferenceProfileDimension> sources;
  final List<PreferenceProfileDimension> topics;
}

abstract interface class PreferenceProfileExperience {
  Future<PreferenceProfileSnapshot> loadProfile();
  Future<void> setEnabled(bool enabled);
  Future<void> setSourceAdjustment(String sourceId, double adjustment);
  Future<void> setTopicAdjustment(String topic, double adjustment);
  Future<void> setSourceBlocked(String sourceId, bool blocked);
  Future<void> setTopicBlocked(String topic, bool blocked);
  Future<int> clearProfile();
}

final class LocalPersonalizedArticleExperience
    implements PreferenceProfileExperience {
  const LocalPersonalizedArticleExperience({
    required this.feeds,
    required this.behavior,
    required this.clock,
    this.profileModel = const LocalPreferenceProfileModel(),
    this.ranker = const LocalArticleRanker(),
    this.guardrails = const LocalRankingGuardrails(),
    this.explainer = const LocalRecommendationExplainer(),
    this.experiment,
  });

  final FeedRepository feeds;
  final ReadingBehaviorRepository behavior;
  final Clock clock;
  final LocalPreferenceProfileModel profileModel;
  final LocalArticleRanker ranker;
  final LocalRankingGuardrails guardrails;
  final LocalRecommendationExplainer explainer;
  final LocalRankingExperiment? experiment;

  Stream<PersonalizedArticleListSnapshot> watch(
    FeedArticleQuery query, {
    bool recordExperimentExposure = true,
  }) {
    if (query.sort != FeedArticleSort.smart) {
      return feeds.watchArticles(query: query).map(
            PersonalizedArticleListSnapshot.chronological,
          );
    }
    final chronologicalQuery = query.copyWith(sort: FeedArticleSort.newest);
    return feeds.watchArticles(query: chronologicalQuery).asyncMap(
      (articles) async {
        final snapshot = await _personalize(articles, query: query);
        if (recordExperimentExposure) {
          await _recordExposure(snapshot);
        }
        return snapshot;
      },
    );
  }

  @override
  Future<PreferenceProfileSnapshot> loadProfile() async {
    final settings = await behavior.readSettings();
    final articles =
        await feeds.watchArticles(query: const FeedArticleQuery()).first;
    final context = await _buildProfileContext(
      articles: articles,
      settings: settings,
    );
    final sourceLabels = <String, String>{
      for (final article in articles) article.feedId: article.feedTitle,
    };
    final sourceIds = SplayTreeSet<String>()
      ..addAll(context.learned.sourceScores.keys)
      ..addAll(settings.preferenceControls.sourceScoreAdjustments.keys)
      ..addAll(settings.preferenceControls.blockedSourceIds);
    final topicIds = SplayTreeSet<String>()
      ..addAll(context.learned.topicScores.keys)
      ..addAll(settings.preferenceControls.topicScoreAdjustments.keys)
      ..addAll(settings.preferenceControls.blockedTopics);
    final sources = <PreferenceProfileDimension>[
      for (final sourceId in sourceIds)
        PreferenceProfileDimension(
          id: sourceId,
          label: sourceLabels[sourceId] ?? sourceId,
          learnedScore: context.learned.sourceScore(sourceId),
          adjustment:
              settings.preferenceControls.sourceScoreAdjustments[sourceId] ?? 0,
          blocked:
              settings.preferenceControls.blockedSourceIds.contains(sourceId),
        ),
    ]..sort(_compareDimensions);
    final topics = <PreferenceProfileDimension>[
      for (final topic in topicIds)
        PreferenceProfileDimension(
          id: topic,
          label: topic,
          learnedScore: context.learned.topicScore(topic),
          adjustment:
              settings.preferenceControls.topicScoreAdjustments[topic] ?? 0,
          blocked: settings.preferenceControls.blockedTopics.contains(topic),
        ),
    ]..sort(_compareDimensions);
    return PreferenceProfileSnapshot(
      settings: settings,
      evidenceCount: context.learned.evidenceCount,
      sources: sources,
      topics: topics,
    );
  }

  @override
  Future<void> setEnabled(bool enabled) async {
    final settings = await behavior.readSettings();
    if (settings.captureEnabled == enabled) return;
    await behavior.saveSettings(
      settings.copyWith(captureEnabled: enabled),
      updatedAt: clock.now(),
    );
  }

  @override
  Future<void> setSourceAdjustment(String sourceId, double adjustment) =>
      _updateControls((controls) {
        final values = Map<String, double>.from(
          controls.sourceScoreAdjustments,
        );
        if (adjustment == 0) {
          values.remove(sourceId);
        } else {
          values[sourceId] = adjustment;
        }
        return controls.copyWith(sourceScoreAdjustments: values);
      });

  @override
  Future<void> setTopicAdjustment(String topic, double adjustment) =>
      _updateControls((controls) {
        final values = Map<String, double>.from(
          controls.topicScoreAdjustments,
        );
        if (adjustment == 0) {
          values.remove(topic);
        } else {
          values[topic] = adjustment;
        }
        return controls.copyWith(topicScoreAdjustments: values);
      });

  @override
  Future<void> setSourceBlocked(String sourceId, bool blocked) =>
      _updateControls((controls) {
        final values = Set<String>.from(controls.blockedSourceIds);
        blocked ? values.add(sourceId) : values.remove(sourceId);
        return controls.copyWith(blockedSourceIds: values);
      });

  @override
  Future<void> setTopicBlocked(String topic, bool blocked) =>
      _updateControls((controls) {
        final normalized = topic.trim().toLowerCase();
        final values = Set<String>.from(controls.blockedTopics);
        blocked ? values.add(normalized) : values.remove(normalized);
        return controls.copyWith(blockedTopics: values);
      });

  @override
  Future<int> clearProfile() => behavior.clearPreferenceProfile(
        updatedAt: clock.now(),
      );

  Future<PersonalizedArticleListSnapshot> _personalize(
    List<FeedArticleRecord> articles, {
    required FeedArticleQuery query,
  }) async {
    final settings = await behavior.readSettings();
    if (!settings.captureEnabled || articles.isEmpty) {
      return PersonalizedArticleListSnapshot.chronological(articles);
    }
    try {
      final enrollment = await experiment?.readEnrollment();
      if (enrollment?.arm == RankingExperimentArm.chronological) {
        return PersonalizedArticleListSnapshot.chronological(articles);
      }
      final allArticles = query.view == FeedArticleView.inbox &&
              query.feedId == null &&
              query.folderId == null
          ? articles
          : await feeds.watchArticles(query: const FeedArticleQuery()).first;
      final context = await _buildProfileContext(
        articles: allArticles,
        settings: settings,
      );
      final blockedSources = settings.preferenceControls.blockedSourceIds;
      final eligible = articles
          .where((article) => !blockedSources.contains(article.feedId))
          .toList(growable: false);
      if (eligible.isEmpty) {
        return PersonalizedArticleListSnapshot(
          articles: const <FeedArticleRecord>[],
          explanations: const <String, RecommendationExplanation>{},
          personalized: true,
          filteredByBlockedSource: articles.length,
        );
      }
      if (eligible.length > guardrails.config.maximumCandidates) {
        return PersonalizedArticleListSnapshot.chronological(articles);
      }
      final now = clock.now().toUtc();
      final candidates = <ArticleRankingCandidate>[
        for (final article in eligible)
          ArticleRankingCandidate(
            articleId: article.id,
            sourceId: article.feedId,
            publishedAt: (article.publishedAt ?? article.createdAt)?.toUtc() ??
                DateTime.utc(1970),
            semanticSimilarity: 0.5,
            completionProbability: _completionProbability(article),
            explorationProbability: _stableExploration(article.id),
          ),
      ];
      final ranked = ranker.rank(
        candidates: candidates,
        profile: context.controlled,
        now: now,
      );
      final result = guardrails.apply(
        rankedCandidates: ranked,
        profile: context.controlled,
        limit: math.min(eligible.length, guardrails.config.maximumResults),
        blockedTopics: settings.preferenceControls.blockedTopics,
      );
      final byId = <String, FeedArticleRecord>{
        for (final article in eligible) article.id: article,
      };
      return PersonalizedArticleListSnapshot(
        articles: <FeedArticleRecord>[
          for (final item in result.items)
            byId[item.ranked.candidate.articleId]!,
        ],
        explanations: <String, RecommendationExplanation>{
          for (final item in result.items)
            item.ranked.candidate.articleId: explainer.explain(
              item: item,
              guardrailModelVersion: result.modelVersion,
            ),
        },
        personalized: true,
        filteredByBlockedSource: articles.length - eligible.length,
      );
    } on FormatException {
      return PersonalizedArticleListSnapshot.chronological(articles);
    }
  }

  Future<void> _recordExposure(PersonalizedArticleListSnapshot snapshot) async {
    final metrics = experiment;
    if (metrics == null || snapshot.articles.isEmpty) return;
    try {
      await metrics.recordExposure(
        sourceIds: snapshot.articles.map((article) => article.feedId),
        now: clock.now(),
      );
    } on Object {
      // Local experiment observability must never block the article list.
    }
  }

  Future<_ProfileContext> _buildProfileContext({
    required List<FeedArticleRecord> articles,
    required ReadingBehaviorSettings settings,
  }) async {
    final byId = <String, FeedArticleRecord>{
      for (final article in articles) article.id: article,
    };
    final events = await behavior.readEvents();
    final evidence = <PreferenceEvidence>[
      for (final event in events)
        if (byId[event.articleId] case final article?)
          PreferenceEvidence(event: event, sourceId: article.feedId),
    ];
    final learned = profileModel.build(evidence: evidence, now: clock.now());
    return _ProfileContext(
      learned: learned,
      controlled: applyReadingPreferenceControls(
        profile: learned,
        controls: settings.preferenceControls,
      ),
    );
  }

  Future<void> _updateControls(
    ReadingPreferenceControls Function(ReadingPreferenceControls) update,
  ) async {
    final settings = await behavior.readSettings();
    final controls = update(settings.preferenceControls);
    controls.validate();
    await behavior.saveSettings(
      settings.copyWith(preferenceControls: controls),
      updatedAt: clock.now(),
    );
  }
}

final class _ProfileContext {
  const _ProfileContext({required this.learned, required this.controlled});

  final PreferenceProfile learned;
  final PreferenceProfile controlled;
}

double _completionProbability(FeedArticleRecord article) {
  if (article.read) return 0.75;
  return 0.5;
}

double _stableExploration(String articleId) {
  var hash = 2166136261;
  for (final codeUnit in articleId.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 16777619) & 0xffffffff;
  }
  return hash / 0xffffffff;
}

int _compareDimensions(
  PreferenceProfileDimension left,
  PreferenceProfileDimension right,
) {
  if (left.blocked != right.blocked) return left.blocked ? -1 : 1;
  final byMagnitude = right.score.abs().compareTo(left.score.abs());
  if (byMagnitude != 0) return byMagnitude;
  return left.label.compareTo(right.label);
}
