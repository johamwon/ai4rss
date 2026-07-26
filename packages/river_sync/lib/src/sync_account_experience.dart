import 'dart:async';

import 'incremental_sync.dart';
import 'sync_auth.dart';
import 'sync_protocol.dart';

final class SyncStorageStatus {
  SyncStorageStatus({
    required this.pendingMutations,
    required this.unresolvedConflicts,
    required this.serverSequence,
    required this.updatedAt,
  }) {
    if (pendingMutations < 0 || unresolvedConflicts < 0 || serverSequence < 0) {
      throw ArgumentError('Sync status counters must be non-negative.');
    }
    if (!updatedAt.isUtc) {
      throw ArgumentError.value(updatedAt, 'updatedAt');
    }
  }

  final int pendingMutations;
  final int unresolvedConflicts;
  final int serverSequence;
  final DateTime updatedAt;
}

final class SyncConflictHistoryEntry {
  SyncConflictHistoryEntry({
    required this.mutationId,
    required this.objectKind,
    required this.objectId,
    required this.detectedAt,
    required this.resolutionKind,
    this.resolutionMutationId,
    this.resolvedAt,
  }) {
    if (mutationId.isEmpty || objectId.isEmpty) {
      throw ArgumentError('Conflict history identifiers cannot be empty.');
    }
    if (!detectedAt.isUtc || (resolvedAt != null && !resolvedAt!.isUtc)) {
      throw ArgumentError('Conflict history timestamps must be UTC.');
    }
  }

  final String mutationId;
  final SyncObjectKind objectKind;
  final String objectId;
  final DateTime detectedAt;
  final String resolutionKind;
  final String? resolutionMutationId;
  final DateTime? resolvedAt;

  bool get isResolved => resolutionKind != 'unresolved';
}

abstract interface class SyncStatusRepository {
  Future<SyncStorageStatus> readStatus();

  Future<List<SyncConflictHistoryEntry>> readConflictHistory({
    int limit = 100,
  });
}

abstract interface class SyncRetryRunner {
  Future<IncrementalSyncResult> retry();
}

enum SyncAccountPhase {
  loading,
  signedOut,
  ready,
  syncing,
  retryableFailure,
  blocked,
}

final class SyncAccountState {
  const SyncAccountState({
    required this.phase,
    this.session,
    this.storage,
    this.failureCode,
    this.retryAfter,
  });

  const SyncAccountState.loading() : this(phase: SyncAccountPhase.loading);

  const SyncAccountState.signedOut() : this(phase: SyncAccountPhase.signedOut);

  final SyncAccountPhase phase;
  final SyncSession? session;
  final SyncStorageStatus? storage;
  final IncrementalSyncFailureCode? failureCode;
  final Duration? retryAfter;

  bool get canRetry => phase == SyncAccountPhase.retryableFailure;
}

abstract interface class SyncAccountExperience {
  SyncAccountState get state;
  Stream<SyncAccountState> get states;
  Future<void> load();
  Future<void> retryNow();
  Future<List<SyncConflictHistoryEntry>> conflictHistory({int limit = 100});
  Future<void> signOut();
  Future<SyncAuthResult<CloudDataDeletionReceipt>> deleteCloudData();
}

final class SyncAccountExperienceController implements SyncAccountExperience {
  SyncAccountExperienceController({
    required SyncAuthController auth,
    required SyncStatusRepository status,
    required SyncRetryRunner retry,
  })  : _auth = auth,
        _status = status,
        _retry = retry;

  final SyncAuthController _auth;
  final SyncStatusRepository _status;
  final SyncRetryRunner _retry;
  final StreamController<SyncAccountState> _states =
      StreamController<SyncAccountState>.broadcast();
  SyncAccountState _state = const SyncAccountState.loading();
  bool _running = false;

  @override
  SyncAccountState get state => _state;

  @override
  Stream<SyncAccountState> get states => _states.stream;

