import 'dart:convert';

const String readingEventSchema = 'river.reading-event';
const int readingEventSchemaVersion = 1;
const String readingBehaviorExportSchema = 'river.reading-event-export';
const int readingBehaviorExportSchemaVersion = 1;

enum ReadingEventRecordResult { inserted, duplicate, captureDisabled }

abstract interface class ReadingEventRepository {
  Future<ReadingEventRecordResult> record(ReadingEvent event);
}

abstract interface class ReadingBehaviorRepository
    implements ReadingEventRepository {
  Future<bool> needsIntroduction();
  Stream<ReadingBehaviorSettings> watchSettings();
  Future<ReadingBehaviorSettings> readSettings();
  Future<void> saveSettings(
    ReadingBehaviorSettings settings, {
    required DateTime updatedAt,
  });
  Future<List<ReadingEvent>> readEvents();
  Future<int> purgeExpired({required DateTime now});
  Future<int> clearEvents();
  Future<int> clearPreferenceProfile({required DateTime updatedAt});
  Future<String> exportJson({required DateTime exportedAt});
}

final class ReadingBehaviorSettings {
  const ReadingBehaviorSettings({
    this.captureEnabled = false,
    this.retentionDays = 90,
    this.preferenceControls = const ReadingPreferenceControls(),
  });

  final bool captureEnabled;
  final int retentionDays;
  final ReadingPreferenceControls preferenceControls;

  ReadingBehaviorSettings copyWith({
    bool? captureEnabled,
    int? retentionDays,
    ReadingPreferenceControls? preferenceControls,
  }) =>
      ReadingBehaviorSettings(
        captureEnabled: captureEnabled ?? this.captureEnabled,
        retentionDays: retentionDays ?? this.retentionDays,
        preferenceControls: preferenceControls ?? this.preferenceControls,
      );

  void validate() {
    if (retentionDays < 1 || retentionDays > 3650) {
      throw const FormatException(
        'Reading event retention must be between 1 and 3650 days.',
      );
    }
    preferenceControls.validate();
  }

  @override
  bool operator ==(Object other) =>
      other is ReadingBehaviorSettings &&
      other.captureEnabled == captureEnabled &&
      other.retentionDays == retentionDays &&
      other.preferenceControls == preferenceControls;

  @override
  int get hashCode =>
      Object.hash(captureEnabled, retentionDays, preferenceControls);
}

final class ReadingPreferenceControls {
  const ReadingPreferenceControls({
    this.sourceScoreAdjustments = const <String, double>{},
    this.topicScoreAdjustments = const <String, double>{},
    this.blockedSourceIds = const <String>{},
    this.blockedTopics = const <String>{},
  });

  static const int maximumSourceDimensions = 256;
  static const int maximumTopicDimensions = 64;
  static const double maximumAbsoluteAdjustment = 4;

  final Map<String, double> sourceScoreAdjustments;
  final Map<String, double> topicScoreAdjustments;
  final Set<String> blockedSourceIds;
  final Set<String> blockedTopics;

  bool get isEmpty =>
      sourceScoreAdjustments.isEmpty &&
      topicScoreAdjustments.isEmpty &&
      blockedSourceIds.isEmpty &&
      blockedTopics.isEmpty;

  ReadingPreferenceControls copyWith({
    Map<String, double>? sourceScoreAdjustments,
    Map<String, double>? topicScoreAdjustments,
    Set<String>? blockedSourceIds,
    Set<String>? blockedTopics,
  }) =>
      ReadingPreferenceControls(
        sourceScoreAdjustments:
            sourceScoreAdjustments ?? this.sourceScoreAdjustments,
        topicScoreAdjustments:
            topicScoreAdjustments ?? this.topicScoreAdjustments,
        blockedSourceIds: blockedSourceIds ?? this.blockedSourceIds,
        blockedTopics: blockedTopics ?? this.blockedTopics,
      );

  void validate() {
    if (sourceScoreAdjustments.length > maximumSourceDimensions ||
        blockedSourceIds.length > maximumSourceDimensions ||
        topicScoreAdjustments.length > maximumTopicDimensions ||
        blockedTopics.length > maximumTopicDimensions) {
      throw const FormatException('Too many reading preference controls.');
    }
    for (final entry in sourceScoreAdjustments.entries) {
      _validatePreferenceDimension(
        entry.key,
        maximumLength: 256,
        normalizeAsTopic: false,
      );
      _validatePreferenceAdjustment(entry.value);
    }
    for (final entry in topicScoreAdjustments.entries) {
      _validatePreferenceDimension(
        entry.key,
        maximumLength: 64,
        normalizeAsTopic: true,
      );
      _validatePreferenceAdjustment(entry.value);
    }
    for (final sourceId in blockedSourceIds) {
      _validatePreferenceDimension(
        sourceId,
        maximumLength: 256,
        normalizeAsTopic: false,
      );
    }
    for (final topic in blockedTopics) {
      _validatePreferenceDimension(
        topic,
        maximumLength: 64,
        normalizeAsTopic: true,
      );
    }
  }

