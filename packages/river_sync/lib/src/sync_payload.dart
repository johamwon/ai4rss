import 'dart:convert';
import 'dart:typed_data';

import 'sync_protocol.dart';

final class SyncObjectPayload {
  SyncObjectPayload._({
    required this.objectKind,
    required this.objectId,
    required Map<String, Object?> fields,
  }) : fields = Map<String, Object?>.unmodifiable(_copyFields(fields)) {
    _requireIdentifier(objectId, 'objectId');
    _validateFields(objectKind, this.fields);
  }

  factory SyncObjectPayload.subscription({
    required String objectId,
    required String canonicalUrl,
    required String title,
    required bool enabled,
    String? folderId,
  }) =>
      SyncObjectPayload._(
        objectKind: SyncObjectKind.subscription,
        objectId: objectId,
        fields: <String, Object?>{
          'canonicalUrl': canonicalUrl,
          'title': title,
          'folderId': folderId,
          'enabled': enabled,
        },
      );

  factory SyncObjectPayload.folder({
    required String objectId,
    required String name,
    required int position,
    String? parentId,
  }) =>
      SyncObjectPayload._(
        objectKind: SyncObjectKind.folder,
        objectId: objectId,
        fields: <String, Object?>{
          'name': name,
          'position': position,
          'parentId': parentId,
        },
      );

  factory SyncObjectPayload.articleState({
    required String objectId,
    required bool read,
    required bool starred,
    required bool readLater,
    required int activeReadSeconds,
    required double scrollDepth,
    DateTime? completedAt,
  }) =>
      SyncObjectPayload._(
        objectKind: SyncObjectKind.articleState,
        objectId: objectId,
        fields: <String, Object?>{
          'read': read,
          'starred': starred,
          'readLater': readLater,
          'activeReadSeconds': activeReadSeconds,
          'scrollDepth': scrollDepth,
          'completedAt': completedAt?.toIso8601String(),
        },
      );

  factory SyncObjectPayload.readerSettings({
    required String objectId,
    required String fontFamily,
    required double fontScale,
    required double lineHeight,
    required double contentWidth,
    required String theme,
  }) =>
      SyncObjectPayload._(
        objectKind: SyncObjectKind.readerSettings,
        objectId: objectId,
        fields: <String, Object?>{
          'fontFamily': fontFamily,
          'fontScale': fontScale,
          'lineHeight': lineHeight,
          'contentWidth': contentWidth,
          'theme': theme,
        },
      );

  factory SyncObjectPayload.audioProgress({
    required String objectId,
    required String itemKind,
    required int positionMs,
    int? segmentIndex,
    int? characterOffset,
    String? contentRevision,
    int? durationMs,
  }) =>
      SyncObjectPayload._(
        objectKind: SyncObjectKind.audioProgress,
        objectId: objectId,
        fields: <String, Object?>{
          'itemKind': itemKind,
          'positionMs': positionMs,
          'segmentIndex': segmentIndex,
          'characterOffset': characterOffset,
          'contentRevision': contentRevision,
          'durationMs': durationMs,
        },
      );

  factory SyncObjectPayload.knowledgeMetadata({
    required String objectId,
    required String title,
    required String originalUrl,
    required String contentHash,
    required List<String> tags,
    required Map<String, String> externalMappings,
    String? articleId,
  }) =>
      SyncObjectPayload._(
        objectKind: SyncObjectKind.knowledgeMetadata,
        objectId: objectId,
        fields: <String, Object?>{
          'articleId': articleId,
          'title': title,
          'originalUrl': originalUrl,
          'contentHash': contentHash,
          'tags': List<String>.unmodifiable(tags),
          'externalMappings':
              Map<String, String>.unmodifiable(externalMappings),
        },
      );

  factory SyncObjectPayload.fromFields({
    required SyncObjectKind objectKind,
    required String objectId,
    required Map<String, Object?> fields,
  }) =>
      SyncObjectPayload._(
        objectKind: objectKind,
        objectId: objectId,
        fields: fields,
      );

  final SyncObjectKind objectKind;
  final String objectId;
  final Map<String, Object?> fields;

  @override
  String toString() =>
      'SyncObjectPayload(kind: ${objectKind.name}, objectId: $objectId)';
}

final class SyncTombstoneBody {
  SyncTombstoneBody({
    required this.objectKind,
    required this.objectId,
    required this.deletedAt,
    required this.deletedByDeviceId,
  }) {
    _requireIdentifier(objectId, 'objectId');
    _requireIdentifier(deletedByDeviceId, 'deletedByDeviceId');
    _requireUtc(deletedAt, 'deletedAt');
  }

