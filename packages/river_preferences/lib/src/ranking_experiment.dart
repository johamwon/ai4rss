import 'dart:convert';
import 'dart:math' as math;

import 'package:river_domain/river_domain.dart';

const String rankingExperimentId = 'ranking-time-control/1';
const String rankingExperimentAggregateSchema =
    'river.ranking-experiment-aggregate/1';

enum RankingExperimentDecision { insufficientData, ship, hold }

final class RankingExperimentArmMetrics {
  const RankingExperimentArmMetrics({
    required this.arm,
    required this.exposures,
    required this.exposedArticles,
    required this.opens,
    required this.activeSeconds,
    required this.completions,
    required this.quickExits,
    required this.sourceDiversityMean,
    required this.sourceDiversityVariance,
    required this.summaryEligible,
    required this.summaryCacheHits,
    required this.summaryGenerated,
    required this.summaryFailures,
    required this.summaryProviderCalls,
    required this.summaryLatencyMilliseconds,
    required this.summaryCostUsd,
  });

  final RankingExperimentArm arm;
  final int exposures;
  final int exposedArticles;
  final int opens;
  final int activeSeconds;
  final int completions;
  final int quickExits;
  final double sourceDiversityMean;
  final double sourceDiversityVariance;
  final int summaryEligible;
  final int summaryCacheHits;
  final int summaryGenerated;
  final int summaryFailures;
  final int summaryProviderCalls;
  final int summaryLatencyMilliseconds;
  final double summaryCostUsd;

  double get completionRate => _rate(completions, opens);
  double get quickExitRate => _rate(quickExits, opens);
  double get summaryCacheHitRate => _rate(summaryCacheHits, summaryEligible);
  double get summarySuccessRate =>
      _rate(summaryCacheHits + summaryGenerated, summaryEligible);
  double get averageSummaryLatencyMilliseconds =>
      _rate(summaryLatencyMilliseconds, summaryGenerated + summaryFailures);
  double get averageSummaryCostUsd =>
      summaryGenerated == 0 ? 0 : summaryCostUsd / summaryGenerated;

  Map<String, Object> toAggregateJson() => <String, Object>{
        'arm': arm.name,
        'exposures': exposures,
        'exposedArticles': exposedArticles,
        'opens': opens,
        'activeSeconds': activeSeconds,
        'completions': completions,
        'quickExits': quickExits,
        'completionRate': completionRate,
        'quickExitRate': quickExitRate,
        'sourceDiversityMean': sourceDiversityMean,
        'summaryEligible': summaryEligible,
        'summaryCacheHits': summaryCacheHits,
        'summaryGenerated': summaryGenerated,
        'summaryFailures': summaryFailures,
        'summaryProviderCalls': summaryProviderCalls,
        'summaryCacheHitRate': summaryCacheHitRate,
        'summarySuccessRate': summarySuccessRate,
        'averageSummaryLatencyMilliseconds': averageSummaryLatencyMilliseconds,
        'summaryCostUsd': summaryCostUsd,
        'averageSummaryCostUsd': averageSummaryCostUsd,
      };
}

final class RankingExperimentDifference {
  const RankingExperimentDifference({
    required this.estimate,
    required this.lower95,
    required this.upper95,
  });

  final double estimate;
  final double lower95;
  final double upper95;

  Map<String, double> toJson() => <String, double>{
        'estimate': estimate,
        'lower95': lower95,
        'upper95': upper95,
      };
}

final class RankingExperimentReport {
  const RankingExperimentReport({
    required this.experimentId,
    required this.startDay,
    required this.endDay,
    required this.chronological,
    required this.personalized,
    required this.completionRateLift,
    required this.quickExitRateDelta,
    required this.sourceDiversityDelta,
    required this.decision,
  });

  final String experimentId;
  final String startDay;
  final String endDay;
  final RankingExperimentArmMetrics chronological;
  final RankingExperimentArmMetrics personalized;
  final RankingExperimentDifference completionRateLift;
  final RankingExperimentDifference quickExitRateDelta;
  final RankingExperimentDifference sourceDiversityDelta;
  final RankingExperimentDecision decision;

