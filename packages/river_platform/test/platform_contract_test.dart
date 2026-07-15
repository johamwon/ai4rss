import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:river_platform/river_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('platform bridge keeps a stable Dart contract', () async {
    const channel = MethodChannel('app.river/test-platform');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'platformVersion');
      return 'test-os';
    });

    final bridge = MethodChannelRiverPlatform(channel: channel);
    expect(await bridge.platformVersion(), 'test-os');
  });
}
