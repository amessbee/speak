import SwiftUI
import AppKit

struct SlideStageView: View {
    @ObservedObject var vm: PresentationViewModel
    let onBack: () -> Void

    @StateObject private var drawing = DrawingViewModel()
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
                        VideoSlideView(url: url, restartToken: vm.videoRestartToken) {
                            vm.onVideoFinished()
                        }
                        .transition(.opacity)

                    case .image(let url):
                        ImageSlideView(url: url)
                            .transition(.opacity)

                    case .youtube(let urlStr):
                        // onKeyDown: JS injected into every frame (incl. cross-origin YouTube
                        // iframe) intercepts nav keys before the player sees them and sends
                        // them here via postMessage — the only path that survives WKWebView's
                        // web-content XPC routing.
                        YouTubePlayerView(
                            urlString: urlStr,
                            restartToken: vm.videoRestartToken,
                            onKeyDown: { keyCode, meta in handleYouTubeKey(keyCode, meta) },
                            onFinished: { vm.onVideoFinished() }
                        )
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

                    let hotkeys = vm.currentHotkeys
                    if !hotkeys.isEmpty {
                        HotkeyHintBar(hotkeys: hotkeys)
                            .padding(.bottom, 8)
                    }

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
        .onAppear {
            vm.triggerControlsVisibility()
            // Single monitor handles both keyboard and mouse for all slide types.
            // For YouTube slides the JS injection is the primary keyboard path; this
            // monitor serves as a fallback and handles all non-YouTube slides.
            keyMonitor = NSEvent.addLocalMonitorForEvents(
                matching: [.keyDown, .mouseMoved, .leftMouseDragged]
            ) { [drawing, vm] event in
                switch event.type {
                case .mouseMoved, .leftMouseDragged:
                    if drawing.isPenMode { NSCursor.crosshair.set() }
                    return event
                case .keyDown:
                    switch event.keyCode {
                    case 123, 126: vm.previous(); return nil
                    case 124, 125: vm.next();     return nil
                    case 49:       vm.next();     return nil   // space
                    case 35:       drawing.activatePen();       return nil
                    case 4:        drawing.activateHighlight(); return nil
                    case 6 where event.modifierFlags.contains(.command):
                        drawing.undo(); return nil
                    default:
                        if let ch = event.characters?.first,
                           !event.modifierFlags.contains(.command) {
                            vm.fireTriggerKey(ch)
                        }
                        return event
                    }
                default:
                    return event
                }
            }
        }
        .onDisappear {
            if let m = keyMonitor { NSEvent.removeMonitor(m); keyMonitor = nil }
        }
        .onTapGesture { vm.triggerControlsVisibility() }
    }

    // Called by YouTubePlayerView when its injected JS intercepts a nav key.
    private func handleYouTubeKey(_ keyCode: Int, _ meta: Bool) {
        switch keyCode {
        case 37, 38: vm.previous()
        case 39, 40: vm.next()
        case 32:     vm.next()
        case 27:     NSApp.keyWindow?.toggleFullScreen(nil)
        case 80:     drawing.activatePen()
        case 72:     drawing.activateHighlight()
        case 90 where meta: drawing.undo()
        default: break
        }
    }
}

// MARK: - Hotkey Hint Bar

struct HotkeyHintBar: View {
    let hotkeys: [CompiledHotkey]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(hotkeys, id: \.key) { hk in
                HStack(spacing: 4) {
                    Text("[\(String(hk.key))]")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color(hex: "#f97316"))
                    Text(hk.displayLabel)
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(.ultraThinMaterial))
            }
        }
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
