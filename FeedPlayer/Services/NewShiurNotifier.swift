import BackgroundTasks
import Foundation
import UIKit
import UserNotifications

/// Day 1 notifications: at most one standard iOS notification a day, only when
/// new shiurim were uploaded. iOS wakes the app in the background (Background
/// App Refresh) to check the feed, so no server is needed.
/// The full Notifications center (days, times, categories) is planned for Day 2.
enum NewShiurNotifier {
    static let taskID = "org.hashevaynu.app.refresh"
    private static let defaults = UserDefaults.standard

    /// The listener's switch in More. On by default once they allow notifications.
    static var enabled: Bool {
        get { defaults.object(forKey: "notify.enabled") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "notify.enabled") }
    }

    // MARK: Background refresh

    /// Call once while the app launches.
    static func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskID, using: nil) { task in
            guard let task = task as? BGAppRefreshTask else { return }
            schedule()
            let work = Task {
                await checkForNewShiurim()
                task.setTaskCompleted(success: true)
            }
            task.expirationHandler = { work.cancel() }
        }
    }

    /// Ask iOS to wake the app again in a few hours. iOS decides the exact time.
    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: taskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 3 * 3600)
        try? BGTaskScheduler.shared.submit(request)
    }

    /// Remember the newest shiur the listener has already seen in the app,
    /// so they are never notified about something they already saw.
    static func markSeen(_ episodes: [Episode]) {
        if let newest = episodes.first { defaults.set(newest.id, forKey: "notify.lastSeen") }
    }

    static func checkForNewShiurim() async {
        guard enabled else { return }
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        guard status == .authorized || status == .provisional else { return }
        guard let (data, _) = try? await URLSession.shared.data(from: FeedStore.feedURL),
              let episodes = try? FeedParser.parse(data).episodes, !episodes.isEmpty else { return }

        guard let lastSeen = defaults.string(forKey: "notify.lastSeen") else {
            markSeen(episodes)   // first run: start counting from now
            return
        }
        let fresh = Array(episodes.prefix { $0.id != lastSeen }.prefix(30))
        guard !fresh.isEmpty else { return }

        // At most one a day, and never on Shabbos. Anything new waits for the next allowed day.
        let now = Date()
        let today = dayKey(now)
        guard defaults.string(forKey: "notify.lastDay") != today, !isShabbos(now) else { return }

        let content = UNMutableNotificationContent()
        if fresh.count == 1 {
            content.title = "New shiur"
            content.body = fresh[0].title
        } else {
            content.title = "\(fresh.count) new shiurim"
            content.body = fresh.prefix(3).map(\.title).joined(separator: " · ")
        }
        content.sound = .default
        content.threadIdentifier = "new-shiurim"
        let request = UNNotificationRequest(identifier: "new-shiurim-\(today)", content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
        defaults.set(today, forKey: "notify.lastDay")
        markSeen(episodes)
    }

    // MARK: Permission

    /// Shows the standard iOS "Allow notifications?" prompt (only the first time).
    @discardableResult
    static func requestPermission() async -> Bool {
        let granted = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        defaults.set(true, forKey: "notify.asked")
        return granted
    }

    static var hasAsked: Bool { defaults.bool(forKey: "notify.asked") }

    // MARK: Helpers

    private static func dayKey(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return "\(c.year ?? 0)-\(c.month ?? 0)-\(c.day ?? 0)"
    }

    /// Rough Shabbos window (Friday 4 PM to Saturday 9 PM, local time).
    /// Day 2: use exact candle-lighting and havdalah times from Hebcal.
    private static func isShabbos(_ date: Date) -> Bool {
        let c = Calendar.current.dateComponents([.weekday, .hour], from: date)
        guard let weekday = c.weekday, let hour = c.hour else { return false }
        return (weekday == 6 && hour >= 16) || (weekday == 7 && hour < 21)
    }
}

/// Shows notifications as banners even while the app is open.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
