import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:river_domain/river_domain.dart';
import 'package:river_platform/river_platform.dart';
import 'package:river_platform/src/background_refresh_scheduler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Android initializes and updates one unique periodic task', () async {
    final gateway = _FakeWorkmanagerGateway();
    final scheduler = PlatformBackgroundRefreshScheduler(
      platform: TargetPlatform.android,
      workmanager: gateway,
    );
    final policy = BackgroundRefreshPolicy(
      interval: Duration(minutes: 30),
      wifiOnly: true,
    );

    await scheduler.initialize(_emptyDispatcher);
    final configured = await scheduler.configure(policy);
    final inspected = await scheduler.inspect();

    expect(gateway.initialized, isTrue);
    expect(gateway.uniqueName, riverBackgroundRefreshIdentifier);
    expect(gateway.taskName, riverBackgroundRefreshTaskName);
    expect(gateway.policy, same(policy));
    expect(configured.platform, BackgroundRefreshPlatform.android);
    expect(configured.state, BackgroundRefreshScheduleState.scheduled);
    expect(configured.isExact, isFalse);
    expect(inspected.state, BackgroundRefreshScheduleState.scheduled);
  });

  test('iOS reports opportunistic scheduling without claiming exactness',
      () async {
    final gateway = _FakeWorkmanagerGateway();
    final scheduler = PlatformBackgroundRefreshScheduler(
      platform: TargetPlatform.iOS,
      workmanager: gateway,
    );

    final configured = await scheduler.configure(
      BackgroundRefreshPolicy(),
    );

    expect(configured.platform, BackgroundRefreshPlatform.ios);
    expect(configured.state, BackgroundRefreshScheduleState.scheduled);
    expect(configured.isExact, isFalse);
    expect(configured.interval, const Duration(hours: 1));
    expect(configured.detail, contains('opportunistic'));
    final inspected = await scheduler.inspect();
    expect(inspected.interval, const Duration(hours: 1));
    expect(inspected.detail, contains('does not expose'));
  });

  test('disabled policy cancels the mobile task', () async {
    final gateway = _FakeWorkmanagerGateway();
    final scheduler = PlatformBackgroundRefreshScheduler(
      platform: TargetPlatform.android,
      workmanager: gateway,
    );

    final status = await scheduler.configure(
      BackgroundRefreshPolicy(enabled: false),
    );

    expect(gateway.cancelledName, riverBackgroundRefreshIdentifier);
    expect(status.state, BackgroundRefreshScheduleState.disabled);
  });

  test('Windows sends bounded arguments and maps native inspection', () async {
    const channel = MethodChannel('test.river/background_refresh');
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'inspect') {
        return <String, Object?>{
          'state': 'scheduled',
          'intervalMinutes': 45,
          'detail': 'River feed refresh task is ready.',
        };
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });
    final scheduler = PlatformBackgroundRefreshScheduler(
      platform: TargetPlatform.windows,
      windowsChannel: channel,
    );
    final policy = BackgroundRefreshPolicy(
      interval: Duration(minutes: 45),
      pauseWhenBatteryLow: false,
    );

    await scheduler.configure(policy);
    final inspected = await scheduler.inspect();
    await scheduler.cancel();

    expect(calls.map((call) => call.method), <String>[
      'configure',
      'inspect',
      'cancel',
    ]);
    expect(calls.first.arguments, policy.toPlatformArguments());
    expect(inspected.platform, BackgroundRefreshPlatform.windows);
    expect(inspected.state, BackgroundRefreshScheduleState.scheduled);
    expect(inspected.interval, const Duration(minutes: 45));
    expect(inspected.isExact, isFalse);
  });

  test('unsupported platforms stay side-effect free', () async {
    final gateway = _FakeWorkmanagerGateway();
    final scheduler = PlatformBackgroundRefreshScheduler(
      platform: TargetPlatform.linux,
      workmanager: gateway,
    );

    await scheduler.initialize(_emptyDispatcher);
    final status = await scheduler.configure(
      BackgroundRefreshPolicy(),
    );

    expect(status.platform, BackgroundRefreshPlatform.unsupported);
    expect(gateway.initialized, isFalse);
  });
}

void _emptyDispatcher() {}

final class _FakeWorkmanagerGateway implements BackgroundWorkmanagerGateway {
  bool initialized = false;
  bool scheduled = false;
  String? uniqueName;
  String? taskName;
  String? cancelledName;
  BackgroundRefreshPolicy? policy;

  @override
  Future<void> cancel(String uniqueName) async {
    cancelledName = uniqueName;
    scheduled = false;
  }

  @override
  Future<void> initialize(void Function() callbackDispatcher) async {
    initialized = true;
  }

  @override
  Future<bool> isScheduled(String uniqueName) async => scheduled;

  @override
  Future<void> registerPeriodic({
    required String uniqueName,
    required String taskName,
    required BackgroundRefreshPolicy policy,
  }) async {
    this.uniqueName = uniqueName;
    this.taskName = taskName;
    this.policy = policy;
    scheduled = true;
  }
}
