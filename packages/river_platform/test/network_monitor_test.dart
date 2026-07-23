import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:river_domain/river_domain.dart';
import 'package:river_platform/river_platform.dart';

void main() {
  test('maps transport hints without claiming Internet reachability', () {
    expect(
      availabilityForConnectivity(const <ConnectivityResult>[]),
      NetworkAvailability.unknown,
    );
    expect(
      availabilityForConnectivity(const <ConnectivityResult>[
        ConnectivityResult.none,
      ]),
      NetworkAvailability.offline,
    );
    expect(
      availabilityForConnectivity(const <ConnectivityResult>[
        ConnectivityResult.none,
        ConnectivityResult.wifi,
      ]),
      NetworkAvailability.online,
    );
  });

  test('checks and streams gateway availability', () async {
    final gateway = _FakeConnectivityGateway(
      current: const <ConnectivityResult>[ConnectivityResult.none],
    );
    final monitor = ConnectivityNetworkMonitor(gateway: gateway);
    addTearDown(gateway.close);

    expect(await monitor.check(), NetworkAvailability.offline);

    final next = monitor.changes.first;
    gateway.emit(const <ConnectivityResult>[ConnectivityResult.ethernet]);
    expect(await next, NetworkAvailability.online);
  });

  test('adapter failure degrades to unknown instead of blocking requests',
      () async {
    final monitor = ConnectivityNetworkMonitor(
      gateway: _ThrowingConnectivityGateway(),
    );

    expect(await monitor.check(), NetworkAvailability.unknown);
    expect(await monitor.changes.first, NetworkAvailability.unknown);
  });
}

final class _FakeConnectivityGateway implements ConnectivityGateway {
  _FakeConnectivityGateway({required this.current});

  final StreamController<List<ConnectivityResult>> _changes =
      StreamController<List<ConnectivityResult>>();
  List<ConnectivityResult> current;

  @override
  Future<List<ConnectivityResult>> check() async => current;

  @override
  Stream<List<ConnectivityResult>> get changes => _changes.stream;

  void emit(List<ConnectivityResult> value) {
    current = value;
    _changes.add(value);
  }

  Future<void> close() => _changes.close();
}

final class _ThrowingConnectivityGateway implements ConnectivityGateway {
  @override
  Future<List<ConnectivityResult>> check() async => throw StateError('hidden');

  @override
  Stream<List<ConnectivityResult>> get changes =>
      Stream<List<ConnectivityResult>>.error(StateError('hidden'));
}
