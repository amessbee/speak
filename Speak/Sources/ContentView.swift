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
}
