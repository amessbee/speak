import SwiftUI

struct ActionEditorSheet: View {
    let plan: Plan
    let onCommit: (PlanAction) -> Void
    let editing: PlanAction?

    @Environment(\.dismiss) private var dismiss

    // Action type picker
    @State private var selectedType: ActionType = .pdfSlides

    // PDF Slides fields
    @State private var pdfAlias: String = ""
    @State private var rangeType: RangePickerType = .all
    @State private var rangeN: String = ""
    @State private var rangeFrom: String = ""
    @State private var rangeTo: String = ""

    // Video / Image fields
    @State private var mediaAlias: String = ""

    // Conditional fields
    @State private var triggerKey: String = ""
    @State private var ifBranchType: BranchPickerType = .advance
    @State private var ifJumpOffset: String = ""
    @State private var ifPlayAlias: String = ""
    @State private var elseBranchType: BranchPickerType = .advance
    @State private var elseJumpOffset: String = ""

    enum ActionType: String, CaseIterable {
        case pdfSlides = "PDF Slides"
        case video = "Video"
        case image = "Image"
        case conditional = "Conditional"
    }

    enum RangePickerType: String, CaseIterable {
        case all = "All pages"
        case first = "First N pages"
        case suffix = "From page N"
        case range = "Page range"
    }

    enum BranchPickerType: String, CaseIterable {
        case advance = "Advance"
        case jumpBy = "Jump by N"
        case playThenAdvance = "Play media then advance"
    }

    init(plan: Plan, editing: PlanAction? = nil, onCommit: @escaping (PlanAction) -> Void) {
        self.plan = plan
        self.editing = editing
        self.onCommit = onCommit
    }

    var body: some View {
        VStack(spacing: 0) {
            // Sheet header
            HStack {
                Text(editing == nil ? "Add Action" : "Edit Action")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 16)

            Divider().background(Color.white.opacity(0.08))

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // Action type (only show when adding new)
                    if editing == nil {
                        FormSection("Action Type") {
                            Picker("Type", selection: $selectedType) {
                                ForEach(ActionType.allCases, id: \.self) {
                                    Text($0.rawValue).tag($0)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                    }

                    // Type-specific fields
                    switch selectedType {
                    case .pdfSlides:
                        FormSection("PDF Source") {
                            aliasPickerFor(kind: .pdf, selection: $pdfAlias)
                        }
                        FormSection("Page Range") {
                            Picker("Range", selection: $rangeType) {
                                ForEach(RangePickerType.allCases, id: \.self) {
                                    Text($0.rawValue).tag($0)
                                }
                            }
                            .pickerStyle(.menu)

                            switch rangeType {
                            case .all: EmptyView()
                            case .first:
                                FormTextField("Page count", text: $rangeN, placeholder: "e.g. 10")
                            case .suffix:
                                FormTextField("Start from page", text: $rangeFrom, placeholder: "e.g. 5")
                            case .range:
                                HStack {
                                    FormTextField("From", text: $rangeFrom, placeholder: "1")
                                    Text("–").foregroundStyle(.white.opacity(0.5))
                                    FormTextField("To", text: $rangeTo, placeholder: "10")
                                }
                            }
                        }

                    case .video:
                        FormSection("Video Source") {
                            aliasPickerFor(kind: .video, selection: $mediaAlias)
                        }

                    case .image:
                        FormSection("Image Source") {
                            aliasPickerFor(kind: .image, selection: $mediaAlias)
                        }

                    case .conditional:
                        FormSection("Trigger Key") {
                            FormTextField("Key (single character)", text: $triggerKey, placeholder: "e.g. b")
                                .onChange(of: triggerKey) { _, val in
                                    if val.count > 1 { triggerKey = String(val.suffix(1)) }
                                }
                        }
                        FormSection("If branch (key pressed)") {
                            branchEditor(typeBinding: $ifBranchType, jumpBinding: $ifJumpOffset, playBinding: $ifPlayAlias)
                        }
                        FormSection("Else branch (key not pressed)") {
                            branchEditor(typeBinding: $elseBranchType, jumpBinding: $elseJumpOffset, playBinding: .constant(""))
                                .disabled(true) // else branch can only be advance/jump, not playMedia
                            // Re-enable just the relevant pickers
                            Picker("Else", selection: $elseBranchType) {
                                Text(BranchPickerType.advance.rawValue).tag(BranchPickerType.advance)
                                Text(BranchPickerType.jumpBy.rawValue).tag(BranchPickerType.jumpBy)
                            }
                            .pickerStyle(.segmented)
                            if elseBranchType == .jumpBy {
                                FormTextField("Jump offset (can be negative)", text: $elseJumpOffset, placeholder: "e.g. -2 or 3")
                            }
                        }
                    }
                }
                .padding(24)
            }

            Divider().background(Color.white.opacity(0.08))

            // Footer
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(WorkspaceToolbarButtonStyle())
                Button(editing == nil ? "Add" : "Save") { commit() }
                    .buttonStyle(WorkspacePresentButtonStyle())
                    .disabled(!canCommit)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .frame(width: 480)
        .background(Color(hex: "#13131a"))
        .preferredColorScheme(.dark)
        .onAppear { populateFromEditing() }
    }

    // MARK: - Subviews

    @ViewBuilder
    private func aliasPickerFor(kind: SourceKind, selection: Binding<String>) -> some View {
        let sources = plan.sources.filter { $0.kind == kind }
        if sources.isEmpty {
            Text("No \(kind.label) sources added yet.")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.4))
        } else {
            Picker("Source", selection: selection) {
                Text("Select…").tag("")
                ForEach(sources) { src in
                    Text("\(src.alias) — \(URL(fileURLWithPath: src.path).lastPathComponent)")
                        .tag(src.alias)
                }
            }
            .pickerStyle(.menu)
            .onAppear {
                if selection.wrappedValue.isEmpty, let first = sources.first {
                    selection.wrappedValue = first.alias
                }
            }
        }
    }

