import SwiftUI

struct ActionEditorSheet: View {
    let plan: Plan
    let editing: PlanAction?
    let onCommit: (PlanAction) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var selectedType: ActionType = .pdfSlides
    @State private var pdfAlias: String = ""
    @State private var rangeType: RangePickerType = .all
    @State private var rangeN: String = ""
    @State private var rangeFrom: String = ""
    @State private var rangeTo: String = ""
    @State private var mediaAlias: String = ""
    @State private var hotkeys: [HotkeyBehavior] = []

    enum ActionType: String, CaseIterable {
        case pdfSlides = "PDF Slides"
        case video     = "Video"
        case image     = "Image"
        case youtube   = "YouTube"
    }

    enum RangePickerType: String, CaseIterable {
        case all    = "All pages"
        case first  = "First N pages"
        case suffix = "From page N"
        case range  = "Page range"
    }

    init(plan: Plan, editing: PlanAction? = nil, onCommit: @escaping (PlanAction) -> Void) {
        self.plan = plan
        self.editing = editing
        self.onCommit = onCommit
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(editing == nil ? "Add Action" : "Edit Action")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
                Button { dismiss() } label: {
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

                    // Action type (only when adding new)
                    if editing == nil {
                        FormSection("Action Type") {
                            Picker("Type", selection: $selectedType) {
                                ForEach(ActionType.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                            }
                            .pickerStyle(.segmented)
                        }
                    }

                    // Type-specific source/range fields
                    switch selectedType {
                    case .pdfSlides:
                        FormSection("PDF Source") {
                            aliasPickerFor(kind: .pdf, selection: $pdfAlias)
                        }
                        FormSection("Page Range") {
                            Picker("Range", selection: $rangeType) {
                                ForEach(RangePickerType.allCases, id: \.self) { Text($0.rawValue).tag($0) }
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

                    case .youtube:
                        FormSection("YouTube Source") {
                            aliasPickerFor(kind: .youtube, selection: $mediaAlias)
                        }
                    }

                    // Hotkeys section
                    HotkeyEditorSection(
                        hotkeys: $hotkeys,
                        actionKind: selectedType,
                        plan: plan
                    )
                }
                .padding(24)
            }

            Divider().background(Color.white.opacity(0.08))

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
        .frame(width: 520)
        .background(Color(hex: "#13131a"))
        .preferredColorScheme(.dark)
        .onAppear { populateFromEditing() }
    }

    // MARK: - Helpers

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
                    Text("\(src.alias) — \(URL(fileURLWithPath: src.path).lastPathComponent)").tag(src.alias)
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

    var canCommit: Bool {
        switch selectedType {
        case .pdfSlides:              return !pdfAlias.isEmpty
        case .video, .image, .youtube: return !mediaAlias.isEmpty
        }
    }

    private func commit() {
        guard let action = buildAction() else { return }
        onCommit(action)
        dismiss()
    }

    private func buildAction() -> PlanAction? {
        switch selectedType {
        case .pdfSlides:
            return .pdfSlides(PDFSlidesAction(sourceAlias: pdfAlias, range: buildRange(), hotkeys: hotkeys))
        case .video:
            return .video(SingleSourceAction(sourceAlias: mediaAlias, hotkeys: hotkeys))
        case .image:
            return .image(SingleSourceAction(sourceAlias: mediaAlias, hotkeys: hotkeys))
        case .youtube:
            return .youtube(SingleSourceAction(sourceAlias: mediaAlias, hotkeys: hotkeys))
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

    private func populateFromEditing() {
        guard let action = editing else { return }
        hotkeys = action.hotkeys
        switch action {
        case .pdfSlides(let a):
            selectedType = .pdfSlides; pdfAlias = a.sourceAlias
            switch a.range {
            case .all:                 rangeType = .all
            case .first(let n):        rangeType = .first; rangeN = "\(n)"
            case .suffix(let f):       rangeType = .suffix; rangeFrom = "\(f)"
            case .range(let a2, let b): rangeType = .range; rangeFrom = "\(a2)"; rangeTo = "\(b)"
            }
        case .video(let a):
            selectedType = .video; mediaAlias = a.sourceAlias
        case .image(let a):
            selectedType = .image; mediaAlias = a.sourceAlias
        case .youtube(let a):
            selectedType = .youtube; mediaAlias = a.sourceAlias
        }
    }
}

// MARK: - Hotkey Editor Section

struct HotkeyEditorSection: View {
    @Binding var hotkeys: [HotkeyBehavior]
    let actionKind: ActionEditorSheet.ActionType
    let plan: Plan

    var body: some View {
        FormSection("Hotkeys") {
            VStack(spacing: 6) {
                ForEach($hotkeys) { $hk in
                    HotkeyRow(hotkey: $hk, actionKind: actionKind, plan: plan) {
                        hotkeys.removeAll { $0.id == hk.id }
                    }
                }

                Button {
                    hotkeys.append(HotkeyBehavior(key: "", action: defaultAction))
                } label: {
                    Label("Add Hotkey", systemImage: "plus")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.5))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(Color.white.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                            .foregroundStyle(Color.white.opacity(0.12)))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var defaultAction: HotkeyAction {
        switch actionKind {
        case .pdfSlides:             return .jumpToPage(1)
        case .video, .image, .youtube: return .replayFromStart
        }
    }
}

// MARK: - Hotkey Row

struct HotkeyRow: View {
    @Binding var hotkey: HotkeyBehavior
    let actionKind: ActionEditorSheet.ActionType
    let plan: Plan
    let onDelete: () -> Void

    @State private var pageStr: String = ""
    @State private var detourAlias: String = ""

    var body: some View {
        HStack(spacing: 8) {
            // Key input
            TextField("key", text: $hotkey.key)
                .textFieldStyle(.plain)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(Color(hex: "#f97316"))
                .multilineTextAlignment(.center)
                .frame(width: 28)
                .padding(6)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 5))
                .onChange(of: hotkey.key) { _, val in
                    if val.count > 1 { hotkey.key = String(val.suffix(1)) }
                }

            // Action picker
            Picker("", selection: actionTypeBinding) {
                ForEach(availableActionTypes, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity)

            // Detail field
            switch hotkey.action {
            case .jumpToPage:
                TextField("page #", text: $pageStr)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.white)
                    .frame(width: 52)
                    .padding(6)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                    .onChange(of: pageStr) { _, val in
                        if let n = Int(val) { hotkey.action = .jumpToPage(n) }
                    }
                    .onAppear {
                        if case .jumpToPage(let n) = hotkey.action { pageStr = "\(n)" }
                    }

            case .playDetour:
                let mediaSources = plan.sources.filter { $0.kind == .video || $0.kind == .image || $0.kind == .youtube }
                Picker("", selection: $detourAlias) {
                    Text("Pick…").tag("")
                    ForEach(mediaSources) { src in Text(src.alias).tag(src.alias) }
                }
                .pickerStyle(.menu)
                .frame(width: 80)
                .onChange(of: detourAlias) { _, val in
                    hotkey.action = .playDetour(alias: val)
                }
                .onAppear {
                    if case .playDetour(let a) = hotkey.action { detourAlias = a }
                }

            default:
                Spacer().frame(width: 52)
            }

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 11))
            }
            .buttonStyle(IconButtonStyle(tint: .red))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var availableActionTypes: [String] {
        switch actionKind {
        case .pdfSlides:
            return ["Jump to page", "Play detour", "Skip to next", "Go back"]
        case .video, .image, .youtube:
            return ["Replay from start", "Play detour", "Skip to next", "Go back"]
        }
    }

    private var actionTypeBinding: Binding<String> {
        Binding(
            get: { labelFor(hotkey.action) },
            set: { label in
                switch label {
                case "Jump to page":
                    let n = (pageStr.isEmpty ? 1 : Int(pageStr) ?? 1)
                    hotkey.action = .jumpToPage(n)
                case "Replay from start":
                    hotkey.action = .replayFromStart
                case "Play detour":
                    hotkey.action = .playDetour(alias: detourAlias)
                case "Skip to next":
                    hotkey.action = .skipToNextAction
                case "Go back":
                    hotkey.action = .goBackToPreviousAction
                default: break
                }
            }
        )
    }

    private func labelFor(_ action: HotkeyAction) -> String {
        switch action {
        case .jumpToPage:            return "Jump to page"
        case .replayFromStart:       return "Replay from start"
        case .playDetour:            return "Play detour"
        case .skipToNextAction:      return "Skip to next"
        case .goBackToPreviousAction: return "Go back"
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
