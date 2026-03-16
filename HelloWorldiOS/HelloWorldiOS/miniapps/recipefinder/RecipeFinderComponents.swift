import SwiftUI

struct RecipeSearchFormView: View {
    let cuisines: [String]
    @Binding var selectedCuisine: String
    @Binding var selectedPrepTimeRange: RecipeTimeRange
    @Binding var selectedCookTimeRange: RecipeTimeRange
    let isLoading: Bool
    let onFindRecipe: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Find a recipe")
                .font(.headline)

            Picker("Cuisine", selection: $selectedCuisine) {
                ForEach(cuisines, id: \.self) { cuisine in
                    Text(cuisine).tag(cuisine)
                }
            }
            .pickerStyle(.menu)

            Picker("Prep time", selection: $selectedPrepTimeRange) {
                ForEach(RecipeTimeRange.allCases) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(.segmented)

            Picker("Cook time", selection: $selectedCookTimeRange) {
                ForEach(RecipeTimeRange.allCases) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(.segmented)

            Button(action: onFindRecipe) {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Find Best Match")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isLoading)
        }
    }
}

struct RecipeErrorView: View {
    let message: String

    var body: some View {
        ContentUnavailableView(
            "No Recipe Match",
            systemImage: "fork.knife.circle",
            description: Text(message)
        )
    }
}

struct RecipeResultView: View {
    let recipe: WebRecipe
    let currentStepIndex: Int
    let onPreviousStep: () -> Void
    let onNextStep: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(recipe.title)
                .font(.title3)
                .fontWeight(.semibold)

            if !recipe.description.isEmpty {
                Text(recipe.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 16) {
                RecipeTimeChip(label: "Prep", minutes: recipe.prepMinutes ?? recipe.totalMinutes)
                RecipeTimeChip(label: "Cook", minutes: recipe.cookMinutes ?? recipe.totalMinutes)
            }

            if !recipe.ingredients.isEmpty {
                Text("Ingredients")
                    .font(.headline)
                ForEach(recipe.ingredients.prefix(8), id: \.self) { ingredient in
                    Text("• \(ingredient)")
                        .font(.subheadline)
                }
            }

            Divider()

            Text("Step \(currentStepIndex + 1) of \(recipe.steps.count)")
                .font(.headline)

            Text(recipe.steps[currentStepIndex])
                .font(.body)

            HStack {
                Button("Back", action: onPreviousStep)
                    .disabled(currentStepIndex == 0)

                Spacer()

                Button("Next", action: onNextStep)
                    .disabled(currentStepIndex >= recipe.steps.count - 1)
            }
            .buttonStyle(.bordered)

            Link("Open source recipe", destination: recipe.sourceURL)
                .font(.footnote)
        }
    }
}

private struct RecipeTimeChip: View {
    let label: String
    let minutes: Int?

    var body: some View {
        Label {
            Text("\(label): \(minutesText)")
        } icon: {
            Image(systemName: "clock")
        }
        .font(.footnote)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(.secondarySystemBackground))
        .clipShape(Capsule())
    }

    private var minutesText: String {
        guard let minutes else { return "Unknown" }
        return "\(minutes) min"
    }
}