  String exportAggregateJson() {
    if (decision == RankingExperimentDecision.insufficientData) {
      throw StateError('Insufficient aggregate sample for export.');
    }
    return jsonEncode(<String, Object>{
      'schema': rankingExperimentAggregateSchema,
      'experimentId': experimentId,
      'startDay': startDay,
      'endDay': endDay,
      'arms': <Object>[
        chronological.toAggregateJson(),
        personalized.toAggregateJson(),
      ],
      'differences': <String, Object>{
        'completionRateLift': completionRateLift.toJson(),
        'quickExitRateDelta': quickExitRateDelta.toJson(),
        'sourceDiversityDelta': sourceDiversityDelta.toJson(),
      },
      'decision': decision.name,
    });
  }
}

final class LocalRankingExperiment {
  const LocalRankingExperiment({
    required RankingExperimentRepository repository,
    this.minimumOpensPerArm = 100,
    this.minimumExposuresPerArm = 20,
    this.maximumQuickExitIncrease = 0.02,
    this.maximumDiversityDecrease = 0.05,
  }) : _repository = repository;

  final RankingExperimentRepository _repository;
  final int minimumOpensPerArm;
  final int minimumExposuresPerArm;
  final double maximumQuickExitIncrease;
  final double maximumDiversityDecrease;

  Future<RankingExperimentEnrollment?> readEnrollment() =>
      _repository.readEnrollment();

  Stream<RankingExperimentEnrollment?> watchEnrollment() =>
      _repository.watchEnrollment();

  Future<RankingExperimentEnrollment> enable({
    required String entropy,
    required DateTime now,
    String experimentId = rankingExperimentId,
  }) async {
    final existing = await _repository.readEnrollment();
    if (existing?.experimentId == experimentId) return existing!;
    final enrollment = RankingExperimentEnrollment(
      experimentId: experimentId,
      arm: assignRankingExperimentArm(
        experimentId: experimentId,
        entropy: entropy,
      ),
      assignedAt: now.toUtc(),
    );
    enrollment.validate();
    await _repository.saveEnrollment(enrollment);
    return enrollment;
  }

  Future<void> disable({required DateTime now}) =>
      _repository.disable(updatedAt: now.toUtc());

  Future<bool> shouldUsePersonalizedRanking() async {
    final enrollment = await _repository.readEnrollment();
    return enrollment == null ||
        enrollment.arm == RankingExperimentArm.personalized;
  }

  Future<void> recordExposure({
    required Iterable<String> sourceIds,
    required DateTime now,
  }) async {
    final enrollment = await _repository.readEnrollment();
    if (enrollment == null) return;
    final sources = sourceIds.toList(growable: false);
    if (sources.isEmpty) return;
    await _repository.recordExposure(
      RankingExperimentExposure(
        experimentId: enrollment.experimentId,
        arm: enrollment.arm,
        dayKey: rankingExperimentLocalDayKey(now),
        articleCount: sources.length,
        sourceDiversity: normalizedSourceDiversity(sources),
        recordedAt: now.toUtc(),
      ),
    );
  }

  Future<void> recordReadingOutcome({
    required RankingExperimentEnrollment enrollment,
    required int activeSeconds,
    required bool completed,
    required DateTime now,
  }) =>
      _repository.recordReadingOutcome(
        RankingExperimentReadingOutcome(
          experimentId: enrollment.experimentId,
          arm: enrollment.arm,
          dayKey: rankingExperimentLocalDayKey(now),
          activeSeconds: activeSeconds,
          completed: completed,
          quickExit: !completed && activeSeconds < 10,
          recordedAt: now.toUtc(),
        ),
      );

