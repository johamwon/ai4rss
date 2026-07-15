import 'package:drift/drift.dart';

import 'database.dart';
import 'tables.dart';

enum DurableJobStatus { queued, running, completed, failed }

final class NewDurableJob {
  const NewDurableJob({
    required this.id,
    required this.type,
    required this.idempotencyKey,
    required this.payloadJson,
    required this.availableAt,
    this.maxAttempts = 5,
  });

  final String id;
  final String type;
  final String idempotencyKey;
  final String payloadJson;
  final DateTime availableAt;
  final int maxAttempts;
}

final class ClaimedDurableJob {
  const ClaimedDurableJob({
    required this.id,
    required this.type,
    required this.payloadJson,
    required this.attempt,
    required this.leaseUntil,
  });

  final String id;
  final String type;
  final String payloadJson;
  final int attempt;
  final DateTime leaseUntil;
}

final class PersistentJobQueue {
  const PersistentJobQueue(this._database);

  final RiverDatabase _database;

  Future<bool> enqueue(NewDurableJob job, DateTime now) async {
    final inserted = await _database
        .into(_database.backgroundJobs)
        .insertReturningOrNull(
          BackgroundJobsCompanion.insert(
            id: job.id,
            type: job.type,
            idempotencyKey: job.idempotencyKey,
            payloadJson: job.payloadJson,
            availableAt: job.availableAt,
            maxAttempts: Value<int>(job.maxAttempts),
            createdAt: now,
            updatedAt: now,
          ),
          mode: InsertMode.insertOrIgnore,
        );
    return inserted != null;
  }

  Future<ClaimedDurableJob?> claimNext({
    required DateTime now,
    Duration leaseDuration = const Duration(minutes: 2),
  }) {
    return _database.transaction(() async {
      final query = _database.select(_database.backgroundJobs)
        ..where(
          (BackgroundJobs table) =>
              table.status.equals(DurableJobStatus.queued.name) &
              table.availableAt.isSmallerOrEqualValue(now),
        )
        ..orderBy(<OrderingTerm Function(BackgroundJobs)>[
          (BackgroundJobs table) => OrderingTerm.asc(table.availableAt),
          (BackgroundJobs table) => OrderingTerm.asc(table.createdAt),
        ])
        ..limit(1);
      final candidate = await query.getSingleOrNull();
      if (candidate == null) return null;

      final leaseUntil = now.add(leaseDuration);
      await (_database.update(
        _database.backgroundJobs,
      )..where((BackgroundJobs table) => table.id.equals(candidate.id))).write(
        BackgroundJobsCompanion(
          status: Value<String>(DurableJobStatus.running.name),
          attempt: Value<int>(candidate.attempt + 1),
          leaseUntil: Value<DateTime?>(leaseUntil),
          updatedAt: Value<DateTime>(now),
        ),
      );
      return ClaimedDurableJob(
        id: candidate.id,
        type: candidate.type,
        payloadJson: candidate.payloadJson,
        attempt: candidate.attempt + 1,
        leaseUntil: leaseUntil,
      );
    });
  }

  Future<void> complete(String id, DateTime now) async {
    await (_database.update(
      _database.backgroundJobs,
    )..where((BackgroundJobs table) => table.id.equals(id))).write(
      BackgroundJobsCompanion(
        status: Value<String>(DurableJobStatus.completed.name),
        leaseUntil: const Value<DateTime?>(null),
        updatedAt: Value<DateTime>(now),
      ),
    );
  }

  Future<void> failOrRetry({
    required String id,
    required String errorCode,
    required DateTime now,
    Duration retryDelay = const Duration(minutes: 1),
  }) async {
    await _database.transaction(() async {
      final job = await (_database.select(
        _database.backgroundJobs,
      )..where((BackgroundJobs table) => table.id.equals(id))).getSingle();
      final exhausted = job.attempt >= job.maxAttempts;
      await (_database.update(
        _database.backgroundJobs,
      )..where((BackgroundJobs table) => table.id.equals(id))).write(
        BackgroundJobsCompanion(
          status: Value<String>(
            exhausted
                ? DurableJobStatus.failed.name
                : DurableJobStatus.queued.name,
          ),
          availableAt: Value<DateTime>(now.add(retryDelay)),
          leaseUntil: const Value<DateTime?>(null),
          lastErrorCode: Value<String>(errorCode),
          updatedAt: Value<DateTime>(now),
        ),
      );
    });
  }

  Future<int> recoverExpiredLeases(DateTime now) {
    return (_database.update(_database.backgroundJobs)..where(
          (BackgroundJobs table) =>
              table.status.equals(DurableJobStatus.running.name) &
              table.leaseUntil.isNotNull() &
              table.leaseUntil.isSmallerOrEqualValue(now),
        ))
        .write(
          BackgroundJobsCompanion(
            status: Value<String>(DurableJobStatus.queued.name),
            leaseUntil: const Value<DateTime?>(null),
            availableAt: Value<DateTime>(now),
            updatedAt: Value<DateTime>(now),
          ),
        );
  }
}
