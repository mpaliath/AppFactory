import SwiftUI

struct CardScannerTokenPoolView: View {
    let blocks: [ScannedTextBlock]
    let onMerge: (UUID, UUID) -> Void

    private let columns = [GridItem(.adaptive(minimum: 120), spacing: 8)]

    var body: some View {
        Section("Scanned Words & Numbers") {
            if blocks.isEmpty {
                Text("All scanned blocks are assigned.")
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                    ForEach(blocks) { block in
                        DraggableBlockChip(text: block.text, id: block.id)
                            .dropDestination(for: String.self) { items, _ in
                                guard let sourceID = items.first.flatMap(UUID.init(uuidString:)) else {
                                    return false
                                }
                                onMerge(sourceID, block.id)
                                return true
                            }
                    }
                }
            }
        }
    }
}

struct CardScannerDropFormView: View {
    @ObservedObject var viewModel: CardScannerViewModel

    var body: some View {
        Section("Detected Details") {
            DroppableField(
                title: "Full Name",
                text: $viewModel.scannedContact.fullName,
                dropField: .fullName,
                onDrop: viewModel.useBlock(_:for:)
            )

            DroppableField(
                title: "Company",
                text: $viewModel.scannedContact.companyName,
                dropField: .company,
                onDrop: viewModel.useBlock(_:for:)
            )

            ForEach(Array(viewModel.scannedContact.phoneNumbers.indices), id: \.self) { index in
                DroppableField(
                    title: "Phone \(index + 1)",
                    text: Binding(
                        get: { viewModel.scannedContact.phoneNumbers[index] },
                        set: { viewModel.scannedContact.phoneNumbers[index] = $0 }
                    ),
                    keyboardType: .phonePad,
                    dropField: .phone(index),
                    onDrop: viewModel.useBlock(_:for:),
                    onTextChange: {
                        viewModel.sanitizePhoneField(at: index)
                    }
                )
            }

            Button("Add Phone") {
                viewModel.addPhoneField()
            }

            DroppableField(
                title: "Notes",
                text: $viewModel.scannedContact.notes,
                dropField: .notes,
                onDrop: viewModel.useBlock(_:for:)
            )
        }
    }
}

struct DroppableField: View {
    let title: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    let dropField: ContactDropField
    let onDrop: (UUID, ContactDropField) -> Void
    var onTextChange: (() -> Void)?

    var body: some View {
        TextField(title, text: $text, axis: title == "Notes" ? .vertical : .horizontal)
            .keyboardType(keyboardType)
            .textInputAutocapitalization(title == "Notes" ? .sentences : .words)
            .lineLimit(title == "Notes" ? 3...6 : 1...1)
            .onChange(of: text) { _, _ in
                onTextChange?()
            }
            .dropDestination(for: String.self) { items, _ in
                guard let blockID = items.first.flatMap(UUID.init(uuidString:)) else {
                    return false
                }
                onDrop(blockID, dropField)
                return true
            }
    }
}

struct DraggableBlockChip: View {
    let text: String
    let id: UUID

    var body: some View {
        Text(text)
            .font(.subheadline)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
            .onDrag {
                NSItemProvider(object: id.uuidString as NSString)
            }
    }
}
