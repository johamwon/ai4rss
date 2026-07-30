import 'package:river_domain/river_domain.dart';

enum ReadingSessionVisibility {
  foreground,
  splitScreen,
  background,
  screenLocked;

  bool get permitsActiveReading =>
      this == ReadingSessionVisibility.foreground ||
      this == ReadingSessionVisibility.splitScreen;
}

final class ReadingSessionTracker {
  ReadingSessionTracker({
    required this.articleId,
    required Clock clock,
    required IdGenerator idGenerator,
    this.idleTimeout = const Duration(seconds: 60),
    this.minimumCompletionTime = const Duration(seconds: 30),
    this.completionThreshold = 0.9,
  })  : _clock = clock,
        _idGenerator = idGenerator {
    if (articleId.isEmpty ||
        articleId.length > 256 ||
        articleId.trim() != articleId ||
        idleTimeout <= Duration.zero ||
        minimumCompletionTime <= Duration.zero ||
        !completionThreshold.isFinite ||
        completionThreshold <= 0 ||
        completionThreshold > 1) {
      throw ArgumentError('Invalid reading session configuration.');
    }
  }

  final String articleId;
  final Duration idleTimeout;
  final Duration minimumCompletionTime;
  final double completionThreshold;
  final Clock _clock;
  final IdGenerator _idGenerator;
  final List<ReadingEvent> _pendingEvents = <ReadingEvent>[];

  ReadingSessionVisibility _visibility = ReadingSessionVisibility.foreground;
  bool _readerVisible = true;
  bool _started = false;
  bool _closed = false;
  bool _completionRecorded = false;
  DateTime? _checkpointAt;
  DateTime? _lastInteractionAt;
  Duration _activeDuration = Duration.zero;
  int _reportedActiveSeconds = 0;
  double _maximumScrollDepth = 0;

  Duration get activeDuration => _activeDuration;
  double get maximumScrollDepth => _maximumScrollDepth;
  bool get isCompleted => _completionRecorded;

  void start() {
    if (_started || _closed) {
      throw StateError('Reading session has already started.');
    }
    final now = _now();
    _started = true;
    _checkpointAt = now;
    _lastInteractionAt = now;
    _pendingEvents.add(_event(ReadingEventType.open, now));
  }

  void updateVisibility(ReadingSessionVisibility visibility) {
    final now = _requireOpenSession();
    _checkpoint(now);
    _visibility = visibility;
  }

  void setReaderVisible(bool visible) {
    final now = _requireOpenSession();
    _checkpoint(now);
    _readerVisible = visible;
  }

  void recordInteraction() {
    final now = _requireOpenSession();
    _checkpoint(now);
    _lastInteractionAt = now;
  }

  void recordScrollDepth(double depth) {
    if (!depth.isFinite || depth < 0 || depth > 1) {
      throw RangeError.range(depth, 0, 1, 'depth');
    }
    final now = _requireOpenSession();
    _checkpoint(now);
    _lastInteractionAt = now;
    if (depth > _maximumScrollDepth) {
      _maximumScrollDepth = depth;
    }
    _recordCompletionIfEligible(now);
  }

  List<ReadingEvent> flush() {
    final now = _requireOpenSession();
    _checkpoint(now);
    _emitUnreportedActiveRead(now);
    return drainEvents();
  }

  List<ReadingEvent> close() {
    final now = _requireOpenSession();
    _checkpoint(now);
    _emitUnreportedActiveRead(now);
    _closed = true;
    return drainEvents();
  }

  List<ReadingEvent> drainEvents() {
    final events = List<ReadingEvent>.unmodifiable(_pendingEvents);
    _pendingEvents.clear();
    return events;
  }

  DateTime _requireOpenSession() {
    if (!_started || _closed) {
      throw StateError('Reading session is not active.');
    }
    return _now();
  }

  DateTime _now() => _clock.now().toUtc();

  void _checkpoint(DateTime now) {
    final checkpoint = _checkpointAt!;
    if (now.isBefore(checkpoint)) {
      throw StateError('Reading session clock moved backwards.');
    }
    final lastInteraction = _lastInteractionAt;
    if (_visibility.permitsActiveReading &&
        _readerVisible &&
        lastInteraction != null) {
      final idleDeadline = lastInteraction.add(idleTimeout);
      final effectiveEnd = now.isBefore(idleDeadline) ? now : idleDeadline;
      if (effectiveEnd.isAfter(checkpoint)) {
        _activeDuration += effectiveEnd.difference(checkpoint);
      }
    }
    _checkpointAt = now;
    _recordCompletionIfEligible(now);
  }

  void _recordCompletionIfEligible(DateTime now) {
    if (_completionRecorded ||
        _activeDuration < minimumCompletionTime ||
        _maximumScrollDepth < completionThreshold) {
      return;
    }
    _emitUnreportedActiveRead(now);
    _completionRecorded = true;
    _pendingEvents.add(
      _event(
        ReadingEventType.completed,
        now,
        completionRatio: _maximumScrollDepth,
      ),
    );
  }

  void _emitUnreportedActiveRead(DateTime now) {
    final wholeActiveSeconds = _activeDuration.inSeconds;
    var unreportedSeconds = wholeActiveSeconds - _reportedActiveSeconds;
    while (unreportedSeconds > 0) {
      final chunkSeconds = unreportedSeconds > const Duration(days: 1).inSeconds
          ? const Duration(days: 1).inSeconds
          : unreportedSeconds;
      _pendingEvents.add(
        _event(
          ReadingEventType.activeRead,
          now,
          activeSeconds: chunkSeconds,
          completionRatio: _maximumScrollDepth,
        ),
      );
      _reportedActiveSeconds += chunkSeconds;
      unreportedSeconds -= chunkSeconds;
    }
  }

  ReadingEvent _event(
    ReadingEventType type,
    DateTime occurredAt, {
    int activeSeconds = 0,
    double completionRatio = 0,
  }) {
    final event = ReadingEvent(
      eventId: _idGenerator.next(),
      articleId: articleId,
      type: type,
      occurredAt: occurredAt,
      activeSeconds: activeSeconds,
      completionRatio: completionRatio,
    );
    event.validate();
    return event;
  }
}
