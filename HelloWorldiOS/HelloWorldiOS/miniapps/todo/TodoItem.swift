import Foundation

struct TodoItem: Identifiable {
    let id = UUID()
    let title: String
    var isCompleted: Bool = false
}
