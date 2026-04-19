import Foundation

struct ScannedContact {
    var fullName: String = ""
    var companyName: String = ""
    var phoneNumbers: [String] = [""]
    var notes: String = ""

    var canSave: Bool {
        !fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct ScannedTextBlock: Identifiable, Equatable {
    let id: UUID
    var text: String

    init(id: UUID = UUID(), text: String) {
        self.id = id
        self.text = text
    }
}

struct ParsedCardScan {
    var textBlocks: [ScannedTextBlock]
    var phoneNumbers: [String]
}
