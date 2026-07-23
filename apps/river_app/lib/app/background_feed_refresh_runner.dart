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
  });

  final Future<FeedRefreshBatchState> Function() resumePending;
  final LoadSubscriptions loadSubscriptions;
  final RunFeedRefresh start;

  Future<bool> run() async {
    final resumed = await resumePending();
    if (resumed.total > 0) {
      return _succeeded(resumed);
    }

    final subscriptions = await loadSubscriptions();
    return _succeeded(await start(subscriptions));
  }

  bool _succeeded(FeedRefreshBatchState state) {
    return state.phase == FeedRefreshBatchPhase.completed && state.failed == 0;
  }
}
