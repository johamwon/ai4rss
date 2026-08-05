import 'package:flutter_test/flutter_test.dart';
import 'package:river_app/app/background_feed_refresh_runner.dart';
import 'package:river_data/river_data.dart';
import 'package:river_feed/river_feed.dart';

void main() {
  test('resumes a durable batch without creating a duplicate batch', () async {
    var loaded = false;
    var started = false;
    final runner = BackgroundFeedRefreshRunner(
      resumePending: () async => _state(total: 2, succeeded: 2),
      loadSubscriptions: () async {
        loaded = true;
        return <FeedSubscriptionRecord>[];
      },
      start: (subscriptions) async {
        started = true;
        return _state();
      },
    );

    expect(await runner.run(), isTrue);
    expect(loaded, isFalse);
    expect(started, isFalse);
  });

  test('starts a new batch when no durable work is pending', () async {
    var received = -1;
    final runner = BackgroundFeedRefreshRunner(
      resumePending: () async => const FeedRefreshBatchState.idle(),
      loadSubscriptions: () async => <FeedSubscriptionRecord>[
        _subscription('one'),
        _subscription('two'),
      ],
      start: (subscriptions) async {
        received = subscriptions.length;
        return _state(total: 2, succeeded: 2);
      },
    );

    expect(await runner.run(), isTrue);
    expect(received, 2);
  });

  test('reports failure so the operating system can retry later', () async {
    final runner = BackgroundFeedRefreshRunner(
      resumePending: () async => const FeedRefreshBatchState.idle(),
      loadSubscriptions: () async => <FeedSubscriptionRecord>[],
      start: (subscriptions) async => _state(total: 1, failed: 1),
    );

    expect(await runner.run(), isFalse);
  });

  test('successful background refresh triggers best-effort follow-up',
      () async {
    var followUps = 0;
    final runner = BackgroundFeedRefreshRunner(
      resumePending: () async => const FeedRefreshBatchState.idle(),
      loadSubscriptions: () async => <FeedSubscriptionRecord>[],
      start: (subscriptions) async => _state(total: 1, succeeded: 1),
      afterRefresh: () async => followUps += 1,
    );

    expect(await runner.run(), isTrue);
    expect(followUps, 1);
  });

  test('AI follow-up failure never changes feed refresh success', () async {
    final runner = BackgroundFeedRefreshRunner(
      resumePending: () async => const FeedRefreshBatchState.idle(),
      loadSubscriptions: () async => <FeedSubscriptionRecord>[],
      start: (subscriptions) async => _state(total: 1, succeeded: 1),
      afterRefresh: () async => throw StateError('private AI failure'),
    );

    expect(await runner.run(), isTrue);
  });
}

FeedRefreshBatchState _state({
  int total = 0,
  int succeeded = 0,
  int failed = 0,
}) {
  return FeedRefreshBatchState(
    phase: FeedRefreshBatchPhase.completed,
    total: total,
    succeeded: succeeded,
    failed: failed,
    cancelled: 0,
    inFlight: 0,
  );
}

FeedSubscriptionRecord _subscription(String id) {
  return FeedSubscriptionRecord(
    id: id,
    canonicalUrl: Uri.parse('https://$id.example/feed.xml'),
    title: id,
    kind: FeedDocumentKind.rss,
    etag: null,
    lastModified: null,
    enabled: true,
    lastRefreshedAt: null,
    folderId: null,
  );
}
