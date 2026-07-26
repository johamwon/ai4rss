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

  test('Android registers background media playback and headset controls', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    final activity = File(
      'android/app/src/main/kotlin/com/example/river_app/MainActivity.kt',
    ).readAsStringSync();

    expect(manifest, contains('android.permission.WAKE_LOCK'));
    expect(manifest, contains('android.permission.FOREGROUND_SERVICE'));
    expect(
      manifest,
      contains('android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK'),
    );
    expect(
      manifest,
      contains('com.ryanheise.audioservice.AudioService'),
    );
    expect(
      manifest,
      contains('com.ryanheise.audioservice.MediaButtonReceiver'),
    );
    expect(activity, contains('AudioServiceActivity'));
  });

  test('iOS registers the same permitted background task identifier', () {
    final appDelegate = File('ios/Runner/AppDelegate.swift').readAsStringSync();
    final infoPlist = File('ios/Runner/Info.plist').readAsStringSync();

    expect(appDelegate, contains(riverBackgroundRefreshIdentifier));
    expect(infoPlist, contains(riverBackgroundRefreshIdentifier));
    expect(infoPlist, contains('BGTaskSchedulerPermittedIdentifiers'));
    expect(infoPlist, contains('<string>audio</string>'));
    expect(infoPlist, contains('<string>fetch</string>'));
  });

  test('Windows runner owns a system media transport controls adapter', () {
    final cmake = File('windows/runner/CMakeLists.txt').readAsStringSync();
    final implementation = File(
      'windows/runner/audio_system_session_controls.cpp',
    ).readAsStringSync();
    final flutterWindow =
        File('windows/runner/flutter_window.cpp').readAsStringSync();

    expect(cmake, contains('audio_system_session_controls.cpp'));
    expect(cmake, contains('windowsapp.lib'));
    expect(
      implementation,
      contains('SystemMediaTransportControls'),
    );
    expect(
      implementation,
      contains('app.river/audio_system_session'),
    );
    expect(flutterWindow, contains('HandleWindowMessage'));
  });
}