  @override
  bool operator ==(Object other) =>
      other is ReadingPreferenceControls &&
      _mapsEqual(other.sourceScoreAdjustments, sourceScoreAdjustments) &&
      _mapsEqual(other.topicScoreAdjustments, topicScoreAdjustments) &&
      _setsEqual(other.blockedSourceIds, blockedSourceIds) &&
      _setsEqual(other.blockedTopics, blockedTopics);

  @override
  int get hashCode => Object.hash(
        _stableMapHash(sourceScoreAdjustments),
        _stableMapHash(topicScoreAdjustments),
        _stableSetHash(blockedSourceIds),
        _stableSetHash(blockedTopics),
      );
}

abstract final class ReadingBehaviorExportCodec {
  static String encode({
    required ReadingBehaviorSettings settings,
    required Iterable<ReadingEvent> events,
    required DateTime exportedAt,
  }) {
    settings.validate();
    final ordered = events.toList()
      ..sort((left, right) {
        final byTime = left.occurredAt.compareTo(right.occurredAt);
        return byTime != 0 ? byTime : left.eventId.compareTo(right.eventId);
      });
    for (final event in ordered) {
      event.validate();
    }
    return jsonEncode(<String, Object>{
      'schema': readingBehaviorExportSchema,
      'version': readingBehaviorExportSchemaVersion,
      'exportedAt': exportedAt.toUtc().toIso8601String(),
      'settings': <String, Object>{
        'captureEnabled': settings.captureEnabled,
        'retentionDays': settings.retentionDays,
        'preferenceControls': <String, Object>{
          'sourceScoreAdjustments': _sortedMap(
            settings.preferenceControls.sourceScoreAdjustments,
          ),
          'topicScoreAdjustments': _sortedMap(
            settings.preferenceControls.topicScoreAdjustments,
          ),
          'blockedSourceIds':
              settings.preferenceControls.blockedSourceIds.toList()..sort(),
          'blockedTopics': settings.preferenceControls.blockedTopics.toList()
            ..sort(),
        },
      },
      'events': ordered.map((event) => event.toJson()).toList(),
    });
  }
}

final class ReadingEventIdentityConflict implements Exception {
  const ReadingEventIdentityConflict(this.eventId);

  final String eventId;

  @override
  String toString() =>
      'ReadingEventIdentityConflict: event ID "$eventId" was reused.';
}

enum ReadingEventType {
  impression,
  open,
  activeRead,
  completed,
  starred,
  savedToKnowledge,
  notInterested;

  String get wireName => switch (this) {
        ReadingEventType.impression => 'impression',
        ReadingEventType.open => 'open',
        ReadingEventType.activeRead => 'active_read',
        ReadingEventType.completed => 'completed',
        ReadingEventType.starred => 'starred',
        ReadingEventType.savedToKnowledge => 'saved_to_knowledge',
        ReadingEventType.notInterested => 'not_interested',
      };

  static ReadingEventType fromWireName(String value) => switch (value) {
        'impression' => ReadingEventType.impression,
        'open' => ReadingEventType.open,
        'active_read' => ReadingEventType.activeRead,
        'completed' => ReadingEventType.completed,
        'starred' => ReadingEventType.starred,
        'saved_to_knowledge' => ReadingEventType.savedToKnowledge,
        'not_interested' => ReadingEventType.notInterested,
        _ => throw FormatException('Unknown reading event type: $value'),
      };
}

final class ReadingEvent {
  const ReadingEvent({
    required this.eventId,
    required this.articleId,
    required this.type,
    required this.occurredAt,
    this.schemaVersion = readingEventSchemaVersion,
    this.activeSeconds = 0,
    this.completionRatio = 0,
  });

  factory ReadingEvent.fromJson(Map<String, Object?> json) {
    _requireExactEventKeys(
      json,
      const <String>{
        'schema',
        'version',
        'eventId',
        'articleId',
        'type',
        'occurredAt',
        'payload',
      },
      'envelope',
    );
    if (json['schema'] != readingEventSchema) {
      throw const FormatException('Unsupported reading event schema.');
    }
    final version = json['version'];
    if (version is! int || version != readingEventSchemaVersion) {
      throw FormatException(
        'Unsupported reading event schema version: $version',
      );
    }
    final occurredAtValue = json['occurredAt'];
    if (occurredAtValue is! String || !occurredAtValue.endsWith('Z')) {
      throw const FormatException('Invalid reading event envelope.');
    }
    final occurredAt = DateTime.tryParse(occurredAtValue);
    final payload = json['payload'];
    if (occurredAt == null ||
        !occurredAt.isUtc ||
        payload is! Map<String, Object?>) {
      throw const FormatException('Invalid reading event envelope.');
    }
    _requireExactEventKeys(
      payload,
      const <String>{'activeSeconds', 'completionRatio'},
      'payload',
    );
    final activeSeconds = payload['activeSeconds'];
    final completionRatio = payload['completionRatio'];
    if (activeSeconds is! int || completionRatio is! num) {
      throw const FormatException('Invalid reading event payload.');
    }
    final event = ReadingEvent(
      eventId: _requiredEventString(json, 'eventId'),
      articleId: _requiredEventString(json, 'articleId'),
      type: ReadingEventType.fromWireName(
        _requiredEventString(json, 'type'),
      ),
      occurredAt: occurredAt.toUtc(),
      schemaVersion: version,
      activeSeconds: activeSeconds,
      completionRatio: completionRatio.toDouble(),
    );
    event.validate();
    return event;
  }

