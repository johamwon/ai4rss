import Flutter
import UIKit
import workmanager_apple

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  static let backgroundFeedRefreshIdentifier = "com.example.riverApp.backgroundFeedRefresh"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    WorkmanagerPlugin.registerPeriodicTask(
      withIdentifier: Self.backgroundFeedRefreshIdentifier,
      frequency: NSNumber(value: 60 * 60)
    )
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
