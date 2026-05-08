import SwiftUI
import Combine

@MainActor
final class PresentationViewModel: ObservableObject {

    // MARK: - Published State

    @Published var currentIndex: Int = 0
    @Published var isLoaded: Bool = false
    @Published var showControls: Bool = true
    @Published var loadError: String? = nil
    @Published var videoRestartToken: UUID = UUID()

    // Non-nil while a detour (if-branch media) is playing.
    @Published private(set) var detourSlide: Slide? = nil

    // MARK: - Private

    private(set) var plan: Plan = .empty
    private var executor: PlanExecutor?
    private var controlsHideTask: Task<Void, Never>?

    // Detour queue: items queued by a "playDetour" hotkey action.
    private var detourQueue: [ExecutableItem] = []
    private var detourReturnIndex: Int = 0

    // MARK: - Computed

    var currentSlide: Slide? {
        if let detour = detourSlide { return detour }
        guard let exec = executor, exec.items.indices.contains(currentIndex) else { return nil }
        return slide(from: exec.items[currentIndex])
    }

    var totalSlides: Int { executor?.items.count ?? 0 }

    var progress: Double {
        guard totalSlides > 0 else { return 0 }
        return Double(currentIndex + 1) / Double(totalSlides)
    }

    var isVideoSlide: Bool {
        switch currentSlide {
        case .video, .youtube: return true
        default:               return false
        }
    }

    var currentHotkeys: [CompiledHotkey] {
        guard detourSlide == nil, let exec = executor else { return [] }
        return exec.hotkeys(at: currentIndex)
    }

    // MARK: - Load / Unload

    func load(plan: Plan) {
        self.plan = plan
        loadError = nil
        detourSlide = nil
        detourQueue = []
        do {
            let exec = try PlanExecutor(plan: plan)
            self.executor = exec
            currentIndex = 0
            isLoaded = true
        } catch {
            loadError = error.localizedDescription
            isLoaded = false
        }
    }

    func unload() {
        executor = nil
        isLoaded = false
        currentIndex = 0
        detourSlide = nil
        detourQueue = []
        loadError = nil
    }

    // MARK: - Navigation

    func next() {
        guard detourSlide == nil, let exec = executor else { return }
        if currentIndex < exec.items.count - 1 {
            currentIndex += 1
        }
    }

    func previous() {
        guard detourSlide == nil else { return }
        if currentIndex > 0 { currentIndex -= 1 }
    }

    // MARK: - Hotkey dispatch

    func fireTriggerKey(_ key: Character) {
        guard let exec = executor else { return }
        guard let hotkey = exec.hotkeys(at: currentIndex).first(where: { $0.key == key }) else { return }

        switch hotkey.action {
        case .jumpToIndex(let idx):
            currentIndex = max(0, min(idx, exec.items.count - 1))

        case .restartCurrent:
            videoRestartToken = UUID()

        case .playDetour(let items):
            detourQueue = items
            detourReturnIndex = min(currentIndex + 1, exec.items.count - 1)
            advanceDetour()
        }
    }

    // MARK: - Video callbacks

    func onVideoFinished() {
        if detourSlide != nil {
            advanceDetour()
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.next()
            }
        }
    }

    // MARK: - Controls visibility

    func triggerControlsVisibility() {
        showControls = true
        controlsHideTask?.cancel()
        controlsHideTask = Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if !Task.isCancelled {
                await MainActor.run { self.showControls = false }
            }
        }
    }

    // MARK: - Private

    private func advanceDetour() {
        guard !detourQueue.isEmpty else {
            detourSlide = nil
            return
        }
        let item = detourQueue.removeFirst()
        detourSlide = slide(from: item)
    }

    private func slide(from item: ExecutableItem) -> Slide? {
        switch item {
        case .pdfPage(let p):   return .pdfPage(p)
        case .video(let u):     return .video(u)
        case .image(let u):     return .image(u)
        case .youtube(let url): return .youtube(url)
        }
    }
}
