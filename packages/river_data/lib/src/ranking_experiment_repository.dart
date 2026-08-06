import 'package:drift/drift.dart';
import 'package:river_domain/river_domain.dart' as domain;

import 'database.dart';

final class DriftRankingExperimentRepository
    implements domain.RankingExperimentRepository {
  const DriftRankingExperimentRepository(this._database);

  final RiverDatabase _database;

  @override
  Future<domain.RankingExperimentEnrollment?> readEnrollment() async =>
      _enrollmentFromRow(await _readEnrollmentRow());

  @override
  Stream<domain.RankingExperimentEnrollment?> watchEnrollment() =>
      (_database.select(_database.rankingExperimentEnrollmentRows)
            ..where((table) => table.id.equals(1)))
          .watchSingleOrNull()
          .map(_enrollmentFromRow);

  @override
  Future<void> saveEnrollment(
    domain.RankingExperimentEnrollment enrollment,
  ) async {
    enrollment.validate();
    await _database.transaction(() async {
      final existing = await _readEnrollmentRow();
      if (existing != null &&
          existing.experimentId == enrollment.experimentId &&
          existing.arm != enrollment.arm.name) {
        throw StateError('Ranking experiment arm cannot be reassigned.');
      }
      await _database
          .into(_database.rankingExperimentEnrollmentRows)
          .insertOnConflictUpdate(
            RankingExperimentEnrollmentRowsCompanion.insert(
              id: const Value<int>(1),
              experimentId: enrollment.experimentId,
              arm: enrollment.arm.name,
              assignedAt: enrollment.assignedAt.toUtc(),
              updatedAt: enrollment.assignedAt.toUtc(),
            ),
          );
    });
  }

  @override
  Future<void> disable({required DateTime updatedAt}) async {
    if (!updatedAt.isUtc) {
      throw ArgumentError.value(updatedAt, 'updatedAt');
    }
    await (_database.delete(
      _database.rankingExperimentEnrollmentRows,
    )..where((table) => table.id.equals(1))).go();
  }

  @override
  Future<void> recordExposure(domain.RankingExperimentExposure exposure) {
    exposure.validate();
    return _mutate(
      experimentId: exposure.experimentId,
      arm: exposure.arm,
      dayKey: exposure.dayKey,
      recordedAt: exposure.recordedAt,
      delta: _MetricsDelta(
        exposures: 1,
        exposedArticles: exposure.articleCount,
        sourceDiversitySum: exposure.sourceDiversity,
        sourceDiversitySquaredSum:
            exposure.sourceDiversity * exposure.sourceDiversity,
      ),
    );
  }

  @override
  Future<void> recordReadingOutcome(
    domain.RankingExperimentReadingOutcome outcome,
  ) {
    outcome.validate();
    return _mutate(
      experimentId: outcome.experimentId,
      arm: outcome.arm,
      dayKey: outcome.dayKey,
      recordedAt: outcome.recordedAt,
      delta: _MetricsDelta(
        opens: 1,
        activeSeconds: outcome.activeSeconds,
        completions: outcome.completed ? 1 : 0,
        quickExits: outcome.quickExit ? 1 : 0,
      ),
    );
  }

  @override
  Future<void> recordSummaryObservation(
    domain.RankingExperimentSummaryObservation observation,
  ) {
    observation.validate();
    return _mutate(
      experimentId: observation.experimentId,
      arm: observation.arm,
      dayKey: observation.dayKey,
      recordedAt: observation.recordedAt,
      delta: _MetricsDelta(
        summaryEligible: observation.eligible,
        summaryCacheHits: observation.cacheHits,
        summaryGenerated: observation.generated,
        summaryFailures: observation.failures,
        summaryProviderCalls: observation.providerCalls,
        summaryLatencyMilliseconds: observation.latencyMilliseconds,
        summaryCostUsd: observation.costUsd,
      ),
    );
  }

  @override
  Future<List<domain.RankingExperimentDailyMetrics>> readMetrics({
    required String experimentId,
    required String startDay,
    required String endDay,
  }) async {
    _validateQuery(experimentId, startDay, endDay);
    final query = _database.select(_database.rankingExperimentDailyMetricRows)
      ..where(
        (table) =>
            table.experimentId.equals(experimentId) &
            table.dayKey.isBiggerOrEqualValue(startDay) &
            table.dayKey.isSmallerOrEqualValue(endDay),
      )
      ..orderBy([
        (table) => OrderingTerm.asc(table.dayKey),
        (table) => OrderingTerm.asc(table.arm),
      ]);
    return List<domain.RankingExperimentDailyMetrics>.unmodifiable(
      (await query.get()).map(_metricsFromRow),
    );
  }

  @override
  Future<int> clearMetrics({required String experimentId}) async {
    _validateExperimentId(experimentId);
    return (_database.delete(
      _database.rankingExperimentDailyMetricRows,
    )..where((table) => table.experimentId.equals(experimentId))).go();
  }

  Future<void> _mutate({
    required String experimentId,
    required domain.RankingExperimentArm arm,
    required String dayKey,
    required DateTime recordedAt,
    required _MetricsDelta delta,
  }) async {
    await _database.transaction(() async {
      final enrollment = _enrollmentFromRow(await _readEnrollmentRow());
      if (enrollment == null ||
          enrollment.experimentId != experimentId ||
          enrollment.arm != arm) {
        return;
      }
      final query = _database.select(_database.rankingExperimentDailyMetricRows)
        ..where(
          (table) =>
              table.experimentId.equals(experimentId) &
              table.arm.equals(arm.name) &
              table.dayKey.equals(dayKey),
        );
      final existing = await query.getSingleOrNull();
      final next = delta.apply(
        existing == null
            ? domain.RankingExperimentDailyMetrics(
                experimentId: experimentId,
                arm: arm,
                dayKey: dayKey,
              )
            : _metricsFromRow(existing),
      );
      next.validate();
      final companion = _companion(next, recordedAt);
      if (existing == null) {
        await _database
            .into(_database.rankingExperimentDailyMetricRows)
            .insert(companion);
      } else {
        await (_database.update(_database.rankingExperimentDailyMetricRows)
              ..where(
                (table) =>
                    table.experimentId.equals(experimentId) &
                    table.arm.equals(arm.name) &
                    table.dayKey.equals(dayKey),
              ))
            .write(companion);
      }
    });
  }

  Future<RankingExperimentEnrollmentRow?> _readEnrollmentRow() =>
      (_database.select(
        _database.rankingExperimentEnrollmentRows,
      )..where((table) => table.id.equals(1))).getSingleOrNull();
}