  @override
  Future<void> load() async {
    try {
      final session = await _auth.restoreLocalSession();
      if (session case SyncAuthSuccess<SyncSession>(:final value)) {
        try {
          _emit(
            SyncAccountState(
              phase: SyncAccountPhase.ready,
              session: value,
              storage: await _status.readStatus(),
            ),
          );
        } on Object {
          _emit(
            SyncAccountState(
              phase: SyncAccountPhase.retryableFailure,
              session: value,
              failureCode: IncrementalSyncFailureCode.storage,
            ),
          );
        }
        return;
      }
      final failure = session as SyncAuthFailure<SyncSession>;
      if (failure.code == SyncAuthFailureCode.sessionExpired) {
        final refreshed = await _auth.refreshDeviceStatus();
        if (refreshed case SyncAuthSuccess<SyncSession>(:final value)) {
          await _emitReady(value);
          return;
        }
        final refreshFailure = refreshed as SyncAuthFailure<SyncSession>;
        _emit(
          SyncAccountState(
            phase: refreshFailure.retryable
                ? SyncAccountPhase.retryableFailure
                : SyncAccountPhase.signedOut,
          ),
        );
        return;
      }
      _emit(
        SyncAccountState(
          phase: failure.retryable
              ? SyncAccountPhase.retryableFailure
              : SyncAccountPhase.signedOut,
        ),
      );
    } on Object {
      _emit(
        const SyncAccountState(
          phase: SyncAccountPhase.retryableFailure,
          failureCode: IncrementalSyncFailureCode.storage,
        ),
      );
    }
  }

  @override
  Future<void> retryNow() async {
    if (_running) return;
    if (_state.session == null) {
      await load();
      if (_state.session == null) return;
    }
    _running = true;
    final session = _state.session!;
    _emit(
      SyncAccountState(
        phase: SyncAccountPhase.syncing,
        session: session,
        storage: _state.storage,
      ),
    );
    try {
      final result = await _retry.retry();
      switch (result) {
        case IncrementalSyncSuccess():
          _emit(
            SyncAccountState(
              phase: SyncAccountPhase.ready,
              session: session,
              storage: await _status.readStatus(),
            ),
          );
        case IncrementalSyncFailure(
            :final code,
            :final retryable,
            :final retryAfter,
          ):
          _emit(
            SyncAccountState(
              phase: retryable
                  ? SyncAccountPhase.retryableFailure
                  : SyncAccountPhase.blocked,
              session: session,
              storage: _state.storage,
              failureCode: code,
              retryAfter: retryAfter,
            ),
          );
      }
    } on Object {
      _emit(
        SyncAccountState(
          phase: SyncAccountPhase.retryableFailure,
          session: session,
          storage: _state.storage,
          failureCode: IncrementalSyncFailureCode.storage,
        ),
      );
    } finally {
      _running = false;
    }
  }

  @override
  Future<List<SyncConflictHistoryEntry>> conflictHistory({
    int limit = 100,
  }) =>
      _status.readConflictHistory(limit: limit);

  @override
  Future<void> signOut() async {
    await _auth.signOut();
    _emit(const SyncAccountState.signedOut());
  }

  @override
  Future<SyncAuthResult<CloudDataDeletionReceipt>> deleteCloudData() async {
    final result = await _auth.deleteCloudData();
    if (result is SyncAuthSuccess<CloudDataDeletionReceipt>) {
      _emit(const SyncAccountState.signedOut());
    }
    return result;
  }

  Future<void> dispose() => _states.close();

  void _emit(SyncAccountState state) {
    _state = state;
    if (!_states.isClosed) _states.add(state);
  }

  Future<void> _emitReady(SyncSession session) async {
    try {
      _emit(
        SyncAccountState(
          phase: SyncAccountPhase.ready,
          session: session,
          storage: await _status.readStatus(),
        ),
      );
    } on Object {
      _emit(
        SyncAccountState(
          phase: SyncAccountPhase.retryableFailure,
          session: session,
          failureCode: IncrementalSyncFailureCode.storage,
        ),
      );
    }
  }
}
