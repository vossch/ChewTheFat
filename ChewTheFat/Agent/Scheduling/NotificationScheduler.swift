import Foundation
import UserNotifications

/// Wraps `UNUserNotificationCenter` for the four daily proactive prompts.
/// The scheduler is read-only with respect to preferences: it observes the
/// boolean toggles, requests authorization on first opt-in, and
/// adds/removes the per-slot notifications. Foreground delivery is
/// suppressed by `ForegroundSuppressDelegate` so an active session never
/// gets pinged.
@MainActor
final class NotificationScheduler {
    /// Hardcoded daily slots. The hour/minute pair feeds
    /// `UNCalendarNotificationTrigger`; identifiers double as the toggle
    /// key in `AppPreferences`.
    enum Slot: String, CaseIterable {
        case weighIn
        case breakfast
        case lunch
        case dinner

        var hour: Int {
            switch self {
            case .weighIn: return 8
            case .breakfast: return 9
            case .lunch: return 12
            case .dinner: return 18
            }
        }

        var minute: Int {
            switch self {
            case .weighIn: return 0
            case .breakfast: return 0
            case .lunch: return 30
            case .dinner: return 30
            }
        }

        var identifier: String { "ctf.notification.\(rawValue)" }

        var title: String {
            switch self {
            case .weighIn: return "Time to weigh in"
            case .breakfast: return "Breakfast?"
            case .lunch: return "Lunch?"
            case .dinner: return "Dinner?"
            }
        }

        var body: String {
            switch self {
            case .weighIn: return "Tap to log today's weight."
            case .breakfast: return "Log what you had for breakfast."
            case .lunch: return "Log what you had for lunch."
            case .dinner: return "Log what you had for dinner."
            }
        }
    }

    private let center: UNUserNotificationCenter
    private var hasRequestedAuthorization = false

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    /// Push the current preference state to UNUserNotificationCenter. Called
    /// on app launch and whenever the user toggles a slot. Authorization is
    /// requested lazily — only on the first slot that's flipped on.
    func sync(with preferences: AppPreferences) async {
        let enabled: [Slot: Bool] = [
            .weighIn: preferences.weighInNotificationsEnabled,
            .breakfast: preferences.breakfastNotificationsEnabled,
            .lunch: preferences.lunchNotificationsEnabled,
            .dinner: preferences.dinnerNotificationsEnabled,
        ]

        let anyOn = enabled.values.contains(true)
        if anyOn, !hasRequestedAuthorization {
            hasRequestedAuthorization = true
            _ = try? await center.requestAuthorization(options: [.alert, .sound])
        }

        let settings = await center.notificationSettings()
        let authorized = settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional

        for (slot, on) in enabled {
            if on && authorized {
                schedule(slot)
            } else {
                center.removePendingNotificationRequests(withIdentifiers: [slot.identifier])
            }
        }
    }

    private func schedule(_ slot: Slot) {
        let content = UNMutableNotificationContent()
        content.title = slot.title
        content.body = slot.body
        content.sound = .default

        var components = DateComponents()
        components.hour = slot.hour
        components.minute = slot.minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        let request = UNNotificationRequest(
            identifier: slot.identifier,
            content: content,
            trigger: trigger
        )
        center.add(request)
    }
}

/// Suppresses notification banners while the app is foregrounded. Per the
/// product brief, notifications exist only to bring the user back — if
/// they're already in the app, the daily proactive prompt is irrelevant
/// and the auto-trigger session-seeding flow takes over instead.
final class ForegroundSuppressDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([])
    }
}
