import SwiftUI

struct InfiniteWhiteboardMiniAppView: View {
    @State private var selectedColor: Color = .black
    @State private var isShowingColorPicker = false
    @State private var shouldClearCanvas = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            InfiniteWhiteboardCanvas(
                selectedColor: $selectedColor,
                shouldClear: $shouldClearCanvas,
                onLongPress: { isShowingColorPicker = true }
            )
            .ignoresSafeArea(edges: .bottom)

            WhiteboardToolbar(
                selectedColor: selectedColor,
                onPickColor: { isShowingColorPicker = true },
                onClear: { shouldClearCanvas = true }
            )
            .padding()

            WhiteboardInstructionBanner()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding()
                .allowsHitTesting(false)
        }
        .navigationTitle("Whiteboard")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isShowingColorPicker) {
            WhiteboardColorPickerSheet(selectedColor: $selectedColor)
                .presentationDetents([.height(220)])
        }
    }
}

private struct WhiteboardInstructionBanner: View {
    var body: some View {
        Text("Draw with one finger • Pinch to zoom • Pan with two fingers • Long press for color")
            .font(.caption)
            .multilineTextAlignment(.center)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.thinMaterial, in: Capsule())
    }
}

private struct WhiteboardToolbar: View {
    let selectedColor: Color
    let onPickColor: () -> Void
    let onClear: () -> Void

    var body: some View {
        VStack(alignment: .trailing, spacing: 12) {
            Button(action: onPickColor) {
                Label("Color", systemImage: "paintpalette.fill")
                    .labelStyle(.iconOnly)
                    .font(.title3)
                    .foregroundStyle(selectedColor)
                    .frame(width: 44, height: 44)
                    .background(.thinMaterial, in: Circle())
            }
            .accessibilityLabel("Choose sketch color")

            Button(role: .destructive, action: onClear) {
                Label("Clear", systemImage: "trash")
                    .labelStyle(.iconOnly)
                    .font(.title3)
                    .frame(width: 44, height: 44)
                    .background(.thinMaterial, in: Circle())
            }
            .accessibilityLabel("Clear whiteboard")
        }
    }
}

private struct WhiteboardColorPickerSheet: View {
    @Binding var selectedColor: Color
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                ColorPicker("Sketch color", selection: $selectedColor, supportsOpacity: false)
            }
            .navigationTitle("Sketch Color")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        InfiniteWhiteboardMiniAppView()
    }
}
