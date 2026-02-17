import SwiftUI

/// Root view: shows SetupView until a presentation is loaded,
/// then switches to SlideStageView.
struct ContentView: View {
    @StateObject private var vm = PresentationViewModel()

    var body: some View {
        Group {
            if vm.isLoaded {
                SlideStageView(vm: vm)
                    .toolbar {
                        ToolbarItem(placement: .navigation) {
                            Button("← Back to Setup") {
                                vm.isLoaded = false
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.5))
                        }
                    }
            } else {
                SetupView(vm: vm)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .preferredColorScheme(.dark)
    }
}
