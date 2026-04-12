import Foundation

@MainActor
final class TimeAuditViewModel: ObservableObject {
    enum Mode {
        case onboarding
        case day
        case reflection
    }

    @Published var goalInput = ""
    @Published var newGoalInput = ""
    @Published var intervalMinutes: Int
    @Published var eveningHour: Int
    @Published var eveningMinute: Int
    @Published var selectedGoalIDs: Set<UUID>
    @Published var notificationHint: String?

    let store: TimeAuditStore

    init(store: TimeAuditStore) {
        self.store = store
        intervalMinutes = store.state.defaultIntervalMinutes
        eveningHour = store.state.defaultEveningHour
        eveningMinute = store.state.defaultEveningMinute
        selectedGoalIDs = Set(store.state.selectedGoalIDs)
        notificationHint = nil
    }

    convenience init() {
        self.init(store: TimeAuditStore.shared)
    }

    var mode: Mode {
        if store.state.goals.isEmpty {
            return .onboarding
        }

        guard let session = store.todaySession else {
            return .onboarding
        }

        if Date.now >= store.eveningDate(for: session) {
            return .reflection
        }

        return .day
    }

    var activeSession: TimeAuditSession? {
        store.todaySession
    }

    var selectedGoals: [TimeAuditGoal] {
        let ids = activeSession?.goalIDs ?? store.state.selectedGoalIDs
        return store.goals(for: ids)
    }

    var allGoals: [TimeAuditGoal] {
        store.state.goals
    }

    var timeline: [TimeAuditCheckIn] {
        activeSession?.checkIns.sorted { $0.scheduledAt < $1.scheduledAt } ?? []
    }

    var summaryText: String {
        let entries = timeline
        guard !entries.isEmpty else { return "No check-ins yet." }
        let aligned = entries.filter { $0.status == .aligned }.count
        return "\(aligned) aligned out of \(entries.count) total check-ins."
    }

    var supportsMultipleGoals: Bool {
        store.unlocksMultipleGoals
    }

    var consistencyProgressText: String {
        let activeDays = Set(store.state.sessions.filter { !$0.checkIns.isEmpty }.map { Calendar.current.startOfDay(for: $0.dayStart) }).count
        if supportsMultipleGoals {
            return "Multiple-goal tracking unlocked."
        }

        return "Use it for \(max(0, 5 - activeDays)) more day(s) to unlock multiple goals."
    }

    func refresh() {
        intervalMinutes = store.state.defaultIntervalMinutes
        eveningHour = store.state.defaultEveningHour
        eveningMinute = store.state.defaultEveningMinute
        selectedGoalIDs = Set(store.state.selectedGoalIDs)
        store.ensureMissedCheckIns()
        ensureNotificationPermissionAndSyncState()
    }

    func createInitialGoalAndStart() {
        guard let goal = store.addGoal(title: goalInput) else { return }
        selectedGoalIDs = [goal.id]
        applyPreferences()
        startDay()
        goalInput = ""
    }

    func addGoal() {
        guard let newGoal = store.addGoal(title: newGoalInput) else { return }
        selectedGoalIDs.insert(newGoal.id)
        applyPreferences()
        newGoalInput = ""
    }

    func startDay() {
        applyPreferences()

        guard let session = store.startTodaySession() else { return }
        TimeAuditNotificationManager.shared.configureActions()
        Task { @MainActor in
            let permission = await TimeAuditNotificationManager.shared.requestAuthorizationIfNeeded()

            switch permission {
            case .allowed:
                notificationHint = nil
                await TimeAuditNotificationManager.shared.scheduleNotifications(for: session)
            case .denied:
                notificationHint = "Notifications are disabled. Enable them in Settings to receive check-ins."
            case .notDetermined:
                notificationHint = "We still need notification permission to send check-ins."
            }

            store.ensureMissedCheckIns()
        }
    }

    func applyPreferences() {
        let ids: [UUID]
        if supportsMultipleGoals {
            ids = Array(selectedGoalIDs)
        } else {
            ids = Array(selectedGoalIDs.prefix(1))
        }

        if !ids.isEmpty {
            store.updateGoalSelection(ids)
        }

        store.setDefaults(intervalMinutes: intervalMinutes, eveningHour: eveningHour, eveningMinute: eveningMinute)
    }

    func editCheckIn(id: UUID, status: CheckInStatus, detail: String) {
        store.editCheckIn(id: id, status: status, detail: detail)
    }

    private func ensureNotificationPermissionAndSyncState() {
        Task { @MainActor in
            let permission = await TimeAuditNotificationManager.shared.requestAuthorizationIfNeeded()
            switch permission {
            case .allowed:
                notificationHint = nil
                if let session = store.todaySession {
                    await TimeAuditNotificationManager.shared.scheduleNotifications(for: session)
                }
            case .denied:
                notificationHint = "Notifications are disabled. Enable them in Settings to receive check-ins."
            case .notDetermined:
                notificationHint = "Please allow notifications so Time Audit can send check-ins during day mode."
            }
        }
    }
}
