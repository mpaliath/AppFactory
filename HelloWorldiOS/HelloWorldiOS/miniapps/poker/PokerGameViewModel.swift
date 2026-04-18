import Foundation

@MainActor
final class PokerGameViewModel: ObservableObject {
    @Published private(set) var players: [PokerPlayer] = []
    @Published private(set) var communityCards: [PokerCard] = []
    @Published private(set) var pot: Int = 0
    @Published private(set) var stage: PokerGameStage = .setup
    @Published private(set) var currentPlayerIndex: Int?
    @Published private(set) var currentBet: Int = 0
    @Published private(set) var logs: [PokerActionLog] = []
    @Published var opponentCount: Int = 2

    private var deck: [PokerCard] = []
    private var playersToAct: Set<Int> = []
    private var dealerIndex: Int = 0

    let minimumRaise = 20
    let bigBlind = 20
    let smallBlind = 10

    var canStartHand: Bool {
        players.filter { $0.chips > 0 }.count >= 2
    }

    var isAwaitingHumanAction: Bool {
        guard stage == .preflop, let index = currentPlayerIndex else { return false }
        return players[index].isHuman
    }

    func setupTable() {
        var configuredPlayers = [PokerPlayer(name: "You", isHuman: true)]
        for seat in 1...opponentCount {
            configuredPlayers.append(PokerPlayer(name: "CPU \(seat)", isHuman: false))
        }

        players = configuredPlayers
        dealerIndex = 0
        logs.removeAll()
        stage = .setup
        pot = 0
        currentBet = 0
        currentPlayerIndex = nil
        communityCards = []
        log("Table ready with \(players.count) players.")
    }

    func startNewHand() {
        guard canStartHand else {
            log("Need at least two players with chips to continue.")
            return
        }

        if players.isEmpty {
            setupTable()
        }

        stage = .preflop
        pot = 0
        currentBet = bigBlind
        communityCards = []
        deck = shuffledDeck()

        for index in players.indices {
            players[index].holeCards = []
            players[index].isFolded = players[index].chips == 0
            players[index].currentBet = 0
        }

        dealHoleCards()
        postBlinds()
        dealCommunityCards()

        let firstToAct = nextActiveIndex(from: (dealerIndex + 3) % players.count)
        currentPlayerIndex = firstToAct
        resetPlayersToAct(raisingPlayer: nil)
        if let firstToAct {
            playersToAct.remove(firstToAct)
        }

        log("New hand started. Pot: \(pot)")
        advanceBotsIfNeeded()
    }

    func fold() {
        act(.fold)
    }

    func checkOrCall() {
        guard let index = currentPlayerIndex else { return }
        let toCall = max(0, currentBet - players[index].currentBet)
        if toCall == 0 {
            act(.check)
        } else {
            act(.call)
        }
    }

    func raise() {
        act(.raise(amount: currentBet + minimumRaise))
    }

    private func act(_ action: PokerActionType) {
        guard stage == .preflop, let index = currentPlayerIndex, !players[index].isFolded else { return }

        switch action {
        case .fold:
            players[index].isFolded = true
            log("\(players[index].name) folds")
        case .check:
            log("\(players[index].name) checks")
        case .call:
            let toCall = max(0, currentBet - players[index].currentBet)
            let contributed = contributeChips(for: index, desired: toCall)
            log("\(players[index].name) calls \(contributed)")
        case .raise(let amount):
            let targetBet = max(amount, currentBet + minimumRaise)
            let toRaise = max(0, targetBet - players[index].currentBet)
            let contributed = contributeChips(for: index, desired: toRaise)
            currentBet = max(currentBet, players[index].currentBet)
            log("\(players[index].name) raises to \(players[index].currentBet) (+\(contributed))")
            resetPlayersToAct(raisingPlayer: index)
        }

        playersToAct.remove(index)

        if remainingPlayers.count <= 1 {
            resolveWithoutShowdown()
            return
        }

        if playersToAct.isEmpty {
            revealShowdown()
            return
        }

        currentPlayerIndex = nextIndexFromCurrent(after: index)
        advanceBotsIfNeeded()
    }

    private func advanceBotsIfNeeded() {
        while stage == .preflop,
              let index = currentPlayerIndex,
              !players[index].isHuman {
            let action = botAction(for: index)
            act(action)
        }
    }

