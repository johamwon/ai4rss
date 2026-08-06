import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:river_ai/river_ai.dart';
import 'package:river_app/app/article_summary.dart';
import 'package:river_app/preferences/automatic_summaries.dart';
import 'package:river_app/preferences/personalized_articles.dart';
import 'package:river_data/river_data.dart' hide Article;
import 'package:river_domain/river_domain.dart';
import 'package:river_feed/river_feed.dart';
import 'package:river_preferences/river_preferences.dart';

void main() {
  late RiverDatabase database;
  late DriftAutomaticSummaryRepository repository;
  late PersistentJobQueue jobs;
  late _Network network;
  late _Clock clock;
  late DriftRankingExperimentRepository experimentRepository;
  late LocalRankingExperiment experiment;

  setUp(() async {
    database = RiverDatabase.inMemory();
    repository = DriftAutomaticSummaryRepository(database);
    jobs = PersistentJobQueue(database);
    network = _Network(AutomaticSummaryNetworkKind.wifi);
    clock = _Clock(DateTime.utc(2026, 8, 5, 8));
    experimentRepository = DriftRankingExperimentRepository(database);
    experiment = LocalRankingExperiment(repository: experimentRepository);
    await experimentRepository.saveEnrollment(
      RankingExperimentEnrollment(
        experimentId: rankingExperimentId,
        arm: RankingExperimentArm.personalized,
        assignedAt: clock.now(),
      ),
    );
  });

  tearDown(() async {
    await network.close();
    await database.close();
  });

  DurableAutomaticSummaryManager buildManager({
    required _Summaries summaries,
    Duration providerRetryDelay = const Duration(minutes: 2),
    LocalRankingExperiment? metrics,
    AiMonotonicClock? metricsClock,
  }) =>
      DurableAutomaticSummaryManager(
        jobs: jobs,
        repository: repository,
        loadArticle: (articleId) async => _detail(articleId),
        summaries: summaries,
        network: network,
        clock: clock,
        ids: _Ids(),
        providerRetryDelay: providerRetryDelay,
        metrics: metrics,
        metricsClock: metricsClock,
      );

  test('only high-match unread articles run within the daily limit', () async {
    await repository.saveSettings(
      const AutomaticSummarySettings(enabled: true, dailyLimit: 1),
      updatedAt: clock.now(),
    );
    final summaries = _Summaries();
    final manager = buildManager(summaries: summaries);
    addTearDown(manager.close);

    expect(
      await manager.schedule(_snapshot()).timeout(const Duration(seconds: 2)),
      1,
    );

    expect(summaries.generatedArticleIds, <String>['article-high']);
    final usage = await repository.readUsage('2026-08-05');
    expect(usage.completed, 1);
    expect(usage.reserved, 0);
  });

  test('Wi-Fi policy waits without spending attempts and resumes on Wi-Fi',
      () async {
    await repository.saveSettings(
      const AutomaticSummarySettings(enabled: true),
      updatedAt: clock.now(),
    );
    network.current = AutomaticSummaryNetworkKind.other;
    final generated = Completer<void>();
    final summaries = _Summaries(onGenerated: (_) => generated.complete());
    final manager = buildManager(summaries: summaries);
    addTearDown(manager.close);
    await manager.start();

    expect(await manager.schedule(_snapshot(single: true)), 1);
    expect(summaries.generatedArticleIds, isEmpty);
    final queued =
        (await jobs.list(type: DurableAutomaticSummaryManager.jobType)).single;
    expect(queued.status, DurableJobStatus.queued);
    expect(queued.attempt, 0);
    expect(queued.lastErrorCode, 'wifi_required');

    network.emit(AutomaticSummaryNetworkKind.wifi);
    await generated.future;
    expect(summaries.generatedArticleIds, <String>['article-high']);
  });

  test('retryable failures release quota before a successful retry', () async {
    await repository.saveSettings(
      const AutomaticSummarySettings(enabled: true, dailyLimit: 1),
      updatedAt: clock.now(),
    );
    final summaries = _Summaries(retryableFailures: 1);
    final manager = buildManager(
      summaries: summaries,
      providerRetryDelay: Duration.zero,
    );
    addTearDown(manager.close);

    await manager.schedule(_snapshot(single: true));

    expect(summaries.generateCalls, 2);
    final usage = await repository.readUsage('2026-08-05');
    expect(usage.completed, 1);
    expect(usage.reserved, 0);
  });

  test('a pre-existing cache hit completes without consuming quota', () async {
    await repository.saveSettings(
      const AutomaticSummarySettings(enabled: true, dailyLimit: 1),
      updatedAt: clock.now(),
    );
    final summaries = _Summaries(cached: true);
    final manager = buildManager(summaries: summaries);
    addTearDown(manager.close);

    await manager.schedule(_snapshot(single: true));

    expect(summaries.generateCalls, 0);
    expect((await repository.readUsage('2026-08-05')).consumed, 0);
  });

  test('missing cached content uses the reviewed full-text pipeline', () async {
    await repository.saveSettings(
      const AutomaticSummarySettings(enabled: true, dailyLimit: 1),
      updatedAt: clock.now(),
    );
    final summaries = _Summaries();
    final extractor = _Extractor();
    final manager = DurableAutomaticSummaryManager(
      jobs: jobs,
      repository: repository,
      loadArticle: (articleId) async => _detailWithoutContent(articleId),
      summaries: summaries,
      network: network,
      clock: clock,
      ids: _Ids(),
      extractor: extractor,
    );
    addTearDown(manager.close);

    await manager.schedule(_snapshot(single: true));

    expect(extractor.calls, 1);
    expect(summaries.generatedArticleIds, <String>['article-high']);
    expect((await repository.readUsage('2026-08-05')).completed, 1);
  });

  test('cached recovery completes a reservation left by interruption',
      () async {
    await repository.saveSettings(
      const AutomaticSummarySettings(enabled: true, dailyLimit: 1),
      updatedAt: clock.now(),
    );
    final article = _detail('article-high');
    final contentHash = summaryContentHash(article.content!.plainText);
    final usageKey = 'automatic-summary-usage:v1:article-high:$contentHash';
    await repository.reserveUsage(
      idempotencyKey: usageKey,
      articleId: 'article-high',
      dayKey: '2026-08-05',
      dailyLimit: 1,
      now: clock.now(),
    );
    await jobs.enqueue(
      NewDurableJob(
        id: 'recovered-job',
        type: DurableAutomaticSummaryManager.jobType,
        idempotencyKey: 'automatic-summary:v1:article-high:$contentHash',
        payloadJson: jsonEncode(<String, Object>{
          'schemaVersion': 1,
          'articleId': 'article-high',
          'contentHash': contentHash,
          'rankingScore': 0.9,
          'rankingModelVersion': 1,
        }),
        availableAt: clock.now(),
      ),
      clock.now(),
    );
    final manager = buildManager(summaries: _Summaries(cached: true));
    addTearDown(manager.close);

    await manager.resumePending();

    expect(
      await repository.readUsageStatus(usageKey),
      AutomaticSummaryUsageStatus.completed,
    );
    expect(
      (await jobs.list(type: DurableAutomaticSummaryManager.jobType))
          .single
          .status,
      DurableJobStatus.completed,
    );
  });

  test('disabling automation cancels queued work', () async {
    await repository.saveSettings(
      const AutomaticSummarySettings(enabled: true),
      updatedAt: clock.now(),
    );
    network.current = AutomaticSummaryNetworkKind.other;
    final manager = buildManager(summaries: _Summaries());
    addTearDown(manager.close);
    await manager.schedule(_snapshot(single: true));

    await manager.updateSettings(const AutomaticSummarySettings());

    expect(
      (await jobs.list(type: DurableAutomaticSummaryManager.jobType))
          .single
          .status,
      DurableJobStatus.cancelled,
    );
  });

  test('records eligible, generated, latency, calls, and exact cached cost',
      () async {
    await repository.saveSettings(
      const AutomaticSummarySettings(enabled: true),
      updatedAt: clock.now(),
    );
    final manager = buildManager(
      summaries: _Summaries(),
      metrics: experiment,
      metricsClock: _SteppingMonotonicClock(),
    );
    addTearDown(manager.close);

    await manager.schedule(_snapshot(single: true));

    final metrics = (await experimentRepository.readMetrics(
      experimentId: rankingExperimentId,
      startDay: '2026-08-05',
      endDay: '2026-08-05',
    ))
        .single;
    expect(metrics.summaryEligible, 1);
    expect(metrics.summaryGenerated, 1);
    expect(metrics.summaryProviderCalls, 2);
    expect(metrics.summaryLatencyMilliseconds, 125);
    expect(metrics.summaryCostUsd, 0.0042);
  });
}

