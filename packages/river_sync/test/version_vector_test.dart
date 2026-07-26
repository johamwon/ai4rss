import 'package:river_sync/river_sync.dart';
import 'package:test/test.dart';

void main() {
  test('classifies equal, causal and concurrent vectors', () {
    final base = VersionVector(<String, int>{'device-a': 2});
    final next = base.incrementedBy('device-a');
    final concurrent = base.incrementedBy('device-b');

    expect(
      base.relationTo(VersionVector(<String, int>{'device-a': 2})),
      VersionVectorRelation.equal,
    );
    expect(next.relationTo(base), VersionVectorRelation.dominates);
    expect(base.relationTo(next), VersionVectorRelation.dominatedBy);
    expect(next.relationTo(concurrent), VersionVectorRelation.concurrent);
  });

  test('merge takes component maxima and canonical form is ordered', () {
    final left = VersionVector(<String, int>{
      'device-b': 4,
      'device-a': 1,
    });
    final right = VersionVector(<String, int>{
      'device-a': 3,
      'device-c': 2,
    });

    final merged = left.mergedWith(right);

    expect(
      merged.counters,
      <String, int>{'device-a': 3, 'device-b': 4, 'device-c': 2},
    );
    expect(
      merged.toCanonicalString(),
      'ZGV2aWNlLWE:3,ZGV2aWNlLWI:4,ZGV2aWNlLWM:2',
    );
    expect(
      merged,
      VersionVector(<String, int>{
        'device-c': 2,
        'device-b': 4,
        'device-a': 3,
      }),
    );
  });

  test('rejects ambiguous identifiers and non-positive counters', () {
    expect(
      () => VersionVector(<String, int>{' device-a': 1}),
      throwsArgumentError,
    );
    expect(
      () => VersionVector(<String, int>{'device-a': 0}),
      throwsArgumentError,
    );
  });
}
