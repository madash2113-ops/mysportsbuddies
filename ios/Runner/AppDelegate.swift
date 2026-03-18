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
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)

    // Must call AFTER super so Flutter engine is fully initialized.
    // Registers for APNs so Firebase Auth can use silent push to verify
    // the device — bypasses the reCAPTCHA web-view entirely.
    application.registerForRemoteNotifications()

    return result
  }

  // Pass the APNs device token to Firebase Auth.
  // Without this, Firebase falls back to reCAPTCHA for every phone sign-in.
  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    #if DEBUG
    Auth.auth().setAPNSToken(deviceToken, type: .sandbox)
    #else
    Auth.auth().setAPNSToken(deviceToken, type: .prod)
    #endif
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  // Called when APNs registration fails — log the reason so it is visible
  // in the Xcode console. Most common cause: Push Notifications capability
  // not enabled for this App ID in Apple Developer Portal.
  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    print("⚠️ APNs registration failed — Firebase phone auth will use reCAPTCHA fallback.")
    print("   Error: \(error.localizedDescription)")
    print("   Fix: enable Push Notifications for App ID com.mysportsbuddies.app in")
    print("   developer.apple.com → Identifiers → com.mysportsbuddies.app → Push Notifications")
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
  }

  // Firebase Auth sends a silent push to this device to prove it is real.
  override func application(
    _ application: UIApplication,
    didReceiveRemoteNotification userInfo: [AnyHashable: Any],
    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
  ) {
    if Auth.auth().canHandleNotification(userInfo) {
      completionHandler(.noData)
      return
    }
    super.application(application, didReceiveRemoteNotification: userInfo,
                      fetchCompletionHandler: completionHandler)
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
