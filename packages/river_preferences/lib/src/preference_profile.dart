import 'dart:collection';
import 'dart:convert';
import 'dart:math' as math;

import 'package:river_domain/river_domain.dart';

const String preferenceProfileSchema = 'river.preference-profile';
const int preferenceProfileModelVersion = 1;

final class PreferenceModelConfig {
  const PreferenceModelConfig({
    this.modelVersion = preferenceProfileModelVersion,
    this.halfLifeDays = 30,
    this.maximumAbsoluteDimensionScore = 1000,
  });

  final int modelVersion;
  final double halfLifeDays;
  final double maximumAbsoluteDimensionScore;

  String get modelId => '$preferenceProfileSchema/$modelVersion';

  void validate() {
    if (modelVersion != preferenceProfileModelVersion ||
        !halfLifeDays.isFinite ||
        halfLifeDays <= 0 ||
        !maximumAbsoluteDimensionScore.isFinite ||
        maximumAbsoluteDimensionScore <= 0) {
      throw const FormatException('Invalid preference model configuration.');
    }
  }
}

final class PreferenceEvidence {
  PreferenceEvidence({
    required this.event,
    required String sourceId,
    Iterable<String> topics = const <String>[],
  })  : sourceId = sourceId.trim(),
        topics = List<String>.unmodifiable(_normalizeTopics(topics)) {
    validate();
  }

  final ReadingEvent event;
  final String sourceId;
  final List<String> topics;

  void validate() {
    event.validate();
    if (sourceId.isEmpty ||
        sourceId.length > 256 ||
        topics.length > 16 ||
        topics.any((topic) => topic.isEmpty || topic.length > 64)) {
      throw const FormatException('Invalid preference evidence metadata.');
    }
  }

  String get _identity => jsonEncode(<String, Object>{
        'event': event.toJson(),
        'sourceId': sourceId,
        'topics': topics,
      });
}

final class PreferenceProfile {
  const PreferenceProfile._({
    required this.modelVersion,
    required this.generatedAt,
    required this.evidenceCount,
    required this.sourceScores,
    required this.topicScores,
  });

  final int modelVersion;
  final DateTime generatedAt;
  final int evidenceCount;
  final Map<String, double> sourceScores;
  final Map<String, double> topicScores;

  String get modelId => '$preferenceProfileSchema/$modelVersion';

  double sourceScore(String sourceId) => sourceScores[sourceId] ?? 0;

  double topicScore(String topic) =>
      topicScores[topic.trim().toLowerCase()] ?? 0;
}

final class LocalPreferenceProfileModel {
  const LocalPreferenceProfileModel({
    this.config = const PreferenceModelConfig(),
  });

  final PreferenceModelConfig config;

  PreferenceProfile build({
    required Iterable<PreferenceEvidence> evidence,
    required DateTime now,
  }) {
    config.validate();
    final generatedAt = now.toUtc();
    final unique = <String, PreferenceEvidence>{};
    final identities = <String, String>{};
    for (final item in evidence) {
      item.validate();
      if (item.event.occurredAt.isAfter(generatedAt)) {
        throw const FormatException(
          'Preference evidence cannot occur after profile generation.',
        );
      }
      final key = item.event.idempotencyKey;
      final identity = item._identity;
      final existingIdentity = identities[key];
      if (existingIdentity != null && existingIdentity != identity) {
        throw const FormatException(
          'Conflicting preference evidence identity.',
        );
      }
      identities[key] = identity;
      unique[key] = item;
    }

    final ordered = unique.values.toList()
      ..sort((left, right) {
        final byTime = left.event.occurredAt.compareTo(right.event.occurredAt);
        return byTime != 0
            ? byTime
            : left.event.eventId.compareTo(right.event.eventId);
      });
    final sources = SplayTreeMap<String, double>();
    final topics = SplayTreeMap<String, double>();
    final latestOpens = <String, PreferenceEvidence>{};
    for (final item in ordered) {
      if (item.event.type == ReadingEventType.open) {
        latestOpens[item.event.articleId] = item;
      }
    }

    for (final item in ordered) {
      if (item.event.type == ReadingEventType.open &&
          !identical(latestOpens[item.event.articleId], item)) {
        continue;
      }
      final score = decayWeight(
        weight: readingSignalWeight(item.event),
        occurredAt: item.event.occurredAt,
        now: generatedAt,
        halfLifeDays: config.halfLifeDays,
      );
      if (score == 0) continue;
      sources[item.sourceId] = (sources[item.sourceId] ?? 0) + score;
      if (item.topics.isNotEmpty) {
        final topicShare = score / item.topics.length;
        for (final topic in item.topics) {
          topics[topic] = (topics[topic] ?? 0) + topicShare;
        }
      }
    }

    return PreferenceProfile._(
      modelVersion: config.modelVersion,
      generatedAt: generatedAt,
      evidenceCount: unique.length,
      sourceScores: _boundedScores(
        sources,
        config.maximumAbsoluteDimensionScore,
      ),
      topicScores: _boundedScores(
        topics,
        config.maximumAbsoluteDimensionScore,
      ),
    );
  }
}

double readingSignalWeight(ReadingEvent event) {
  event.validate();
  return switch (event.type) {
    ReadingEventType.impression => 0,
    ReadingEventType.open => 0.2,
    ReadingEventType.activeRead =>
      0.25 + 0.75 * (event.activeSeconds / 120).clamp(0, 1),
    ReadingEventType.completed => 1.5 + event.completionRatio.clamp(0, 1),
    ReadingEventType.starred => 2.5,
    ReadingEventType.savedToKnowledge => 3,
    ReadingEventType.notInterested => -4,
  };
}

double decayWeight({
  required double weight,
  required DateTime occurredAt,
  required DateTime now,
  double halfLifeDays = 30,
}) {
  if (!weight.isFinite || !halfLifeDays.isFinite || halfLifeDays <= 0) {
    throw const FormatException('Invalid preference decay input.');
  }
  final normalizedNow = now.toUtc();
  final normalizedOccurrence = occurredAt.toUtc();
  if (normalizedOccurrence.isAfter(normalizedNow)) {
    throw const FormatException(
      'Preference evidence cannot occur after decay time.',
    );
  }
  if (normalizedOccurrence == normalizedNow || weight == 0) return weight;
  final age = normalizedNow.difference(normalizedOccurrence);
  final days = age.inMicroseconds / Duration.microsecondsPerDay;
  final factor = math.pow(0.5, days / halfLifeDays).toDouble();
  return weight * factor;
}

List<String> _normalizeTopics(Iterable<String> topics) {
  final normalized = SplayTreeSet<String>();
  for (final topic in topics) {
    normalized.add(topic.trim().toLowerCase());
  }
  return normalized.toList(growable: false);
}

Map<String, double> _boundedScores(
  SplayTreeMap<String, double> scores,
  double limit,
) =>
    Map<String, double>.unmodifiable(
      scores.map(
        (key, value) => MapEntry(key, value.clamp(-limit, limit).toDouble()),
      ),
    );
