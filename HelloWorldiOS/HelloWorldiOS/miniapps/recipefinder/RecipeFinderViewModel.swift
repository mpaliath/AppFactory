import Foundation

@MainActor
final class RecipeFinderViewModel: ObservableObject {
    @Published var selectedCuisine = "Italian"
    @Published var selectedPrepTimeRange: RecipeTimeRange = .upTo30
    @Published var selectedCookTimeRange: RecipeTimeRange = .upTo30
    @Published var isLoading = false
    @Published var recipe: WebRecipe?
    @Published var errorMessage: String?
    @Published var currentStepIndex = 0

    let cuisines = [
        "Italian", "Mexican", "Indian", "Thai", "Japanese", "Greek", "Mediterranean", "French", "American"
    ]

    private let service: RecipeFinderService

    init(service: RecipeFinderService = RecipeFinderService()) {
        self.service = service
    }

    func findRecipe() async {
        isLoading = true
        errorMessage = nil
        recipe = nil
        currentStepIndex = 0

        let criteria = RecipeSearchCriteria(
            cuisine: selectedCuisine,
            prepTimeRange: selectedPrepTimeRange,
            cookTimeRange: selectedCookTimeRange
        )

        do {
            recipe = try await service.findBestRecipe(for: criteria)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }

        isLoading = false
    }

    func goToNextStep() {
        guard let recipe else { return }
        currentStepIndex = min(currentStepIndex + 1, recipe.steps.count - 1)
    }

    func goToPreviousStep() {
        currentStepIndex = max(currentStepIndex - 1, 0)
    }
}
