import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:river_domain/river_domain.dart';
import 'package:workmanager/workmanager.dart';

const riverBackgroundRefreshIdentifier =
    'com.example.riverApp.backgroundFeedRefresh';
const riverBackgroundRefreshTaskName = 'river.feed.refresh';
const _windowsChannelName = 'app.river/background_refresh';
const _iosRefreshInterval = Duration(hours: 1);

typedef RiverBackgroundRefreshHandler = Future<bool> Function();

/// Connects the platform-owned background isolate to River's application
/// composition root. Unknown tasks are acknowledged without touching user data.
void executeRiverBackgroundTasks(RiverBackgroundRefreshHandler handler) {
  Workmanager().executeTask((taskName, inputData) {
    if (taskName != riverBackgroundRefreshTaskName &&
        taskName != riverBackgroundRefreshIdentifier) {
      return Future<bool>.value(true);
    }
    return handler();
  });
}

abstract interface class BackgroundWorkmanagerGateway {
  Future<void> initialize(void Function() callbackDispatcher);

  Future<void> registerPeriodic({
    required String uniqueName,
    required String taskName,
    required BackgroundRefreshPolicy policy,
  });

  Future<bool> isScheduled(String uniqueName);

  Future<void> cancel(String uniqueName);
}

final class FlutterBackgroundWorkmanagerGateway
    implements BackgroundWorkmanagerGateway {
  const FlutterBackgroundWorkmanagerGateway();

  @override
  Future<void> initialize(void Function() callbackDispatcher) =>
      Workmanager().initialize(callbackDispatcher);

  @override
  Future<void> registerPeriodic({
    required String uniqueName,
    required String taskName,
    required BackgroundRefreshPolicy policy,
  }) {
    return Workmanager().registerPeriodicTask(
      uniqueName,
      taskName,
      frequency: policy.interval,
      // The Apple adapter uses this as the first earliest-begin date. Android
      // also honors it, preventing an immediate network burst at first launch.
      initialDelay: policy.interval,
      constraints: Constraints(
        networkType:
            policy.wifiOnly ? NetworkType.unmetered : NetworkType.connected,
        requiresBatteryNotLow: policy.pauseWhenBatteryLow,
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(minutes: 15),
      tag: riverBackgroundRefreshTaskName,
    );
  }

  @override
  Future<bool> isScheduled(String uniqueName) =>
      Workmanager().isScheduledByUniqueName(uniqueName);

  @override
  Future<void> cancel(String uniqueName) =>
      Workmanager().cancelByUniqueName(uniqueName);
}

final class PlatformBackgroundRefreshScheduler
    implements BackgroundRefreshScheduler {
  PlatformBackgroundRefreshScheduler({
    TargetPlatform? platform,
    BackgroundWorkmanagerGateway workmanager =
        const FlutterBackgroundWorkmanagerGateway(),
    MethodChannel windowsChannel = const MethodChannel(_windowsChannelName),
  })  : _platform = platform ?? defaultTargetPlatform,
        _workmanager = workmanager,
        _windowsChannel = windowsChannel;

  final TargetPlatform _platform;
  final BackgroundWorkmanagerGateway _workmanager;
  final MethodChannel _windowsChannel;
  BackgroundRefreshPolicy? _lastPolicy;

  BackgroundRefreshPlatform get _riverPlatform => switch (_platform) {
        TargetPlatform.android => BackgroundRefreshPlatform.android,
        TargetPlatform.iOS => BackgroundRefreshPlatform.ios,
        TargetPlatform.windows => BackgroundRefreshPlatform.windows,
        _ => BackgroundRefreshPlatform.unsupported,
      };

  bool get _isMobile =>
      _platform == TargetPlatform.android || _platform == TargetPlatform.iOS;

  @override
  Future<void> initialize(void Function() callbackDispatcher) async {
    if (_isMobile) {
      await _workmanager.initialize(callbackDispatcher);
    }
  }

  @override
  Future<BackgroundRefreshStatus> configure(
    BackgroundRefreshPolicy policy,
  ) async {
    if (!policy.enabled) {
      await cancel();
      _lastPolicy = policy;
      return _status(
        BackgroundRefreshScheduleState.disabled,
        interval: policy.interval,
      );
    }

    switch (_platform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        final effectivePolicy = _platform == TargetPlatform.iOS
            ? BackgroundRefreshPolicy(
                interval: _iosRefreshInterval,
                wifiOnly: policy.wifiOnly,
                pauseWhenBatteryLow: policy.pauseWhenBatteryLow,
              )
            : policy;
        await _workmanager.registerPeriodic(
          uniqueName: riverBackgroundRefreshIdentifier,
          taskName: riverBackgroundRefreshTaskName,
          policy: effectivePolicy,
        );
      case TargetPlatform.windows:
        await _windowsChannel.invokeMethod<void>(
          'configure',
          policy.toPlatformArguments(),
        );
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
        return const BackgroundRefreshStatus.unsupported();
    }
    _lastPolicy = policy;
    return _status(
      BackgroundRefreshScheduleState.scheduled,
      interval: _platform == TargetPlatform.iOS
          ? _iosRefreshInterval
          : policy.interval,
      detail: _platform == TargetPlatform.iOS
          ? 'iOS chooses an opportunistic execution window; network and '
              'battery constraints are advisory only.'
          : null,
    );
  }

  @override
  Future<BackgroundRefreshStatus> inspect() async {
    switch (_platform) {
      case TargetPlatform.android:
        final scheduled = await _workmanager.isScheduled(
          riverBackgroundRefreshIdentifier,
        );
        return _status(
          scheduled
              ? BackgroundRefreshScheduleState.scheduled
              : BackgroundRefreshScheduleState.notScheduled,
          interval: _lastPolicy?.interval,
        );
      case TargetPlatform.iOS:
        final policy = _lastPolicy;
        return _status(
          policy == null
              ? BackgroundRefreshScheduleState.unknown
              : policy.enabled
                  ? BackgroundRefreshScheduleState.scheduled
                  : BackgroundRefreshScheduleState.disabled,
          interval: policy == null
              ? null
              : policy.enabled
                  ? _iosRefreshInterval
                  : policy.interval,
          detail: 'BGTaskScheduler does not expose pending requests to apps.',
        );
      case TargetPlatform.windows:
        final response = await _windowsChannel.invokeMapMethod<String, Object?>(
          'inspect',
        );
        return _statusFromWindows(response);
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
        return const BackgroundRefreshStatus.unsupported();
    }
  }

  @override
  Future<void> cancel() async {
    switch (_platform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        await _workmanager.cancel(riverBackgroundRefreshIdentifier);
      case TargetPlatform.windows:
        await _windowsChannel.invokeMethod<void>('cancel');
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
        break;
    }
  }

  BackgroundRefreshStatus _status(
    BackgroundRefreshScheduleState state, {
    Duration? interval,
    String? detail,
  }) {
    return BackgroundRefreshStatus(
      platform: _riverPlatform,
      state: state,
      interval: interval,
      isExact: false,
      detail: detail,
    );
  }

  BackgroundRefreshStatus _statusFromWindows(
    Map<String, Object?>? response,
  ) {
    final rawState = response?['state'];
    final state = switch (rawState) {
      'scheduled' => BackgroundRefreshScheduleState.scheduled,
      'disabled' => BackgroundRefreshScheduleState.disabled,
      'notScheduled' => BackgroundRefreshScheduleState.notScheduled,
      _ => BackgroundRefreshScheduleState.unknown,
    };
    final minutes = response?['intervalMinutes'];
    return _status(
      state,
      interval:
          minutes is int ? Duration(minutes: minutes) : _lastPolicy?.interval,
      detail: response?['detail'] as String?,
    );
  }
}
