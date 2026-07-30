import 'package:river_domain/river_domain.dart';
import 'package:river_preferences/river_preferences.dart';
import 'package:test/test.dart';

void main() {
  test('foreground interaction records active time and completion in order',
      () {
    final clock = _FakeClock();
    final tracker = _tracker(clock);
    tracker.start();

    clock.advance(const Duration(seconds: 10));
    tracker.recordInteraction();
    clock.advance(const Duration(seconds: 20));
    tracker.recordScrollDepth(0.92);
    final events = tracker.flush();

    expect(
      events.map((event) => event.type),
      <ReadingEventType>[
        ReadingEventType.open,
        ReadingEventType.activeRead,
        ReadingEventType.completed,
      ],
    );
    expect(events[1].activeSeconds, 30);
    expect(events[1].completionRatio, 0.92);
    expect(events[2].completionRatio, 0.92);
    expect(tracker.activeDuration, const Duration(seconds: 30));
  });

  test('background time is excluded until a new interaction', () {
    final clock = _FakeClock();
    final tracker = _tracker(clock);
    tracker.start();

    clock.advance(const Duration(seconds: 10));
    tracker.updateVisibility(ReadingSessionVisibility.background);
    clock.advance(const Duration(minutes: 5));
    tracker.updateVisibility(ReadingSessionVisibility.foreground);
    clock.advance(const Duration(seconds: 20));
    tracker.recordInteraction();
    clock.advance(const Duration(seconds: 10));
    final active = _activeEvent(tracker.flush());

    expect(active.activeSeconds, 20);
  });

  test('visible split screen remains eligible for bounded active time', () {
    final clock = _FakeClock();
    final tracker = _tracker(clock);
    tracker.start();
    tracker.updateVisibility(ReadingSessionVisibility.splitScreen);

    clock.advance(const Duration(seconds: 20));
    tracker.recordInteraction();
    clock.advance(const Duration(seconds: 20));
    final active = _activeEvent(tracker.flush());

    expect(active.activeSeconds, 40);
  });

  test('screen lock excludes elapsed time and expires stale attention', () {
    final clock = _FakeClock();
    final tracker = _tracker(clock);
    tracker.start();

    clock.advance(const Duration(seconds: 10));
    tracker.updateVisibility(ReadingSessionVisibility.screenLocked);
    clock.advance(const Duration(minutes: 5));
    tracker.updateVisibility(ReadingSessionVisibility.foreground);
    clock.advance(const Duration(seconds: 10));
    tracker.recordInteraction();
    clock.advance(const Duration(seconds: 5));
    final active = _activeEvent(tracker.flush());

    expect(active.activeSeconds, 15);
  });

  test('an invisible reader page never accrues active time', () {
    final clock = _FakeClock();
    final tracker = _tracker(clock);
    tracker.start();

    clock.advance(const Duration(seconds: 8));
    tracker.setReaderVisible(false);
    clock.advance(const Duration(minutes: 2));
    tracker.setReaderVisible(true);
    tracker.recordInteraction();
    clock.advance(const Duration(seconds: 7));
    final active = _activeEvent(tracker.flush());

    expect(active.activeSeconds, 15);
  });

  test('idle timeout caps unattended foreground time', () {
    final clock = _FakeClock();
    final tracker = _tracker(clock);
    tracker.start();

    clock.advance(const Duration(minutes: 10));
    final active = _activeEvent(tracker.flush());

    expect(active.activeSeconds, 60);
    expect(tracker.activeDuration, const Duration(seconds: 60));
  });

  test('jumping to the end does not complete without effective reading', () {
    final clock = _FakeClock();
    final tracker = _tracker(clock);
    tracker.start();
    tracker.recordScrollDepth(0.99);

    clock.advance(const Duration(seconds: 10));
    var events = tracker.flush();
    expect(
      events.where((event) => event.type == ReadingEventType.completed),
      isEmpty,
    );

    tracker.recordInteraction();
    clock.advance(const Duration(seconds: 20));
    events = tracker.flush();
    expect(
      events.where((event) => event.type == ReadingEventType.completed),
      hasLength(1),
    );
  });

  test('flush emits only new whole seconds and close is terminal', () {
    final clock = _FakeClock();
    final tracker = _tracker(clock);
    tracker.start();
    clock.advance(const Duration(milliseconds: 1500));

    expect(_activeEvent(tracker.flush()).activeSeconds, 1);
    clock.advance(const Duration(milliseconds: 400));
    expect(
      tracker.flush().where(
            (event) => event.type == ReadingEventType.activeRead,
          ),
      isEmpty,
    );
    clock.advance(const Duration(milliseconds: 600));
    expect(_activeEvent(tracker.close()).activeSeconds, 1);
    expect(tracker.flush, throwsStateError);
  });

  test('invalid configuration and a backwards clock fail closed', () {
    final clock = _FakeClock();
    expect(
      () => ReadingSessionTracker(
        articleId: 'article-1',
        clock: clock,
        idGenerator: _SequentialIds(),
        minimumCompletionTime: Duration.zero,
      ),
      throwsArgumentError,
    );
    final tracker = _tracker(clock);
    tracker.start();
    clock.advance(const Duration(seconds: 5));
    tracker.recordInteraction();
    clock.advance(const Duration(seconds: -1));

    expect(tracker.flush, throwsStateError);
  });

  test('unreported active time is split into schema-bounded events', () {
    final clock = _FakeClock();
    final tracker = ReadingSessionTracker(
      articleId: 'article-1',
      clock: clock,
      idGenerator: _SequentialIds(),
      idleTimeout: const Duration(days: 3),
    );
    tracker.start();
    clock.advance(const Duration(days: 2, seconds: 5));

    final activeEvents = tracker
        .flush()
        .where((event) => event.type == ReadingEventType.activeRead)
        .toList();

    expect(activeEvents, hasLength(3));
    expect(
      activeEvents.map((event) => event.activeSeconds),
      <int>[86400, 86400, 5],
    );
    for (final event in activeEvents) {
      expect(event.toJson(), isNotEmpty);
    }
  });
}

ReadingSessionTracker _tracker(_FakeClock clock) => ReadingSessionTracker(
      articleId: 'article-1',
      clock: clock,
      idGenerator: _SequentialIds(),
    );

ReadingEvent _activeEvent(List<ReadingEvent> events) => events.singleWhere(
      (event) => event.type == ReadingEventType.activeRead,
    );

final class _FakeClock implements Clock {
  DateTime _now = DateTime.utc(2026, 7, 30, 12);

  @override
  DateTime now() => _now;

  void advance(Duration duration) {
    _now = _now.add(duration);
  }
}

final class _SequentialIds implements IdGenerator {
  var _next = 0;

  @override
  String next() => 'reading-event-${_next++}';
}
