enum RankingExperimentArm { chronological, personalized }

final class RankingExperimentEnrollment {
  const RankingExperimentEnrollment({
    required this.experimentId,
    required this.arm,
    required this.assignedAt,
  });

  final String experimentId;
  final RankingExperimentArm arm;
  final DateTime assignedAt;

  void validate() {
    if (!_experimentId.hasMatch(experimentId) || !assignedAt.isUtc) {
      throw const FormatException('Invalid ranking experiment enrollment.');
    }
  }
}

final class RankingExperimentExposure {
  const RankingExperimentExposure({
    required this.experimentId,
    required this.arm,
    required this.dayKey,
    required this.articleCount,
    required this.sourceDiversity,
    required this.recordedAt,
  });

  final String experimentId;
  final RankingExperimentArm arm;
  final String dayKey;
  final int articleCount;
  final double sourceDiversity;
  final DateTime recordedAt;

  void validate() {
    _validateIdentity(experimentId, dayKey);
    if (articleCount < 1 ||
        articleCount > 500 ||
        !sourceDiversity.isFinite ||
        sourceDiversity < 0 ||
        sourceDiversity > 1 ||
        !recordedAt.isUtc) {
      throw const FormatException('Invalid ranking experiment exposure.');
    }
  }
}

final class RankingExperimentReadingOutcome {
  const RankingExperimentReadingOutcome({
    required this.experimentId,
    required this.arm,
    required this.dayKey,
    required this.activeSeconds,
    required this.completed,
    required this.quickExit,
    required this.recordedAt,
  });

  final String experimentId;
  final RankingExperimentArm arm;
  final String dayKey;
  final int activeSeconds;
  final bool completed;
  final bool quickExit;
  final DateTime recordedAt;

  void validate() {
    _validateIdentity(experimentId, dayKey);
    if (activeSeconds < 0 ||
        activeSeconds > const Duration(days: 1).inSeconds ||
        completed && quickExit ||
        !recordedAt.isUtc) {
      throw const FormatException('Invalid ranking experiment outcome.');
    }
  }
}

final class RankingExperimentSummaryObservation {
  const RankingExperimentSummaryObservation({
    required this.experimentId,
    required this.arm,
    required this.dayKey,
    required this.recordedAt,
    this.eligible = 0,
    this.cacheHits = 0,
    this.generated = 0,
    this.failures = 0,
    this.providerCalls = 0,
    this.latencyMilliseconds = 0,
    this.costUsd = 0,
  });

  final String experimentId;
  final RankingExperimentArm arm;
  final String dayKey;
  final DateTime recordedAt;
  final int eligible;
  final int cacheHits;
  final int generated;
  final int failures;
  final int providerCalls;
  final int latencyMilliseconds;
  final double costUsd;

  void validate() {
    _validateIdentity(experimentId, dayKey);
    final counts = <int>[
      eligible,
      cacheHits,
      generated,
      failures,
      providerCalls,
      latencyMilliseconds,
    ];
    if (counts.any((value) => value < 0) ||
        counts.every((value) => value == 0) && costUsd == 0 ||
        eligible > 500 ||
        cacheHits > 500 ||
        generated > 500 ||
        failures > 500 ||
        providerCalls > 1024 ||
        latencyMilliseconds > const Duration(days: 1).inMilliseconds ||
        !costUsd.isFinite ||
        costUsd < 0 ||
        costUsd > 10000 ||
        !recordedAt.isUtc) {
      throw const FormatException('Invalid automatic summary observation.');
    }
  }
}

final class RankingExperimentDailyMetrics {
  const RankingExperimentDailyMetrics({
    required this.experimentId,
    required this.arm,
    required this.dayKey,
    this.exposures = 0,
    this.exposedArticles = 0,
    this.sourceDiversitySum = 0,
    this.sourceDiversitySquaredSum = 0,
    this.opens = 0,
    this.activeSeconds = 0,
    this.completions = 0,
    this.quickExits = 0,
    this.summaryEligible = 0,
    this.summaryCacheHits = 0,
    this.summaryGenerated = 0,
    this.summaryFailures = 0,
    this.summaryProviderCalls = 0,
    this.summaryLatencyMilliseconds = 0,
    this.summaryCostUsd = 0,
  });

  final String experimentId;
  final RankingExperimentArm arm;
  final String dayKey;
  final int exposures;
  final int exposedArticles;
  final double sourceDiversitySum;
  final double sourceDiversitySquaredSum;
  final int opens;
  final int activeSeconds;
  final int completions;
  final int quickExits;
  final int summaryEligible;
  final int summaryCacheHits;
  final int summaryGenerated;
  final int summaryFailures;
  final int summaryProviderCalls;
  final int summaryLatencyMilliseconds;
  final double summaryCostUsd;

  void validate() {
    _validateIdentity(experimentId, dayKey);
    final counts = <int>[
      exposures,
      exposedArticles,
      opens,
      activeSeconds,
      completions,
      quickExits,
      summaryEligible,
      summaryCacheHits,
      summaryGenerated,
      summaryFailures,
      summaryProviderCalls,
      summaryLatencyMilliseconds,
    ];
    if (counts.any((value) => value < 0) ||
        completions > opens ||
        quickExits > opens ||
        !sourceDiversitySum.isFinite ||
        !sourceDiversitySquaredSum.isFinite ||
        sourceDiversitySum < 0 ||
        sourceDiversitySquaredSum < 0 ||
        sourceDiversitySum > exposures ||
        sourceDiversitySquaredSum > exposures ||
        !summaryCostUsd.isFinite ||
        summaryCostUsd < 0) {
      throw const FormatException('Invalid ranking experiment metrics.');
    }
  }
}

abstract interface class RankingExperimentRepository {
  Future<RankingExperimentEnrollment?> readEnrollment();

  Stream<RankingExperimentEnrollment?> watchEnrollment();

  Future<void> saveEnrollment(RankingExperimentEnrollment enrollment);

  Future<void> disable({required DateTime updatedAt});

  Future<void> recordExposure(RankingExperimentExposure exposure);

  Future<void> recordReadingOutcome(RankingExperimentReadingOutcome outcome);

  Future<void> recordSummaryObservation(
    RankingExperimentSummaryObservation observation,
  );

  Future<List<RankingExperimentDailyMetrics>> readMetrics({
    required String experimentId,
    required String startDay,
    required String endDay,
  });

  Future<int> clearMetrics({required String experimentId});
}

final RegExp _experimentId = RegExp(r'^[a-z][a-z0-9-]{0,79}/[1-9][0-9]{0,8}$');
final RegExp _dayKey = RegExp(r'^\d{4}-\d{2}-\d{2}$');

void _validateIdentity(String experimentId, String dayKey) {
  if (!_experimentId.hasMatch(experimentId) || !_dayKey.hasMatch(dayKey)) {
    throw const FormatException('Invalid ranking experiment identity.');
  }
}
