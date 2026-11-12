import Flutter
import UIKit
import WidgetKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let anniversaryNotifications = AnniversaryNotifications()
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    if notification.request.identifier.hasPrefix("ourspace.anniversary.") {
      if #available(iOS 14.0, *) { completionHandler([.banner, .sound]) }
      else { completionHandler([.alert, .sound]) }
      return
    }
    super.userNotificationCenter(center, willPresent: notification, withCompletionHandler: completionHandler)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let anniversaryChannel = FlutterMethodChannel(
      name: "com.ourspace.mobile/anniversary",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    anniversaryChannel.setMethodCallHandler { [weak self] call, result in
      self?.anniversaryNotifications.handle(call, result: result)
    }
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
            WidgetCenter.shared.reloadAllTimelines()
          }
          result(nil)
        case "clear":
          try? FileManager.default.removeItem(at: fileURL)
          if #available(iOS 14.0, *) {
            WidgetCenter.shared.reloadAllTimelines()
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

/// Local reminders only. Uses a dedicated namespace so photo/push requests survive.
/// All state and async completions are serialized on the main queue. Generation
/// checks prevent a delayed permission/add callback from rescheduling after logout.
private final class AnniversaryNotifications {
  private let center = UNUserNotificationCenter.current()
  private let defaults = UserDefaults.standard
  private let key = "ourspace.anniversary."
  private var generation = 0

  private func cancel() {
    let identifiers = defaults.stringArray(forKey: key + "requests") ?? []
    center.removePendingNotificationRequests(withIdentifiers: identifiers)
    center.removeDeliveredNotifications(withIdentifiers: identifiers)
    defaults.removeObject(forKey: key + "requests")
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    generation += 1
    let current = generation
    if call.method == "clear" {
      cancel()
      defaults.removeObject(forKey: key + "couple")
      defaults.set(false, forKey: key + "enabled")
      result(nil)
      return
    }
    guard call.method == "sync" else { result(FlutterMethodNotImplemented); return }
    guard let args = call.arguments as? [String: Any],
          let couple = args["coupleId"] as? String else {
      result(FlutterError(code: "INVALID_REMINDER", message: "Missing couple", details: nil)); return
    }
    if defaults.string(forKey: key + "couple") != couple {
      cancel()
      defaults.set(false, forKey: key + "enabled")
      defaults.set(couple, forKey: key + "couple")
    }
    let explicit = args["enabled"] as? Bool
    if explicit == false {
      cancel(); defaults.set(false, forKey: key + "enabled"); result("disabled"); return
    }
    guard let civil = args["anniversaryDate"] as? String else {
      cancel(); defaults.set(false, forKey: key + "enabled"); result("disabled"); return
    }
    guard explicit == true || defaults.bool(forKey: key + "enabled") else {
      result("disabled"); return
    }
    let complete: (Bool) -> Void = { granted in
      DispatchQueue.main.async {
        guard current == self.generation else { result("disabled"); return }
        guard granted else {
          self.cancel(); self.defaults.set(false, forKey: self.key + "enabled")
          result("denied"); return
        }
        self.schedule(civil, generation: current, result: result)
      }
    }
    if explicit == true {
      center.requestAuthorization(options: [.alert, .sound]) { granted, _ in complete(granted) }
    } else {
      center.getNotificationSettings { settings in
        complete(settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional)
      }
    }
  }

  private func schedule(_ civil: String, generation current: Int, result: @escaping FlutterResult) {
    let parts = civil.split(separator: "-").compactMap { Int($0) }
    guard parts.count == 3 else {
      result(FlutterError(code: "INVALID_REMINDER", message: "Invalid civil date", details: nil)); return
    }
    // No pinned timezone: delivery follows the device's civil clock, even after travel.
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .autoupdatingCurrent
    let now = Date()
    let currentYear = calendar.component(.year, from: now)
    var requests: [UNNotificationRequest] = []
    for year in max(currentYear, parts[0] + 1)...(max(currentYear, parts[0] + 1) + 8) {
      let leap = year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)
      let day = parts[1] == 2 && parts[2] == 29 && !leap ? 28 : parts[2]
      var components = DateComponents()
      components.calendar = calendar
      components.year = year; components.month = parts[1]; components.day = day
      components.hour = 9; components.minute = 0
      guard let fire = calendar.date(from: components), fire > now else { continue }
      let content = UNMutableNotificationContent()
      content.title = "OurSpace · Ngày kỷ niệm"
      content.body = "Hôm nay là ngày kỷ niệm của hai bạn. Mở OurSpace để xem lịch chung."
      content.sound = .default
      let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
      requests.append(UNNotificationRequest(identifier: "ourspace.anniversary.\(UUID().uuidString)", content: content, trigger: trigger))
      if requests.count == 8 { break }
    }
    cancel()
    defaults.set(requests.map { $0.identifier }, forKey: key + "requests")
    defaults.set(false, forKey: key + "enabled")
    func add(_ index: Int) {
      guard current == self.generation else { result("disabled"); return }
      if index == requests.count {
        self.defaults.set(true, forKey: self.key + "enabled"); result("enabled"); return
      }
      self.center.add(requests[index]) { error in
        DispatchQueue.main.async {
          guard current == self.generation else {
            // This add may finish after logout. Unique IDs prevent removing a
            // different account's replacement schedule while cleaning it up.
            self.center.removePendingNotificationRequests(withIdentifiers: [requests[index].identifier])
            self.center.removeDeliveredNotifications(withIdentifiers: [requests[index].identifier])
            result("disabled"); return
          }
          if error != nil {
            self.cancel()
            result(FlutterError(code: "REMINDER_SCHEDULE_FAILED", message: "Cannot schedule reminder", details: nil))
          } else { add(index + 1) }
        }
      }
    }
    add(0)
  }
}
