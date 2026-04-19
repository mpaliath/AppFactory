import Foundation
import CoreTransferable

struct ScannedContact {
    var fullName: String = ""
    var companyName: String = ""
    var emailAddress: String = ""
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

struct BlockDragItem: Codable, Transferable {
    let blockID: String

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .blockDragItem)
    }
}

import UniformTypeIdentifiers

extension UTType {
    static let blockDragItem = UTType(exportedAs: "com.appfactory.cardscanner.blockdragitem")
}

struct ParsedCardScan {
    var textBlocks: [ScannedTextBlock]
    var emailAddresses: [String]
    var phoneNumbers: [String]
}
