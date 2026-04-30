import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var vm = PresentationViewModel()
    @State private var plan: Plan = .empty
    @State private var planFileURL: URL?

    var body: some View {
        Group {
            if vm.isLoaded {
                SlideStageView(vm: vm) {
                    vm.unload()
                }
            } else {
                WorkspaceView(vm: vm, plan: $plan, currentFileURL: $planFileURL)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .preferredColorScheme(.dark)
        .onChange(of: appState.pendingPlanURL) { _, url in
            guard let url else { return }
            appState.pendingPlanURL = nil
            loadPlan(from: url)
        }
        .onChange(of: appState.pendingPDFURL) { _, url in
            guard let url else { return }
            appState.pendingPDFURL = nil
            presentPDF(url)
        }
    }

    private func loadPlan(from url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode(Plan.self, from: data)
            plan = decoded
            planFileURL = url
            vm.load(plan: decoded)
        } catch {
            print("Failed to load plan: \(error)")
        }
    }

    private func presentPDF(_ url: URL) {
        let alias = url.deletingPathExtension().lastPathComponent
        let source = SourceFile(alias: alias, path: url.path, kind: .pdf)
        let action = PlanAction.pdfSlides(PDFSlidesAction(sourceAlias: alias, range: .all))
        let quickPlan = Plan(sources: [source], actions: [action])
        plan = quickPlan
        planFileURL = nil
        vm.load(plan: quickPlan)
    }
}
