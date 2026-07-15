import 'package:river_domain/river_domain.dart';
import 'package:river_preferences/river_preferences.dart';
import 'package:test/test.dart';

void main() {
  test('explicit negative feedback dominates a click', () {
    final now = DateTime.utc(2026, 7, 14);
    final open = ReadingEvent(
      articleId: 'a',
      type: ReadingEventType.open,
      occurredAt: now,
    );
    final negative = ReadingEvent(
      articleId: 'a',
      type: ReadingEventType.notInterested,
      occurredAt: now,
    );

    expect(
      readingSignalWeight(negative).abs(),
      greaterThan(readingSignalWeight(open)),
    );
  });
}
