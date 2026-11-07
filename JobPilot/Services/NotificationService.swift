import Foundation
import UserNotifications

@MainActor
enum NotificationService {
    static let followUpPrefix = "jobpilot.followup."
    static let interviewPrefix = "jobpilot.interview."

    static func requestPermission() async throws -> Bool {
        try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
    }

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    private static func schedule(id: String, title: String, body: String, when: Date) async throws {
        guard when > Date() else { return }
        let status = await authorizationStatus()
        guard status == .authorized || status == .provisional || status == .ephemeral else {
            throw JobPilotError.invalid("Уведомления отключены. Включи их в настройках iPhone.")
        }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        // A single fire date with calendar and timezone to preserve the selected local time.
        let components = Calendar.current.dateComponents(in: TimeZone.current, from: when)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        try await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    static func scheduleFollowUp(_ followUp: FollowUp, company: String) async throws {
        try await schedule(id: followUpPrefix + followUp.id.uuidString, title: "Напомнить о вакансии · \(company)",
            body: followUp.title, when: followUp.dueAt)
    }

    static func scheduleInterview(_ interview: Interview, company: String) async throws {
        let remindAt = interview.at.addingTimeInterval(-30 * 60)
        try await schedule(id: interviewPrefix + interview.id.uuidString, title: "Собеседование · \(company)",
            body: "Через 30 минут начнётся собеседование.", when: remindAt)
    }

    static func cancelFollowUp(id: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [followUpPrefix + id.uuidString])
    }

    static func cancelInterview(id: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [interviewPrefix + id.uuidString])
    }

    static func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
