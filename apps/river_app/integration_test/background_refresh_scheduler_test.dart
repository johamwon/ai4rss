import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:river_domain/river_domain.dart';
import 'package:river_platform/river_platform.dart';

@pragma('vm:entry-point')
void _smokeCallbackDispatcher() {
  executeRiverBackgroundTasks(() async => true);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('registers, inspects, and removes an OS background refresh task',
      (tester) async {
    final scheduler = PlatformBackgroundRefreshScheduler();
    await scheduler.initialize(_smokeCallbackDispatcher);

    try {
      final configured = await scheduler.configure(
        BackgroundRefreshPolicy(
          interval: const Duration(minutes: 15),
        ),
      );
      expect(configured.isExact, isFalse);
      expect(
        configured.state,
        BackgroundRefreshScheduleState.scheduled,
      );

      final inspected = await scheduler.inspect();
      expect(
        inspected.state,
        anyOf(
          BackgroundRefreshScheduleState.scheduled,
          // BGTaskScheduler deliberately has no public pending-request query.
          BackgroundRefreshScheduleState.unknown,
        ),
      );
    } finally {
      await scheduler.cancel();
    }
  });
}