    private func botAction(for index: Int) -> PokerActionType {
        let toCall = max(0, currentBet - players[index].currentBet)
        let handStrength = players[index].holeCards.reduce(0) { $0 + $1.rank.rawValue }
        let aggressiveness = Int.random(in: 0...100)

        if toCall > players[index].chips {
            return .call
        }

        if toCall >= 60, handStrength < 18, aggressiveness < 55 {
            return .fold
        }

        if toCall == 0, aggressiveness > 80, players[index].chips > currentBet + minimumRaise {
            return .raise(amount: currentBet + minimumRaise)
        }

        if toCall <= 20 || handStrength >= 20 || aggressiveness > 30 {
            return toCall == 0 ? .check : .call
        }

        return .fold
    }

    private func revealShowdown() {
        stage = .showdown
        currentPlayerIndex = nil

        let contenders = remainingPlayers
        let evaluated: [(Int, PokerHandRank)] = contenders.map { idx in
            let rank = PokerHandEvaluator.bestRank(from: players[idx].holeCards + communityCards)
            return (idx, rank)
        }

        guard let best = evaluated.map(\.1).max() else { return }
        let winners = evaluated.filter { $0.1 == best }.map(\.0)
        let payout = pot / max(1, winners.count)
        let remainder = pot % max(1, winners.count)

        for (offset, winner) in winners.enumerated() {
            players[winner].chips += payout + (offset == 0 ? remainder : 0)
        }

        let winnerNames = winners.map { players[$0].name }.joined(separator: ", ")
        log("Showdown: \(winnerNames) win \(pot) with \(best.label)")

        pot = 0
        stage = .handComplete
        dealerIndex = nextActiveIndex(from: (dealerIndex + 1) % players.count) ?? dealerIndex
    }

    private func resolveWithoutShowdown() {
        guard let winner = remainingPlayers.first else { return }
        players[winner].chips += pot
        log("\(players[winner].name) wins \(pot) (everyone else folded)")
        pot = 0
        stage = .handComplete
        currentPlayerIndex = nil
        dealerIndex = nextActiveIndex(from: (dealerIndex + 1) % players.count) ?? dealerIndex
    }

    private var remainingPlayers: [Int] {
        players.indices.filter { !players[$0].isFolded && (players[$0].chips > 0 || players[$0].currentBet > 0) }
    }

    private func resetPlayersToAct(raisingPlayer: Int?) {
        playersToAct = Set(players.indices.filter {
            $0 != raisingPlayer && !players[$0].isFolded && players[$0].chips > 0
        })
    }

    private func contributeChips(for index: Int, desired: Int) -> Int {
        let contribution = min(players[index].chips, desired)
        players[index].chips -= contribution
        players[index].currentBet += contribution
        pot += contribution
        return contribution
    }

    private func postBlinds() {
        guard players.count >= 2 else { return }
        let smallBlindIndex = nextActiveIndex(from: (dealerIndex + 1) % players.count) ?? 0
        let bigBlindIndex = nextActiveIndex(from: (smallBlindIndex + 1) % players.count) ?? smallBlindIndex

        let sb = contributeChips(for: smallBlindIndex, desired: smallBlind)
        let bb = contributeChips(for: bigBlindIndex, desired: bigBlind)
        currentBet = max(sb, bb)

        log("\(players[smallBlindIndex].name) posts SB \(sb)")
        log("\(players[bigBlindIndex].name) posts BB \(bb)")
    }

    private func dealHoleCards() {
        for _ in 0..<2 {
            for index in players.indices where players[index].chips > 0 {
                if let card = drawCard() {
                    players[index].holeCards.append(card)
                }
            }
        }
    }

    private func dealCommunityCards() {
        for _ in 0..<5 {
            if let card = drawCard() {
                communityCards.append(card)
            }
        }
    }

    private func nextIndexFromCurrent(after index: Int) -> Int? {
        guard !players.isEmpty else { return nil }
        var next = (index + 1) % players.count
        while next != index {
            if playersToAct.contains(next), !players[next].isFolded {
                return next
            }
            next = (next + 1) % players.count
        }

        return playersToAct.contains(index) ? index : nil
    }

    private func nextActiveIndex(from start: Int) -> Int? {
        guard !players.isEmpty else { return nil }
        var idx = start % players.count
        for _ in players.indices {
            if players[idx].chips > 0 {
                return idx
            }
            idx = (idx + 1) % players.count
        }
        return nil
    }

    private func shuffledDeck() -> [PokerCard] {
        PokerSuit.allCases.flatMap { suit in
            PokerRank.allCases.map { rank in PokerCard(suit: suit, rank: rank) }
        }.shuffled()
    }

    private func drawCard() -> PokerCard? {
        guard !deck.isEmpty else { return nil }
        return deck.removeFirst()
    }

    private func log(_ message: String) {
        logs.insert(PokerActionLog(message: message), at: 0)
    }
}
