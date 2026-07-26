import 'package:river_sync/river_sync.dart';
import 'package:test/test.dart';

void main() {
  const policy = SyncTombstoneCompactionPolicy();
  final deletedAt = DateTime.utc(2026, 6, 1);

  test('offline one week never ages a tombstone out', () {
    expect(
      policy.canCompact(
        tombstoneDeletedAt: deletedAt,
        tombstoneServerSequence: 50,
        deviceCursors: <SyncDeviceCursorCheckpoint>[
          _checkpoint('device-a', 50),
          _checkpoint('device-b', 50),
        ],
        now: deletedAt.add(const Duration(days: 7)),
      ),
      isFalse,
    );
  });

  test('all active device cursors must pass an aged tombstone', () {
    final now = deletedAt.add(const Duration(days: 31));
    expect(
      policy.canCompact(
        tombstoneDeletedAt: deletedAt,
        tombstoneServerSequence: 50,
        deviceCursors: <SyncDeviceCursorCheckpoint>[
          _checkpoint('device-a', 80),
          _checkpoint('device-b', 49),
        ],
        now: now,
      ),
      isFalse,
    );
    expect(
      policy.canCompact(
        tombstoneDeletedAt: deletedAt,
        tombstoneServerSequence: 50,
        deviceCursors: <SyncDeviceCursorCheckpoint>[
          _checkpoint('device-a', 80),
          _checkpoint('device-b', 50),
        ],
        now: now,
      ),
      isTrue,
    );
  });

  test('revoked devices do not retain tombstones forever', () {
    expect(
      policy.canCompact(
        tombstoneDeletedAt: deletedAt,
        tombstoneServerSequence: 50,
        deviceCursors: <SyncDeviceCursorCheckpoint>[
          _checkpoint('device-active', 80),
          _checkpoint(
            'device-revoked',
            2,
            status: SyncDeviceStatus.revoked,
          ),
        ],
        now: deletedAt.add(const Duration(days: 31)),
      ),
      isTrue,
    );
  });

  test('no active device is not sufficient evidence for compaction', () {
    expect(
      policy.canCompact(
        tombstoneDeletedAt: deletedAt,
        tombstoneServerSequence: 50,
        deviceCursors: <SyncDeviceCursorCheckpoint>[
          _checkpoint(
            'device-revoked',
            100,
            status: SyncDeviceStatus.revoked,
          ),
        ],
        now: deletedAt.add(const Duration(days: 31)),
      ),
      isFalse,
    );
  });
}

SyncDeviceCursorCheckpoint _checkpoint(
  String deviceId,
  int sequence, {
  SyncDeviceStatus status = SyncDeviceStatus.active,
}) =>
    SyncDeviceCursorCheckpoint(
      deviceId: deviceId,
      status: status,
      serverSequence: sequence,
    );
