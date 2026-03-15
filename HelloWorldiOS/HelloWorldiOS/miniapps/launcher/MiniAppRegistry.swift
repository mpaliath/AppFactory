import Foundation

enum MiniAppRegistry {
    static let availableApps: [MiniApp] = [
        MiniApp(
            id: "todo",
            name: "Todo",
            description: "Track tasks with a simple checklist."
        )
    ]
}
