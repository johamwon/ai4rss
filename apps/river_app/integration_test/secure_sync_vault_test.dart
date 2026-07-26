import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:river_platform/river_platform.dart';
import 'package:river_sync/river_sync.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('real platform secure storage round trips sync secrets',
      (tester) async {
    final vault = PlatformSecureSyncVault.standard();
    const deviceKeyId = 'integration-device-key';
    const dataKeyId = 'integration-data-key';
    await vault.clear();
    await vault.deleteDeviceKey(deviceKeyId);
    await vault.deleteDataKey(dataKeyId);

    final session = SyncSession(
      id: 'integration-session',
      accountId: 'integration-account',
      deviceId: 'integration-device',
      accessToken: OpaqueSyncToken('integration-access-token'),
      refreshToken: OpaqueSyncToken('integration-refresh-token'),
      issuedAt: DateTime.utc(2026, 7, 27),
      expiresAt: DateTime.utc(2026, 7, 27, 1),
      deviceStatus: SyncDeviceStatus.active,
    );
    final deviceKey = SyncDeviceKeyMaterial(
      keyId: deviceKeyId,
      privateKeyBytes: List<int>.filled(32, 21),
      publicKeyBytes: List<int>.filled(32, 22),
    );
    final dataKey = SyncDataKeyMaterial(
      descriptor: SyncDataKeyDescriptor(
        id: dataKeyId,
        accountId: session.accountId,
        version: 1,
        createdAt: DateTime.utc(2026, 7, 27),
      ),
      keyBytes: List<int>.filled(32, 23),
    );

    try {
      await vault.write(session);
      await vault.writeDeviceKey(deviceKey);
      await vault.writeDataKey(dataKey);

      expect((await vault.read())?.deviceId, session.deviceId);
      expect(
        (await vault.readDeviceKey(deviceKeyId))?.publicKeyBase64,
        base64.encode(List<int>.filled(32, 22)),
      );
      expect(
        (await vault.readDataKey(dataKeyId))?.exportKeyBase64(),
        dataKey.exportKeyBase64(),
      );
    } finally {
      await vault.clear();
      await vault.deleteDeviceKey(deviceKeyId);
      await vault.deleteDataKey(dataKeyId);
    }
  });
}