  final SyncObjectKind objectKind;
  final String objectId;
  final DateTime deletedAt;
  final String deletedByDeviceId;
}

sealed class DecodedSyncPayload {
  const DecodedSyncPayload({
    required this.objectKind,
    required this.objectId,
    required this.payloadKind,
  });

  final SyncObjectKind objectKind;
  final String objectId;
  final SyncPayloadKind payloadKind;
}

final class DecodedSyncUpsert extends DecodedSyncPayload {
  DecodedSyncUpsert(this.payload)
      : super(
          objectKind: payload.objectKind,
          objectId: payload.objectId,
          payloadKind: SyncPayloadKind.upsert,
        );

  final SyncObjectPayload payload;
}

final class DecodedSyncTombstone extends DecodedSyncPayload {
  DecodedSyncTombstone(this.tombstone)
      : super(
          objectKind: tombstone.objectKind,
          objectId: tombstone.objectId,
          payloadKind: SyncPayloadKind.tombstone,
        );

  final SyncTombstoneBody tombstone;
}

abstract final class SyncPayloadCodec {
  static const schemaVersion = 1;
  static const maximumClearTextBytes = 512 * 1024;

  static Uint8List encodeUpsert(SyncObjectPayload payload) => _encode(
        <String, Object?>{
          'schema': schemaVersion,
          'payloadKind': SyncPayloadKind.upsert.name,
          'objectKind': payload.objectKind.name,
          'objectId': payload.objectId,
          'fields': payload.fields,
        },
      );

  static Uint8List encodeTombstone(SyncTombstoneBody tombstone) => _encode(
        <String, Object?>{
          'schema': schemaVersion,
          'payloadKind': SyncPayloadKind.tombstone.name,
          'objectKind': tombstone.objectKind.name,
          'objectId': tombstone.objectId,
          'deletedAt': tombstone.deletedAt.toIso8601String(),
          'deletedByDeviceId': tombstone.deletedByDeviceId,
        },
      );

  static DecodedSyncPayload decode(List<int> bytes) {
    if (bytes.isEmpty || bytes.length > maximumClearTextBytes) {
      throw const SyncPayloadException(SyncPayloadFailureCode.invalidSize);
    }
    try {
      final decoded = jsonDecode(utf8.decode(bytes, allowMalformed: false));
      if (decoded is! Map<String, Object?> ||
          decoded['schema'] != schemaVersion) {
        throw const SyncPayloadException(
          SyncPayloadFailureCode.unsupportedSchema,
        );
      }
      final objectKind = SyncObjectKind.values.byName(
        _string(decoded, 'objectKind'),
      );
      final objectId = _string(decoded, 'objectId');
      final payloadKind = SyncPayloadKind.values.byName(
        _string(decoded, 'payloadKind'),
      );
      switch (payloadKind) {
        case SyncPayloadKind.upsert:
          _requireKeys(
            decoded,
            const <String>{
              'schema',
              'payloadKind',
              'objectKind',
              'objectId',
              'fields',
            },
          );
          final fields = decoded['fields'];
          if (fields is! Map<String, Object?>) {
            throw const SyncPayloadException(
              SyncPayloadFailureCode.invalidShape,
            );
          }
          return DecodedSyncUpsert(
            SyncObjectPayload.fromFields(
              objectKind: objectKind,
              objectId: objectId,
              fields: fields,
            ),
          );
        case SyncPayloadKind.tombstone:
          _requireKeys(
            decoded,
            const <String>{
              'schema',
              'payloadKind',
              'objectKind',
              'objectId',
              'deletedAt',
              'deletedByDeviceId',
            },
          );
          return DecodedSyncTombstone(
            SyncTombstoneBody(
              objectKind: objectKind,
              objectId: objectId,
              deletedAt: DateTime.parse(_string(decoded, 'deletedAt')),
              deletedByDeviceId: _string(decoded, 'deletedByDeviceId'),
            ),
          );
      }
    } on SyncPayloadException {
      rethrow;
    } on Object {
      throw const SyncPayloadException(SyncPayloadFailureCode.invalidShape);
    }
  }

  static Uint8List _encode(Map<String, Object?> value) {
    final encoded = Uint8List.fromList(utf8.encode(jsonEncode(value)));
    if (encoded.length > maximumClearTextBytes) {
      throw const SyncPayloadException(SyncPayloadFailureCode.invalidSize);
    }
    return encoded;
  }
}

