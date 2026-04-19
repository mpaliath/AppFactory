import PhotosUI
import SwiftUI

struct CardScannerMiniAppView: View {
    @StateObject private var viewModel = CardScannerViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
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
            .padding()
        }
        .navigationTitle("Card Scanner")
        .sheet(isPresented: $viewModel.isShowingCamera) {
            CardScannerCameraPicker { image in
                viewModel.handleCapturedImage(image)
            }
            .ignoresSafeArea()
        }
        .photosPicker(
            isPresented: $viewModel.isShowingPhotoPicker,
            selection: Binding(
                get: { nil },
                set: { item in
                    guard let item else { return }
                    Task {
                        if let data = try? await item.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            viewModel.handleCapturedImage(image)
                        }
                    }
                }
            ),
            matching: .images
        )
    }

    private var scanSection: some View {
        GroupBox("Scan") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Button {
                        viewModel.isShowingCamera = true
                    } label: {
                        Label("Camera", systemImage: "camera")
                    }

                    Button {
                        viewModel.isShowingPhotoPicker = true
                    } label: {
                        Label("Photo Library", systemImage: "photo.on.rectangle")
                    }
                }

                if let image = viewModel.capturedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var saveSection: some View {
        GroupBox {
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
            GroupBox("Status") {
                Text(message)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

#Preview {
    NavigationStack {
        CardScannerMiniAppView()
    }
}
