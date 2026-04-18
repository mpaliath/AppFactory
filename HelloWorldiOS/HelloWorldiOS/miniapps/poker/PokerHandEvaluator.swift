import Foundation

enum PokerHandEvaluator {
    static func bestRank(from cards: [PokerCard]) -> PokerHandRank {
        guard cards.count >= 5 else {
            return PokerHandRank(category: -1, tiebreakers: [], label: "Incomplete")
        }

        var best: PokerHandRank?
        for a in 0..<(cards.count - 4) {
            for b in (a + 1)..<(cards.count - 3) {
                for c in (b + 1)..<(cards.count - 2) {
                    for d in (c + 1)..<(cards.count - 1) {
                        for e in (d + 1)..<cards.count {
                            let rank = evaluateFiveCardHand([cards[a], cards[b], cards[c], cards[d], cards[e]])
                            if let best, rank <= best {
                                continue
                            }
                            best = rank
                        }
                    }
                }
            }
        }

        return best ?? PokerHandRank(category: -1, tiebreakers: [], label: "Incomplete")
    }

    private static func evaluateFiveCardHand(_ cards: [PokerCard]) -> PokerHandRank {
        let values = cards.map { $0.rank.rawValue }.sorted(by: >)
        let isFlush = Set(cards.map(\.suit)).count == 1
        let straightHigh = straightHighCard(for: values)

        var countsByRank: [Int: Int] = [:]
        values.forEach { countsByRank[$0, default: 0] += 1 }
        let groups = countsByRank
            .map { (rank: $0.key, count: $0.value) }
            .sorted {
                if $0.count != $1.count {
                    return $0.count > $1.count
                }
                return $0.rank > $1.rank
            }

        if isFlush, let straightHigh {
            return PokerHandRank(category: 8, tiebreakers: [straightHigh], label: "Straight Flush")
        }

        if groups.first?.count == 4, let quad = groups.first, let kicker = groups.last {
            return PokerHandRank(category: 7, tiebreakers: [quad.rank, kicker.rank], label: "Four of a Kind")
        }

        if groups.count >= 2, groups[0].count == 3, groups[1].count == 2 {
            return PokerHandRank(category: 6, tiebreakers: [groups[0].rank, groups[1].rank], label: "Full House")
        }

        if isFlush {
            return PokerHandRank(category: 5, tiebreakers: values, label: "Flush")
        }

        if let straightHigh {
            return PokerHandRank(category: 4, tiebreakers: [straightHigh], label: "Straight")
        }

        if groups.first?.count == 3, let trip = groups.first {
            let kickers = groups.dropFirst().map(\.rank).sorted(by: >)
            return PokerHandRank(category: 3, tiebreakers: [trip.rank] + kickers, label: "Three of a Kind")
        }

        if groups.count >= 3, groups[0].count == 2, groups[1].count == 2 {
            let highPair = max(groups[0].rank, groups[1].rank)
            let lowPair = min(groups[0].rank, groups[1].rank)
            let kicker = groups.dropFirst(2).first?.rank ?? 0
            return PokerHandRank(category: 2, tiebreakers: [highPair, lowPair, kicker], label: "Two Pair")
        }

        if groups.first?.count == 2, let pair = groups.first {
            let kickers = groups.dropFirst().map(\.rank).sorted(by: >)
            return PokerHandRank(category: 1, tiebreakers: [pair.rank] + kickers, label: "Pair")
        }

        return PokerHandRank(category: 0, tiebreakers: values, label: "High Card")
    }

    private static func straightHighCard(for values: [Int]) -> Int? {
        let unique = Array(Set(values)).sorted(by: >)
        guard unique.count >= 5 else { return nil }

        if unique.starts(with: [14, 5, 4, 3, 2]) {
            return 5
        }

        for i in 0...(unique.count - 5) {
            let slice = Array(unique[i..<(i + 5)])
            if slice[0] - slice[4] == 4, Set(slice).count == 5 {
                return slice[0]
            }
        }

        return nil
    }
}
