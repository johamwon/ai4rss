import 'sync_protocol.dart';

final class SyncDeviceCursorCheckpoint {
  SyncDeviceCursorCheckpoint({
    required this.deviceId,
    required this.status,
    required this.serverSequence,
  }) {
    if (deviceId.isEmpty ||
        deviceId.trim() != deviceId ||
        deviceId.length > 256) {
      throw ArgumentError.value(deviceId, 'deviceId');
    }
    if (serverSequence < 0) {
      throw ArgumentError.value(serverSequence, 'serverSequence');
    }
  }

  final String deviceId;
  final SyncDeviceStatus status;
  final int serverSequence;
}

final class SyncTombstoneCompactionPolicy {
  const SyncTombstoneCompactionPolicy({
    this.minimumRetention = const Duration(days: 30),
  });

  final Duration minimumRetention;

  bool canCompact({
    required DateTime tombstoneDeletedAt,
    required int tombstoneServerSequence,
    required Iterable<SyncDeviceCursorCheckpoint> deviceCursors,
    required DateTime now,
  }) {
    if (!tombstoneDeletedAt.isUtc || !now.isUtc) {
      throw ArgumentError('Tombstone compaction timestamps must be UTC.');
    }
    if (minimumRetention <= Duration.zero) {
      throw StateError('Tombstone retention must be positive.');
    }
    if (tombstoneServerSequence <= 0 ||
        now.difference(tombstoneDeletedAt) < minimumRetention) {
      return false;
    }
    final active = deviceCursors
        .where((checkpoint) => checkpoint.status == SyncDeviceStatus.active)
        .toList(growable: false);
    return active.isNotEmpty &&
        active.every(
          (checkpoint) => checkpoint.serverSequence >= tombstoneServerSequence,
        );
  }
}
