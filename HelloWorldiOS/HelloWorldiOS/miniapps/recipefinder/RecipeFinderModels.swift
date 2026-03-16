import Foundation

struct RecipeSearchCriteria {
    let cuisine: String
    let prepTimeRange: RecipeTimeRange
    let cookTimeRange: RecipeTimeRange

    var queryText: String {
        "\(cuisine) recipe prep time \(prepTimeRange.queryHint) cook time \(cookTimeRange.queryHint)"
    }
}

struct WebRecipe: Identifiable {
    let id = UUID()
    let title: String
    let sourceURL: URL
    let description: String
    let prepMinutes: Int?
    let cookMinutes: Int?
    let totalMinutes: Int?
    let ingredients: [String]
    let steps: [String]
}

enum RecipeTimeRange: String, CaseIterable, Identifiable {
    case upTo15 = "Up to 15 min"
    case upTo30 = "Up to 30 min"
    case upTo45 = "Up to 45 min"
    case upTo60 = "Up to 60 min"

    var id: String { rawValue }

    var maxMinutes: Int {
        switch self {
        case .upTo15: 15
        case .upTo30: 30
        case .upTo45: 45
        case .upTo60: 60
        }
    }

    var queryHint: String {
        "under \(maxMinutes) minutes"
    }

    func contains(_ minutes: Int?) -> Bool {
        guard let minutes else { return false }
        return minutes <= maxMinutes
    }
}

enum RecipeFinderError: LocalizedError {
    case noMatchingRecipe

    var errorDescription: String? {
        switch self {
        case .noMatchingRecipe:
            "I couldn't find a recipe that matched those selections. Try a wider time range."
        }
    }
}
