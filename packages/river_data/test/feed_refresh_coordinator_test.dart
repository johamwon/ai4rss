import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:river_data/river_data.dart';
import 'package:river_domain/river_domain.dart';
import 'package:river_feed/river_feed.dart';
import 'package:test/test.dart';

void main() {
  late RiverDatabase database;
  late PersistentJobQueue jobs;
  late _MutableClock clock;
  late _Ids ids;

  setUp(() {
    database = RiverDatabase(NativeDatabase.memory());
    jobs = PersistentJobQueue(database);
    clock = _MutableClock(DateTime.utc(2026, 7, 16));
    ids = _Ids();
  });

  tearDown(() => database.close());

  test('limits global and same-origin refresh concurrency', () async {
    var active = 0;
    var maxActive = 0;
    final activeByHost = <String, int>{};
    final maxByHost = <String, int>{};
    final coordinator = FeedRefreshCoordinator(
      jobs: jobs,
      clock: clock,
      ids: ids,
      refresh: (uri) async {
        active += 1;
        maxActive = active > maxActive ? active : maxActive;
        final hostActive = (activeByHost[uri.host] ?? 0) + 1;
        activeByHost[uri.host] = hostActive;
        final previousMax = maxByHost[uri.host] ?? 0;
        maxByHost[uri.host] = hostActive > previousMax
            ? hostActive
            : previousMax;
        await Future<void>.delayed(const Duration(milliseconds: 10));
        active -= 1;
        activeByHost[uri.host] = hostActive - 1;
        return FeedRefreshResult(
          feedId: uri.path,
          articleCount: 0,
          notModified: true,
        );
      },
    );
    addTearDown(coordinator.close);

    final state = await coordinator.start(<FeedSubscriptionRecord>[
      for (var index = 0; index < 5; index += 1)
        _feed('a-$index', 'https://a.test/$index'),
      for (var index = 0; index < 2; index += 1)
        _feed('b-$index', 'https://b.test/$index'),
      _feed('c-0', 'https://c.test/0'),
    ]);

    expect(state.phase, FeedRefreshBatchPhase.completed);
    expect(state.succeeded, 8);
    expect(state.failed, 0);
    expect(maxActive, lessThanOrEqualTo(4));
    expect(maxByHost.values, everyElement(lessThanOrEqualTo(2)));
  });

  test('reports partial failures without stopping healthy feeds', () async {
    final coordinator = FeedRefreshCoordinator(
      jobs: jobs,
      clock: clock,
      ids: ids,
      refresh: (uri) async {
        if (uri.host == 'bad.test') {
          throw const FeedRefreshException('synthetic failure');
        }
        return FeedRefreshResult(
          feedId: uri.host,
          articleCount: 0,
          notModified: true,
        );
      },
    );
    addTearDown(coordinator.close);

    final state = await coordinator.start(<FeedSubscriptionRecord>[
      _feed('good', 'https://good.test/feed'),
      _feed('bad', 'https://bad.test/feed'),
    ]);

    expect(state.phase, FeedRefreshBatchPhase.completed);
    expect(state.succeeded, 1);
    expect(state.failed, 1);
    expect(state.settled, 2);
    final records = await jobs.list(
      typePrefix: FeedRefreshCoordinator.jobTypePrefix,
    );
    expect(
      records.where((job) => job.status == DurableJobStatus.failed),
      hasLength(1),
    );
    expect(
      records
          .singleWhere((job) => job.status == DurableJobStatus.failed)
          .lastErrorCode,
      'feed_refresh_failed',
    );
  });

  test(
    'cancels queued work and lets in-flight operations finish safely',
    () async {
      final firstRequestsStarted = Completer<void>();
      final releaseRequests = Completer<void>();
      var requests = 0;
      final coordinator = FeedRefreshCoordinator(
        jobs: jobs,
        clock: clock,
        ids: ids,
        refresh: (uri) async {
          requests += 1;
          if (requests == 2) firstRequestsStarted.complete();
          await releaseRequests.future;
          return FeedRefreshResult(
            feedId: uri.path,
            articleCount: 0,
            notModified: true,
          );
        },
      );
      addTearDown(coordinator.close);

      final run = coordinator.start(<FeedSubscriptionRecord>[
        for (var index = 0; index < 5; index += 1)
          _feed('feed-$index', 'https://same.test/$index'),
      ]);
      await firstRequestsStarted.future;
      await coordinator.cancel();
      releaseRequests.complete();
      final state = await run;

      expect(state.phase, FeedRefreshBatchPhase.cancelled);
      expect(state.cancelled, 5);
      expect(state.succeeded, 0);
      expect(requests, 2);
    },
  );

  test('recovers a persisted running refresh after process restart', () async {
    const type = '${FeedRefreshCoordinator.jobTypePrefix}restart-batch';
    await jobs.enqueue(
      NewDurableJob(
        id: 'persisted-job',
        type: type,
        idempotencyKey: '$type:feed-1',
        payloadJson: jsonEncode(<String, String>{
          'feedId': 'feed-1',
          'canonicalUrl': 'https://resume.test/feed',
        }),
        availableAt: clock.now(),
        maxAttempts: 1,
      ),
      clock.now(),
    );
    await jobs.claimNext(now: clock.now(), type: type);
    var refreshes = 0;
    final restarted = FeedRefreshCoordinator(
      jobs: jobs,
      clock: clock,
      ids: ids,
      refresh: (uri) async {
        refreshes += 1;
        return const FeedRefreshResult(
          feedId: 'feed-1',
          articleCount: 0,
          notModified: true,
        );
      },
    );
    addTearDown(restarted.close);

    final state = await restarted.resumePending();

    expect(refreshes, 1);
    expect(state.phase, FeedRefreshBatchPhase.completed);
    expect(state.succeeded, 1);
    expect((await jobs.list(type: type)).single.attempt, 2);
  });
}

FeedSubscriptionRecord _feed(String id, String url) => FeedSubscriptionRecord(
  id: id,
  canonicalUrl: Uri.parse(url),
  title: id,
  kind: FeedDocumentKind.rss,
  enabled: true,
);

final class _MutableClock implements Clock {
  _MutableClock(this.value);

  DateTime value;

  @override
  DateTime now() => value;
}

final class _Ids implements IdGenerator {
  var _next = 0;

  @override
  String next() => 'id-${++_next}';
}
