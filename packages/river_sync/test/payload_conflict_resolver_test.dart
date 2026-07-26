import 'dart:convert';

import 'package:river_sync/river_sync.dart';
import 'package:test/test.dart';

void main() {
  const resolver = SyncPayloadConflictResolver();

  test('independent subscription field edits merge deterministically', () {
    final base = DateTime.utc(2026, 7, 27);
    final local = SyncObjectPayload.subscription(
      objectId: 'feed-1',
      canonicalUrl: 'https://example.com/feed.xml',
      title: 'Local title',
      enabled: true,
    ).withFieldVersions(<String, SyncFieldVersion>{
      'title': _version(base.add(const Duration(minutes: 2)), 'device-a', 'a2'),
      'enabled': _version(base, 'device-a', 'a1'),
    });
    final remote = SyncObjectPayload.subscription(
      objectId: 'feed-1',
      canonicalUrl: 'https://example.com/feed.xml',
      title: 'Original',
      enabled: false,
    ).withFieldVersions(<String, SyncFieldVersion>{
      'title': _version(base, 'device-b', 'b1'),
      'enabled':
          _version(base.add(const Duration(minutes: 3)), 'device-b', 'b2'),
    });

    final result = resolver.resolve(
      localEnvelope: _envelope(local, 'device-a', 'a2'),
      localPayload: DecodedSyncUpsert(local),
      remoteEnvelope: _envelope(remote, 'device-b', 'b2'),
      remotePayload: DecodedSyncUpsert(remote),
    );

    expect(result.kind, SyncConflictResolutionKind.merged);
    final merged = (result.mergedPayload! as DecodedSyncUpsert).payload;
    expect(merged.fields['title'], 'Local title');
    expect(merged.fields['enabled'], isFalse);
  });

  test('field ties use device, mutation, then canonical value', () {
    final time = DateTime.utc(2026, 7, 27);
    final local = _folder('Alpha').withFieldVersions(<String, SyncFieldVersion>{
      'name': _version(time, 'device-a', 'same'),
    });
    final remote = _folder('Beta').withFieldVersions(<String, SyncFieldVersion>{
      'name': _version(time, 'device-b', 'same'),
    });

    final result = resolver.resolve(
      localEnvelope: _envelope(local, 'device-a', 'a1'),
      localPayload: DecodedSyncUpsert(local),
      remoteEnvelope: _envelope(remote, 'device-b', 'b1'),
      remotePayload: DecodedSyncUpsert(remote),
    );

    expect(result.kind, SyncConflictResolutionKind.merged);
    expect(
      (result.mergedPayload! as DecodedSyncUpsert).payload.fields['name'],
      'Beta',
    );
  });

  test('article state preserves semantic reading progress', () {
    final local = SyncObjectPayload.articleState(
      objectId: 'article-1',
      read: true,
      starred: false,
      readLater: true,
      activeReadSeconds: 15,
      scrollDepth: 0.4,
      completedAt: DateTime.utc(2026, 7, 27, 1),
    );
    final remote = SyncObjectPayload.articleState(
      objectId: 'article-1',
      read: false,
      starred: true,
      readLater: false,
      activeReadSeconds: 42,
      scrollDepth: 0.9,
      completedAt: DateTime.utc(2026, 7, 27, 2),
    );

    final result = resolver.resolve(
      localEnvelope: _envelope(local, 'device-a', 'a1'),
      localPayload: DecodedSyncUpsert(local),
      remoteEnvelope: _envelope(remote, 'device-b', 'b1'),
      remotePayload: DecodedSyncUpsert(remote),
    );

    final fields = (result.mergedPayload! as DecodedSyncUpsert).payload.fields;
    expect(fields['read'], isTrue);
    expect(fields['activeReadSeconds'], 42);
    expect(fields['scrollDepth'], 0.9);
    expect(
      fields['completedAt'],
      DateTime.utc(2026, 7, 27, 2).toIso8601String(),
    );
  });

  test('same audio revision keeps furthest playback point', () {
    final local = _audio(
      revision: 'sha256:r1',
      segment: 2,
      character: 120,
      position: 8000,
    );
    final remote = _audio(
      revision: 'sha256:r1',
      segment: 3,
      character: 10,
      position: 1000,
    );

    final result = resolver.resolve(
      localEnvelope: _envelope(
        local,
        'device-z',
        'z1',
        occurredAt: DateTime.utc(2026, 7, 27, 2),
      ),
      localPayload: DecodedSyncUpsert(local),
      remoteEnvelope: _envelope(
        remote,
        'device-a',
        'a1',
        occurredAt: DateTime.utc(2026, 7, 27, 1),
      ),
      remotePayload: DecodedSyncUpsert(remote),
    );

    expect(result.kind, SyncConflictResolutionKind.remote);
  });

  test('different audio revisions use deterministic record LWW', () {
    final local = _audio(
      revision: 'sha256:old',
      segment: 20,
      character: 0,
      position: 90000,
    );
    final remote = _audio(
      revision: 'sha256:new',
      segment: 0,
      character: 0,
      position: 100,
    );

    final result = resolver.resolve(
      localEnvelope: _envelope(
        local,
        'device-a',
        'a1',
        occurredAt: DateTime.utc(2026, 7, 27, 1),
      ),
      localPayload: DecodedSyncUpsert(local),
      remoteEnvelope: _envelope(
        remote,
        'device-b',
        'b1',
        occurredAt: DateTime.utc(2026, 7, 27, 2),
      ),
      remotePayload: DecodedSyncUpsert(remote),
    );

    expect(result.kind, SyncConflictResolutionKind.remote);
  });

  test('bounded tombstone policies protect deletes and reading state', () {
    final subscription = SyncObjectPayload.subscription(
      objectId: 'feed-1',
      canonicalUrl: 'https://example.com/feed.xml',
      title: 'Feed',
      enabled: true,
    );
    final article = SyncObjectPayload.articleState(
      objectId: 'article-1',
      read: true,
      starred: false,
      readLater: false,
      activeReadSeconds: 1,
      scrollDepth: 0.1,
    );

    expect(
      resolver
          .resolve(
            localEnvelope: _envelope(subscription, 'device-a', 'a1'),
            localPayload: DecodedSyncUpsert(subscription),
            remoteEnvelope: _tombstoneEnvelope(
              SyncObjectKind.subscription,
              'feed-1',
              'device-b',
              'b1',
            ),
            remotePayload: DecodedSyncTombstone(
              SyncTombstoneBody(
                objectKind: SyncObjectKind.subscription,
                objectId: 'feed-1',
                deletedAt: DateTime.utc(2026, 7, 27),
                deletedByDeviceId: 'device-b',
              ),
            ),
          )
          .kind,
      SyncConflictResolutionKind.remote,
    );
    expect(
      resolver
          .resolve(
            localEnvelope: _envelope(article, 'device-a', 'a1'),
            localPayload: DecodedSyncUpsert(article),
            remoteEnvelope: _tombstoneEnvelope(
              SyncObjectKind.articleState,
              'article-1',
              'device-b',
              'b1',
            ),
            remotePayload: DecodedSyncTombstone(
              SyncTombstoneBody(
                objectKind: SyncObjectKind.articleState,
                objectId: 'article-1',
                deletedAt: DateTime.utc(2026, 7, 27),
                deletedByDeviceId: 'device-b',
              ),
            ),
          )
          .kind,
      SyncConflictResolutionKind.local,
    );
  });
}

