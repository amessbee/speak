import SwiftUI

@MainActor
final class DrawingViewModel: ObservableObject {

    enum DrawMode { case pen, highlight }

    struct Stroke {
        var points: [CGPoint]
        var color: Color
        var width: CGFloat
        var isHighlight: Bool
    }

    private enum UndoEntry {
        case stroke(slideIndex: Int)
        case clear(slideIndex: Int, strokes: [Stroke])
    }

    // MARK: - Published
    @Published var isPenMode = false
    @Published var drawMode: DrawMode = .pen
    @Published var penColor: Color = .red
    @Published var penWidth: CGFloat = 4
    @Published var highlightColor: Color = .yellow
    @Published var highlightWidth: CGFloat = 20
    @Published var currentStroke: Stroke?

    // MARK: - Private
    private var strokesBySlide: [Int: [Stroke]] = [:]
    private var undoStack: [UndoEntry] = []
    private let maxUndoHistory = 1000

    // MARK: - Mode activation

    func activatePen() {
        if drawMode == .pen && isPenMode { isPenMode = false } else { isPenMode = true; drawMode = .pen }
    }

    func activateHighlight() {
        if drawMode == .highlight && isPenMode { isPenMode = false } else { isPenMode = true; drawMode = .highlight }
    }

    // MARK: - Drawing

    func startStroke(at point: CGPoint) {
        let color = drawMode == .pen ? penColor : highlightColor
        let width = drawMode == .pen ? penWidth : highlightWidth
        currentStroke = Stroke(points: [point], color: color, width: width, isHighlight: drawMode == .highlight)
    }

    func addPoint(_ point: CGPoint) {
        currentStroke?.points.append(point)
    }

    func endStroke(slideIndex: Int) {
        guard let stroke = currentStroke else { currentStroke = nil; return }
        objectWillChange.send()
        var arr = strokesBySlide[slideIndex] ?? []
        arr.append(stroke)
        strokesBySlide[slideIndex] = arr
        pushUndo(.stroke(slideIndex: slideIndex))
        currentStroke = nil
    }

    // MARK: - Undo

    func undo() {
        guard let entry = undoStack.popLast() else { return }
        objectWillChange.send()
        switch entry {
        case .stroke(let idx):
            strokesBySlide[idx]?.removeLast()
            if strokesBySlide[idx]?.isEmpty == true { strokesBySlide.removeValue(forKey: idx) }
        case .clear(let idx, let strokes):
            strokesBySlide[idx] = strokes
        }
    }

    // MARK: - Queries

    func strokes(for slideIndex: Int) -> [Stroke] { strokesBySlide[slideIndex] ?? [] }

    func clearStrokes(for slideIndex: Int) {
        guard let strokes = strokesBySlide[slideIndex], !strokes.isEmpty else { return }
        objectWillChange.send()
        pushUndo(.clear(slideIndex: slideIndex, strokes: strokes))
        strokesBySlide.removeValue(forKey: slideIndex)
    }

    // MARK: - Private

    private func pushUndo(_ entry: UndoEntry) {
        undoStack.append(entry)
        if undoStack.count > maxUndoHistory { undoStack.removeFirst() }
    }
}
