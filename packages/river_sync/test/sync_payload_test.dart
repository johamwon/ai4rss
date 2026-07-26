import 'dart:convert';

import 'package:river_sync/river_sync.dart';
import 'package:test/test.dart';

void main() {
  test('six bounded payload kinds round trip without article bodies', () {
    final payloads = <SyncObjectPayload>[
      SyncObjectPayload.subscription(
        objectId: 'subscription-1',
        canonicalUrl: 'https://example.com/feed.xml',
        title: 'Example',
        enabled: true,
        folderId: 'folder-1',
      ),
      SyncObjectPayload.folder(
        objectId: 'folder-1',
        name: 'Technology',
        position: 2,
      ),
      SyncObjectPayload.articleState(
        objectId: 'article-1',
        read: true,
        starred: true,
        readLater: false,
        activeReadSeconds: 42,
        scrollDepth: 0.91,
        completedAt: DateTime.utc(2026, 7, 27),
      ),
      SyncObjectPayload.readerSettings(
        objectId: 'reader-settings',
        fontFamily: 'serif',
        fontScale: 1.2,
        lineHeight: 1.8,
        contentWidth: 760,
        theme: 'dark',
      ),
      SyncObjectPayload.audioProgress(
        objectId: 'audio-1',
        itemKind: 'articleTts',
        positionMs: 32000,
        segmentIndex: 4,
        characterOffset: 280,
        contentRevision: 'sha256:revision',
        durationMs: 120000,
      ),
      SyncObjectPayload.knowledgeMetadata(
        objectId: 'knowledge-1',
        articleId: 'article-1',
        title: 'A note',
        originalUrl: 'https://example.com/articles/1',
        contentHash: 'sha256:content',
        tags: const <String>['rss', 'ai'],
        externalMappings: const <String, String>{
          'notion': 'page-1',
          'ima': 'document-1',
        },
      ),
    ];

    for (final payload in payloads) {
      final encoded = SyncPayloadCodec.encodeUpsert(payload);
      final decoded = SyncPayloadCodec.decode(encoded) as DecodedSyncUpsert;

      expect(decoded.payload.objectKind, payload.objectKind);
      expect(decoded.payload.objectId, payload.objectId);
      expect(decoded.payload.fields, payload.fields);
      expect(utf8.decode(encoded), isNot(contains('article body')));
      expect(encoded.length, lessThan(SyncPayloadCodec.maximumClearTextBytes));
    }
  });

  test('tombstone body round trips author and UTC deletion time', () {
    final body = SyncTombstoneBody(
      objectKind: SyncObjectKind.subscription,
      objectId: 'subscription-1',
      deletedAt: DateTime.utc(2026, 7, 27, 2),
      deletedByDeviceId: 'device-a',
    );

    final decoded = SyncPayloadCodec.decode(
      SyncPayloadCodec.encodeTombstone(body),
    ) as DecodedSyncTombstone;

    expect(decoded.tombstone.objectKind, body.objectKind);
    expect(decoded.tombstone.objectId, body.objectId);
    expect(decoded.tombstone.deletedAt, body.deletedAt);
    expect(decoded.tombstone.deletedByDeviceId, body.deletedByDeviceId);
  });

  test('field versions round trip while legacy upserts remain readable', () {
    final updatedAt = DateTime.utc(2026, 7, 27, 3);
    final payload = SyncObjectPayload.folder(
      objectId: 'folder-1',
      name: 'Saved',
      position: 1,
    ).withFieldVersions(<String, SyncFieldVersion>{
      'name': SyncFieldVersion(
        updatedAt: updatedAt,
        deviceId: 'device-a',
        mutationId: 'mutation-a-1',
      ),
    });

    final decoded = SyncPayloadCodec.decode(
      SyncPayloadCodec.encodeUpsert(payload),
    ) as DecodedSyncUpsert;
    expect(decoded.payload.fieldVersions['name']?.updatedAt, updatedAt);

    final legacy = SyncPayloadCodec.decode(
      utf8.encode(
        jsonEncode(<String, Object?>{
          'schema': 1,
          'payloadKind': 'upsert',
          'objectKind': 'folder',
          'objectId': 'folder-legacy',
          'fields': <String, Object?>{
            'name': 'Legacy',
            'position': 0,
            'parentId': null,
          },
        }),
      ),
    ) as DecodedSyncUpsert;
    expect(legacy.payload.fields['name'], 'Legacy');
    expect(legacy.payload.fieldVersions, isEmpty);
  });

  test('invalid schema, extra fields, ranges, and local URLs fail closed', () {
    expect(
      () => SyncPayloadCodec.decode(utf8.encode('{"schema":99}')),
      throwsA(
        isA<SyncPayloadException>().having(
          (error) => error.code,
          'code',
          SyncPayloadFailureCode.unsupportedSchema,
        ),
      ),
    );
    expect(
      () => SyncPayloadCodec.decode(
        utf8.encode(
          jsonEncode(<String, Object?>{
            'schema': 1,
            'payloadKind': 'upsert',
            'objectKind': 'folder',
            'objectId': 'folder-1',
            'fields': <String, Object?>{
              'name': 'Folder',
              'position': 0,
              'parentId': null,
              'unexpected': true,
            },
          }),
        ),
      ),
      throwsA(isA<SyncPayloadException>()),
    );
    expect(
      () => SyncObjectPayload.articleState(
        objectId: 'article-1',
        read: false,
        starred: false,
        readLater: false,
        activeReadSeconds: 0,
        scrollDepth: 1.1,
      ),
      throwsA(isA<SyncPayloadException>()),
    );
    expect(
      () => SyncObjectPayload.subscription(
        objectId: 'subscription-1',
        canonicalUrl: 'file:///private/feed.xml',
        title: 'Local',
        enabled: true,
      ),
      throwsArgumentError,
    );
  });

  test('payload fields are defensive immutable copies', () {
    final tags = <String>['first'];
    final mappings = <String, String>{'notion': 'page-1'};
    final payload = SyncObjectPayload.knowledgeMetadata(
      objectId: 'knowledge-1',
      title: 'Note',
      originalUrl: 'https://example.com/note',
      contentHash: 'hash',
      tags: tags,
      externalMappings: mappings,
    );
    tags.add('second');
    mappings['notion'] = 'changed';

    expect(payload.fields['tags'], const <String>['first']);
    expect(
      payload.fields['externalMappings'],
      const <String, String>{'notion': 'page-1'},
    );
    expect(
      () => (payload.fields['tags']! as List<Object?>).add('blocked'),
      throwsUnsupportedError,
    );
  });
}