final class _MetricsDelta {
  const _MetricsDelta({
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

  domain.RankingExperimentDailyMetrics apply(
    domain.RankingExperimentDailyMetrics current,
  ) => domain.RankingExperimentDailyMetrics(
    experimentId: current.experimentId,
    arm: current.arm,
    dayKey: current.dayKey,
    exposures: current.exposures + exposures,
    exposedArticles: current.exposedArticles + exposedArticles,
    sourceDiversitySum: current.sourceDiversitySum + sourceDiversitySum,
    sourceDiversitySquaredSum:
        current.sourceDiversitySquaredSum + sourceDiversitySquaredSum,
    opens: current.opens + opens,
    activeSeconds: current.activeSeconds + activeSeconds,
    completions: current.completions + completions,
    quickExits: current.quickExits + quickExits,
    summaryEligible: current.summaryEligible + summaryEligible,
    summaryCacheHits: current.summaryCacheHits + summaryCacheHits,
    summaryGenerated: current.summaryGenerated + summaryGenerated,
    summaryFailures: current.summaryFailures + summaryFailures,
    summaryProviderCalls: current.summaryProviderCalls + summaryProviderCalls,
    summaryLatencyMilliseconds:
        current.summaryLatencyMilliseconds + summaryLatencyMilliseconds,
    summaryCostUsd: current.summaryCostUsd + summaryCostUsd,
  );
}

domain.RankingExperimentEnrollment? _enrollmentFromRow(
  RankingExperimentEnrollmentRow? row,
) {
  if (row == null) return null;
  final enrollment = domain.RankingExperimentEnrollment(
    experimentId: row.experimentId,
    arm: _arm(row.arm),
    assignedAt: row.assignedAt.toUtc(),
  );
  enrollment.validate();
  return enrollment;
}

domain.RankingExperimentDailyMetrics _metricsFromRow(
  RankingExperimentDailyMetricRow row,
) {
  final metrics = domain.RankingExperimentDailyMetrics(
    experimentId: row.experimentId,
    arm: _arm(row.arm),
    dayKey: row.dayKey,
    exposures: row.exposures,
    exposedArticles: row.exposedArticles,
    sourceDiversitySum: row.sourceDiversitySum,
    sourceDiversitySquaredSum: row.sourceDiversitySquaredSum,
    opens: row.opens,
    activeSeconds: row.activeSeconds,
    completions: row.completions,
    quickExits: row.quickExits,
    summaryEligible: row.summaryEligible,
    summaryCacheHits: row.summaryCacheHits,
    summaryGenerated: row.summaryGenerated,
    summaryFailures: row.summaryFailures,
    summaryProviderCalls: row.summaryProviderCalls,
    summaryLatencyMilliseconds: row.summaryLatencyMilliseconds,
    summaryCostUsd: row.summaryCostUsd,
  );
  metrics.validate();
  return metrics;
}

RankingExperimentDailyMetricRowsCompanion _companion(
  domain.RankingExperimentDailyMetrics metrics,
  DateTime recordedAt,
) => RankingExperimentDailyMetricRowsCompanion.insert(
  experimentId: metrics.experimentId,
  arm: metrics.arm.name,
  dayKey: metrics.dayKey,
  exposures: Value<int>(metrics.exposures),
  exposedArticles: Value<int>(metrics.exposedArticles),
  sourceDiversitySum: Value<double>(metrics.sourceDiversitySum),
  sourceDiversitySquaredSum: Value<double>(metrics.sourceDiversitySquaredSum),
  opens: Value<int>(metrics.opens),
  activeSeconds: Value<int>(metrics.activeSeconds),
  completions: Value<int>(metrics.completions),
  quickExits: Value<int>(metrics.quickExits),
  summaryEligible: Value<int>(metrics.summaryEligible),
  summaryCacheHits: Value<int>(metrics.summaryCacheHits),
  summaryGenerated: Value<int>(metrics.summaryGenerated),
  summaryFailures: Value<int>(metrics.summaryFailures),
  summaryProviderCalls: Value<int>(metrics.summaryProviderCalls),
  summaryLatencyMilliseconds: Value<int>(metrics.summaryLatencyMilliseconds),
  summaryCostUsd: Value<double>(metrics.summaryCostUsd),
  updatedAt: recordedAt.toUtc(),
);

domain.RankingExperimentArm _arm(String value) => switch (value) {
  'chronological' => domain.RankingExperimentArm.chronological,
  'personalized' => domain.RankingExperimentArm.personalized,
  _ => throw const FormatException('Invalid ranking experiment arm.'),
};

void _validateQuery(String experimentId, String startDay, String endDay) {
  _validateExperimentId(experimentId);
  if (!_dayKey.hasMatch(startDay) ||
      !_dayKey.hasMatch(endDay) ||
      startDay.compareTo(endDay) > 0) {
    throw const FormatException('Invalid ranking experiment date range.');
  }
}

void _validateExperimentId(String value) {
  if (!_experimentId.hasMatch(value)) {
    throw const FormatException('Invalid ranking experiment ID.');
  }
}

final RegExp _experimentId = RegExp(r'^[a-z][a-z0-9-]{0,79}/[1-9][0-9]{0,8}$');
final RegExp _dayKey = RegExp(r'^\d{4}-\d{2}-\d{2}$');
