import SwiftUI

struct PokerMiniAppView: View {
    @StateObject private var viewModel = PokerGameViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                tableControls
                communityCards
                playersSection
                actionControls
                activityLog
            }
            .padding()
        }
        .navigationTitle("Texas Hold'em")
        .onAppear {
            if viewModel.players.isEmpty {
                viewModel.setupTable()
            }
        }
    }

    private var tableControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Table")
                .font(.headline)

            Stepper("Opponents: \(viewModel.opponentCount)", value: $viewModel.opponentCount, in: 1...5)
                .disabled(viewModel.stage == .preflop)

            HStack {
                Button("Set Up Table") {
                    viewModel.setupTable()
                }
                .buttonStyle(.bordered)

                Button(viewModel.stage == .preflop ? "Hand In Progress" : "Deal New Hand") {
                    viewModel.startNewHand()
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.stage == .preflop || !viewModel.canStartHand)
            }

            Label("Pot: \(viewModel.pot)", systemImage: "dollarsign.circle")
        }
    }

    private var communityCards: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Board")
                .font(.headline)

            if viewModel.communityCards.isEmpty {
                Text("Deal a hand to reveal the board.")
                    .foregroundStyle(.secondary)
            } else {
                CardRowView(cards: viewModel.communityCards)
            }
        }
    }

    private var playersSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Players")
                .font(.headline)

            ForEach(Array(viewModel.players.enumerated()), id: \.element.id) { index, player in
                PlayerRowView(
                    player: player,
                    isCurrentTurn: index == viewModel.currentPlayerIndex,
                    showCards: player.isHuman || viewModel.stage != .preflop
                )
            }
        }
    }

    private var actionControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your Action")
                .font(.headline)

            HStack {
                Button("Fold") {
                    viewModel.fold()
                }
                .buttonStyle(.bordered)

                Button("Check / Call") {
                    viewModel.checkOrCall()
                }
                .buttonStyle(.borderedProminent)

                Button("Raise +\(viewModel.minimumRaise)") {
                    viewModel.raise()
                }
                .buttonStyle(.bordered)
            }
            .disabled(!viewModel.isAwaitingHumanAction)

            if !viewModel.isAwaitingHumanAction {
                Text(viewModel.stage == .preflop ? "Waiting for CPU players..." : "Start a new hand when ready.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var activityLog: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Hand Log")
                .font(.headline)

            if viewModel.logs.isEmpty {
                Text("No actions yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.logs.prefix(12)) { entry in
                    Text("• \(entry.message)")
                        .font(.footnote)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

private struct PlayerRowView: View {
    let player: PokerPlayer
    let isCurrentTurn: Bool
    let showCards: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(player.name)
                    .font(.subheadline.weight(.semibold))
                if isCurrentTurn {
                    Text("Acting")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(.blue.opacity(0.15), in: Capsule())
                }

                Spacer()
                Text("Chips: \(player.chips)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if player.isFolded {
                Text("Folded")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if showCards {
                CardRowView(cards: player.holeCards)
            } else {
                Text("Hole cards hidden")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct CardRowView: View {
    let cards: [PokerCard]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(cards) { card in
                Text(card.label)
                    .font(.system(.body, design: .monospaced).weight(.medium))
                    .frame(minWidth: 42)
                    .padding(.vertical, 6)
                    .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(.secondary.opacity(0.35), lineWidth: 1)
                    )
            }
        }
    }
}

#Preview {
    NavigationStack {
        PokerMiniAppView()
    }
}
