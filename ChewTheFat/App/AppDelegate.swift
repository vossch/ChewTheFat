import UIKit
import BackgroundTasks
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate {
    /// Held strongly so `UNUserNotificationCenter`'s weak `delegate` reference
    /// stays valid for the life of the app.
    private let notificationDelegate = ForegroundSuppressDelegate()
    /// Resolved by `ChewTheFatApp` once `AppEnvironment.live()` succeeds, so
    /// the BGTask handler can reach repositories without a forced unwrap on
    /// cold launch.
    @MainActor static var environmentResolver: @MainActor () -> AppEnvironment? = { nil }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = notificationDelegate
        DailySummaryTask.register { AppDelegate.environmentResolver() }
        DailySummaryTask.schedule()
        return true
    }
}
