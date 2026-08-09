import 'package:river_data/river_data.dart';
import 'package:river_feed/river_feed.dart';

typedef LoadSubscriptions = Future<List<FeedSubscriptionRecord>> Function();
typedef RunFeedRefresh = Future<FeedRefreshBatchState> Function(
  Iterable<FeedSubscriptionRecord> subscriptions,
);

final class BackgroundFeedRefreshRunner {
  const BackgroundFeedRefreshRunner({
    required this.resumePending,
    required this.loadSubscriptions,
    required this.start,
    this.afterRefresh,
  });

  final Future<FeedRefreshBatchState> Function() resumePending;
  final LoadSubscriptions loadSubscriptions;
  final RunFeedRefresh start;
  final Future<void> Function()? afterRefresh;

  Future<bool> run() async {
    final resumed = await resumePending();
    if (resumed.total > 0) {
      await _runAfterRefresh();
      return _succeeded(resumed);
    }

    final subscriptions = await loadSubscriptions();
    final result = await start(subscriptions);
    await _runAfterRefresh();
    return _succeeded(result);
  }

  Future<void> _runAfterRefresh() async {
    try {
      await afterRefresh?.call();
    } on Object {
      // Feed refresh success is independent from best-effort AI automation.
    }
  }

  bool _succeeded(FeedRefreshBatchState state) {
    return state.phase == FeedRefreshBatchPhase.completed && state.failed == 0;
  }
}
