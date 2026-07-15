library;

import 'dart:math' as math;

import 'package:river_domain/river_domain.dart';

double readingSignalWeight(ReadingEvent event) {
  return switch (event.type) {
    ReadingEventType.impression => 0,
    ReadingEventType.open => 0.2,
    ReadingEventType.activeRead =>
      (event.activeSeconds / 120).clamp(0, 1).toDouble(),
    ReadingEventType.completed => 1.5 + event.completionRatio.clamp(0, 1),
    ReadingEventType.starred => 2,
    ReadingEventType.savedToKnowledge => 2.5,
    ReadingEventType.notInterested => -3,
  };
}

double decayWeight({
  required double weight,
  required DateTime occurredAt,
  required DateTime now,
  double halfLifeDays = 30,
}) {
  if (!now.isAfter(occurredAt)) return weight;
  final days = now.difference(occurredAt).inMinutes / Duration.minutesPerDay;
  final factor = math.pow(0.5, days / halfLifeDays).toDouble();
  return weight * factor;
}
