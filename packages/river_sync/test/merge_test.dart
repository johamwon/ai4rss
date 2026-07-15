import 'package:river_sync/river_sync.dart';
import 'package:test/test.dart';

void main() {
  test('merge is deterministic when timestamps tie', () {
    final at = DateTime.utc(2026, 7, 14);
    final a = VersionedValue(value: 'a', updatedAt: at, deviceId: 'device-a');
    final b = VersionedValue(value: 'b', updatedAt: at, deviceId: 'device-b');

    expect(lastWriteWins(a, b).value, 'b');
    expect(lastWriteWins(b, a).value, 'b');
  });
}