  Future<void> recordSummaryObservation({
    required DateTime now,
    int eligible = 0,
    int cacheHits = 0,
    int generated = 0,
    int failures = 0,
    int providerCalls = 0,
    int latencyMilliseconds = 0,
    double costUsd = 0,
  }) async {
    final enrollment = await _repository.readEnrollment();
    if (enrollment == null) return;
    await _repository.recordSummaryObservation(
      RankingExperimentSummaryObservation(
        experimentId: enrollment.experimentId,
        arm: enrollment.arm,
        dayKey: rankingExperimentLocalDayKey(now),
        recordedAt: now.toUtc(),
        eligible: eligible,
        cacheHits: cacheHits,
        generated: generated,
        failures: failures,
        providerCalls: providerCalls,
        latencyMilliseconds: latencyMilliseconds,
        costUsd: costUsd,
      ),
    );
  }

  Future<RankingExperimentReport> buildReport({
    required String startDay,
    required String endDay,
    String experimentId = rankingExperimentId,
  }) async {
    final rows = await _repository.readMetrics(
      experimentId: experimentId,
      startDay: startDay,
      endDay: endDay,
    );
    final chronological = _aggregate(
      RankingExperimentArm.chronological,
      rows.where((row) => row.arm == RankingExperimentArm.chronological),
    );
    final personalized = _aggregate(
      RankingExperimentArm.personalized,
      rows.where((row) => row.arm == RankingExperimentArm.personalized),
    );
    final completion = _proportionDifference(
      personalized.completions,
      personalized.opens,
      chronological.completions,
      chronological.opens,
    );
    final quickExit = _proportionDifference(
      personalized.quickExits,
      personalized.opens,
      chronological.quickExits,
      chronological.opens,
    );
    final diversity = _meanDifference(
      personalized.sourceDiversityMean,
      personalized.sourceDiversityVariance,
      personalized.exposures,
      chronological.sourceDiversityMean,
      chronological.sourceDiversityVariance,
      chronological.exposures,
    );
    final enough = chronological.opens >= minimumOpensPerArm &&
        personalized.opens >= minimumOpensPerArm &&
        chronological.exposures >= minimumExposuresPerArm &&
        personalized.exposures >= minimumExposuresPerArm;
    final passes = completion.lower95 > 0 &&
        quickExit.upper95 <= maximumQuickExitIncrease &&
        diversity.lower95 >= -maximumDiversityDecrease;
    return RankingExperimentReport(
      experimentId: experimentId,
      startDay: startDay,
      endDay: endDay,
      chronological: chronological,
      personalized: personalized,
      completionRateLift: completion,
      quickExitRateDelta: quickExit,
      sourceDiversityDelta: diversity,
      decision: !enough
          ? RankingExperimentDecision.insufficientData
          : passes
              ? RankingExperimentDecision.ship
              : RankingExperimentDecision.hold,
    );
  }

  Future<int> clearMetrics({String experimentId = rankingExperimentId}) =>
      _repository.clearMetrics(experimentId: experimentId);
}

RankingExperimentArm assignRankingExperimentArm({
  required String experimentId,
  required String entropy,
}) {
  if (experimentId.isEmpty ||
      experimentId.length > 96 ||
      entropy.trim() != entropy ||
      entropy.isEmpty ||
      entropy.length > 256) {
    throw ArgumentError('Invalid ranking experiment assignment input.');
  }
  var hash = 2166136261;
  for (final value in '$experimentId\u001f$entropy'.codeUnits) {
    hash ^= value;
    hash = (hash * 16777619) & 0xffffffff;
  }
  return hash.isEven
      ? RankingExperimentArm.chronological
      : RankingExperimentArm.personalized;
}

double normalizedSourceDiversity(Iterable<String> sourceIds) {
  final values = sourceIds.toList(growable: false);
  if (values.length < 2) return 0;
  if (values.length > 500 ||
      values.any(
        (value) => value.isEmpty || value.length > 256 || value.trim() != value,
      )) {
    throw ArgumentError('Invalid source diversity input.');
  }
  final counts = <String, int>{};
  for (final value in values) {
    counts.update(value, (count) => count + 1, ifAbsent: () => 1);
  }
  final total = values.length.toDouble();
  final concentration = counts.values.fold<double>(
    0,
    (sum, count) => sum + math.pow(count / total, 2).toDouble(),
  );
  final maximumConcentration = 1 / total;
  return ((1 - concentration) / (1 - maximumConcentration)).clamp(0, 1);
}

