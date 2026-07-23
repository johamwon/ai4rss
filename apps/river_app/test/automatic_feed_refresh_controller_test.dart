import 'package:flutter_test/flutter_test.dart';
import 'package:river_app/app/automatic_feed_refresh_controller.dart';
import 'package:river_data/river_data.dart';
import 'package:river_domain/river_domain.dart';
import 'package:river_feed/river_feed.dart';

void main() {
  test('runs on startup and again after the foreground cooldown', () async {
    final clock = _MutableClock();
    var starts = 0;
    final controller = AutomaticFeedRefreshController(
      clock: clock,
      currentState: () => const FeedRefreshBatchState.idle(),
      resumePending: () async => const FeedRefreshBatchState.idle(),
      loadSubscriptions: () async => <FeedSubscriptionRecord>[],
      start: (subscriptions) async {
        starts += 1;
        return _completed();
      },
    );

    await controller.run();
    await controller.run();
    expect(starts, 1);

    clock.advance(const Duration(minutes: 6));
    await controller.run();
    expect(starts, 2);
  });

  test('recovered startup work is not followed by a duplicate batch', () async {
    var starts = 0;
    final controller = AutomaticFeedRefreshController(
      clock: _MutableClock(),
      currentState: () => const FeedRefreshBatchState.idle(),
      resumePending: () async => _completed(total: 2),
      loadSubscriptions: () async => <FeedSubscriptionRecord>[],
      start: (subscriptions) async {
        starts += 1;
        return _completed();
      },
    );

    await controller.run();
    expect(starts, 0);
  });

  test('an active manual refresh is never followed by an automatic batch',
      () async {
    var resumed = false;
    final controller = AutomaticFeedRefreshController(
      clock: _MutableClock(),
      currentState: () => FeedRefreshBatchState(
        phase: FeedRefreshBatchPhase.running,
        batchId: 'manual',
        total: 1,
        succeeded: 0,
        failed: 0,
        cancelled: 0,
        inFlight: 1,
      ),
      resumePending: () async {
        resumed = true;
        return _completed();
      },
      loadSubscriptions: () async => <FeedSubscriptionRecord>[],
      start: (subscriptions) async => _completed(),
    );

    await controller.run();
    expect(resumed, isFalse);
  });
}

FeedRefreshBatchState _completed({int total = 0}) {
  return FeedRefreshBatchState(
    phase: FeedRefreshBatchPhase.completed,
    total: total,
    succeeded: total,
    failed: 0,
    cancelled: 0,
    inFlight: 0,
  );
}

final class _MutableClock implements Clock {
  DateTime _now = DateTime.utc(2026, 7, 23);

  @override
  DateTime now() => _now;

  void advance(Duration duration) {
    _now = _now.add(duration);
  }
}
