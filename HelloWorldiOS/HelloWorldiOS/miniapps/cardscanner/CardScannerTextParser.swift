import Foundation

struct CardScannerTextParser {
    private let phoneAllowed = CharacterSet(charactersIn: "+0123456789()- ")

    func parse(lines: [String]) -> ParsedCardScan {
        let cleanedLines = lines
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var foundEmails: [String] = []
        var foundPhones: [String] = []
        var blocks: [ScannedTextBlock] = []

        for line in cleanedLines {
            for email in extractEmails(from: line) {
                foundEmails.append(email.lowercased())
            }

            for phone in extractPhoneNumbers(from: line) {
                let normalized = normalizePhone(phone)
                if !normalized.isEmpty {
                    foundPhones.append(normalized)
                }
            }

            let nonPhoneOrEmailText = removePhonesAndEmails(from: line)
            blocks.append(contentsOf: splitIntoTextBlocks(nonPhoneOrEmailText))
        }

        let uniqueEmails = Array(NSOrderedSet(array: foundEmails)) as? [String] ?? foundEmails
        let uniquePhones = Array(NSOrderedSet(array: foundPhones)) as? [String] ?? foundPhones
        let uniqueBlocks = dedupeBlocks(blocks)

        return ParsedCardScan(
            textBlocks: uniqueBlocks,
            emailAddresses: uniqueEmails,
            phoneNumbers: uniquePhones
        )
    }

    func normalizePhone(_ text: String) -> String {
        text
            .unicodeScalars
            .filter { phoneAllowed.contains($0) }
            .map(String.init)
            .joined()
            .replacingOccurrences(of: ".", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractPhoneNumbers(from text: String) -> [String] {
        let pattern = #"(?:\+?\d[\d\s().-]{7,}\d)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return []
        }

        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex.matches(in: text, range: nsRange)
        return matches.compactMap { match in
            guard let range = Range(match.range, in: text) else { return nil }
            return String(text[range])
        }
    }

    private func extractEmails(from text: String) -> [String] {
        let pattern = #"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }

        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex.matches(in: text, range: nsRange)
        return matches.compactMap { match in
            guard let range = Range(match.range, in: text) else { return nil }
            return String(text[range])
        }
    }

    private func removePhonesAndEmails(from text: String) -> String {
        var output = text
        for phone in extractPhoneNumbers(from: text) {
            output = output.replacingOccurrences(of: phone, with: " ")
        }
        for email in extractEmails(from: text) {
            output = output.replacingOccurrences(of: email, with: " ")
        }
        return output
    }

    private func splitIntoTextBlocks(_ text: String) -> [ScannedTextBlock] {
        text
            .split(whereSeparator: { $0.isNewline })
            .flatMap { part in
                part
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .map { ScannedTextBlock(text: $0.capitalized) }
            }
    }

    private func dedupeBlocks(_ blocks: [ScannedTextBlock]) -> [ScannedTextBlock] {
        var seen: Set<String> = []
        return blocks.filter { block in
            let key = block.text.lowercased()
            guard !seen.contains(key) else { return false }
            seen.insert(key)
            return true
        }
    }
}
