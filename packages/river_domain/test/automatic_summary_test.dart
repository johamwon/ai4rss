import 'package:river_domain/river_domain.dart';
import 'package:test/test.dart';

void main() {
  test('automatic summary policy defaults closed and stays bounded', () {
    const defaults = AutomaticSummarySettings();
    defaults.validate();
    expect(defaults.enabled, isFalse);
    expect(defaults.wifiOnly, isTrue);
    expect(defaults.dailyLimit, 3);

    expect(
      () => const AutomaticSummarySettings(dailyLimit: 0).validate(),
      throwsFormatException,
    );
    expect(
      () => const AutomaticSummarySettings(
        dailyLimit: AutomaticSummarySettings.maximumDailyLimit + 1,
      ).validate(),
      throwsFormatException,
    );
    expect(
      () => const AutomaticSummarySettings(
        minimumRankingScore: double.nan,
      ).validate(),
      throwsFormatException,
    );
  });

  test('usage snapshot counts reservations against the daily cap', () {
    const usage = AutomaticSummaryUsageSnapshot(
      dayKey: '2026-08-05',
      reserved: 2,
      completed: 3,
    );

    expect(usage.consumed, 5);
  });
}