    @ViewBuilder
    private func branchEditor(
        typeBinding: Binding<BranchPickerType>,
        jumpBinding: Binding<String>,
        playBinding: Binding<String>
    ) -> some View {
        Picker("Branch", selection: typeBinding) {
            ForEach(BranchPickerType.allCases, id: \.self) {
                Text($0.rawValue).tag($0)
            }
        }
        .pickerStyle(.segmented)

        switch typeBinding.wrappedValue {
        case .advance: EmptyView()
        case .jumpBy:
            FormTextField("Jump offset", text: jumpBinding, placeholder: "e.g. 2 or -1")
        case .playThenAdvance:
            aliasPickerFor(kind: .video, selection: playBinding)
        }
    }

    // MARK: - Validation

    var canCommit: Bool {
        switch selectedType {
        case .pdfSlides:   return !pdfAlias.isEmpty
        case .video, .image: return !mediaAlias.isEmpty
        case .conditional: return triggerKey.count == 1
        }
    }

    // MARK: - Commit

    private func commit() {
        guard let action = buildAction() else { return }
        onCommit(action)
        dismiss()
    }

    private func buildAction() -> PlanAction? {
        switch selectedType {
        case .pdfSlides:
            let range = buildRange()
            return .pdfSlides(PDFSlidesAction(sourceAlias: pdfAlias, range: range))

        case .video:
            return .video(SingleSourceAction(sourceAlias: mediaAlias))

        case .image:
            return .image(SingleSourceAction(sourceAlias: mediaAlias))

        case .conditional:
            guard triggerKey.count == 1 else { return nil }
            let ifBranch = buildBranch(type: ifBranchType, jump: ifJumpOffset, play: ifPlayAlias)
            let elseBranch = buildBranch(type: elseBranchType, jump: elseJumpOffset, play: "")
            return .conditional(ConditionalAction(
                triggerKey: triggerKey,
                ifBranch: ifBranch,
                elseBranch: elseBranch
            ))
        }
    }

    private func buildRange() -> SlideRange {
        switch rangeType {
        case .all:    return .all
        case .first:  return .first(Int(rangeN) ?? 1)
        case .suffix: return .suffix(from: Int(rangeFrom) ?? 1)
        case .range:  return .range(Int(rangeFrom) ?? 1, Int(rangeTo) ?? 1)
        }
    }

    private func buildBranch(type: BranchPickerType, jump: String, play: String) -> BranchSpec {
        switch type {
        case .advance:         return .advance
        case .jumpBy:          return .jumpBy(Int(jump) ?? 1)
        case .playThenAdvance: return .playThenAdvance(alias: play)
        }
    }

    // MARK: - Populate from editing

    private func populateFromEditing() {
        guard let action = editing else { return }
        switch action {
        case .pdfSlides(let a):
            selectedType = .pdfSlides
            pdfAlias = a.sourceAlias
            switch a.range {
            case .all:
                rangeType = .all
            case .first(let n):
                rangeType = .first; rangeN = "\(n)"
            case .suffix(let f):
                rangeType = .suffix; rangeFrom = "\(f)"
            case .range(let a2, let b):
                rangeType = .range; rangeFrom = "\(a2)"; rangeTo = "\(b)"
            }
        case .video(let a):
            selectedType = .video; mediaAlias = a.sourceAlias
        case .image(let a):
            selectedType = .image; mediaAlias = a.sourceAlias
        case .conditional(let a):
            selectedType = .conditional
            triggerKey = a.triggerKey
            applyBranch(spec: a.ifBranch,
                        typeSet: { ifBranchType = $0 },
                        jumpSet: { ifJumpOffset = $0 },
                        playSet: { ifPlayAlias = $0 })
            applyBranch(spec: a.elseBranch,
                        typeSet: { elseBranchType = $0 },
                        jumpSet: { elseJumpOffset = $0 },
                        playSet: { _ in })
        }
    }

    private func applyBranch(
        spec: BranchSpec,
        typeSet: (BranchPickerType) -> Void,
        jumpSet: (String) -> Void,
        playSet: (String) -> Void
    ) {
        switch spec {
        case .advance:
            typeSet(.advance)
        case .jumpBy(let n):
            typeSet(.jumpBy); jumpSet("\(n)")
        case .playThenAdvance(let alias):
            typeSet(.playThenAdvance); playSet(alias)
        }
    }
}

// MARK: - Form Helpers

struct FormSection<Content: View>: View {
    let title: String
    let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.4))
                .tracking(1)
            content
        }
    }
}

struct FormTextField: View {
    let label: String
    @Binding var text: String
    let placeholder: String

    init(_ label: String, text: Binding<String>, placeholder: String = "") {
        self.label = label
        self._text = text
        self.placeholder = placeholder
    }

    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .font(.system(size: 13, design: .monospaced))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.white.opacity(0.1)))
    }
}
