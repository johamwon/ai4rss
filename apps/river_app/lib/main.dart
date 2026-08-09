import 'dart:io';

import 'package:flutter/material.dart';
import 'package:river_domain/river_domain.dart';
import 'package:river_feed/river_feed.dart';
import 'package:river_platform/river_platform.dart';

import 'app/app_dependencies.dart';
import 'app/background_feed_refresh_runner.dart';
import 'app/river_application.dart';

const _backgroundRefreshEnabled = bool.fromEnvironment(
  'RIVER_BACKGROUND_REFRESH_ENABLED',
  defaultValue: true,
);
const _backgroundRefreshIntervalMinutes = int.fromEnvironment(
  'RIVER_BACKGROUND_REFRESH_INTERVAL_MINUTES',
  defaultValue: 60,
);
const _windowsBackgroundArgument = '--river-background-refresh';

@pragma('vm:entry-point')
void riverBackgroundCallbackDispatcher() {
  executeRiverBackgroundTasks(runRiverBackgroundRefresh);
}

@pragma('vm:entry-point')
Future<bool> runRiverBackgroundRefresh() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!_backgroundRefreshEnabled) return true;

  AppDependencies? dependencies;
  try {
    dependencies = await AppDependencies.production(backgroundExecution: true);
    final runner = BackgroundFeedRefreshRunner(
      resumePending: dependencies.feedRefreshCoordinator.resumePending,
      loadSubscriptions: () => dependencies!.feeds.watchSubscriptions().first,
      start: dependencies.feedRefreshCoordinator.start,
      afterRefresh: () async {
        final snapshot = await dependencies!.personalizedArticles
            .watch(
              const FeedArticleQuery(sort: FeedArticleSort.smart),
            )
            .first;
        await dependencies.automaticSummaries.schedule(snapshot);
        await dependencies.automaticSummaries.resumePending();
      },
    );
    return await runner.run();
  } catch (_) {
    return false;
  } finally {
    await dependencies?.close();
  }
}

Future<void> main(List<String> arguments) async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows && arguments.contains(_windowsBackgroundArgument)) {
    final succeeded = await runRiverBackgroundRefresh();
    exit(succeeded ? 0 : 1);
  }

  final dependencies = await AppDependencies.production();
  await dependencies.backgroundRefresh.initialize(
    riverBackgroundCallbackDispatcher,
  );
  final intervalMinutes = _backgroundRefreshIntervalMinutes.clamp(
    BackgroundRefreshPolicy.minimumInterval.inMinutes,
    Duration.minutesPerDay,
  );
  try {
    await dependencies.backgroundRefresh.configure(
      BackgroundRefreshPolicy(
        enabled: _backgroundRefreshEnabled,
        interval: Duration(minutes: intervalMinutes),
      ),
    );
  } catch (_) {
    // Background scheduling is best-effort. Foreground and manual refresh
    // remain available if the OS rejects registration.
  }
  runApp(RiverApp(dependencies: dependencies));
}
