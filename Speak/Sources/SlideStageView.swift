import SwiftUI

struct SlideStageView: View {
    @ObservedObject var vm: PresentationViewModel
    let onBack: () -> Void

    @StateObject private var drawing = DrawingViewModel()
    @FocusState private var isFocused: Bool
    @State private var keyMonitor: Any?

    // The slide to actually render (queuedSlide overrides currentSlide during if-branch playback)
    private var activeSlide: Slide? {
        vm.queuedSlide ?? vm.currentSlide
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // MARK: - Slide Content
            if let slide = activeSlide {
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

                    case .image(let url):
                        ImageSlideView(url: url)
                            .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.25), value: vm.currentIndex)
                .id(vm.currentIndex)
            }

            // MARK: - Drawing Overlay
            DrawingOverlayView(drawing: drawing, slideIndex: vm.currentIndex)

            // MARK: - Conditional Decision Banner
            if let decision = vm.pendingDecision {
                VStack {
                    DecisionBanner(decision: decision)
                        .padding(.top, 16)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.spring(response: 0.3), value: vm.hasPendingDecision)
            }

            // MARK: - HUD Overlay
            if vm.showControls {
                VStack {
                    // Back button top-left
                    HStack {
                        Button(action: onBack) {
                            HStack(spacing: 6) {
                                Image(systemName: "chevron.left")
                                Text("Workspace")
                            }
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.55))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 14)
                        .padding(.leading, 16)
                        Spacer()
                    }

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
                    case 123, 126: vm.previous(); return nil       // left / up
                    case 124, 125: vm.next(); return nil           // right / down
                    case 35: drawing.activatePen(); return nil     // p
                    case 4:  drawing.activateHighlight(); return nil // h
                    case 6 where event.modifierFlags.contains(.command): // ⌘Z
                        drawing.undo(); return nil
                    default:
                        // Check trigger key for pending decision
                        if let chars = event.characters, chars.count == 1,
                           let ch = chars.first,
                           let decision = vm.pendingDecision, decision.triggerKey == ch {
                            vm.fireTriggerKey(ch)
                            return nil
                        }
                        return event
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

// MARK: - Decision Banner

struct DecisionBanner: View {
    let decision: Decision

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 12))
                .foregroundStyle(Color(hex: "#f97316"))

            Text("Press ")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.7))
            +
            Text("[\(String(decision.triggerKey))]")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(Color(hex: "#f97316"))
            +
            Text(" to take the alternate branch")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.3), radius: 8, y: 2)
    }
}

// MARK: - HUD Progress Bar

struct HUDBar: View {
    @ObservedObject var vm: PresentationViewModel

    var body: some View {
        HStack(spacing: 16) {
            Button(action: vm.previous) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
            }
            .buttonStyle(HUDButtonStyle())
            .disabled(vm.currentIndex == 0)

            Text("\(vm.currentIndex + 1) / \(vm.totalSlides)")
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.85))
                .frame(minWidth: 70)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.15))
                    Capsule()
                        .fill(.white.opacity(0.8))
                        .frame(width: geo.size.width * vm.progress)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: vm.progress)
                }
            }
            .frame(width: 160, height: 4)

            Button(action: vm.next) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
            }
            .buttonStyle(HUDButtonStyle())
            .disabled(vm.currentIndex == vm.totalSlides - 1)

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
