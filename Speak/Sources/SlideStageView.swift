import SwiftUI
/// The main presentation stage.
/// Renders whichever slide is current (PDF page or video),
/// handles keyboard navigation, and shows a minimal HUD.
struct SlideStageView: View {
    @ObservedObject var vm: PresentationViewModel
    @StateObject private var drawing = DrawingViewModel()
    @FocusState private var isFocused: Bool
    @State private var keyMonitor: Any?

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
                .id(vm.currentIndex)
            }

            // MARK: - Drawing Overlay
            DrawingOverlayView(drawing: drawing, slideIndex: vm.currentIndex)

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

            // MARK: - Drawing Tool Panel
            HStack {
                Spacer()
                if drawing.isPenMode {
                    DrawingToolPanel(drawing: drawing, slideIndex: vm.currentIndex)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                        .padding(.trailing, 12)
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.85), value: drawing.isPenMode)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .focusable()
        .focused($isFocused)
        .onAppear {
            isFocused = true
            vm.triggerControlsVisibility()
            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .mouseMoved, .leftMouseDragged]) { event in
                switch event.type {
                case .mouseMoved, .leftMouseDragged:
                    if drawing.isPenMode { NSCursor.crosshair.set() }
                    return event
                case .keyDown:
                    switch event.keyCode {
                    case 123, 126: vm.previous(); return nil       // left / up arrow
                    case 124, 125: vm.next(); return nil           // right / down arrow
                    case 35: drawing.activatePen(); return nil     // p
                    case 4:  drawing.activateHighlight(); return nil // h
                    case 6 where event.modifierFlags.contains(.command): // ⌘Z
                        drawing.undo(); return nil
                    default: return event
                    }
                default:
                    return event
                }
            }
        }
        .onDisappear {
            if let monitor = keyMonitor {
                NSEvent.removeMonitor(monitor)
                keyMonitor = nil
            }
        }
        .onTapGesture {
            isFocused = true
            vm.triggerControlsVisibility()
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
