import Flutter
import UIKit
import WidgetKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(
      name: "com.ourspace.mobile/widget",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      let appGroup = "group.com.ourspace.mobile"
      let filename = "latest-photo.jpg"
      guard let container = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: appGroup
      ) else {
        result(FlutterError(code: "APP_GROUP_UNAVAILABLE", message: "App Group is unavailable.", details: nil))
        return
      }
      let fileURL = container.appendingPathComponent(filename)
      do {
        switch call.method {
        case "showPhoto":
          guard let bytes = call.arguments as? FlutterStandardTypedData else {
            result(FlutterError(code: "INVALID_IMAGE", message: "Expected image bytes.", details: nil))
            return
          }
          try bytes.data.write(to: fileURL, options: .atomic)
          if #available(iOS 14.0, *) {
            WidgetCenter.shared.reloadTimelines(ofKind: "OurSpaceWidget")
          }
          result(nil)
        case "clear":
          try? FileManager.default.removeItem(at: fileURL)
          if #available(iOS 14.0, *) {
            WidgetCenter.shared.reloadTimelines(ofKind: "OurSpaceWidget")
          }
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      } catch {
        result(FlutterError(code: "WIDGET_WRITE_FAILED", message: error.localizedDescription, details: nil))
      }
    }
  }
}
