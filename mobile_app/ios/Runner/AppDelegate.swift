import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "easychat/managed_file_store",
        binaryMessenger: controller.binaryMessenger
      )

      channel.setMethodCallHandler { call, result in
        if call.method != "excludeFromBackup" {
          result(FlutterMethodNotImplemented)
          return
        }

        guard
          let arguments = call.arguments as? [String: Any],
          let path = arguments["path"] as? String
        else {
          result(
            FlutterError(
              code: "invalid_arguments",
              message: "Missing path argument",
              details: nil
            )
          )
          return
        }

        do {
          var url = URL(fileURLWithPath: path)
          var values = URLResourceValues()
          values.isExcludedFromBackup = true
          try url.setResourceValues(values)
          result(true)
        } catch {
          result(
            FlutterError(
              code: "exclude_failed",
              message: "Failed to exclude path from backup",
              details: error.localizedDescription
            )
          )
        }
      }
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
