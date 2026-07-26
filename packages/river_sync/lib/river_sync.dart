library;

export 'src/conflict_model.dart';
export 'src/sync_auth.dart';
export 'src/sync_crypto.dart';
export 'src/sync_protocol.dart';
export 'src/version_vector.dart';

final class VersionedValue<T> {
  const VersionedValue({
    required this.value,
    required this.updatedAt,
    required this.deviceId,
  });

  final T value;
  final DateTime updatedAt;
  final String deviceId;
}

VersionedValue<T> lastWriteWins<T>(
  VersionedValue<T> left,
  VersionedValue<T> right,
) {
  final comparison = left.updatedAt.compareTo(right.updatedAt);
  if (comparison > 0) return left;
  if (comparison < 0) return right;
  return left.deviceId.compareTo(right.deviceId) >= 0 ? left : right;
}
