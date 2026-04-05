import SwiftUI

struct TimeAuditMiniAppView: View {
    @StateObject private var viewModel = TimeAuditViewModel()
    @State private var editingEntry: TimeAuditCheckIn?
    @State private var editStatus: CheckInStatus = .missed
    @State private var editDetail = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                switch viewModel.mode {
                case .onboarding:
                    OnboardingView(viewModel: viewModel)
                case .day:
                    DayModeView(viewModel: viewModel)
                case .reflection:
                    ReflectionModeView(
                        viewModel: viewModel,
                        onEdit: beginEditing
                    )
                }
            }
            .padding()
        }
        .navigationTitle("Time Audit")
        .onAppear(perform: viewModel.refresh)
        .sheet(item: $editingEntry) { entry in
            NavigationStack {
                Form {
                    Picker("Alignment", selection: $editStatus) {
                        Text("Aligned").tag(CheckInStatus.aligned)
                        Text("Not aligned").tag(CheckInStatus.notAligned)
                        Text("Missed").tag(CheckInStatus.missed)
                    }

                    TextField("Detail (optional)", text: $editDetail, axis: .vertical)
                        .lineLimit(3...6)
                }
                .navigationTitle(entry.scheduledAt.formatted(date: .omitted, time: .shortened))
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            editingEntry = nil
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            viewModel.editCheckIn(id: entry.id, status: editStatus, detail: editDetail)
                            editingEntry = nil
                        }
                    }
                }
            }
        }
    }

    private func beginEditing(_ entry: TimeAuditCheckIn) {
        editingEntry = entry
        editStatus = entry.status
        editDetail = entry.detail ?? ""
    }
}

private struct OnboardingView: View {
    @ObservedObject var viewModel: TimeAuditViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(viewModel.allGoals.isEmpty ? "Set your goal for today" : "Start today's focus")
                .font(.title2.weight(.semibold))

            if viewModel.allGoals.isEmpty {
                TextField("One goal for today", text: $viewModel.goalInput)
                    .textFieldStyle(.roundedBorder)
            } else {
                GoalPreferencesView(viewModel: viewModel)
            }

            ScheduleSettingsView(viewModel: viewModel)

            Button("Start Day Mode") {
                if viewModel.allGoals.isEmpty {
                    viewModel.createInitialGoalAndStart()
                } else {
                    viewModel.startDay()
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isPrimaryActionDisabled)
        }
    }

    private var isPrimaryActionDisabled: Bool {
        if viewModel.allGoals.isEmpty {
            return viewModel.goalInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        return viewModel.selectedGoalIDs.isEmpty
    }
}

private struct DayModeView: View {
    @ObservedObject var viewModel: TimeAuditViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Day Mode")
                .font(.title2.weight(.semibold))

            Text("Current goal")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(viewModel.selectedGoals.map(\.title).joined(separator: ", "))
                .font(.headline)

            Text("Leave the app and continue your day. Check-ins happen automatically via notifications.")
                .foregroundStyle(.secondary)

            Divider()
            Text(viewModel.consistencyProgressText)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

private struct ReflectionModeView: View {
    @ObservedObject var viewModel: TimeAuditViewModel
    let onEdit: (TimeAuditCheckIn) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Reflection Mode")
                .font(.title2.weight(.semibold))

            Text(viewModel.summaryText)
                .font(.headline)

            GoalPreferencesView(viewModel: viewModel)
            ScheduleSettingsView(viewModel: viewModel)

            if viewModel.timeline.isEmpty {
                ContentUnavailableView(
                    "No check-ins yet",
                    systemImage: "clock.badge.questionmark",
                    description: Text("As notifications are answered (or missed), your timeline will appear here.")
                )
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(viewModel.timeline) { entry in
                        Button {
                            onEdit(entry)
                        } label: {
                            TimelineRow(entry: entry)
                        }
                        .buttonStyle(.plain)

                        Divider()
                    }
                }
            }
        }
    }
}

private struct GoalPreferencesView: View {
    @ObservedObject var viewModel: TimeAuditViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Goals")
                .font(.headline)

            ForEach(viewModel.allGoals) { goal in
                Toggle(isOn: Binding(
                    get: { viewModel.selectedGoalIDs.contains(goal.id) },
                    set: { selected in
                        if selected {
                            viewModel.selectedGoalIDs.insert(goal.id)
                        } else {
                            viewModel.selectedGoalIDs.remove(goal.id)
                        }
                    }
                )) {
                    Text(goal.title)
                }
                .disabled(!viewModel.supportsMultipleGoals && !viewModel.selectedGoalIDs.contains(goal.id))
            }

            HStack {
                TextField(viewModel.supportsMultipleGoals ? "Add goal" : "Add goal (unlocks later)", text: $viewModel.newGoalInput)
                    .textFieldStyle(.roundedBorder)

                Button("Add") {
                    viewModel.addGoal()
                }
                .disabled(viewModel.newGoalInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            Button("Save preferences") {
                viewModel.applyPreferences()
            }
            .buttonStyle(.bordered)
        }
    }
}

private struct ScheduleSettingsView: View {
    @ObservedObject var viewModel: TimeAuditViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Schedule")
                .font(.headline)

            Stepper(value: $viewModel.intervalMinutes, in: 15...180, step: 15) {
                Text("Check every \(viewModel.intervalMinutes) min")
            }

            HStack {
                Text("Reflection after")
                Spacer()
                DatePicker(
                    "",
                    selection: Binding(
                        get: {
                            Calendar.current.date(
                                from: DateComponents(hour: viewModel.eveningHour, minute: viewModel.eveningMinute)
                            ) ?? .now
                        },
                        set: { value in
                            let comps = Calendar.current.dateComponents([.hour, .minute], from: value)
                            viewModel.eveningHour = comps.hour ?? 19
                            viewModel.eveningMinute = comps.minute ?? 0
                        }
                    ),
                    displayedComponents: .hourAndMinute
                )
                .labelsHidden()
            }
        }
    }
}

private struct TimelineRow: View {
    let entry: TimeAuditCheckIn

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(entry.scheduledAt, format: .dateTime.hour().minute())
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(entry.status.title)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.15), in: Capsule())
                    .foregroundStyle(statusColor)
            }

            if let detail = entry.detail, !detail.isEmpty {
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var statusColor: Color {
        switch entry.status {
        case .aligned:
            return .green
        case .notAligned:
            return .orange
        case .missed:
            return .gray
        }
    }
}

#Preview {
    NavigationStack {
        TimeAuditMiniAppView()
    }
}
