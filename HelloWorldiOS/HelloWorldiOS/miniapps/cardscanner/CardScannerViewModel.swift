import Contacts
import SwiftUI
import UIKit
@preconcurrency import Vision

@MainActor
final class CardScannerViewModel: ObservableObject {
    @Published var scannedContact = ScannedContact()
    @Published var isShowingCamera = false
    @Published var isShowingPhotoPicker = false
    @Published var isSaving = false
    @Published var statusMessage: String?
    @Published var capturedImage: UIImage?
    @Published var availableBlocks: [ScannedTextBlock] = []
    @Published var isInReviewStep = false

    private let parser = CardScannerTextParser()
    private let contactStore = CNContactStore()

    func handleCapturedImage(_ image: UIImage) {
        capturedImage = image
        statusMessage = nil
        isInReviewStep = false

        guard let cgImage = image.cgImage else {
            statusMessage = "Couldn't read this image. Please try again."
            return
        }

        let request = VNRecognizeTextRequest { [weak self] request, error in
            guard let self else { return }

            if error != nil {
                Task { @MainActor in
                    self.statusMessage = "Text recognition failed. Try taking another photo."
                }
                return
            }

            let observations = request.results as? [VNRecognizedTextObservation] ?? []
            let lines = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }

            let parsedResult = self.parser.parse(lines: lines)
            Task { @MainActor in
                self.availableBlocks = parsedResult.textBlocks
                self.scannedContact = ScannedContact(
                    fullName: "",
                    companyName: "",
                    emailAddress: parsedResult.emailAddresses.first ?? "",
                    phoneNumbers: Array(repeating: "", count: max(1, parsedResult.phoneNumbers.count)),
                    notes: ""
                )

                for (index, phone) in parsedResult.phoneNumbers.enumerated() {
                    self.assign(phone, toPhoneAt: index)
                }

                self.isInReviewStep = true
                self.statusMessage = "Drag text into fields, then save the contact."
            }
        }

        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        DispatchQueue.global(qos: .userInitiated).async {
            let handler = VNImageRequestHandler(cgImage: cgImage)
            do {
                try handler.perform([request])
            } catch {
                Task { @MainActor in
                    self.statusMessage = "Scanning failed. Please try again."
                }
            }
        }
    }

    func mergeBlock(sourceID: UUID, into targetID: UUID) {
        guard sourceID != targetID,
              let sourceIndex = availableBlocks.firstIndex(where: { $0.id == sourceID }),
              let targetIndex = availableBlocks.firstIndex(where: { $0.id == targetID }) else {
            return
        }

        let sourceText = availableBlocks[sourceIndex].text
        availableBlocks[targetIndex].text = combinedText(availableBlocks[targetIndex].text, sourceText)
        availableBlocks.remove(at: sourceIndex)
    }

    func useBlock(_ blockID: UUID, for field: ContactDropField) {
        guard let index = availableBlocks.firstIndex(where: { $0.id == blockID }) else { return }

        let block = availableBlocks.remove(at: index)
        switch field {
        case .fullName:
            scannedContact.fullName = combinedText(scannedContact.fullName, block.text)
        case .company:
            scannedContact.companyName = combinedText(scannedContact.companyName, block.text)
        case .email:
            scannedContact.emailAddress = combinedText(scannedContact.emailAddress, block.text)
        case let .phone(phoneIndex):
            assign(block.text, toPhoneAt: phoneIndex)
        case .notes:
            scannedContact.notes = combinedText(scannedContact.notes, block.text)
        }
    }

    func addPhoneField() {
        scannedContact.phoneNumbers.append("")
    }

    func sanitizePhoneField(at index: Int) {
        guard scannedContact.phoneNumbers.indices.contains(index) else { return }
        scannedContact.phoneNumbers[index] = parser.normalizePhone(scannedContact.phoneNumbers[index])
    }

    func saveContact() async {
        guard scannedContact.canSave else {
            statusMessage = "A name is required before saving."
            return
        }

        isSaving = true
        defer { isSaving = false }

        do {
            try await requestAccessIfNeeded()
            try createContact()
            statusMessage = "Contact saved to your address book."
        } catch {
            statusMessage = "Unable to save contact. Check contacts permission in Settings."
        }
    }

    private func assign(_ value: String, toPhoneAt index: Int) {
        guard scannedContact.phoneNumbers.indices.contains(index) else { return }
        scannedContact.phoneNumbers[index] = parser.normalizePhone(value)
    }

    private func combinedText(_ base: String, _ newText: String) -> String {
        let trimmedBase = base.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNew = newText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedBase.isEmpty { return trimmedNew }
        if trimmedNew.isEmpty { return trimmedBase }
        return "\(trimmedBase) \(trimmedNew)"
    }

    private func requestAccessIfNeeded() async throws {
        if CNContactStore.authorizationStatus(for: .contacts) == .authorized {
            return
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            contactStore.requestAccess(for: .contacts) { granted, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                if granted {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(throwing: NSError(domain: "CardScanner", code: 1))
                }
            }
        }
    }

    private func createContact() throws {
        let mutableContact = CNMutableContact()
        let components = scannedContact.fullName.split(separator: " ")

        if let firstName = components.first {
            mutableContact.givenName = String(firstName)
        }

        if components.count > 1 {
            mutableContact.familyName = components.dropFirst().joined(separator: " ")
        }

        mutableContact.organizationName = scannedContact.companyName
        mutableContact.note = scannedContact.notes
        let trimmedEmail = scannedContact.emailAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedEmail.isEmpty {
            mutableContact.emailAddresses = [
                CNLabeledValue(label: CNLabelWork, value: trimmedEmail as NSString)
            ]
        }

        let phoneValues = scannedContact.phoneNumbers
            .map { parser.normalizePhone($0) }
            .filter { !$0.isEmpty }

        mutableContact.phoneNumbers = phoneValues.map {
            CNLabeledValue(label: CNLabelPhoneNumberMain, value: CNPhoneNumber(stringValue: $0))
        }

        let saveRequest = CNSaveRequest()
        saveRequest.add(mutableContact, toContainerWithIdentifier: nil)
        try contactStore.execute(saveRequest)
    }
}

enum ContactDropField: Hashable {
    case fullName
    case company
    case email
    case phone(Int)
    case notes
}
