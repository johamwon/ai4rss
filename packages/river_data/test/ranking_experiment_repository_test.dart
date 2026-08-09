import 'package:drift/native.dart';
import 'package:river_data/river_data.dart';
import 'package:river_domain/river_domain.dart';
import 'package:test/test.dart';

void main() {
  late RiverDatabase database;
  late DriftRankingExperimentRepository repository;
  final at = DateTime.utc(2026, 8, 6, 12);

  setUp(() {
    database = RiverDatabase(NativeDatabase.memory());
    repository = DriftRankingExperimentRepository(database);
  });

  tearDown(() => database.close());

  test('default off and enrollment arm cannot be reassigned', () async {
    expect(await repository.readEnrollment(), isNull);
    final enrollment = _enrollment(at);
    await repository.saveEnrollment(enrollment);
    expect((await repository.readEnrollment())?.arm, enrollment.arm);
    expect(
      () => repository.saveEnrollment(
        RankingExperimentEnrollment(
          experimentId: enrollment.experimentId,
          arm: RankingExperimentArm.chronological,
          assignedAt: at,
        ),
      ),
      throwsStateError,
    );
  });

  test('disabled and wrong-arm observations are dropped', () async {
    await repository.recordExposure(_exposure(at));
    await repository.saveEnrollment(_enrollment(at));
    await repository.recordExposure(
      RankingExperimentExposure(
        experimentId: 'ranking-time-control/1',
        arm: RankingExperimentArm.chronological,
        dayKey: '2026-08-06',
        articleCount: 10,
        sourceDiversity: 1,
        recordedAt: at,
      ),
    );
    expect(
      await repository.readMetrics(
        experimentId: 'ranking-time-control/1',
        startDay: '2026-08-06',
        endDay: '2026-08-06',
      ),
      isEmpty,
    );
  });

  test(
    'concurrent increments preserve every aggregate and injected time',
    () async {
      await repository.saveEnrollment(_enrollment(at));
      await Future.wait(<Future<void>>[
        for (var index = 0; index < 25; index++)
          repository.recordExposure(_exposure(at)),
      ]);
      await repository.recordReadingOutcome(
        RankingExperimentReadingOutcome(
          experimentId: 'ranking-time-control/1',
          arm: RankingExperimentArm.personalized,
          dayKey: '2026-08-06',
          activeSeconds: 42,
          completed: true,
          quickExit: false,
          recordedAt: at,
        ),
      );
      await repository.recordSummaryObservation(
        RankingExperimentSummaryObservation(
          experimentId: 'ranking-time-control/1',
          arm: RankingExperimentArm.personalized,
          dayKey: '2026-08-06',
          recordedAt: at,
          eligible: 1,
          generated: 1,
          providerCalls: 1,
          latencyMilliseconds: 250,
          costUsd: 0.002,
        ),
      );

      final row = (await repository.readMetrics(
        experimentId: 'ranking-time-control/1',
        startDay: '2026-08-06',
        endDay: '2026-08-06',
      )).single;
      expect(row.exposures, 25);
      expect(row.exposedArticles, 250);
      expect(row.opens, 1);
      expect(row.completions, 1);
      expect(row.summaryGenerated, 1);
      expect(row.summaryProviderCalls, 1);
      expect(row.summaryCostUsd, 0.002);
      expect(
        (await database
                .select(database.rankingExperimentDailyMetricRows)
                .getSingle())
            .updatedAt
            .toUtc(),
        at,
      );

      expect(await repository.clearMetrics(experimentId: row.experimentId), 1);
      expect(
        await database.select(database.rankingExperimentDailyMetricRows).get(),
        isEmpty,
      );
    },
  );
}

RankingExperimentEnrollment _enrollment(DateTime at) =>
    RankingExperimentEnrollment(
      experimentId: 'ranking-time-control/1',
      arm: RankingExperimentArm.personalized,
      assignedAt: at,
    );

RankingExperimentExposure _exposure(DateTime at) => RankingExperimentExposure(
  experimentId: 'ranking-time-control/1',
  arm: RankingExperimentArm.personalized,
  dayKey: '2026-08-06',
  articleCount: 10,
  sourceDiversity: 0.5,
  recordedAt: at,
);
