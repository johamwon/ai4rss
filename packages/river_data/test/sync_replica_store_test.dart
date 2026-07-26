import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:river_data/river_data.dart';
import 'package:river_sync/river_sync.dart';
import 'package:test/test.dart';

void main() {
  test(
    'local record, encrypted outbox, and cursor survive database restart',
    () async {
      final directory = await Directory.systemTemp.createTemp('river-sync-');
      final file = File('${directory.path}${Platform.pathSeparator}sync.db');
      addTearDown(() async {
        if (directory.existsSync()) await directory.delete(recursive: true);
      });
      final record = _record(
        deviceId: 'device-a',
        mutationId: 'mutation-a-1',
        objectId: 'subscription-1',
        counter: 1,
      );
      var database = RiverDatabase(NativeDatabase(file));
      var store = _store(database, 'device-a');
      await store.commitLocal(record);
      await database.close();

      database = RiverDatabase(NativeDatabase(file));
      addTearDown(database.close);
      store = _store(database, 'device-a');

      expect(
        (await store.readRecord(
          SyncObjectKind.subscription,
          record.envelope.objectId,
        ))?.envelope.mutationId,
        record.envelope.mutationId,
      );
      expect(
        (await store.readOutbox(limit: 10)).single.mutationId,
        record.envelope.mutationId,
      );
      expect((await store.readCursor()).serverSequence, 0);

      await store.acknowledgeOutbox(<String>{record.envelope.mutationId});
      expect(await store.readOutbox(limit: 10), isEmpty);
    },
  );

  test(
    'remote page atomically accepts records, conflicts, and cursor',
    () async {
      final database = RiverDatabase.inMemory();
      addTearDown(database.close);
      final store = _store(database, 'device-a');
      final accepted = _record(
        deviceId: 'device-b',
        mutationId: 'mutation-b-1',
        objectId: 'subscription-1',
        counter: 1,
      );
      final conflict = _record(
        deviceId: 'device-b',
        mutationId: 'mutation-b-2',
        objectId: 'subscription-2',
        counter: 2,
      );
      final next = SyncCursor(serverSequence: 2, opaqueToken: 'cursor-2');

      await store.commitRemotePage(
        expectedCursor: SyncCursor.initial(),
        nextCursor: next,
        records: <SyncIncomingRecord>[
          SyncIncomingRecord(
            record: accepted,
            action: SyncIncomingAction.accept,
          ),
          SyncIncomingRecord(
            record: conflict,
            action: SyncIncomingAction.conflict,
          ),
        ],
      );

      expect(
        await store.readRecord(
          accepted.envelope.objectKind,
          accepted.envelope.objectId,
        ),
        isNotNull,
      );
      expect(
        await store.readRecord(
          conflict.envelope.objectKind,
          conflict.envelope.objectId,
        ),
        isNull,
      );
      expect((await store.readCursor()).serverSequence, 2);
      expect(
        await database.select(database.syncConflictRows).get(),
        hasLength(1),
      );

      final rejected = _record(
        deviceId: 'device-b',
        mutationId: 'mutation-b-3',
        objectId: 'subscription-3',
        counter: 3,
      );
      await expectLater(
        store.commitRemotePage(
          expectedCursor: SyncCursor.initial(),
          nextCursor: SyncCursor(serverSequence: 3, opaqueToken: 'cursor-3'),
          records: <SyncIncomingRecord>[
            SyncIncomingRecord(
              record: rejected,
              action: SyncIncomingAction.accept,
            ),
          ],
        ),
        throwsStateError,
      );
      expect(
        await store.readRecord(
          rejected.envelope.objectKind,
          rejected.envelope.objectId,
        ),
        isNull,
      );
      expect((await store.readCursor()).serverSequence, 2);
    },
  );

  test('outbox acknowledgement is scoped to account and device', () async {
    final database = RiverDatabase.inMemory();
    addTearDown(database.close);
    final storeA = _store(database, 'device-a');
    final storeB = _store(database, 'device-b');
    final recordA = _record(
      deviceId: 'device-a',
      mutationId: 'mutation-a-1',
      objectId: 'subscription-a',
      counter: 1,
    );
    final recordB = _record(
      deviceId: 'device-b',
      mutationId: 'mutation-b-1',
      objectId: 'subscription-b',
      counter: 1,
    );
    await storeA.commitLocal(recordA);
    await storeB.commitLocal(recordB);

    await storeA.acknowledgeOutbox(<String>{recordB.envelope.mutationId});

    expect(await storeA.readOutbox(limit: 10), hasLength(1));
    expect(await storeB.readOutbox(limit: 10), hasLength(1));
  });
}

DriftSyncReplicaStore _store(RiverDatabase database, String deviceId) =>
    DriftSyncReplicaStore(
      database: database,
      accountId: 'account-1',
      deviceId: deviceId,
      clock: () => DateTime.utc(2026, 7, 27, 5),
    );

SyncReplicaRecord _record({
  required String deviceId,
  required String mutationId,
  required String objectId,
  required int counter,
}) {
  final payload = SyncObjectPayload.subscription(
    objectId: objectId,
    canonicalUrl: 'https://example.com/$objectId.xml',
    title: objectId,
    enabled: true,
  );
  return SyncReplicaRecord(
    envelope: EncryptedSyncEnvelope(
      mutationId: mutationId,
      accountId: 'account-1',
      objectKind: payload.objectKind,
      objectId: payload.objectId,
      payloadKind: SyncPayloadKind.upsert,
      dataKeyId: 'data-key-1',
      authorDeviceId: deviceId,
      versionVector: VersionVector(<String, int>{deviceId: counter}),
      occurredAt: DateTime.utc(2026, 7, 27, 5, counter),
      nonceBase64: _bytes(12, counter),
      ciphertextBase64: _bytes(32, counter + 1),
      authenticationTagBase64: _bytes(16, counter + 2),
    ),
    decodedPayload: DecodedSyncUpsert(payload),
  );
}

String _bytes(int count, int seed) =>
    base64.encode(List<int>.generate(count, (index) => (index + seed) % 251));
