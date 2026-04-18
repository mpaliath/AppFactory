import Foundation

enum PokerSuit: String, CaseIterable {
    case clubs = "♣︎"
    case diamonds = "♦︎"
    case hearts = "♥︎"
    case spades = "♠︎"
}

enum PokerRank: Int, CaseIterable, Comparable {
    case two = 2
    case three = 3
    case four = 4
    case five = 5
    case six = 6
    case seven = 7
    case eight = 8
    case nine = 9
    case ten = 10
    case jack = 11
    case queen = 12
    case king = 13
    case ace = 14

    static func < (lhs: PokerRank, rhs: PokerRank) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var label: String {
        switch self {
        case .ace: return "A"
        case .king: return "K"
        case .queen: return "Q"
        case .jack: return "J"
        case .ten: return "10"
        default: return "\(rawValue)"
        }
    }
}

struct PokerCard: Identifiable, Equatable {
    let suit: PokerSuit
    let rank: PokerRank

    var id: String { "\(rank.rawValue)-\(suit.rawValue)" }
    var label: String { "\(rank.label)\(suit.rawValue)" }
}

struct PokerPlayer: Identifiable {
    let id: UUID
    let name: String
    let isHuman: Bool
    var chips: Int
    var holeCards: [PokerCard]
    var isFolded: Bool
    var currentBet: Int

    init(name: String, isHuman: Bool, chips: Int = 1_000) {
        id = UUID()
        self.name = name
        self.isHuman = isHuman
        self.chips = chips
        holeCards = []
        isFolded = false
        currentBet = 0
    }
}

enum PokerGameStage {
    case setup
    case preflop
    case showdown
    case handComplete
}

enum PokerActionType {
    case fold
    case check
    case call
    case raise(amount: Int)
}

struct PokerActionLog: Identifiable {
    let id = UUID()
    let message: String
}

struct PokerHandRank: Comparable {
    let category: Int
    let tiebreakers: [Int]
    let label: String

    static func < (lhs: PokerHandRank, rhs: PokerHandRank) -> Bool {
        if lhs.category != rhs.category {
            return lhs.category < rhs.category
        }

        for (left, right) in zip(lhs.tiebreakers, rhs.tiebreakers) where left != right {
            return left < right
        }

        return lhs.tiebreakers.count < rhs.tiebreakers.count
    }
}
