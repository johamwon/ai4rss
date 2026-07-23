import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:river_platform/river_platform.dart';

void main() {
  test('Android release manifest permits feed network access', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

    expect(
      manifest,
      contains('android.permission.INTERNET'),
    );
  });

  test('iOS registers the same permitted background task identifier', () {
    final appDelegate = File('ios/Runner/AppDelegate.swift').readAsStringSync();
    final infoPlist = File('ios/Runner/Info.plist').readAsStringSync();

    expect(appDelegate, contains(riverBackgroundRefreshIdentifier));
    expect(infoPlist, contains(riverBackgroundRefreshIdentifier));
    expect(infoPlist, contains('BGTaskSchedulerPermittedIdentifiers'));
    expect(infoPlist, contains('<string>fetch</string>'));
  });
}
