import SwiftUI

struct CardScannerMiniAppView: View {
    @StateObject private var viewModel = CardScannerViewModel()

    var body: some View {
        Form {
            scanSection

            if viewModel.isInReviewStep {
                CardScannerTokenPoolView(
                    blocks: viewModel.availableBlocks,
                    onMerge: viewModel.mergeBlock(sourceID:into:)
                )

                CardScannerDropFormView(viewModel: viewModel)
            }

            saveSection
            statusSection
        }
        .navigationTitle("Card Scanner")
        .sheet(isPresented: $viewModel.isShowingCamera) {
            CardScannerCameraPicker { image in
                viewModel.handleCapturedImage(image)
            }
            .ignoresSafeArea()
        }
    }

    private var scanSection: some View {
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
    }

    private var saveSection: some View {
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
    }

    @ViewBuilder
    private var statusSection: some View {
        if let message = viewModel.statusMessage {
            Section("Status") {
                Text(message)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    NavigationStack {
        CardScannerMiniAppView()
    }
}
