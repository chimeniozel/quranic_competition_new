import Flutter
import UIKit
import UserNotifications
import FirebaseCore   // seulement si Firebase
@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Faire de l'AppDelegate le délégué des notifications : il relaie ensuite
    // les événements à firebase_messaging ET à flutter_local_notifications.
    // Sans cela, firebase_messaging devient seul délégué et les notifications
    // locales ne s'affichent pas au premier plan (ni leur clic n'est traité).
    UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Chaque push envoie « badge: 1 » : on remet la pastille à zéro dès que
  // l'utilisateur revient dans l'application, sinon elle ne disparaît jamais.
  override func applicationDidBecomeActive(_ application: UIApplication) {
    super.applicationDidBecomeActive(application)
    if #available(iOS 16.0, *) {
      UNUserNotificationCenter.current().setBadgeCount(0)
    } else {
      application.applicationIconBadgeNumber = 0
    }
  }
}
