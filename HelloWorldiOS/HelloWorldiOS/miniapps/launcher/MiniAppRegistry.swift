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
        ),
        MiniApp(
            id: "poker",
            name: "Texas Hold'em Poker",
            description: "Play hold'em against up to 5 CPU opponents."
        ),
        MiniApp(
            id: "timeaudit",
            name: "Time Audit",
            description: "Passive check-ins that show where your day really went."
        ),
        MiniApp(
            id: "cardscanner",
            name: "Card Scanner",
            description: "Scan a business card and save it as a contact."
        ),
        MiniApp(
            id: "whiteboard",
            name: "Infinite Whiteboard",
            description: "Sketch, zoom, pan, and change ink color with a long press."
        )
    ]
}
