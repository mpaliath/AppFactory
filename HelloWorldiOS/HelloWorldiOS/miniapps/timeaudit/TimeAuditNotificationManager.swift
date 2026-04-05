import Foundation
import UserNotifications

enum TimeAuditNotificationAction {
    static let categoryIdentifier = "TIME_AUDIT_CHECKIN"
    static let yesIdentifier = "TIME_AUDIT_YES"
    static let noIdentifier = "TIME_AUDIT_NO"
    static let detailIdentifier = "TIME_AUDIT_DETAIL"
}

final class TimeAuditNotificationManager {
    static let shared = TimeAuditNotificationManager()

    private init() {}

    func configureActions() {
        let yes = UNNotificationAction(
            identifier: TimeAuditNotificationAction.yesIdentifier,
            title: "Yes",
            options: [.authenticationRequired]
        )

        let no = UNNotificationAction(
            identifier: TimeAuditNotificationAction.noIdentifier,
            title: "No",
            options: [.authenticationRequired]
        )

        let detail = UNTextInputNotificationAction(
            identifier: TimeAuditNotificationAction.detailIdentifier,
            title: "Add detail",
            options: [.authenticationRequired],
            textInputButtonTitle: "Save",
            textInputPlaceholder: "What are you doing right now?"
        )

        let category = UNNotificationCategory(
            identifier: TimeAuditNotificationAction.categoryIdentifier,
            actions: [yes, no, detail],
            intentIdentifiers: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
    }

    func scheduleNotifications(for session: TimeAuditSession) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: pendingIDs(for: session))

        let slots = notificationSlots(for: session)
        for slot in slots where slot > .now {
            let content = UNMutableNotificationContent()
            content.title = "Quick check-in"
            content.body = "Are you working on your goal?"
            content.sound = .default
            content.categoryIdentifier = TimeAuditNotificationAction.categoryIdentifier
            content.userInfo = [
                "sessionDay": ISO8601DateFormatter().string(from: session.dayStart),
                "slot": ISO8601DateFormatter().string(from: slot)
            ]

            let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: slot)
            let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
            let id = notificationID(for: session.dayStart, slot: slot)
            let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request)
        }
    }

    func handleNotificationResponse(_ response: UNNotificationResponse) {
        guard
            let sessionDay = parseISODate(response.notification.request.content.userInfo["sessionDay"]),
            let slot = parseISODate(response.notification.request.content.userInfo["slot"])
        else {
            return
        }

        switch response.actionIdentifier {
        case TimeAuditNotificationAction.yesIdentifier:
            Task { @MainActor in
                TimeAuditStore.shared.updateCheckIn(sessionDayStart: sessionDay, scheduledAt: slot, status: .aligned, detail: nil)
            }
        case TimeAuditNotificationAction.noIdentifier:
            Task { @MainActor in
                TimeAuditStore.shared.updateCheckIn(sessionDayStart: sessionDay, scheduledAt: slot, status: .notAligned, detail: nil)
            }
        case TimeAuditNotificationAction.detailIdentifier:
            let typed = (response as? UNTextInputNotificationResponse)?.userText
            Task { @MainActor in
                TimeAuditStore.shared.updateCheckIn(sessionDayStart: sessionDay, scheduledAt: slot, status: .notAligned, detail: typed)
            }
        default:
            break
        }
    }

    private func notificationID(for day: Date, slot: Date) -> String {
        let iso = ISO8601DateFormatter()
        return "time-audit-\(iso.string(from: day))-\(iso.string(from: slot))"
    }

    private func pendingIDs(for session: TimeAuditSession) -> [String] {
        let slots = notificationSlots(for: session)
        return slots.map { notificationID(for: session.dayStart, slot: $0) }
    }

    private func notificationSlots(for session: TimeAuditSession) -> [Date] {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: session.dayStart)
        components.hour = session.eveningHour
        components.minute = session.eveningMinute
        let evening = Calendar.current.date(from: components) ?? session.dayStart.addingTimeInterval(19 * 3600)

        guard evening > session.dayStart else { return [] }

        var slots: [Date] = []
        var cursor = session.dayStart.addingTimeInterval(TimeInterval(session.intervalMinutes * 60))
        while cursor <= evening {
            slots.append(cursor)
            cursor = cursor.addingTimeInterval(TimeInterval(session.intervalMinutes * 60))
        }
        return slots
    }

    private func parseISODate(_ value: Any?) -> Date? {
        guard let string = value as? String else { return nil }
        return ISO8601DateFormatter().date(from: string)
    }
}
