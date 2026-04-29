import SwiftUI
import UniformTypeIdentifiers

struct SourcePanelView: View {
    @Binding var plan: Plan
    @State private var editingID: UUID?
    @State private var editingAlias: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("SOURCES")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
                    .tracking(1.5)
                Spacer()
                Menu {
                    ForEach(SourceKind.allCases, id: \.self) { kind in
                        Button(action: { addSource(kind: kind) }) {
                            Label(kind.label, systemImage: kind.systemImage)
                        }
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(width: 24, height: 24)
                }
                .menuStyle(.borderlessButton)
                .frame(width: 24, height: 24)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider().background(Color.white.opacity(0.06))

            // Source list
            if plan.sources.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "doc.badge.plus")
                        .font(.system(size: 24))
                        .foregroundStyle(.white.opacity(0.15))
                    Text("Add PDFs, images, or videos\nusing the + button above")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.25))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(plan.sources) { source in
                            SourceRow(
                                source: source,
                                isEditing: editingID == source.id,
                                editingAlias: $editingAlias,
                                onCommitEdit: { commitEdit(id: source.id) },
                                onStartEdit: { startEdit(source) },
                                onDelete: { deleteSource(id: source.id) }
                            )
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    // MARK: - Helpers

    private func addSource(kind: SourceKind) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        let utTypes = kind.allowedExtensions.compactMap { UTType(filenameExtension: $0) }
        panel.allowedContentTypes = utTypes.isEmpty ? [.data] : utTypes

        guard panel.runModal() == .OK else { return }

        for url in panel.urls {
            let alias = nextAlias(for: kind)
            let src = SourceFile(alias: alias, path: url.path, kind: kind)
            plan.sources.append(src)
        }
    }

    private func nextAlias(for kind: SourceKind) -> String {
        var counter = 1
        let existing = Set(plan.sources.map { $0.alias })
        while existing.contains("\(kind.aliasPrefix)\(counter)") { counter += 1 }
        return "\(kind.aliasPrefix)\(counter)"
    }

    private func startEdit(_ source: SourceFile) {
        editingID = source.id
        editingAlias = source.alias
    }

    private func commitEdit(id: UUID) {
        if let idx = plan.sources.firstIndex(where: { $0.id == id }) {
            let trimmed = editingAlias.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty {
                plan.sources[idx].alias = trimmed
            }
        }
        editingID = nil
    }

    private func deleteSource(id: UUID) {
        plan.sources.removeAll { $0.id == id }
    }
}

// MARK: - Source Row

struct SourceRow: View {
    let source: SourceFile
    let isEditing: Bool
    @Binding var editingAlias: String
    let onCommitEdit: () -> Void
    let onStartEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: source.kind.systemImage)
                .font(.system(size: 12))
                .foregroundStyle(kindColor(source.kind))
                .frame(width: 16)

            if isEditing {
                TextField("alias", text: $editingAlias)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(.white)
                    .onSubmit(onCommitEdit)
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text(source.alias)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.9))
                    Text(URL(fileURLWithPath: source.path).lastPathComponent)
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.35))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Spacer()

            if !isEditing {
                HStack(spacing: 4) {
                    Button(action: onStartEdit) {
                        Image(systemName: "pencil")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(IconButtonStyle())

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(IconButtonStyle(tint: .red))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Color.white.opacity(isEditing ? 0.06 : 0))
        .contentShape(Rectangle())
        .onTapGesture { if !isEditing { onStartEdit() } }
    }

    private func kindColor(_ kind: SourceKind) -> Color {
        switch kind {
        case .pdf:   return Color(hex: "#8b5cf6")
        case .image: return Color(hex: "#34d399")
        case .video: return Color(hex: "#f59e0b")
        }
    }
}

// MARK: - Icon Button Style

struct IconButtonStyle: ButtonStyle {
    var tint: Color = .white

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(tint.opacity(configuration.isPressed ? 0.4 : 0.35))
            .frame(width: 22, height: 22)
            .background(Color.white.opacity(configuration.isPressed ? 0.08 : 0))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
