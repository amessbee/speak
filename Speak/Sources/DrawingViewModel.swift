import SwiftUI

@MainActor
final class DrawingViewModel: ObservableObject {

    struct Stroke {
        var points: [CGPoint]
        var color: Color
        var width: CGFloat
    }

    @Published var isPenMode = false
    @Published var penColor: Color = .red
    @Published var penWidth: CGFloat = 4
    @Published var currentStroke: Stroke?

    private var strokesBySlide: [Int: [Stroke]] = [:]

    func togglePenMode() {
        isPenMode.toggle()
        if !isPenMode { currentStroke = nil }
    }

    func startStroke(at point: CGPoint, slideIndex: Int) {
        currentStroke = Stroke(points: [point], color: penColor, width: penWidth)
    }

    func addPoint(_ point: CGPoint) {
        currentStroke?.points.append(point)
    }

    func endStroke(slideIndex: Int) {
        guard let stroke = currentStroke else {
            currentStroke = nil
            return
        }
        objectWillChange.send()
        var arr = strokesBySlide[slideIndex] ?? []
        arr.append(stroke)
        strokesBySlide[slideIndex] = arr
        currentStroke = nil
    }

    func strokes(for slideIndex: Int) -> [Stroke] {
        strokesBySlide[slideIndex] ?? []
    }

    func clearStrokes(for slideIndex: Int) {
        objectWillChange.send()
        strokesBySlide.removeValue(forKey: slideIndex)
    }
}
