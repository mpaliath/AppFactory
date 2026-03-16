import Foundation

enum MiniAppRegistry {
    static let availableApps: [MiniApp] = [
        MiniApp(
            id: "todo",
            name: "Todo",
            description: "Track tasks with a simple checklist."
        ),
        MiniApp(
            id: "recipefinder",
            name: "Recipe Finder",
            description: "Find one web recipe by cuisine and time limits."
        )
    ]
}
