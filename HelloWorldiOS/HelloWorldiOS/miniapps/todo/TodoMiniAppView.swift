import SwiftUI

struct TodoMiniAppView: View {
    @State private var todos: [TodoItem] = []
    @State private var newTodoTitle = ""

    var body: some View {
        VStack(spacing: 16) {
            TodoInputRow(newTodoTitle: $newTodoTitle, onAddTodo: addTodo)

            if todos.isEmpty {
                TodoEmptyStateView()
            } else {
                TodoListView(todos: todos, onToggle: toggle, onDelete: delete)
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

private struct TodoInputRow: View {
    @Binding var newTodoTitle: String
    let onAddTodo: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            TextField("Add a todo", text: $newTodoTitle)
                .textFieldStyle(.roundedBorder)
                .submitLabel(.done)
                .onSubmit(onAddTodo)

            Button("Add", action: onAddTodo)
                .buttonStyle(.borderedProminent)
                .disabled(trimmedTitle.isEmpty)
        }
    }

    private var trimmedTitle: String {
        newTodoTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct TodoEmptyStateView: View {
    var body: some View {
        ContentUnavailableView(
            "No Todos Yet",
            systemImage: "checklist",
            description: Text("Add your first task to get started.")
        )
    }
}

private struct TodoListView: View {
    let todos: [TodoItem]
    let onToggle: (TodoItem) -> Void
    let onDelete: (TodoItem) -> Void

    var body: some View {
        List {
            ForEach(todos) { todo in
                TodoListItemView(todo: todo, onToggle: { onToggle(todo) }, onDelete: { onDelete(todo) })
                    .padding(.vertical, 2)
            }
        }
        .listStyle(.plain)
    }
}

private struct TodoListItemView: View {
    let todo: TodoItem
    let onToggle: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack {
            Button(action: onToggle) {
                Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(todo.isCompleted ? .green : .secondary)
            }
            .buttonStyle(.plain)

            Text(todo.title)
                .strikethrough(todo.isCompleted, color: .secondary)
                .foregroundStyle(todo.isCompleted ? .secondary : .primary)

            Spacer()

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    NavigationStack {
        TodoMiniAppView()
    }
}
