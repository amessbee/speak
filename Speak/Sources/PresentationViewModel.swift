import SwiftUI
import Combine

@MainActor
final class PresentationViewModel: ObservableObject {

    // MARK: - Published State

    @Published var currentIndex: Int = 0
    @Published var isLoaded: Bool = false
    @Published var showControls: Bool = true
    @Published var pendingDecision: Decision? = nil
    @Published var loadError: String? = nil

    // MARK: - Private

    private(set) var plan: Plan = .empty
    private var executor: PlanExecutor?
    private var controlsHideTask: Task<Void, Never>?

    // MARK: - Computed

    var currentSlide: Slide? {
        guard let exec = executor else { return nil }
        return contentSlide(at: currentIndex, in: exec.items)
    }

    var totalSlides: Int {
        guard let exec = executor else { return 0 }
        return exec.items.filter { if case .decision = $0 { return false }; return true }.count
    }

    var progress: Double {
        guard totalSlides > 0 else { return 0 }
        return Double(contentPosition + 1) / Double(totalSlides)
    }

    var isVideoSlide: Bool {
        if case .video = currentSlide { return true }
        return false
    }

    var hasPendingDecision: Bool { pendingDecision != nil }

    // MARK: - Load

    func load(plan: Plan) {
        self.plan = plan
        loadError = nil
        do {
            let exec = try PlanExecutor(plan: plan)
            self.executor = exec
            currentIndex = firstContentIndex(in: exec.items)
            checkForDecisionAhead()
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
        pendingDecision = nil
        loadError = nil
    }

    // MARK: - Navigation

    func next() {
        guard let exec = executor else { return }

        // If there is a pending decision, take the else branch
        if let decision = pendingDecision {
            pendingDecision = nil
            applyJump(decision.elseJumpOffset, in: exec.items)
            checkForDecisionAhead()
            return
        }

        let items = exec.items
        // Peek ahead past decision nodes
        var peekIndex = currentIndex + 1
        while peekIndex < items.count, case .decision(let d) = items[peekIndex] {
            pendingDecision = d
            peekIndex += 1
            break
        }

        if pendingDecision != nil { return } // stay on current slide, showing the decision prompt

        let nextContent = nextContentIndex(after: currentIndex, in: items)
        if let idx = nextContent {
            currentIndex = idx
            checkForDecisionAhead()
        }
    }

    func previous() {
        guard let exec = executor else { return }
        pendingDecision = nil
        let prevContent = prevContentIndex(before: currentIndex, in: exec.items)
        if let idx = prevContent { currentIndex = idx }
    }

    func goTo(contentPosition pos: Int) {
        guard let exec = executor else { return }
        pendingDecision = nil
        let idx = rawIndex(forContentPosition: pos, in: exec.items)
        if let idx { currentIndex = idx }
    }

    // MARK: - Trigger Key (conditional if-branch)

    func fireTriggerKey(_ key: Character) {
        guard let decision = pendingDecision, decision.triggerKey == key else { return }
        guard let exec = executor else { return }
        pendingDecision = nil

        if decision.ifInserts.isEmpty {
            // advance or jump — handled by elseJumpOffset on if-branch side
            // For advance: insert nothing, move to next content
            let nextContent = nextContentIndex(after: currentIndex, in: exec.items)
            if let idx = nextContent { currentIndex = idx }
        } else {
            // Insert the media items temporarily before the next item
            // We do this by injecting into a transient queue
            insertQueue.append(contentsOf: decision.ifInserts)
            advanceIntoQueue()
        }
        checkForDecisionAhead()
    }

    // MARK: - Inserted Queue (for if-branch media)

    private var insertQueue: [ExecutableItem] = []
    private var inInsertQueue = false

    func onVideoFinished() {
        if inInsertQueue && !insertQueue.isEmpty {
            advanceIntoQueue()
        } else {
            inInsertQueue = false
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

    // MARK: - Private helpers

    private func advanceIntoQueue() {
        guard !insertQueue.isEmpty else {
            inInsertQueue = false
            let nextContent = nextContentIndex(after: currentIndex, in: executor?.items ?? [])
            if let idx = nextContent { currentIndex = idx }
            return
        }
        inInsertQueue = true
        let item = insertQueue.removeFirst()
        switch item {
        case .pdfPage, .video, .image:
            // Temporarily stash item and navigate to it by abusing currentSlide
            // Use queuedSlide override
            queuedSlide = slideFrom(item: item)
        case .decision:
            advanceIntoQueue() // skip decisions in queue
        }
    }

    // Override currentSlide during queue playback
    @Published var queuedSlide: Slide? = nil

    private func slideFrom(item: ExecutableItem) -> Slide? {
        switch item {
        case .pdfPage(let p): return .pdfPage(p)
        case .video(let u):   return .video(u)
        case .image(let u):   return .image(u)
        case .decision:       return nil
        }
    }

    private func checkForDecisionAhead() {
        guard let exec = executor else { return }
        let nextIdx = currentIndex + 1
        guard nextIdx < exec.items.count else { return }
        if case .decision(let d) = exec.items[nextIdx] {
            pendingDecision = d
        } else {
            pendingDecision = nil
        }
    }

    private func applyJump(_ offset: Int, in items: [ExecutableItem]) {
        let pos = contentPosition + offset - 1
        let clamped = max(0, min(pos, totalSlides - 1))
        if let idx = rawIndex(forContentPosition: clamped, in: items) {
            currentIndex = idx
        }
    }

    private var contentPosition: Int {
        guard let exec = executor else { return 0 }
        return contentSlideCount(upTo: currentIndex, in: exec.items)
    }

    private func contentSlide(at rawIndex: Int, in items: [ExecutableItem]) -> Slide? {
        guard rawIndex < items.count else { return nil }
        switch items[rawIndex] {
        case .pdfPage(let p): return .pdfPage(p)
        case .video(let u):   return .video(u)
        case .image(let u):   return .image(u)
        case .decision:       return nil
        }
    }

    private func firstContentIndex(in items: [ExecutableItem]) -> Int {
        for (i, item) in items.enumerated() {
            if case .decision = item { continue }
            return i
        }
        return 0
    }

    private func nextContentIndex(after index: Int, in items: [ExecutableItem]) -> Int? {
        var i = index + 1
        while i < items.count {
            if case .decision = items[i] { i += 1; continue }
            return i
        }
        return nil
    }

    private func prevContentIndex(before index: Int, in items: [ExecutableItem]) -> Int? {
        var i = index - 1
        while i >= 0 {
            if case .decision = items[i] { i -= 1; continue }
            return i
        }
        return nil
    }

    private func contentSlideCount(upTo index: Int, in items: [ExecutableItem]) -> Int {
        var count = 0
        for i in 0..<min(index, items.count) {
            if case .decision = items[i] { continue }
            count += 1
        }
        return count
    }

    private func rawIndex(forContentPosition pos: Int, in items: [ExecutableItem]) -> Int? {
        var count = 0
        for (i, item) in items.enumerated() {
            if case .decision = item { continue }
            if count == pos { return i }
            count += 1
        }
        return nil
    }
}
