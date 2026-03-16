import Foundation

struct RecipeFinderService {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func findBestRecipe(for criteria: RecipeSearchCriteria) async throws -> WebRecipe {
        let links = try await searchResultLinks(for: criteria.queryText)
        for link in links.prefix(8) {
            guard let recipe = try await fetchRecipe(from: link) else { continue }
            let prepCandidate = recipe.prepMinutes ?? recipe.totalMinutes
            let cookCandidate = recipe.cookMinutes ?? recipe.totalMinutes
            if criteria.prepTimeRange.contains(prepCandidate) && criteria.cookTimeRange.contains(cookCandidate) {
                return recipe
            }
        }
        throw RecipeFinderError.noMatchingRecipe
    }

    private func searchResultLinks(for query: String) async throws -> [URL] {
        guard var components = URLComponents(string: "https://duckduckgo.com/html/") else { return [] }
        components.queryItems = [URLQueryItem(name: "q", value: query)]
        guard let url = components.url else { return [] }

        let (data, _) = try await session.data(from: url)
        guard let html = String(data: data, encoding: .utf8) else { return [] }

        let pattern = "result__a\" href=\"([^\"]+)\""
        let regex = try NSRegularExpression(pattern: pattern)
        let nsrange = NSRange(html.startIndex..<html.endIndex, in: html)

        var urls: [URL] = []
        regex.enumerateMatches(in: html, range: nsrange) { match, _, _ in
            guard
                let match,
                let hrefRange = Range(match.range(at: 1), in: html)
            else { return }

            let rawHref = String(html[hrefRange])
            let decoded = rawHref.removingPercentEncoding ?? rawHref
            if let resolved = Self.extractDuckDuckGoTarget(from: decoded), !urls.contains(resolved) {
                urls.append(resolved)
            }
        }

        return urls
    }

    private static func extractDuckDuckGoTarget(from href: String) -> URL? {
        if href.hasPrefix("http"), let url = URL(string: href), url.scheme == "https" {
            return url
        }

        guard let components = URLComponents(string: "https://duckduckgo.com\(href)") else { return nil }
        guard let target = components.queryItems?.first(where: { $0.name == "uddg" })?.value else { return nil }
        guard let cleaned = target.removingPercentEncoding else { return nil }
        guard let url = URL(string: cleaned), url.scheme == "https" else { return nil }
        return url
    }

    private func fetchRecipe(from sourceURL: URL) async throws -> WebRecipe? {
        let (data, _) = try await session.data(from: sourceURL)
        guard let html = String(data: data, encoding: .utf8) else { return nil }

        let jsonBlocks = extractJSONLDBlocks(from: html)
        for block in jsonBlocks {
            if let recipe = parseRecipe(from: block, sourceURL: sourceURL) {
                return recipe
            }
        }
        return nil
    }

    private func extractJSONLDBlocks(from html: String) -> [String] {
        let pattern = "<script[^>]*type=\"application/ld\\+json\"[^>]*>([\\s\\S]*?)</script>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }

        let nsrange = NSRange(html.startIndex..<html.endIndex, in: html)
        var blocks: [String] = []

        regex.enumerateMatches(in: html, range: nsrange) { match, _, _ in
            guard
                let match,
                let blockRange = Range(match.range(at: 1), in: html)
            else { return }

            let block = String(html[blockRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !block.isEmpty else { return }
            blocks.append(block)
        }

        return blocks
    }

    private func parseRecipe(from jsonText: String, sourceURL: URL) -> WebRecipe? {
        guard let data = jsonText.data(using: .utf8) else { return nil }
        guard let object = try? JSONSerialization.jsonObject(with: data) else { return nil }

        if let dict = object as? [String: Any] {
            if let recipe = parseRecipeObject(dict, sourceURL: sourceURL) {
                return recipe
            }
            if let graph = dict["@graph"] as? [[String: Any]] {
                for graphItem in graph {
                    if let recipe = parseRecipeObject(graphItem, sourceURL: sourceURL) {
                        return recipe
                    }
                }
            }
        }

        if let array = object as? [[String: Any]] {
            for item in array {
                if let recipe = parseRecipeObject(item, sourceURL: sourceURL) {
                    return recipe
                }
                if let graph = item["@graph"] as? [[String: Any]] {
                    for graphItem in graph {
                        if let recipe = parseRecipeObject(graphItem, sourceURL: sourceURL) {
                            return recipe
                        }
                    }
                }
            }
        }

        return nil
    }

    private func parseRecipeObject(_ dict: [String: Any], sourceURL: URL) -> WebRecipe? {
        guard isRecipeType(dict["@type"]) else { return nil }
        guard let title = dict["name"] as? String, !title.isEmpty else { return nil }

        let description = (dict["description"] as? String) ?? ""
        let ingredients = (dict["recipeIngredient"] as? [String]) ?? []
        let steps = parseInstructions(dict["recipeInstructions"])
        guard !steps.isEmpty else { return nil }

        let prepMinutes = Self.durationToMinutes(dict["prepTime"] as? String)
        let cookMinutes = Self.durationToMinutes(dict["cookTime"] as? String)
        let totalMinutes = Self.durationToMinutes(dict["totalTime"] as? String)

        return WebRecipe(
            title: title,
            sourceURL: sourceURL,
            description: description,
            prepMinutes: prepMinutes,
            cookMinutes: cookMinutes,
            totalMinutes: totalMinutes,
            ingredients: ingredients,
            steps: steps
        )
    }

    private func isRecipeType(_ typeValue: Any?) -> Bool {
        if let type = typeValue as? String {
            return type.lowercased().contains("recipe")
        }

        if let types = typeValue as? [String] {
            return types.contains(where: { $0.lowercased().contains("recipe") })
        }

        return false
    }

    private func parseInstructions(_ value: Any?) -> [String] {
        if let text = value as? String {
            return [text]
        }

        if let list = value as? [String] {
            return list.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        }

        if let list = value as? [[String: Any]] {
            return list.compactMap { item in
                if let text = item["text"] as? String, !text.isEmpty {
                    return text
                }
                if let name = item["name"] as? String, !name.isEmpty {
                    return name
                }
                return nil
            }
        }

        return []
    }

    private static func durationToMinutes(_ iso8601Duration: String?) -> Int? {
        guard let iso8601Duration else { return nil }
        let pattern = "PT(?:(\\d+)H)?(?:(\\d+)M)?"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(iso8601Duration.startIndex..<iso8601Duration.endIndex, in: iso8601Duration)
        guard let match = regex.firstMatch(in: iso8601Duration, range: range) else { return nil }

        let hoursRange = Range(match.range(at: 1), in: iso8601Duration)
        let minutesRange = Range(match.range(at: 2), in: iso8601Duration)

        let hours = hoursRange.flatMap { Int(iso8601Duration[$0]) } ?? 0
        let minutes = minutesRange.flatMap { Int(iso8601Duration[$0]) } ?? 0

        let total = (hours * 60) + minutes
        return total > 0 ? total : nil
    }
}
