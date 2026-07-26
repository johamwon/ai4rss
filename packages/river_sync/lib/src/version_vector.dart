import 'dart:collection';
import 'dart:convert';

enum VersionVectorRelation { equal, dominates, dominatedBy, concurrent }

final class VersionVector {
  factory VersionVector([Map<String, int> counters = const <String, int>{}]) {
    final sorted = SplayTreeMap<String, int>();
    for (final entry in counters.entries) {
      _validateDeviceId(entry.key);
      if (entry.value <= 0) {
        throw ArgumentError.value(
          entry.value,
          'counters[${entry.key}]',
          'Version counters must be positive; zero counters are omitted.',
        );
      }
      sorted[entry.key] = entry.value;
    }
    return VersionVector._(Map<String, int>.unmodifiable(sorted));
  }

  const VersionVector._(this._counters);

  final Map<String, int> _counters;

  Map<String, int> get counters => _counters;
  bool get isEmpty => _counters.isEmpty;

  int counterFor(String deviceId) => _counters[deviceId] ?? 0;

  VersionVector incrementedBy(String deviceId) {
    _validateDeviceId(deviceId);
    return VersionVector(<String, int>{
      ..._counters,
      deviceId: counterFor(deviceId) + 1,
    });
  }

  VersionVector mergedWith(VersionVector other) {
    final merged = <String, int>{..._counters};
    for (final entry in other._counters.entries) {
      final current = merged[entry.key] ?? 0;
      if (entry.value > current) merged[entry.key] = entry.value;
    }
    return VersionVector(merged);
  }

  VersionVectorRelation relationTo(VersionVector other) {
    var greater = false;
    var less = false;
    final devices = <String>{..._counters.keys, ...other._counters.keys};
    for (final deviceId in devices) {
      final comparison =
          counterFor(deviceId).compareTo(other.counterFor(deviceId));
      if (comparison > 0) greater = true;
      if (comparison < 0) less = true;
      if (greater && less) return VersionVectorRelation.concurrent;
    }
    if (greater) return VersionVectorRelation.dominates;
    if (less) return VersionVectorRelation.dominatedBy;
    return VersionVectorRelation.equal;
  }

  String toCanonicalString() => _counters.entries
      .map((entry) => '${_escape(entry.key)}:${entry.value}')
      .join(',');

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! VersionVector || other._counters.length != _counters.length) {
      return false;
    }
    for (final entry in _counters.entries) {
      if (other._counters[entry.key] != entry.value) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(
        _counters.entries.expand<Object>(
          (entry) => <Object>[entry.key, entry.value],
        ),
      );

  @override
  String toString() => 'VersionVector(${toCanonicalString()})';

  static void _validateDeviceId(String deviceId) {
    if (deviceId.isEmpty ||
        deviceId.trim() != deviceId ||
        deviceId.length > 128) {
      throw ArgumentError.value(deviceId, 'deviceId', 'Invalid device id.');
    }
  }

  static String _escape(String value) =>
      base64Url.encode(utf8.encode(value)).replaceAll('=', '');
}
