/// Best-effort device network-link availability.
///
/// [online] means that at least one network transport is available. It does
/// not promise that the public Internet or a particular feed is reachable.
enum NetworkAvailability {
  unknown,
  offline,
  online;

  bool get isOffline => this == NetworkAvailability.offline;

  bool get mayAttemptRequest => this != NetworkAvailability.offline;
}

/// Supplies network-link hints without coupling features to a Flutter plugin.
abstract interface class NetworkMonitor {
  Future<NetworkAvailability> check();

  Stream<NetworkAvailability> get changes;
}

/// Safe fallback for tests and hosts that do not expose network-link events.
final class UnknownNetworkMonitor implements NetworkMonitor {
  const UnknownNetworkMonitor();

  @override
  Future<NetworkAvailability> check() async => NetworkAvailability.unknown;

  @override
  Stream<NetworkAvailability> get changes =>
      const Stream<NetworkAvailability>.empty();
}
