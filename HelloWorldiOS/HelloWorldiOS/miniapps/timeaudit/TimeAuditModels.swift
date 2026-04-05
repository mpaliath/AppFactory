import Foundation

enum CheckInStatus: String, Codable, CaseIterable {
    case aligned
    case notAligned
    case missed

    var title: String {
        switch self {
        case .aligned:
            return "Aligned"
        case .notAligned:
            return "Not aligned"
        case .missed:
            return "Missed"
        }
    }
}

struct TimeAuditGoal: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    let createdAt: Date

    init(id: UUID = UUID(), title: String, createdAt: Date = .now) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
    }
}

struct TimeAuditCheckIn: Identifiable, Codable, Hashable {
    let id: UUID
    let scheduledAt: Date
    var respondedAt: Date?
    var status: CheckInStatus
    var detail: String?

    init(
        id: UUID = UUID(),
        scheduledAt: Date,
        respondedAt: Date? = nil,
        status: CheckInStatus,
        detail: String? = nil
    ) {
        self.id = id
        self.scheduledAt = scheduledAt
        self.respondedAt = respondedAt
        self.status = status
        self.detail = detail
    }
}

struct TimeAuditSession: Identifiable, Codable, Hashable {
    let id: UUID
    let dayStart: Date
    var goalIDs: [UUID]
    var intervalMinutes: Int
    var eveningHour: Int
    var eveningMinute: Int
    var checkIns: [TimeAuditCheckIn]

    init(
        id: UUID = UUID(),
        dayStart: Date,
        goalIDs: [UUID],
        intervalMinutes: Int,
        eveningHour: Int,
        eveningMinute: Int,
        checkIns: [TimeAuditCheckIn] = []
    ) {
        self.id = id
        self.dayStart = dayStart
        self.goalIDs = goalIDs
        self.intervalMinutes = intervalMinutes
        self.eveningHour = eveningHour
        self.eveningMinute = eveningMinute
        self.checkIns = checkIns
    }
}

struct TimeAuditState: Codable {
    var goals: [TimeAuditGoal]
    var sessions: [TimeAuditSession]
    var selectedGoalIDs: [UUID]
    var defaultIntervalMinutes: Int
    var defaultEveningHour: Int
    var defaultEveningMinute: Int

    static let `default` = TimeAuditState(
        goals: [],
        sessions: [],
        selectedGoalIDs: [],
        defaultIntervalMinutes: 60,
        defaultEveningHour: 19,
        defaultEveningMinute: 0
    )
}
