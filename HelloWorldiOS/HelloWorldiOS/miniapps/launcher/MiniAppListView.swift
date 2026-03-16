import SwiftUI

struct MiniAppListView: View {
    var body: some View {
        NavigationStack {
            List(MiniAppRegistry.availableApps) { miniApp in
                NavigationLink(value: miniApp.id) {
                    MiniAppRowView(miniApp: miniApp)
                }
            }
            .navigationTitle("Mini Apps")
            .navigationDestination(for: String.self) { destination in
                MiniAppDestinationView(destination: destination)
            }
        }
    }
}

private struct MiniAppRowView: View {
    let miniApp: MiniApp

    var body: some View {
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

private struct MiniAppDestinationView: View {
    let destination: String

    var body: some View {
        switch destination {
        case "todo":
            TodoMiniAppView()
        case "recipefinder":
            RecipeFinderMiniAppView()
        default:
            Text("Mini app unavailable.")
        }
    }
}

#Preview {
    MiniAppListView()
}
