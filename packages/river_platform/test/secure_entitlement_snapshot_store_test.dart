import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:river_commerce/river_commerce.dart';
import 'package:river_platform/river_platform.dart';

void main() {
  test('secure entitlement snapshot round trips and clears', () async {
    final store = _MemorySecureStore();
    final cache = PlatformSecureEntitlementSnapshotStore(store: store);
    final snapshot = _snapshot();

    await cache.write(snapshot);
    final restored = await cache.read();

    expect(restored?.canonicalPayload, snapshot.canonicalPayload);
    expect(restored?.signature, snapshot.signature);
    expect(store.values.values.single, contains('managedAi'));
    expect(store.values.values.single, contains('signature'));
    await cache.clear();
    expect(await cache.read(), isNull);
  });

  test('unsupported and corrupt cache values fail without silent deletion',
      () async {
    final store = _MemorySecureStore();
    final cache = PlatformSecureEntitlementSnapshotStore(store: store);

    store.values[_storageKey] = '{"schema":99}';
    await expectLater(
      cache.read(),
      throwsA(
        isA<SecureEntitlementStoreException>().having(
          (error) => error.code,
          'code',
          SecureEntitlementStoreFailureCode.unsupportedSchema,
        ),
      ),
    );
    expect(store.values, isNotEmpty);

    store.values[_storageKey] = '{"schema":1,"revision":"bad"}';
    await expectLater(
      cache.read(),
      throwsA(
        isA<SecureEntitlementStoreException>().having(
          (error) => error.code,
          'code',
          SecureEntitlementStoreFailureCode.corruptValue,
        ),
      ),
    );
    expect(store.values, isNotEmpty);
  });

  test('secure storage operations remain serialized after failure', () async {
    final store = _MemorySecureStore(delay: const Duration(milliseconds: 5));
    final cache = PlatformSecureEntitlementSnapshotStore(store: store);
    store.values[_storageKey] = '{"schema":99}';

    await expectLater(
      cache.read(),
      throwsA(isA<SecureEntitlementStoreException>()),
    );
    await cache.write(_snapshot());
    expect((await cache.read())?.revision, 1);
    expect(store.maxActive, 1);
  });

  test('Ed25519 verifier accepts exact payload and rejects mutation', () async {
    final algorithm = Ed25519();
    final keyPair = await algorithm.newKeyPair();
    final publicKey = await keyPair.extractPublicKey();
    final unsigned = _snapshot(signature: 'placeholder');
    final signature = await algorithm.sign(
      utf8.encode(unsigned.canonicalPayload),
      keyPair: keyPair,
    );
    final verifier = Ed25519EntitlementSnapshotVerifier(
      publicKeyBytes: publicKey.bytes,
    );
    final encoded = base64Url.encode(signature.bytes).replaceAll('=', '');

    expect(await verifier.verify(unsigned.canonicalPayload, encoded), isTrue);
    expect(
      await verifier.verify('${unsigned.canonicalPayload} ', encoded),
      isFalse,
    );
    expect(await verifier.verify(unsigned.canonicalPayload, 'forged'), isFalse);
  });
}

const _storageKey = 'river.commerce.v1.entitlements';

EntitlementSnapshot _snapshot({String signature = 'signed-proof'}) =>
    EntitlementSnapshot(
      revision: 1,
      subjectHash:
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      plan: EntitlementPlan.pro,
      granted: const <EntitlementKey>{
        EntitlementKey.managedAi,
        EntitlementKey.cloudTts,
      },
      issuedAt: DateTime.utc(2026, 8, 6, 10),
      refreshAfter: DateTime.utc(2026, 8, 6, 18),
      validUntil: DateTime.utc(2026, 8, 7, 10),
      signature: signature,
    );

final class _MemorySecureStore implements SecureKeyValueStore {
  _MemorySecureStore({this.delay = Duration.zero});

  final Duration delay;
  final Map<String, String> values = <String, String>{};
  int active = 0;
  int maxActive = 0;

  @override
  Future<void> delete(String key) => _run(() => values.remove(key));

  @override
  Future<String?> read(String key) => _run(() => values[key]);

  @override
  Future<void> write(String key, String value) =>
      _run(() => values[key] = value);

  Future<T> _run<T>(T Function() operation) async {
    active += 1;
    if (active > maxActive) maxActive = active;
    try {
      if (delay > Duration.zero) await Future<void>.delayed(delay);
      return operation();
    } finally {
      active -= 1;
    }
  }
}
