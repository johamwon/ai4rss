import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:river_domain/river_domain.dart';

abstract interface class ConnectivityGateway {
  Future<List<ConnectivityResult>> check();

  Stream<List<ConnectivityResult>> get changes;
}

final class PluginConnectivityGateway implements ConnectivityGateway {
  PluginConnectivityGateway({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  @override
  Future<List<ConnectivityResult>> check() => _connectivity.checkConnectivity();

  @override
  Stream<List<ConnectivityResult>> get changes =>
      _connectivity.onConnectivityChanged;
}

/// Maps native transport hints into River's vendor-independent contract.
///
/// A connected transport can still be behind a captive portal or unable to
/// reach a feed. Callers must continue to handle request failures normally.
final class ConnectivityNetworkMonitor implements NetworkMonitor {
  ConnectivityNetworkMonitor({ConnectivityGateway? gateway})
      : _gateway = gateway ?? PluginConnectivityGateway();

  final ConnectivityGateway _gateway;

  @override
  Future<NetworkAvailability> check() async {
    try {
      return availabilityForConnectivity(await _gateway.check());
    } on Object {
      return NetworkAvailability.unknown;
    }
  }

  @override
  Stream<NetworkAvailability> get changes async* {
    try {
      await for (final result in _gateway.changes) {
        yield availabilityForConnectivity(result);
      }
    } on Object {
      yield NetworkAvailability.unknown;
    }
  }
}

final class ConnectivityAutomaticSummaryNetworkMonitor
    implements AutomaticSummaryNetworkMonitor {
  ConnectivityAutomaticSummaryNetworkMonitor({ConnectivityGateway? gateway})
      : _gateway = gateway ?? PluginConnectivityGateway();

  final ConnectivityGateway _gateway;

  @override
  Future<AutomaticSummaryNetworkKind> check() async {
    try {
      return automaticSummaryNetworkForConnectivity(await _gateway.check());
    } on Object {
      return AutomaticSummaryNetworkKind.unknown;
    }
  }

  @override
  Stream<AutomaticSummaryNetworkKind> get changes async* {
    try {
      await for (final result in _gateway.changes) {
        yield automaticSummaryNetworkForConnectivity(result);
      }
    } on Object {
      yield AutomaticSummaryNetworkKind.unknown;
    }
  }
}

NetworkAvailability availabilityForConnectivity(
  List<ConnectivityResult> results,
) {
  if (results.isEmpty) {
    return NetworkAvailability.unknown;
  }
  if (results.every((result) => result == ConnectivityResult.none)) {
    return NetworkAvailability.offline;
  }
  return NetworkAvailability.online;
}

AutomaticSummaryNetworkKind automaticSummaryNetworkForConnectivity(
  List<ConnectivityResult> results,
) {
  if (results.isEmpty) return AutomaticSummaryNetworkKind.unknown;
  if (results.every((result) => result == ConnectivityResult.none)) {
    return AutomaticSummaryNetworkKind.offline;
  }
  if (results.contains(ConnectivityResult.wifi)) {
    return AutomaticSummaryNetworkKind.wifi;
  }
  return AutomaticSummaryNetworkKind.other;
}
