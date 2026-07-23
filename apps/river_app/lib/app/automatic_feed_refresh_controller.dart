import 'package:river_data/river_data.dart';
import 'package:river_domain/river_domain.dart';
import 'package:river_feed/river_feed.dart';

typedef LoadAutomaticSubscriptions = Future<List<FeedSubscriptionRecord>>
    Function();
typedef StartAutomaticRefresh = Future<FeedRefreshBatchState> Function(
  Iterable<FeedSubscriptionRecord> subscriptions,
);

final class AutomaticFeedRefreshController {
  AutomaticFeedRefreshController({
    required this.clock,
    required this.currentState,
    required this.resumePending,
    required this.loadSubscriptions,
    required this.start,
    this.cooldown = const Duration(minutes: 5),
  });

  final Clock clock;
  final FeedRefreshBatchState Function() currentState;
  final Future<FeedRefreshBatchState> Function() resumePending;
  final LoadAutomaticSubscriptions loadSubscriptions;
  final StartAutomaticRefresh start;
  final Duration cooldown;
  DateTime? _lastRunAt;

  Future<void> run() async {
    if (currentState().isActive) return;

    final now = clock.now().toUtc();
    final last = _lastRunAt;
    if (last != null && now.difference(last) < cooldown) return;
    _lastRunAt = now;

    final stateBeforeRecovery = currentState();
    final recovered = await resumePending();
    final recoveredStartupBatch =
        stateBeforeRecovery.phase == FeedRefreshBatchPhase.idle &&
            recovered.total > 0;
    if (recoveredStartupBatch) return;

    await start(await loadSubscriptions());
  }
}
