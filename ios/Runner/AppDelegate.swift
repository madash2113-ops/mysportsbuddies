import Flutter
import UIKit
import FirebaseAuth
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Register for remote notifications so Firebase Auth can use APNs silent
    // push to verify the device — this bypasses the reCAPTCHA web-view entirely.
    // Firebase Auth intercepts the silent push internally; no visible notification
    // is shown to the user.
    UNUserNotificationCenter.current().delegate = self
    application.registerForRemoteNotifications()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Pass the APNs device token to Firebase Auth.
  // Without this, Firebase falls back to reCAPTCHA for every phone sign-in.
  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    Auth.auth().setAPNSToken(deviceToken, type: .unknown)
  }

  // Firebase Auth sends a silent push to this device to prove it is real.
  // Return true when Firebase handled it so no other code processes it.
  override func application(
    _ application: UIApplication,
    didReceiveRemoteNotification userInfo: [AnyHashable: Any],
    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
  ) {
    if Auth.auth().canHandleNotification(userInfo) {
      completionHandler(.noData)
      return
    }
    completionHandler(.noData)
  }

  // Handle reCAPTCHA redirect URL (fallback when APNs is unavailable).
  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    if Auth.auth().canHandle(url) { return true }
    return super.application(app, open: url, options: options)
  }
}
