import SwiftUI

/// The main presentation stage.
/// Renders whichever slide is current (PDF page or video),
/// handles keyboard navigation, and shows a minimal HUD.
struct SlideStageView: View {
    @ObservedObject var vm: PresentationViewModel
    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // MARK: - Slide Content
            if let slide = vm.currentSlide {
                Group {
                    switch slide {
                    case .pdfPage(let page):
                        PDFPageView(page: page)
                            .transition(.opacity)

                    case .video(let url):
                        VideoSlideView(url: url) {
                            vm.onVideoFinished()
                        }
                        .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.25), value: vm.currentIndex)
                .id(vm.currentIndex) // Forces view recreation on slide change
            }

            // MARK: - HUD Overlay
            if vm.showControls {
                VStack {
                    Spacer()
                    HUDBar(vm: vm)
                        .padding(.bottom, 20)
                }
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.3), value: vm.showControls)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .focusable()
        .focused($isFocused)
        .onAppear {
            isFocused = true
            vm.triggerControlsVisibility()
        }
        .onTapGesture {
            isFocused = true
            vm.triggerControlsVisibility()
        }
        .onMoveCommand { direction in
            switch direction {
            case .right, .down:
                vm.next()
            case .left, .up:
                vm.previous()
            @unknown default:
                break
            }
        }
        .onKeyPress(.space) {
            vm.next()
            return .handled
        }
        .onKeyPress(.escape) {
            NSApp.keyWindow?.toggleFullScreen(nil)
            return .handled
        }
    }
}

// MARK: - HUD Progress Bar

struct HUDBar: View {
    @ObservedObject var vm: PresentationViewModel

    var body: some View {
        HStack(spacing: 16) {
            // Prev button
            Button(action: vm.previous) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
            }
            .buttonStyle(HUDButtonStyle())
            .disabled(vm.currentIndex == 0)

            // Slide counter
            Text("\(vm.currentIndex + 1) / \(vm.totalSlides)")
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.85))
                .frame(minWidth: 70)

            // Progress track
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.15))
                    Capsule()
                        .fill(.white.opacity(0.8))
                        .frame(width: geo.size.width * vm.progress)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: vm.progress)
                }
            }
            .frame(width: 160, height: 4)

            // Next button
            Button(action: vm.next) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
            }
            .buttonStyle(HUDButtonStyle())
            .disabled(vm.currentIndex == vm.totalSlides - 1)

            // Fullscreen toggle
            Button(action: { NSApp.keyWindow?.toggleFullScreen(nil) }) {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 13, weight: .semibold))
            }
            .buttonStyle(HUDButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.4), radius: 12, y: 4)
        )
    }
}

struct HUDButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white.opacity(configuration.isPressed ? 0.5 : 0.85))
            .frame(width: 28, height: 28)
            .background(Circle().fill(.white.opacity(configuration.isPressed ? 0.1 : 0.05)))
    }
}
