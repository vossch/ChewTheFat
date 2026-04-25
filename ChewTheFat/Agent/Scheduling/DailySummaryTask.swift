import Foundation
import BackgroundTasks

/// BGTaskScheduler wrapper for the once-a-day summary refresh. The actual
/// recompute lives in `DailySummaryGenerator`; this type just owns the
/// register / submit / handle dance with iOS.
///
/// Production scheduling depends on the matching `BGTaskSchedulerPermittedIdentifiers`
/// entry being present in Info.plist alongside `UIBackgroundModes` →
/// `processing`. Without those keys iOS rejects the registration with a
/// console error, but the foreground fallback in
/// `AppEnvironment.runDailySummaryIfNeeded()` keeps the summary fresh.
@MainActor
enum DailySummaryTask {
    static let identifier = "com.PixelKinetics.ChewTheFat.dailySummary"

    /// Called from `AppDelegate.application(_:didFinishLaunchingWithOptions:)`
    /// before the first scene connects. Re-registering is idempotent.
    static func register(environment: @escaping @MainActor () -> AppEnvironment?) {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: identifier,
            using: nil
        ) { task in
            Task { @MainActor in
                handle(task: task, environment: environment())
            }
        }
    }

    static func schedule(after interval: TimeInterval = 60 * 60 * 12) {
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: interval)
        try? BGTaskScheduler.shared.submit(request)
    }

    private static func handle(task: BGTask, environment: AppEnvironment?) {
        schedule()
        defer { task.setTaskCompleted(success: true) }
        guard let environment else { return }
        environment.runDailySummaryIfNeeded()
    }
}
