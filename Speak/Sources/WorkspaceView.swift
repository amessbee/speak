import SwiftUI
import UniformTypeIdentifiers

struct WorkspaceView: View {
    @ObservedObject var vm: PresentationViewModel
    @Binding var plan: Plan
    @Binding var currentFileURL: URL?
    @State private var errorMessage: String?
    @State private var showErrorAlert = false

    var body: some View {
        VStack(spacing: 0) {
            // MARK: Header toolbar
            HStack(spacing: 12) {
                Text("Speak")
                    .font(.system(size: 16, weight: .thin, design: .serif))
                    .foregroundStyle(.white.opacity(0.9))

                Spacer()

                Button(action: newPlan) {
                    Label("New", systemImage: "doc.badge.plus")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(WorkspaceToolbarButtonStyle())

                Button(action: openPlan) {
                    Label("Open", systemImage: "folder")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(WorkspaceToolbarButtonStyle())

                Button(action: savePlan) {
                    Label("Save", systemImage: "arrow.down.doc")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(WorkspaceToolbarButtonStyle())

                Divider()
                    .frame(height: 16)
                    .background(Color.white.opacity(0.2))

                Button(action: launchPresentation) {
                    Label("Present", systemImage: "play.fill")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(WorkspacePresentButtonStyle())
                .disabled(plan.actions.isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(hex: "#0f0f14"))

            Divider().background(Color.white.opacity(0.08))

            // MARK: Two-column body
            HStack(spacing: 0) {
                // Source panel
                SourcePanelView(plan: $plan)
                    .frame(width: 260)
                    .background(Color(hex: "#13131a"))

                Divider().background(Color.white.opacity(0.08))

                // Plan panel
                PlanPanelView(plan: $plan)
                    .frame(maxWidth: .infinity)
                    .background(Color(hex: "#0f0f14"))
            }

            // MARK: Footer status bar
            HStack {
                if let url = currentFileURL {
                    Image(systemName: "doc.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.3))
                    Text(url.lastPathComponent)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))
                } else {
                    Text("Unsaved plan")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.25))
                }

                Spacer()

                Text("\(plan.sources.count) sources  ·  \(plan.actions.count) actions")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(hex: "#0a0a10"))
        }
        .alert("Error", isPresented: $showErrorAlert, presenting: errorMessage) { _ in
            Button("OK") {}
        } message: { msg in
            Text(msg)
        }
    }

    // MARK: Actions

    private func newPlan() {
        plan = .empty
        currentFileURL = nil
    }

    private func openPlan() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.speakPlan]
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let data = try Data(contentsOf: url)
            plan = try JSONDecoder().decode(Plan.self, from: data)
            currentFileURL = url
        } catch {
            errorMessage = "Could not open plan: \(error.localizedDescription)"
            showErrorAlert = true
        }
    }

    private func savePlan() {
        if let url = currentFileURL {
            writePlan(to: url)
        } else {
            savePlanAs()
        }
    }

    private func savePlanAs() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.speakPlan]
        panel.nameFieldStringValue = "presentation.speakplan"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        currentFileURL = url
        writePlan(to: url)
    }

    private func writePlan(to url: URL) {
        do {
            let data = try JSONEncoder().encode(plan)
            try data.write(to: url, options: .atomic)
        } catch {
            errorMessage = "Could not save plan: \(error.localizedDescription)"
            showErrorAlert = true
        }
    }

    private func launchPresentation() {
        vm.load(plan: plan)
        if let err = vm.loadError {
            errorMessage = err
            showErrorAlert = true
        }
    }
}

// MARK: - Button Styles

struct WorkspaceToolbarButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white.opacity(configuration.isPressed ? 0.5 : 0.7))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.white.opacity(configuration.isPressed ? 0.08 : 0.04))
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

struct WorkspacePresentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white.opacity(configuration.isPressed ? 0.6 : 1.0))
            .padding(.horizontal, 14)
            .padding(.vertical, 5)
            .background(
                LinearGradient(
                    colors: [Color(hex: "#5b6ef5"), Color(hex: "#8b5cf6")],
                    startPoint: .leading, endPoint: .trailing
                )
                .opacity(configuration.isPressed ? 0.7 : 1.0)
            )
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
