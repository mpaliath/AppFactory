import Contacts
import SwiftUI
import UIKit
import Vision

@MainActor
final class CardScannerViewModel: ObservableObject {
    @Published var scannedContact = ScannedContact()
    @Published var isShowingCamera = false
    @Published var isSaving = false
    @Published var statusMessage: String?
    @Published var capturedImage: UIImage?

    private let parser = CardScannerTextParser()
    private let contactStore = CNContactStore()

    func handleCapturedImage(_ image: UIImage) {
        capturedImage = image
        statusMessage = nil

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

            let parsedContact = self.parser.parse(lines: lines)
            Task { @MainActor in
                self.scannedContact = parsedContact
                self.statusMessage = "Review details, then save the contact."
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

    private func requestAccessIfNeeded() async throws {
        if CNContactStore.authorizationStatus(for: .contacts) == .authorized {
            return
        }

        try await withCheckedThrowingContinuation { continuation in
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

        if !scannedContact.phoneNumber.isEmpty {
            let phone = CNLabeledValue(
                label: CNLabelPhoneNumberMain,
                value: CNPhoneNumber(stringValue: scannedContact.phoneNumber)
            )
            mutableContact.phoneNumbers = [phone]
        }

        let saveRequest = CNSaveRequest()
        saveRequest.add(mutableContact, toContainerWithIdentifier: nil)
        try contactStore.execute(saveRequest)
    }
}
