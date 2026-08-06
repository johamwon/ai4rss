import 'dart:convert';

import 'package:river_domain/river_domain.dart';
import 'package:river_preferences/river_preferences.dart';
import 'package:test/test.dart';

void main() {
  final now = DateTime.utc(2026, 8, 6, 12);

  test('assignment is stable and does not collapse to one arm', () {
    for (var index = 0; index < 100; index++) {
      expect(
        assignRankingExperimentArm(
          experimentId: rankingExperimentId,
          entropy: 'device-$index',
        ),
        assignRankingExperimentArm(
          experimentId: rankingExperimentId,
          entropy: 'device-$index',
        ),
      );
    }
    final arms = <RankingExperimentArm>{
      for (var index = 0; index < 100; index++)
        assignRankingExperimentArm(
          experimentId: rankingExperimentId,
          entropy: 'device-$index',
        ),
    };
    expect(arms, RankingExperimentArm.values.toSet());
  });

  test('source diversity is normalized and permutation invariant', () {
    expect(normalizedSourceDiversity(<String>['a', 'a', 'a']), 0);
    expect(normalizedSourceDiversity(<String>['a', 'b', 'c']), 1);
    expect(
      normalizedSourceDiversity(<String>['a', 'a', 'b', 'c']),
      normalizedSourceDiversity(<String>['c', 'a', 'b', 'a']),
    );
  });

  test('experiment is default-off, stable after opt-in, and derives quick exit',
      () async {
    final repository = _MemoryRepository();
    final experiment = LocalRankingExperiment(repository: repository);
    expect(await experiment.shouldUsePersonalizedRanking(), isTrue);

    final first = await experiment.enable(entropy: 'device-a', now: now);
    final second = await experiment.enable(entropy: 'different', now: now);
    expect(second.arm, first.arm);

    await experiment.recordReadingOutcome(
      enrollment: first,
      activeSeconds: 9,
      completed: false,
      now: now,
    );
    expect(repository.outcomes.single.quickExit, isTrue);
    expect(repository.outcomes.single.recordedAt, now);

    await experiment.disable(now: now);
    await experiment
        .recordExposure(sourceIds: <String>['private-feed'], now: now);
    expect(repository.exposures, isEmpty);
  });

  test('decision requires sample and all three safety gates', () async {
    final repository = _MemoryRepository();
    final experiment = LocalRankingExperiment(repository: repository);
    var report = await experiment.buildReport(
      startDay: '2026-08-01',
      endDay: '2026-08-06',
    );
    expect(report.decision, RankingExperimentDecision.insufficientData);
    expect(report.exportAggregateJson, throwsStateError);

    repository.metrics = <RankingExperimentDailyMetrics>[
      _metrics(RankingExperimentArm.chronological, completions: 50),
      _metrics(RankingExperimentArm.personalized, completions: 80),
    ];
    report = await experiment.buildReport(
      startDay: '2026-08-01',
      endDay: '2026-08-06',
    );
    expect(report.decision, RankingExperimentDecision.ship);

    repository.metrics = <RankingExperimentDailyMetrics>[
      _metrics(RankingExperimentArm.chronological, completions: 50),
      _metrics(RankingExperimentArm.personalized, completions: 50),
    ];
    expect(
      (await experiment.buildReport(
        startDay: '2026-08-01',
        endDay: '2026-08-06',
      ))
          .decision,
      RankingExperimentDecision.hold,
    );
  });

  test('export contains aggregates only', () async {
    final repository = _MemoryRepository()
      ..metrics = <RankingExperimentDailyMetrics>[
        _metrics(RankingExperimentArm.chronological, completions: 50),
        _metrics(RankingExperimentArm.personalized, completions: 80),
      ];
    final report = await LocalRankingExperiment(repository: repository)
        .buildReport(startDay: '2026-08-01', endDay: '2026-08-06');
    final export = report.exportAggregateJson();
    final decoded = jsonDecode(export) as Map<String, Object?>;

    expect(decoded['schema'], rankingExperimentAggregateSchema);
    for (final forbidden in <String>[
      'articleId',
      'sourceId',
      'title',
      'url',
      'body',
      'summaryText',
    ]) {
      expect(_allKeys(decoded), isNot(contains(forbidden)));
    }
  });
}

RankingExperimentDailyMetrics _metrics(
  RankingExperimentArm arm, {
  required int completions,
}) =>
    RankingExperimentDailyMetrics(
      experimentId: rankingExperimentId,
      arm: arm,
      dayKey: '2026-08-06',
      exposures: 20,
      exposedArticles: 400,
      sourceDiversitySum: 10,
      sourceDiversitySquaredSum: 5,
      opens: 100,
      activeSeconds: 6000,
      completions: completions,
      quickExits: 0,
      summaryEligible: arm == RankingExperimentArm.personalized ? 20 : 0,
      summaryCacheHits: arm == RankingExperimentArm.personalized ? 5 : 0,
      summaryGenerated: arm == RankingExperimentArm.personalized ? 15 : 0,
      summaryProviderCalls: arm == RankingExperimentArm.personalized ? 15 : 0,
      summaryLatencyMilliseconds:
          arm == RankingExperimentArm.personalized ? 15000 : 0,
      summaryCostUsd: arm == RankingExperimentArm.personalized ? 0.1 : 0,
    );

final class _MemoryRepository implements RankingExperimentRepository {
  RankingExperimentEnrollment? enrollment;
  List<RankingExperimentDailyMetrics> metrics =
      <RankingExperimentDailyMetrics>[];
  final exposures = <RankingExperimentExposure>[];
  final outcomes = <RankingExperimentReadingOutcome>[];
  final summaries = <RankingExperimentSummaryObservation>[];

  @override
  Future<int> clearMetrics({required String experimentId}) async {
    final count = metrics.length;
    metrics.clear();
    return count;
  }

  @override
  Future<void> disable({required DateTime updatedAt}) async =>
      enrollment = null;

  @override
  Future<RankingExperimentEnrollment?> readEnrollment() async => enrollment;

  @override
  Future<List<RankingExperimentDailyMetrics>> readMetrics({
    required String experimentId,
    required String startDay,
    required String endDay,
  }) async =>
      List<RankingExperimentDailyMetrics>.of(metrics);

  @override
  Future<void> recordExposure(RankingExperimentExposure exposure) async =>
      exposures.add(exposure);

  @override
  Future<void> recordReadingOutcome(
    RankingExperimentReadingOutcome outcome,
  ) async =>
      outcomes.add(outcome);

  @override
  Future<void> recordSummaryObservation(
    RankingExperimentSummaryObservation observation,
  ) async =>
      summaries.add(observation);

  @override
  Future<void> saveEnrollment(RankingExperimentEnrollment value) async =>
      enrollment = value;

  @override
  Stream<RankingExperimentEnrollment?> watchEnrollment() =>
      Stream<RankingExperimentEnrollment?>.value(enrollment);
}

Set<String> _allKeys(Object? value) {
  final result = <String>{};
  void visit(Object? current) {
    if (current is Map<String, Object?>) {
      result.addAll(current.keys);
      current.values.forEach(visit);
    } else if (current is List<Object?>) {
      current.forEach(visit);
    }
  }

  visit(value);
  return result;
}