enum SyncPayloadFailureCode {
  invalidSize,
  invalidShape,
  unsupportedSchema,
}

final class SyncPayloadException implements Exception {
  const SyncPayloadException(this.code);

  final SyncPayloadFailureCode code;

  @override
  String toString() => 'SyncPayloadException(${code.name})';
}

Map<String, Object?> _copyFields(Map<String, Object?> fields) {
  final result = <String, Object?>{};
  for (final entry in fields.entries) {
    final value = entry.value;
    result[entry.key] = switch (value) {
      final List<Object?> values => List<Object?>.unmodifiable(values),
      final Map<Object?, Object?> values => Map<String, Object?>.unmodifiable(
          values.map(
            (key, value) => MapEntry<String, Object?>(key as String, value),
          ),
        ),
      _ => value,
    };
  }
  return result;
}

void _validateFields(
  SyncObjectKind objectKind,
  Map<String, Object?> fields,
) {
  switch (objectKind) {
    case SyncObjectKind.subscription:
      _requireKeys(
        fields,
        const <String>{'canonicalUrl', 'title', 'folderId', 'enabled'},
      );
      _publicHttpUri(_string(fields, 'canonicalUrl'), 'canonicalUrl');
      _boundedString(fields, 'title', maximum: 1024);
      _nullableIdentifier(fields, 'folderId');
      _boolean(fields, 'enabled');
    case SyncObjectKind.folder:
      _requireKeys(
        fields,
        const <String>{'name', 'position', 'parentId'},
      );
      _boundedString(fields, 'name', maximum: 256);
      _nonNegativeInteger(fields, 'position');
      _nullableIdentifier(fields, 'parentId');
    case SyncObjectKind.articleState:
      _requireKeys(
        fields,
        const <String>{
          'read',
          'starred',
          'readLater',
          'activeReadSeconds',
          'scrollDepth',
          'completedAt',
        },
      );
      _boolean(fields, 'read');
      _boolean(fields, 'starred');
      _boolean(fields, 'readLater');
      _nonNegativeInteger(fields, 'activeReadSeconds');
      final depth = _finiteDouble(fields, 'scrollDepth');
      if (depth < 0 || depth > 1) {
        throw const SyncPayloadException(SyncPayloadFailureCode.invalidShape);
      }
      _nullableUtcTimestamp(fields, 'completedAt');
    case SyncObjectKind.readerSettings:
      _requireKeys(
        fields,
        const <String>{
          'fontFamily',
          'fontScale',
          'lineHeight',
          'contentWidth',
          'theme',
        },
      );
      _boundedString(fields, 'fontFamily', maximum: 64);
      _boundedDouble(fields, 'fontScale', minimum: 0.75, maximum: 2);
      _boundedDouble(fields, 'lineHeight', minimum: 1, maximum: 3);
      _boundedDouble(fields, 'contentWidth', minimum: 320, maximum: 1600);
      final theme = _string(fields, 'theme');
      if (!const <String>{'system', 'light', 'dark'}.contains(theme)) {
        throw const SyncPayloadException(SyncPayloadFailureCode.invalidShape);
      }
    case SyncObjectKind.audioProgress:
      _requireKeys(
        fields,
        const <String>{
          'itemKind',
          'positionMs',
          'segmentIndex',
          'characterOffset',
          'contentRevision',
          'durationMs',
        },
      );
      final itemKind = _string(fields, 'itemKind');
      if (!const <String>{'articleTts', 'podcast'}.contains(itemKind)) {
        throw const SyncPayloadException(SyncPayloadFailureCode.invalidShape);
      }
      _nonNegativeInteger(fields, 'positionMs');
      _nullableNonNegativeInteger(fields, 'segmentIndex');
      _nullableNonNegativeInteger(fields, 'characterOffset');
      _nullableBoundedString(fields, 'contentRevision', maximum: 256);
      _nullableNonNegativeInteger(fields, 'durationMs');
    case SyncObjectKind.knowledgeMetadata:
      _requireKeys(
        fields,
        const <String>{
          'articleId',
          'title',
          'originalUrl',
          'contentHash',
          'tags',
          'externalMappings',
        },
      );
      _nullableIdentifier(fields, 'articleId');
      _boundedString(fields, 'title', maximum: 2048);
      _publicHttpUri(_string(fields, 'originalUrl'), 'originalUrl');
      _boundedString(fields, 'contentHash', maximum: 256);
      final tags = fields['tags'];
      if (tags is! List<Object?> ||
          tags.length > 100 ||
          tags.any(
            (tag) => tag is! String || tag.isEmpty || tag.length > 128,
          )) {
        throw const SyncPayloadException(SyncPayloadFailureCode.invalidShape);
      }
      final mappings = fields['externalMappings'];
      if (mappings is! Map<Object?, Object?> ||
          mappings.length > 32 ||
          mappings.entries.any(
            (entry) =>
                entry.key is! String ||
                (entry.key! as String).isEmpty ||
                (entry.key! as String).length > 64 ||
                entry.value is! String ||
                (entry.value! as String).isEmpty ||
                (entry.value! as String).length > 512,
          )) {
        throw const SyncPayloadException(SyncPayloadFailureCode.invalidShape);
      }
  }
}

