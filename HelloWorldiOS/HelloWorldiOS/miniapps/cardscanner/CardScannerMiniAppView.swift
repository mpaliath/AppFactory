import SwiftUI

struct CardScannerMiniAppView: View {
    @StateObject private var viewModel = CardScannerViewModel()

    var body: some View {
        Form {
            Section("Scan") {
                Button("Take Card Photo") {
                    viewModel.isShowingCamera = true
                }

                if let image = viewModel.capturedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }

            Section("Detected Details") {
                TextField("Full Name", text: $viewModel.scannedContact.fullName)
                    .textInputAutocapitalization(.words)
                TextField("Phone Number", text: $viewModel.scannedContact.phoneNumber)
                    .keyboardType(.phonePad)
                TextField("Company", text: $viewModel.scannedContact.companyName)
                    .textInputAutocapitalization(.words)
            }

            Section {
                Button {
                    Task {
                        await viewModel.saveContact()
                    }
                } label: {
                    if viewModel.isSaving {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Save Contact")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(viewModel.isSaving || !viewModel.scannedContact.canSave)
            }

            if let message = viewModel.statusMessage {
                Section("Status") {
                    Text(message)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Card Scanner")
        .sheet(isPresented: $viewModel.isShowingCamera) {
            CardScannerCameraPicker { image in
                viewModel.handleCapturedImage(image)
            }
            .ignoresSafeArea()
        }
    }
}

#Preview {
    NavigationStack {
        CardScannerMiniAppView()
    }
}
