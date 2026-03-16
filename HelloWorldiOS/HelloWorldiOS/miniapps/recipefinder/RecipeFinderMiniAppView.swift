import SwiftUI

struct RecipeFinderMiniAppView: View {
    @StateObject private var viewModel = RecipeFinderViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                RecipeSearchFormView(
                    cuisines: viewModel.cuisines,
                    selectedCuisine: $viewModel.selectedCuisine,
                    selectedPrepTimeRange: $viewModel.selectedPrepTimeRange,
                    selectedCookTimeRange: $viewModel.selectedCookTimeRange,
                    isLoading: viewModel.isLoading,
                    onFindRecipe: {
                        Task { await viewModel.findRecipe() }
                    }
                )

                if let message = viewModel.errorMessage {
                    RecipeErrorView(message: message)
                }

                if let recipe = viewModel.recipe {
                    RecipeResultView(
                        recipe: recipe,
                        currentStepIndex: viewModel.currentStepIndex,
                        onPreviousStep: viewModel.goToPreviousStep,
                        onNextStep: viewModel.goToNextStep
                    )
                }
            }
            .padding()
        }
        .navigationTitle("Recipe Finder")
    }
}

#Preview {
    NavigationStack {
        RecipeFinderMiniAppView()
    }
}
