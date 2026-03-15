import SwiftUI

struct MiniApp: Identifiable {
    let id: String
    let name: String
    let description: String
}

struct TodoItem: Identifiable {
    let id = UUID()
    let title: String
    var isCompleted: Bool = false
}

struct ContentView: View {
    private let miniApps: [MiniApp] = [
        MiniApp(
            id: "todo",
            name: "Todo",
            description: "Track tasks with a simple checklist."
        )
    ]

    var body: some View {
        NavigationStack {
            List(miniApps) { miniApp in
                NavigationLink(value: miniApp.id) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(miniApp.name)
                            .font(.headline)
                        Text(miniApp.description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Mini Apps")
            .navigationDestination(for: String.self) { destination in
                switch destination {
                case "todo":
                    TodoMiniAppView()
                default:
                    Text("Mini app unavailable.")
                }
            }
        }
    }
}

private struct TodoMiniAppView: View {
    @State private var todos: [TodoItem] = []
    @State private var newTodoTitle = ""

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 8) {
                TextField("Add a todo", text: $newTodoTitle)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.done)
                    .onSubmit(addTodo)

                Button("Add", action: addTodo)
                    .buttonStyle(.borderedProminent)
                    .disabled(newTodoTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if todos.isEmpty {
                ContentUnavailableView(
                    "No Todos Yet",
                    systemImage: "checklist",
                    description: Text("Add your first task to get started.")
                )
            } else {
                List {
                    ForEach(todos) { todo in
                        HStack {
                            Button {
                                toggle(todo)
                            } label: {
                                Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(todo.isCompleted ? .green : .secondary)
                            }
                            .buttonStyle(.plain)

                            Text(todo.title)
                                .strikethrough(todo.isCompleted, color: .secondary)
                                .foregroundStyle(todo.isCompleted ? .secondary : .primary)

                            Spacer()

                            Button(role: .destructive) {
                                delete(todo)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 2)
                    }
                }
                .listStyle(.plain)
            }
        }
        .padding()
        .navigationTitle("Todo")
    }

    private func addTodo() {
        let title = newTodoTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }

        todos.append(TodoItem(title: title))
        newTodoTitle = ""
    }

    private func toggle(_ item: TodoItem) {
        guard let index = todos.firstIndex(where: { $0.id == item.id }) else { return }
        todos[index].isCompleted.toggle()
    }

    private func delete(_ item: TodoItem) {
        todos.removeAll { $0.id == item.id }
    }
}

#Preview {
    ContentView()
}
