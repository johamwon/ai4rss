import 'package:river_domain/river_domain.dart';
import 'package:test/test.dart';

void main() {
  final at = DateTime.utc(2026, 8, 6, 12);

  test('aggregate observations accept only bounded UTC metadata', () {
    RankingExperimentExposure(
      experimentId: 'ranking-time-control/1',
      arm: RankingExperimentArm.personalized,
      dayKey: '2026-08-06',
      articleCount: 20,
      sourceDiversity: 0.75,
      recordedAt: at,
    ).validate();

    expect(
      () => RankingExperimentReadingOutcome(
        experimentId: 'ranking-time-control/1',
        arm: RankingExperimentArm.chronological,
        dayKey: '2026-08-06',
        activeSeconds: 5,
        completed: true,
        quickExit: true,
        recordedAt: at,
      ).validate(),
      throwsFormatException,
    );
    expect(
      () => RankingExperimentSummaryObservation(
        experimentId: 'ranking-time-control/1',
        arm: RankingExperimentArm.personalized,
        dayKey: '2026-08-06',
        recordedAt: DateTime(2026, 8, 6),
        generated: 1,
      ).validate(),
      throwsFormatException,
    );
  });

  test('daily metrics reject internally inconsistent aggregates', () {
    expect(
      () => const RankingExperimentDailyMetrics(
        experimentId: 'ranking-time-control/1',
        arm: RankingExperimentArm.personalized,
        dayKey: '2026-08-06',
        opens: 1,
        completions: 2,
      ).validate(),
      throwsFormatException,
    );
  });
}