  final String eventId;
  final String articleId;
  final ReadingEventType type;
  final DateTime occurredAt;
  final int schemaVersion;
  final int activeSeconds;
  final double completionRatio;

  String get idempotencyKey => '$readingEventSchema/$schemaVersion/$eventId';

  Map<String, Object> toJson() {
    validate();
    return <String, Object>{
      'schema': readingEventSchema,
      'version': schemaVersion,
      'eventId': eventId,
      'articleId': articleId,
      'type': type.wireName,
      'occurredAt': occurredAt.toUtc().toIso8601String(),
      'payload': <String, Object>{
        'activeSeconds': activeSeconds,
        'completionRatio': completionRatio,
      },
    };
  }

  void validate() {
    if (schemaVersion != readingEventSchemaVersion) {
      throw FormatException(
        'Unsupported reading event schema version: $schemaVersion',
      );
    }
    if (!_validEventIdentifier(eventId) || !_validEventIdentifier(articleId)) {
      throw const FormatException('Invalid reading event identifier.');
    }
    if (activeSeconds < 0 ||
        activeSeconds > const Duration(days: 1).inSeconds ||
        !completionRatio.isFinite ||
        completionRatio < 0 ||
        completionRatio > 1) {
      throw const FormatException('Invalid reading event payload.');
    }
    switch (type) {
      case ReadingEventType.activeRead:
        if (activeSeconds == 0) {
          throw const FormatException(
            'An active-read event requires a positive duration.',
          );
        }
      case ReadingEventType.completed:
        if (completionRatio == 0) {
          throw const FormatException(
            'A completed event requires a positive completion ratio.',
          );
        }
      case ReadingEventType.impression:
      case ReadingEventType.open:
      case ReadingEventType.starred:
      case ReadingEventType.savedToKnowledge:
      case ReadingEventType.notInterested:
        if (activeSeconds != 0 || completionRatio != 0) {
          throw const FormatException(
            'This reading event type does not accept progress payload.',
          );
        }
    }
  }
}

String _requiredEventString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('Missing reading event field: $key');
  }
  return value;
}

bool _validEventIdentifier(String value) =>
    value.isNotEmpty && value.length <= 256 && value.trim() == value;

void _validatePreferenceDimension(
  String value, {
  required int maximumLength,
  required bool normalizeAsTopic,
}) {
  final normalized =
      normalizeAsTopic ? value.trim().toLowerCase() : value.trim();
  if (value.isEmpty || value.length > maximumLength || value != normalized) {
    throw const FormatException('Invalid reading preference dimension.');
  }
}

void _validatePreferenceAdjustment(double value) {
  if (!value.isFinite ||
      value < -ReadingPreferenceControls.maximumAbsoluteAdjustment ||
      value > ReadingPreferenceControls.maximumAbsoluteAdjustment) {
    throw const FormatException('Invalid reading preference adjustment.');
  }
}

bool _mapsEqual(Map<String, double> left, Map<String, double> right) {
  if (left.length != right.length) return false;
  return left.entries.every((entry) => right[entry.key] == entry.value);
}

bool _setsEqual(Set<String> left, Set<String> right) =>
    left.length == right.length && left.containsAll(right);

int _stableMapHash(Map<String, double> value) {
  final keys = value.keys.toList()..sort();
  return Object.hashAll(keys.map((key) => Object.hash(key, value[key])));
}

int _stableSetHash(Set<String> value) {
  final items = value.toList()..sort();
  return Object.hashAll(items);
}

Map<String, double> _sortedMap(Map<String, double> value) {
  final keys = value.keys.toList()..sort();
  return <String, double>{for (final key in keys) key: value[key]!};
}

void _requireExactEventKeys(
  Map<String, Object?> value,
  Set<String> expected,
  String location,
) {
  if (value.length != expected.length ||
      !value.keys.toSet().containsAll(expected)) {
    throw FormatException('Invalid reading event $location fields.');
  }
}