PersonalizedArticleListSnapshot _snapshot({bool single = false}) {
  final articles = <FeedArticleRecord>[
    _record('article-high'),
    if (!single) _record('article-low'),
  ];
  return PersonalizedArticleListSnapshot(
    articles: articles,
    explanations: <String, RecommendationExplanation>{
      'article-high': _explanation(0.9),
      if (!single) 'article-low': _explanation(0.4),
    },
    personalized: true,
  );
}

FeedArticleRecord _record(String id) => FeedArticleRecord(
      id: id,
      feedId: 'feed-1',
      feedTitle: 'Example',
      canonicalUrl: Uri.parse('https://example.test/$id'),
      title: id,
      read: false,
      starred: false,
      readLater: false,
    );

RecommendationExplanation _explanation(double score) =>
    RecommendationExplanation(
      version: recommendationExplanationVersion,
      rankingModelVersion: 1,
      guardrailModelVersion: 1,
      score: score,
      reasons: const <RecommendationReason>[],
    );

FeedArticleDetailRecord _detail(String id) => FeedArticleDetailRecord(
      id: id,
      feedId: 'feed-1',
      feedTitle: 'Example',
      canonicalUrl: Uri.parse('https://example.test/$id'),
      title: id,
      read: false,
      starred: false,
      readLater: false,
      scrollDepth: 0,
      activeReadSeconds: 0,
      content: FeedArticleContentRecord(
        sanitizedHtml: '<p>Full text for $id</p>',
        markdown: 'Full text for $id',
        plainText: 'Full text for $id',
        extractorName: 'test',
        extractorVersion: '1',
        extractedAt: DateTime.utc(2026, 8, 5),
      ),
    );