SyncObjectPayload _folder(String name) => SyncObjectPayload.folder(
      objectId: 'folder-1',
      name: name,
      position: 0,
    );

SyncObjectPayload _audio({
  required String revision,
  required int segment,
  required int character,
  required int position,
}) =>
    SyncObjectPayload.audioProgress(
      objectId: 'audio-1',
      itemKind: 'articleTts',
      positionMs: position,
      segmentIndex: segment,
      characterOffset: character,
      contentRevision: revision,
      durationMs: 100000,
    );

SyncFieldVersion _version(
  DateTime updatedAt,
  String deviceId,
  String mutationId,
) =>
    SyncFieldVersion(
      updatedAt: updatedAt,
      deviceId: deviceId,
      mutationId: mutationId,
    );

EncryptedSyncEnvelope _envelope(
  SyncObjectPayload payload,
  String deviceId,
  String mutationId, {
  DateTime? occurredAt,
}) =>
    EncryptedSyncEnvelope(
      mutationId: mutationId,
      accountId: 'account-1',
      objectKind: payload.objectKind,
      objectId: payload.objectId,
      payloadKind: SyncPayloadKind.upsert,
      dataKeyId: 'key-1',
      authorDeviceId: deviceId,
      versionVector: VersionVector(<String, int>{deviceId: 1}),
      occurredAt: occurredAt ?? DateTime.utc(2026, 7, 27),
      nonceBase64: _bytes(12, 1),
      ciphertextBase64: _bytes(32, 2),
      authenticationTagBase64: _bytes(16, 3),
    );

EncryptedSyncEnvelope _tombstoneEnvelope(
  SyncObjectKind kind,
  String objectId,
  String deviceId,
  String mutationId,
) =>
    EncryptedSyncEnvelope(
      mutationId: mutationId,
      accountId: 'account-1',
      objectKind: kind,
      objectId: objectId,
      payloadKind: SyncPayloadKind.tombstone,
      dataKeyId: 'key-1',
      authorDeviceId: deviceId,
      versionVector: VersionVector(<String, int>{deviceId: 1}),
      occurredAt: DateTime.utc(2026, 7, 27),
      nonceBase64: _bytes(12, 1),
      ciphertextBase64: _bytes(32, 2),
      authenticationTagBase64: _bytes(16, 3),
    );

String _bytes(int count, int seed) =>
    base64.encode(List<int>.generate(count, (index) => (index + seed) % 251));
