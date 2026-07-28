import 'package:drift/native.dart';
import 'package:river_data/river_data.dart';
import 'package:test/test.dart';

void main() {
  late RiverDatabase database;
  late PersistentJobQueue queue;

  setUp(() {
    database = RiverDatabase(NativeDatabase.memory());
    queue = PersistentJobQueue(database);
  });

  tearDown(() => database.close());

  test('enqueue is idempotent and claims a job once', () async {
    final now = DateTime.utc(2026, 7, 15);
    final job = NewDurableJob(
      id: 'job-1',
      type: 'refresh-feed',
      idempotencyKey: 'refresh:feed-1:2026-07-15',
      payloadJson: '{"feedId":"feed-1"}',
      availableAt: now,
    );

    expect(await queue.enqueue(job, now), isTrue);
    expect(await queue.enqueue(job, now), isFalse);
    final claimed = await queue.claimNext(now: now);
    expect(claimed?.id, 'job-1');
    expect(claimed?.attempt, 1);
    expect(await queue.claimNext(now: now), isNull);
  });

  test('expired lease is recovered after process interruption', () async {
    final now = DateTime.utc(2026, 7, 15);
    await queue.enqueue(
      NewDurableJob(
        id: 'job-1',
        type: 'extract',
        idempotencyKey: 'extract:article-1',
        payloadJson: '{"articleId":"article-1"}',
        availableAt: now,
      ),
      now,
    );
    await queue.claimNext(now: now, leaseDuration: const Duration(seconds: 30));

    final recovered = await queue.recoverExpiredLeases(
      now.add(const Duration(seconds: 31)),
    );
    final reclaimed = await queue.claimNext(
      now: now.add(const Duration(seconds: 31)),
    );

    expect(recovered, 1);
    expect(reclaimed?.id, 'job-1');
    expect(reclaimed?.attempt, 2);
  });

  test('failed jobs stop retrying at max attempts', () async {
    final now = DateTime.utc(2026, 7, 15);
    await queue.enqueue(
      NewDurableJob(
        id: 'job-1',
        type: 'extract',
        idempotencyKey: 'extract:article-1',
        payloadJson: '{}',
        availableAt: now,
        maxAttempts: 1,
      ),
      now,
    );
    await queue.claimNext(now: now);
    await queue.failOrRetry(id: 'job-1', errorCode: 'timeout', now: now);

    expect(
      await queue.claimNext(now: now.add(const Duration(days: 1))),
      isNull,
    );
  });

  test(
    'explicit retry resets a terminal failure without duplicating work',
    () async {
      final now = DateTime.utc(2026, 7, 15);
      await queue.enqueue(
        NewDurableJob(
          id: 'job-1',
          type: 'extract',
          idempotencyKey: 'extract:article-1',
          payloadJson: '{}',
          availableAt: now,
          maxAttempts: 1,
        ),
        now,
      );
      await queue.claimNext(now: now);
      await queue.failOrRetry(id: 'job-1', errorCode: 'network', now: now);

      expect(
        await queue.retryFailed(
          idempotencyKey: 'extract:article-1',
          now: now.add(const Duration(minutes: 1)),
        ),
        isTrue,
      );
      expect(
        await queue.retryFailed(
          idempotencyKey: 'extract:article-1',
          now: now.add(const Duration(minutes: 1)),
        ),
        isFalse,
      );
      final retried = await queue.claimNext(
        now: now.add(const Duration(minutes: 1)),
      );
      expect(retried?.id, 'job-1');
      expect(retried?.attempt, 1);
    },
  );

  test('type filtering and cancellation preserve terminal state', () async {
    final now = DateTime.utc(2026, 7, 15);
    for (final type in <String>['refresh/a', 'extract']) {
      await queue.enqueue(
        NewDurableJob(
          id: 'job-$type',
          type: type,
          idempotencyKey: 'key-$type',
          payloadJson: '{}',
          availableAt: now,
        ),
        now,
      );
    }

    final refresh = await queue.claimNext(now: now, type: 'refresh/a');
    expect(refresh?.type, 'refresh/a');
    expect(await queue.cancelType('refresh/a', now), 1);
    expect(await queue.complete(refresh!.id, now), isFalse);
    expect(
      (await queue.list(type: 'refresh/a')).single.status,
      DurableJobStatus.cancelled,
    );
    expect((await queue.claimNext(now: now))?.type, 'extract');
  });

  test(
    'type-prefix claims preserve queue order across related operations',
    () async {
      final now = DateTime.utc(2026, 7, 15);
      await queue.enqueue(
        NewDurableJob(
          id: 'delete',
          type: 'knowledge-export/v1/delete',
          idempotencyKey: 'delete-1',
          payloadJson: '{}',
          availableAt: now,
        ),
        now,
      );
      await queue.enqueue(
        NewDurableJob(
          id: 'other',
          type: 'refresh',
          idempotencyKey: 'refresh-1',
          payloadJson: '{}',
          availableAt: now,
        ),
        now,
      );
      await queue.enqueue(
        NewDurableJob(
          id: 'upsert',
          type: 'knowledge-export/v1/upsert',
          idempotencyKey: 'upsert-1',
          payloadJson: '{}',
          availableAt: now,
        ),
        now.add(const Duration(microseconds: 1)),
      );

      final first = await queue.claimNext(
        now: now,
        typePrefix: 'knowledge-export/v1/',
      );
      final second = await queue.claimNext(
        now: now,
        typePrefix: 'knowledge-export/v1/',
      );

      expect(first?.id, 'delete');
      expect(second?.id, 'upsert');
      expect(
        () => queue.claimNext(
          now: now,
          type: 'refresh',
          typePrefix: 'knowledge-',
        ),
        throwsArgumentError,
      );
    },
  );
}