FeedArticleDetailRecord _detailWithoutContent(String id) =>
    FeedArticleDetailRecord(
      id: id,
      feedId: 'feed-1',
      feedTitle: 'Example',
      canonicalUrl: Uri.parse('https://example.test/$id'),
      title: id,
      read: false,
      starred: false,
      readLater: false,
      scrollDepth: 0,
      activeReadSeconds: 0,
      feedContentHtml: '<p>Feed preview</p>',
    );

final class _Summaries implements ArticleSummaryExperience {
  _Summaries({
    this.cached = false,
    this.retryableFailures = 0,
    this.onGenerated,
  });

  final bool cached;
  int retryableFailures;
  final void Function(String articleId)? onGenerated;
  final List<String> generatedArticleIds = <String>[];
  var generateCalls = 0;
  var generatedCache = false;

  @override
  Future<ArticleSummaryInspection> inspect(Article article) async =>
      ArticleSummaryInspection(
        preparation: _preparation,
        cachedSummary: cached || generatedCache ? _summary : null,
        accounting: cached || generatedCache
            ? const ArticleSummaryAccounting(
                inputTokens: 100,
                outputTokens: 40,
                providerCalls: 2,
                costUsd: 0.0042,
              )
            : null,
      );

  @override
  Future<ArticleSummary> summarize(Article article) async {
    generateCalls += 1;
    if (retryableFailures > 0) {
      retryableFailures -= 1;
      throw const ArticleSummaryExperienceFailure(
        code: ArticleSummaryExperienceFailureCode.timeout,
        retryable: true,
      );
    }
    generatedArticleIds.add(article.id);
    generatedCache = true;
    onGenerated?.call(article.id);
    return _summary;
  }
}

final class _Extractor implements FullTextExtractor {
  var calls = 0;

  @override
  Future<ExtractionResult> extract(ExtractionRequest request) async {
    calls += 1;
    return const ExtractionSuccess(
      article: ExtractedArticle(
        title: 'Extracted article',
        html: '<p>Extracted full text</p>',
        plainText: 'Extracted full text',
        extractor: 'test',
        extractorVersion: '1',
      ),
      attempts: <ExtractionAttempt>[],
    );
  }
}

const _preparation = ArticleSummaryPreparation(
  providerLabel: 'Test',
  model: 'test-v1',
  contentCharacters: 20,
  isLongArticle: false,
  maximumProviderCalls: 1,
  estimatedInputTokens: 10,
  estimatedOutputTokens: 10,
);

const _summary = ArticleSummary(
  oneLine: 'Summary',
  keyPoints: <String>['One', 'Two', 'Three'],
  language: 'en-US',
  model: 'test-v1',
  promptVersion: 'article-summary@1',
);

final class _Network implements AutomaticSummaryNetworkMonitor {
  _Network(this.current);

  AutomaticSummaryNetworkKind current;
  final StreamController<AutomaticSummaryNetworkKind> _changes =
      StreamController<AutomaticSummaryNetworkKind>.broadcast();

  @override
  Future<AutomaticSummaryNetworkKind> check() async => current;

  @override
  Stream<AutomaticSummaryNetworkKind> get changes => _changes.stream;

  void emit(AutomaticSummaryNetworkKind value) {
    current = value;
    _changes.add(value);
  }

  Future<void> close() => _changes.close();
}

final class _Clock implements Clock {
  _Clock(this.value);

  DateTime value;

  @override
  DateTime now() => value;
}

final class _SteppingMonotonicClock implements AiMonotonicClock {
  Duration _value = Duration.zero;

  @override
  Duration elapsed() {
    final current = _value;
    _value += const Duration(milliseconds: 125);
    return current;
  }
}

final class _Ids implements IdGenerator {
  var value = 0;

  @override
  String next() => 'automatic-summary-job-${++value}';
}