String rankingExperimentLocalDayKey(DateTime now) {
  final local = now.toLocal();
  return '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}

RankingExperimentArmMetrics _aggregate(
  RankingExperimentArm arm,
  Iterable<RankingExperimentDailyMetrics> rows,
) {
  var exposures = 0;
  var exposedArticles = 0;
  var diversitySum = 0.0;
  var diversitySquaredSum = 0.0;
  var opens = 0;
  var activeSeconds = 0;
  var completions = 0;
  var quickExits = 0;
  var eligible = 0;
  var cacheHits = 0;
  var generated = 0;
  var failures = 0;
  var providerCalls = 0;
  var latency = 0;
  var cost = 0.0;
  for (final row in rows) {
    row.validate();
    exposures += row.exposures;
    exposedArticles += row.exposedArticles;
    diversitySum += row.sourceDiversitySum;
    diversitySquaredSum += row.sourceDiversitySquaredSum;
    opens += row.opens;
    activeSeconds += row.activeSeconds;
    completions += row.completions;
    quickExits += row.quickExits;
    eligible += row.summaryEligible;
    cacheHits += row.summaryCacheHits;
    generated += row.summaryGenerated;
    failures += row.summaryFailures;
    providerCalls += row.summaryProviderCalls;
    latency += row.summaryLatencyMilliseconds;
    cost += row.summaryCostUsd;
  }
  final diversityMean = _rateDouble(diversitySum, exposures);
  final diversityVariance = exposures < 2
      ? 0.0
      : math.max<double>(
          0,
          (diversitySquaredSum - exposures * diversityMean * diversityMean) /
              (exposures - 1),
        );
  return RankingExperimentArmMetrics(
    arm: arm,
    exposures: exposures,
    exposedArticles: exposedArticles,
    opens: opens,
    activeSeconds: activeSeconds,
    completions: completions,
    quickExits: quickExits,
    sourceDiversityMean: diversityMean,
    sourceDiversityVariance: diversityVariance,
    summaryEligible: eligible,
    summaryCacheHits: cacheHits,
    summaryGenerated: generated,
    summaryFailures: failures,
    summaryProviderCalls: providerCalls,
    summaryLatencyMilliseconds: latency,
    summaryCostUsd: cost,
  );
}

RankingExperimentDifference _proportionDifference(
  int treatmentSuccesses,
  int treatmentTotal,
  int controlSuccesses,
  int controlTotal,
) {
  final treatment = _rate(treatmentSuccesses, treatmentTotal);
  final control = _rate(controlSuccesses, controlTotal);
  final difference = treatment - control;
  if (treatmentTotal == 0 || controlTotal == 0) {
    return RankingExperimentDifference(
      estimate: difference,
      lower95: double.negativeInfinity,
      upper95: double.infinity,
    );
  }
  final standardError = math.sqrt(
    treatment * (1 - treatment) / treatmentTotal +
        control * (1 - control) / controlTotal,
  );
  return RankingExperimentDifference(
    estimate: difference,
    lower95: difference - 1.96 * standardError,
    upper95: difference + 1.96 * standardError,
  );
}

RankingExperimentDifference _meanDifference(
  double treatmentMean,
  double treatmentVariance,
  int treatmentCount,
  double controlMean,
  double controlVariance,
  int controlCount,
) {
  final difference = treatmentMean - controlMean;
  if (treatmentCount < 2 || controlCount < 2) {
    return RankingExperimentDifference(
      estimate: difference,
      lower95: double.negativeInfinity,
      upper95: double.infinity,
    );
  }
  final standardError = math.sqrt(
    treatmentVariance / treatmentCount + controlVariance / controlCount,
  );
  return RankingExperimentDifference(
    estimate: difference,
    lower95: difference - 1.96 * standardError,
    upper95: difference + 1.96 * standardError,
  );
}

double _rate(int numerator, int denominator) =>
    denominator == 0 ? 0 : numerator / denominator;

double _rateDouble(double numerator, int denominator) =>
    denominator == 0 ? 0 : numerator / denominator;
