import Foundation

@MainActor
final class TimeAuditStore: ObservableObject {
    static let shared = TimeAuditStore()

    @Published private(set) var state: TimeAuditState

    private let storageKey = "time_audit_state_v1"
    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder.dateDecodingStrategy = .iso8601

        if
            let data = defaults.data(forKey: storageKey),
            let saved = try? decoder.decode(TimeAuditState.self, from: data)
        {
            state = saved
        } else {
            state = .default
        }
    }

    var unlocksMultipleGoals: Bool {
        let activeDays = Set(state.sessions.filter { !$0.checkIns.isEmpty }.map { Calendar.current.startOfDay(for: $0.dayStart) })
        return activeDays.count >= 5
    }

    var todaySession: TimeAuditSession? {
        let todayStart = Calendar.current.startOfDay(for: .now)
        return state.sessions.first { Calendar.current.isDate($0.dayStart, inSameDayAs: todayStart) }
    }

    func eveningDate(for session: TimeAuditSession) -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: session.dayStart)
        components.hour = session.eveningHour
        components.minute = session.eveningMinute
        return Calendar.current.date(from: components) ?? session.dayStart.addingTimeInterval(19 * 3600)
    }

    func goals(for ids: [UUID]) -> [TimeAuditGoal] {
        ids.compactMap { id in state.goals.first(where: { $0.id == id }) }
    }

    func addGoal(title: String) -> TimeAuditGoal? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let goal = TimeAuditGoal(title: trimmed)
        state.goals.append(goal)

        if state.selectedGoalIDs.isEmpty {
            state.selectedGoalIDs = [goal.id]
        }

        persist()
        return goal
    }

    func updateGoalSelection(_ ids: [UUID]) {
        state.selectedGoalIDs = ids
        persist()
    }

    func setDefaults(intervalMinutes: Int, eveningHour: Int, eveningMinute: Int) {
        state.defaultIntervalMinutes = max(15, intervalMinutes)
        state.defaultEveningHour = min(max(0, eveningHour), 23)
        state.defaultEveningMinute = min(max(0, eveningMinute), 59)
        persist()
    }

    func startTodaySession() -> TimeAuditSession? {
        let today = Calendar.current.startOfDay(for: .now)
        if let existing = todaySession {
            return existing
        }

        let selected = state.selectedGoalIDs.filter { id in state.goals.contains(where: { $0.id == id }) }
        guard !selected.isEmpty else { return nil }

        let allowedGoals = unlocksMultipleGoals ? selected : Array(selected.prefix(1))
        let session = TimeAuditSession(
            dayStart: today,
            goalIDs: allowedGoals,
            intervalMinutes: max(15, state.defaultIntervalMinutes),
            eveningHour: state.defaultEveningHour,
            eveningMinute: state.defaultEveningMinute
        )
        state.sessions.append(session)
        persist()
        return session
    }

    func updateCheckIn(sessionDayStart: Date, scheduledAt: Date, status: CheckInStatus, detail: String?) {
        guard let idx = indexOfSession(for: sessionDayStart) else { return }
        var session = state.sessions[idx]
        if let checkInIndex = session.checkIns.firstIndex(where: { Calendar.current.compare($0.scheduledAt, to: scheduledAt, toGranularity: .minute) == .orderedSame }) {
            session.checkIns[checkInIndex].status = status
            session.checkIns[checkInIndex].respondedAt = .now
            session.checkIns[checkInIndex].detail = normalizedDetail(detail)
        } else {
            session.checkIns.append(
                TimeAuditCheckIn(
                    scheduledAt: scheduledAt,
                    respondedAt: .now,
                    status: status,
                    detail: normalizedDetail(detail)
                )
            )
        }
        session.checkIns.sort { $0.scheduledAt < $1.scheduledAt }
        state.sessions[idx] = session
        persist()
    }

    func ensureMissedCheckIns(for now: Date = .now) {
        guard let idx = indexOfSession(for: Calendar.current.startOfDay(for: now)) else { return }
        var session = state.sessions[idx]

        let slots = expectedSlots(for: session, now: now)
        for slot in slots {
            let exists = session.checkIns.contains { existing in
                Calendar.current.compare(existing.scheduledAt, to: slot, toGranularity: .minute) == .orderedSame
            }
            if !exists {
                session.checkIns.append(TimeAuditCheckIn(scheduledAt: slot, status: .missed))
            }
        }

        session.checkIns.sort { $0.scheduledAt < $1.scheduledAt }
        state.sessions[idx] = session
        persist()
    }

    func editCheckIn(id: UUID, status: CheckInStatus, detail: String?) {
        guard let sessionIndex = state.sessions.firstIndex(where: { session in
            session.checkIns.contains(where: { $0.id == id })
        }) else {
            return
        }

        guard let checkInIndex = state.sessions[sessionIndex].checkIns.firstIndex(where: { $0.id == id }) else { return }
        state.sessions[sessionIndex].checkIns[checkInIndex].status = status
        state.sessions[sessionIndex].checkIns[checkInIndex].detail = normalizedDetail(detail)
        if status != .missed {
            state.sessions[sessionIndex].checkIns[checkInIndex].respondedAt = .now
        }
        persist()
    }

    func expectedSlots(for session: TimeAuditSession, now: Date = .now) -> [Date] {
        let start = session.dayStart
        let evening = eveningDate(for: session)
        let end = min(now, evening)
        guard end > start else { return [] }

        var slots: [Date] = []
        var cursor = start.addingTimeInterval(TimeInterval(session.intervalMinutes * 60))

        while cursor <= end {
            slots.append(cursor)
            cursor = cursor.addingTimeInterval(TimeInterval(session.intervalMinutes * 60))
        }

        return slots
    }

    private func indexOfSession(for dayStart: Date) -> Int? {
        state.sessions.firstIndex { Calendar.current.isDate($0.dayStart, inSameDayAs: dayStart) }
    }

    private func persist() {
        guard let data = try? encoder.encode(state) else { return }
        defaults.set(data, forKey: storageKey)
    }

    private func normalizedDetail(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
