import 'package:river_domain/river_domain.dart';
import 'package:test/test.dart';

void main() {
  test('default policy is battery-aware and uses an opportunistic interval',
      () {
    final policy = BackgroundRefreshPolicy();

    expect(policy.enabled, isTrue);
    expect(policy.interval, const Duration(hours: 1));
    expect(policy.wifiOnly, isFalse);
    expect(policy.pauseWhenBatteryLow, isTrue);
    expect(policy.toPlatformArguments(), <String, Object>{
      'enabled': true,
      'intervalMinutes': 60,
      'wifiOnly': false,
      'pauseWhenBatteryLow': true,
    });
  });

  test('supported interval is between fifteen minutes and one day', () {
    expect(
      () => BackgroundRefreshPolicy(
        interval: const Duration(minutes: 14),
      ),
      throwsArgumentError,
    );
    expect(
      () => BackgroundRefreshPolicy(
        interval: const Duration(hours: 25),
      ),
      throwsArgumentError,
    );
  });

  test('supported schedule never claims exact execution', () {
    const status = BackgroundRefreshStatus(
      platform: BackgroundRefreshPlatform.ios,
      state: BackgroundRefreshScheduleState.scheduled,
      interval: Duration(hours: 1),
      isExact: false,
    );

    expect(status.isExact, isFalse);
  });
}
