import SwiftUI
import AVFoundation
import Combine

@MainActor
final class PresentationViewModel: ObservableObject {

    // MARK: - Published State

    @Published var currentIndex: Int = 0
    @Published var isLoaded: Bool = false
    @Published var isFullScreen: Bool = false
    @Published var videoFinished: Bool = false
    @Published var showControls: Bool = true

    // MARK: - Private

    private(set) var sequence: PresentationSequence?
    private var controlsHideTask: Task<Void, Never>?

    // MARK: - Computed

    var currentSlide: Slide? {
        guard let seq = sequence, currentIndex < seq.totalCount else { return nil }
        return seq.slides[currentIndex]
    }

    var isVideoSlide: Bool {
        if case .video = currentSlide { return true }
        return false
    }

    var totalSlides: Int {
        sequence?.totalCount ?? 0
    }

    var progress: Double {
        guard totalSlides > 0 else { return 0 }
        return Double(currentIndex + 1) / Double(totalSlides)
    }

    // MARK: - Load

    func load(pdfURL: URL, videoURL: URL, videoAfterPage: Int = 5) {
        sequence = PresentationSequence(pdfURL: pdfURL, videoURL: videoURL, videoAfterPage: videoAfterPage)
        currentIndex = 0
        isLoaded = sequence != nil
    }

    // MARK: - Navigation

    func next() {
        guard let seq = sequence else { return }
        if currentIndex < seq.totalCount - 1 {
            videoFinished = false
            currentIndex += 1
        }
    }

    func previous() {
        if currentIndex > 0 {
            videoFinished = false
            currentIndex -= 1
        }
    }

    func goTo(index: Int) {
        guard let seq = sequence else { return }
        if index >= 0 && index < seq.totalCount {
            videoFinished = false
            currentIndex = index
        }
    }

    // MARK: - Video callbacks

    func onVideoFinished() {
        videoFinished = true
        // Auto-advance to next slide
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.next()
        }
    }

    // MARK: - Controls visibility

    func triggerControlsVisibility() {
        showControls = true
        controlsHideTask?.cancel()
        controlsHideTask = Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
            if !Task.isCancelled {
                await MainActor.run { self.showControls = false }
            }
        }
    }
}
