const String readingEventSchema = 'river.reading-event';
const int readingEventSchemaVersion = 1;

enum ReadingEventRecordResult { inserted, duplicate }

abstract interface class ReadingEventRepository {
  Future<ReadingEventRecordResult> record(ReadingEvent event);
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
