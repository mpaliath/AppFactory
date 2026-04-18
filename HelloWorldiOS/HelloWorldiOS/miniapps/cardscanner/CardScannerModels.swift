import Foundation

struct ScannedContact {
    var fullName: String = ""
    var phoneNumber: String = ""
    var companyName: String = ""

    var canSave: Bool {
        !fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
