enum BackgroundRefreshPlatform { android, ios, windows, unsupported }

enum BackgroundRefreshScheduleState {
  scheduled,
  disabled,
  notScheduled,
  unknown
}

final class BackgroundRefreshPolicy {
  BackgroundRefreshPolicy({
    this.enabled = true,
    this.interval = const Duration(hours: 1),
    this.wifiOnly = false,
    this.pauseWhenBatteryLow = true,
  }) {
    if (interval < minimumInterval || interval > maximumInterval) {
      throw RangeError.range(
        interval.inMinutes,
        minimumInterval.inMinutes,
        maximumInterval.inMinutes,
        'interval.inMinutes',
      );
    }
  }

  static const minimumInterval = Duration(minutes: 15);
  static const maximumInterval = Duration(days: 1);

  final bool enabled;
  final Duration interval;
  final bool wifiOnly;
  final bool pauseWhenBatteryLow;

  Map<String, Object> toPlatformArguments() => <String, Object>{
        'enabled': enabled,
        'intervalMinutes': interval.inMinutes,
        'wifiOnly': wifiOnly,
        'pauseWhenBatteryLow': pauseWhenBatteryLow,
      };
}

final class BackgroundRefreshStatus {
  const BackgroundRefreshStatus({
    required this.platform,
    required this.state,
    required this.interval,
    required this.isExact,
    this.detail,
  });

  const BackgroundRefreshStatus.unsupported()
      : platform = BackgroundRefreshPlatform.unsupported,
        state = BackgroundRefreshScheduleState.unknown,
        interval = null,
        isExact = false,
        detail = 'Background refresh is unsupported on this platform.';

  final BackgroundRefreshPlatform platform;
  final BackgroundRefreshScheduleState state;
  final Duration? interval;

  /// Always false for the supported River schedulers. The operating system
  /// chooses an execution window based on power, network, and usage signals.
  final bool isExact;
  final String? detail;
}

abstract interface class BackgroundRefreshScheduler {
  Future<void> initialize(void Function() callbackDispatcher);

  Future<BackgroundRefreshStatus> configure(BackgroundRefreshPolicy policy);

  Future<BackgroundRefreshStatus> inspect();

  Future<void> cancel();
}
