import Foundation

struct CardScannerTextParser {
    func parse(lines: [String]) -> ScannedContact {
        let cleanedLines = lines
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let phoneLine = cleanedLines.first(where: isLikelyPhoneNumber) ?? ""
        let companyLine = cleanedLines.first(where: isLikelyCompanyName) ?? ""

        let nameLine = cleanedLines.first { line in
            !isLikelyPhoneNumber(line)
                && !isLikelyEmail(line)
                && !isLikelyAddress(line)
                && !isLikelyCompanyName(line)
                && looksLikePersonName(line)
        } ?? cleanedLines.first ?? ""

        return ScannedContact(
            fullName: normalizeName(nameLine),
            phoneNumber: normalizePhone(phoneLine),
            companyName: companyLine
        )
    }

    private func isLikelyPhoneNumber(_ text: String) -> Bool {
        let digitCount = text.filter { $0.isNumber }.count
        return digitCount >= 10
    }

    private func isLikelyEmail(_ text: String) -> Bool {
        text.contains("@")
    }

    private func isLikelyAddress(_ text: String) -> Bool {
        let lowercased = text.lowercased()
        return lowercased.contains("street")
            || lowercased.contains("st.")
            || lowercased.contains("avenue")
            || lowercased.contains("ave")
            || lowercased.contains("road")
            || lowercased.contains("rd")
            || lowercased.contains("suite")
    }

    private func isLikelyCompanyName(_ text: String) -> Bool {
        let lowercased = text.lowercased()
        return lowercased.contains("inc")
            || lowercased.contains("llc")
            || lowercased.contains("corp")
            || lowercased.contains("company")
            || lowercased.contains("co.")
            || lowercased.contains("technologies")
    }

    private func looksLikePersonName(_ text: String) -> Bool {
        let words = text.split(separator: " ")
        guard words.count >= 2 && words.count <= 4 else {
            return false
        }

        return words.allSatisfy { word in
            guard let firstCharacter = word.first else {
                return false
            }
            return firstCharacter.isUppercase
        }
    }

    private func normalizeName(_ text: String) -> String {
        text
            .split(separator: " ")
            .map { $0.capitalized }
            .joined(separator: " ")
    }

    private func normalizePhone(_ text: String) -> String {
        let allowedCharacters = CharacterSet(charactersIn: "+0123456789()- .")
        return text.unicodeScalars.filter { allowedCharacters.contains($0) }.map(String.init).joined()
    }
}
