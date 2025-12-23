import Foundation
import UserNotifications

struct NotificationManager {
    private let center = UNUserNotificationCenter.current()
    private let identifier = "daily_deadlines"

    func requestAuthorization() async throws -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            if !granted {
                print("Notification permission not granted")
            }
            return granted
        } catch {
            print("Notification permission error: \(error)")
            throw error
        }
    }

    func scheduleDailyReminder(hour: Int, minute: Int, body: String) async {
        await center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let content = UNMutableNotificationContent()
        content.title = "LearnReminder"
        content.body = body
        content.sound = .default

        var components = DateComponents()
        components.hour = hour
        components.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        do {
            try await center.add(request)
        } catch {
            print("Failed to schedule daily reminder: \(error)")
        }
    }

    func cancelDailyReminder() async {
        await center.removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}