void _requireKeys(Map<String, Object?> fields, Set<String> expected) {
  if (fields.length != expected.length ||
      !fields.keys.toSet().containsAll(expected)) {
    throw const SyncPayloadException(SyncPayloadFailureCode.invalidShape);
  }
}

String _string(Map<String, Object?> fields, String key) {
  final value = fields[key];
  if (value is! String || value.isEmpty) {
    throw const SyncPayloadException(SyncPayloadFailureCode.invalidShape);
  }
  return value;
}

void _boundedString(
  Map<String, Object?> fields,
  String key, {
  required int maximum,
}) {
  final value = _string(fields, key);
  if (value.length > maximum || value.trim() != value) {
    throw const SyncPayloadException(SyncPayloadFailureCode.invalidShape);
  }
}

void _nullableBoundedString(
  Map<String, Object?> fields,
  String key, {
  required int maximum,
}) {
  final value = fields[key];
  if (value == null) return;
  if (value is! String ||
      value.isEmpty ||
      value.length > maximum ||
      value.trim() != value) {
    throw const SyncPayloadException(SyncPayloadFailureCode.invalidShape);
  }
}

void _boolean(Map<String, Object?> fields, String key) {
  if (fields[key] is! bool) {
    throw const SyncPayloadException(SyncPayloadFailureCode.invalidShape);
  }
}

int _nonNegativeInteger(Map<String, Object?> fields, String key) {
  final value = fields[key];
  if (value is! int || value < 0) {
    throw const SyncPayloadException(SyncPayloadFailureCode.invalidShape);
  }
  return value;
}

void _nullableNonNegativeInteger(Map<String, Object?> fields, String key) {
  if (fields[key] == null) return;
  _nonNegativeInteger(fields, key);
}

double _finiteDouble(Map<String, Object?> fields, String key) {
  final value = fields[key];
  if (value is! num || !value.isFinite) {
    throw const SyncPayloadException(SyncPayloadFailureCode.invalidShape);
  }
  return value.toDouble();
}

void _boundedDouble(
  Map<String, Object?> fields,
  String key, {
  required double minimum,
  required double maximum,
}) {
  final value = _finiteDouble(fields, key);
  if (value < minimum || value > maximum) {
    throw const SyncPayloadException(SyncPayloadFailureCode.invalidShape);
  }
}

void _nullableIdentifier(Map<String, Object?> fields, String key) {
  final value = fields[key];
  if (value == null) return;
  if (value is! String) {
    throw const SyncPayloadException(SyncPayloadFailureCode.invalidShape);
  }
  _requireIdentifier(value, key);
}

void _nullableUtcTimestamp(Map<String, Object?> fields, String key) {
  final value = fields[key];
  if (value == null) return;
  if (value is! String) {
    throw const SyncPayloadException(SyncPayloadFailureCode.invalidShape);
  }
  try {
    _requireUtc(DateTime.parse(value), key);
  } on SyncPayloadException {
    rethrow;
  } on Object {
    throw const SyncPayloadException(SyncPayloadFailureCode.invalidShape);
  }
}

void _publicHttpUri(String value, String name) {
  final uri = Uri.tryParse(value);
  if (uri == null ||
      !uri.hasAuthority ||
      !const <String>{'http', 'https'}.contains(uri.scheme) ||
      uri.userInfo.isNotEmpty ||
      uri.host.isEmpty) {
    throw ArgumentError.value(value, name, 'Must be a public HTTP(S) URI.');
  }
}

void _requireIdentifier(String value, String name) {
  if (value.isEmpty || value.trim() != value || value.length > 256) {
    throw ArgumentError.value(value, name, 'Invalid identifier.');
  }
}

void _requireUtc(DateTime value, String name) {
  if (!value.isUtc) {
    throw const SyncPayloadException(SyncPayloadFailureCode.invalidShape);
  }
}
