import 'package:drift/drift.dart';

import 'database.dart';
import 'tables.dart';

enum DurableJobStatus { queued, running, completed, failed, cancelled }

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

final class DurableJobRecord {
  const DurableJobRecord({
    required this.id,
    required this.type,
    required this.idempotencyKey,
    required this.payloadJson,
    required this.status,
    required this.attempt,
    required this.maxAttempts,
    required this.availableAt,
    required this.createdAt,
    required this.updatedAt,
    this.leaseUntil,
    this.lastErrorCode,
  });

  final String id;
  final String type;
  final String idempotencyKey;
  final String payloadJson;
  final DurableJobStatus status;
  final int attempt;
  final int maxAttempts;
  final DateTime availableAt;
  final DateTime? leaseUntil;
  final String? lastErrorCode;
  final DateTime createdAt;
  final DateTime updatedAt;
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
    String? type,
  }) {
    return _database.transaction(() async {
      final query = _database.select(_database.backgroundJobs);
      query.where(
        (BackgroundJobs table) =>
            table.status.equals(DurableJobStatus.queued.name) &
            table.availableAt.isSmallerOrEqualValue(now),
      );
      if (type != null) {
        query.where((BackgroundJobs table) => table.type.equals(type));
      }
      query
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

  Future<bool> complete(String id, DateTime now) async {
    final updated =
        await (_database.update(_database.backgroundJobs)..where(
              (BackgroundJobs table) =>
                  table.id.equals(id) &
                  table.status.equals(DurableJobStatus.running.name),
            ))
            .write(
              BackgroundJobsCompanion(
                status: Value<String>(DurableJobStatus.completed.name),
                leaseUntil: const Value<DateTime?>(null),
                updatedAt: Value<DateTime>(now),
              ),
            );
    return updated == 1;
  }

  Future<DurableJobStatus> failOrRetry({
    required String id,
    required String errorCode,
    required DateTime now,
    Duration retryDelay = const Duration(minutes: 1),
  }) {
    return _database.transaction(() async {
      final job = await (_database.select(
        _database.backgroundJobs,
      )..where((BackgroundJobs table) => table.id.equals(id))).getSingle();
      final currentStatus = _statusFromName(job.status);
      if (currentStatus != DurableJobStatus.running) {
        return currentStatus;
      }
      final exhausted = job.attempt >= job.maxAttempts;
      final nextStatus = exhausted
          ? DurableJobStatus.failed
          : DurableJobStatus.queued;
      await (_database.update(
        _database.backgroundJobs,
      )..where((BackgroundJobs table) => table.id.equals(id))).write(
        BackgroundJobsCompanion(
          status: Value<String>(nextStatus.name),
          availableAt: Value<DateTime>(now.add(retryDelay)),
          leaseUntil: const Value<DateTime?>(null),
          lastErrorCode: Value<String>(errorCode),
          updatedAt: Value<DateTime>(now),
        ),
      );
      return nextStatus;
    });
  }

  Future<bool> failPermanently({
    required String id,
    required String errorCode,
    required DateTime now,
  }) async {
    final updated =
        await (_database.update(_database.backgroundJobs)..where(
              (BackgroundJobs table) =>
                  table.id.equals(id) &
                  table.status.equals(DurableJobStatus.running.name),
            ))
            .write(
              BackgroundJobsCompanion(
                status: Value<String>(DurableJobStatus.failed.name),
                leaseUntil: const Value<DateTime?>(null),
                lastErrorCode: Value<String>(errorCode),
                updatedAt: Value<DateTime>(now),
              ),
            );
    return updated == 1;
  }

  Future<bool> retryFailed({
    required String idempotencyKey,
    required DateTime now,
  }) async {
    final updated =
        await (_database.update(_database.backgroundJobs)..where(
              (BackgroundJobs table) =>
                  table.idempotencyKey.equals(idempotencyKey) &
                  table.status.equals(DurableJobStatus.failed.name),
            ))
            .write(
              BackgroundJobsCompanion(
                status: Value<String>(DurableJobStatus.queued.name),
                attempt: const Value<int>(0),
                availableAt: Value<DateTime>(now),
                leaseUntil: const Value<DateTime?>(null),
                lastErrorCode: const Value<String?>(null),
                updatedAt: Value<DateTime>(now),
              ),
            );
    return updated == 1;
  }

  Future<DurableJobRecord?> findByIdempotencyKey(String key) async {
    final row =
        await (_database.select(_database.backgroundJobs)..where(
              (BackgroundJobs table) => table.idempotencyKey.equals(key),
            ))
            .getSingleOrNull();
    return row == null ? null : _toRecord(row);
  }

  Future<int> recoverExpiredLeases(
    DateTime now, {
    String? typePrefix,
    bool includeUnexpired = false,
  }) {
    final update = _database.update(_database.backgroundJobs);
    if (includeUnexpired) {
      update.where(
        (BackgroundJobs table) =>
            table.status.equals(DurableJobStatus.running.name) &
            table.leaseUntil.isNotNull(),
      );
    } else {
      update.where(
        (BackgroundJobs table) =>
            table.status.equals(DurableJobStatus.running.name) &
            table.leaseUntil.isNotNull() &
            table.leaseUntil.isSmallerOrEqualValue(now),
      );
    }
    if (typePrefix != null) {
      update.where((BackgroundJobs table) => table.type.like('$typePrefix%'));
    }
    return update.write(
      BackgroundJobsCompanion(
        status: Value<String>(DurableJobStatus.queued.name),
        leaseUntil: const Value<DateTime?>(null),
        availableAt: Value<DateTime>(now),
        updatedAt: Value<DateTime>(now),
      ),
    );
  }

  Future<int> cancelType(String type, DateTime now) {
    return (_database.update(_database.backgroundJobs)..where(
          (BackgroundJobs table) =>
              table.type.equals(type) &
              table.status.isIn(<String>[
                DurableJobStatus.queued.name,
                DurableJobStatus.running.name,
              ]),
        ))
        .write(
          BackgroundJobsCompanion(
            status: Value<String>(DurableJobStatus.cancelled.name),
            leaseUntil: const Value<DateTime?>(null),
            updatedAt: Value<DateTime>(now),
          ),
        );
  }

  Future<List<DurableJobRecord>> list({
    String? type,
    String? typePrefix,
    Set<DurableJobStatus>? statuses,
  }) async {
    if (type != null && typePrefix != null) {
      throw ArgumentError('Only one of type or typePrefix may be provided.');
    }
    final query = _database.select(_database.backgroundJobs);
    if (type != null) {
      query.where((BackgroundJobs table) => table.type.equals(type));
    }
    if (typePrefix != null) {
      query.where((BackgroundJobs table) => table.type.like('$typePrefix%'));
    }
    if (statuses != null && statuses.isNotEmpty) {
      query.where(
        (BackgroundJobs table) =>
            table.status.isIn(statuses.map((status) => status.name)),
      );
    }
    query.orderBy(<OrderingTerm Function(BackgroundJobs)>[
      (BackgroundJobs table) => OrderingTerm.asc(table.createdAt),
      (BackgroundJobs table) => OrderingTerm.asc(table.id),
    ]);
    final rows = await query.get();
    return rows.map(_toRecord).toList(growable: false);
  }
}

DurableJobRecord _toRecord(BackgroundJob job) => DurableJobRecord(
  id: job.id,
  type: job.type,
  idempotencyKey: job.idempotencyKey,
  payloadJson: job.payloadJson,
  status: _statusFromName(job.status),
  attempt: job.attempt,
  maxAttempts: job.maxAttempts,
  availableAt: job.availableAt,
  leaseUntil: job.leaseUntil,
  lastErrorCode: job.lastErrorCode,
  createdAt: job.createdAt,
  updatedAt: job.updatedAt,
);

DurableJobStatus _statusFromName(String name) =>
    DurableJobStatus.values.firstWhere(
      (status) => status.name == name,
      orElse: () => DurableJobStatus.failed,
    );
