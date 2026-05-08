import Foundation
import PDFKit

// MARK: - Executable Items

enum ExecutableItem {
    case pdfPage(PDFPage)
    case video(URL)
    case image(URL)
    case youtube(String)   // YouTube video URL string
}

// MARK: - Compiled Hotkeys

struct CompiledHotkey {
    let key: Character
    let displayLabel: String      // e.g. "Jump to page 5"
    let action: CompiledHotkeyAction
}

enum CompiledHotkeyAction {
    case jumpToIndex(Int)
    case restartCurrent
    case playDetour([ExecutableItem])
}

// MARK: - Errors

enum ExecutorError: LocalizedError {
    case emptyPlan
    case sourceNotFound(String)
    case fileUnreadable(String, String)

    var errorDescription: String? {
        switch self {
        case .emptyPlan:                    return "The plan has no actions."
        case .sourceNotFound(let alias):   return "Source \"\(alias)\" not found in source list."
        case .fileUnreadable(let a, let p): return "Cannot read file for \"\(a)\" at \(p)."
        }
    }
}

// MARK: - PlanExecutor

final class PlanExecutor {

    let items: [ExecutableItem]
    private let hotkeysByIndex: [Int: [CompiledHotkey]]
    private let retainedDocuments: [PDFDocument]

    init(plan: Plan) throws {
        guard !plan.actions.isEmpty else { throw ExecutorError.emptyPlan }

        let sourceMap = Dictionary(uniqueKeysWithValues: plan.sources.map { ($0.alias, $0) })
        var docs: [PDFDocument] = []

        // ── Pass 1: expand each action to raw items; record block boundaries ──
        struct BlockBoundary {
            let start: Int          // inclusive index into items
            let end: Int            // exclusive
            let hotkeys: [HotkeyBehavior]
        }

        var rawItems: [ExecutableItem] = []
        var boundaries: [BlockBoundary] = []

        for action in plan.actions {
            let start = rawItems.count
            let expanded = try Self.expand(action: action, sourceMap: sourceMap, docs: &docs)
            rawItems.append(contentsOf: expanded)
            let end = rawItems.count
            if !action.hotkeys.isEmpty {
                boundaries.append(BlockBoundary(start: start, end: end, hotkeys: action.hotkeys))
            }
        }

        // ── Pass 2: compile hotkeys → absolute indices ──
        var hotkeyMap: [Int: [CompiledHotkey]] = [:]

        for (bi, boundary) in boundaries.enumerated() {
            let prevStart = bi > 0 ? boundaries[bi - 1].start : 0
            var compiled: [CompiledHotkey] = []

            for hk in boundary.hotkeys {
                guard let char = hk.key.first else { continue }
                let action: CompiledHotkeyAction
                switch hk.action {
                case .jumpToPage(let n):
                    let idx = (boundary.start + n - 1).clamped(to: boundary.start ..< boundary.end)
                    action = .jumpToIndex(idx)

                case .replayFromStart:
                    action = .restartCurrent

                case .playDetour(let alias):
                    guard let src = sourceMap[alias] else { continue }
                    let detourItems = (try? Self.expandSource(src, docs: &docs)) ?? []
                    action = .playDetour(detourItems)

                case .skipToNextAction:
                    let idx = min(boundary.end, rawItems.count - 1)
                    action = .jumpToIndex(idx)

                case .goBackToPreviousAction:
                    action = .jumpToIndex(prevStart)
                }
                compiled.append(CompiledHotkey(key: char, displayLabel: hk.action.displayString, action: action))
            }

            for idx in boundary.start ..< boundary.end {
                hotkeyMap[idx, default: []].append(contentsOf: compiled)
            }
        }

        self.items = rawItems
        self.hotkeysByIndex = hotkeyMap
        self.retainedDocuments = docs
    }

    func hotkeys(at index: Int) -> [CompiledHotkey] {
        hotkeysByIndex[index] ?? []
    }

    // MARK: - Private helpers

    private static func expand(
        action: PlanAction,
        sourceMap: [String: SourceFile],
        docs: inout [PDFDocument]
    ) throws -> [ExecutableItem] {
        switch action {
        case .pdfSlides(let a):
            guard let src = sourceMap[a.sourceAlias] else { throw ExecutorError.sourceNotFound(a.sourceAlias) }
            guard let doc = PDFDocument(url: URL(fileURLWithPath: src.path)) else {
                throw ExecutorError.fileUnreadable(a.sourceAlias, src.path)
            }
            docs.append(doc)
            return pages(for: a.range, in: doc).map { .pdfPage($0) }

        case .video(let a):
            guard let src = sourceMap[a.sourceAlias] else { throw ExecutorError.sourceNotFound(a.sourceAlias) }
            return [.video(URL(fileURLWithPath: src.path))]

        case .image(let a):
            guard let src = sourceMap[a.sourceAlias] else { throw ExecutorError.sourceNotFound(a.sourceAlias) }
            return [.image(URL(fileURLWithPath: src.path))]

        case .youtube(let a):
            guard let src = sourceMap[a.sourceAlias] else { throw ExecutorError.sourceNotFound(a.sourceAlias) }
            return [.youtube(src.path)]
        }
    }

    private static func expandSource(_ src: SourceFile, docs: inout [PDFDocument]) throws -> [ExecutableItem] {
        switch src.kind {
        case .youtube: return [.youtube(src.path)]
        case .video:   return [.video(URL(fileURLWithPath: src.path))]
        case .image:   return [.image(URL(fileURLWithPath: src.path))]
        case .pdf:
            let url = URL(fileURLWithPath: src.path)
            guard let doc = PDFDocument(url: url) else {
                throw ExecutorError.fileUnreadable(src.alias, src.path)
            }
            docs.append(doc)
            return doc.allPages.map { .pdfPage($0) }
        }
    }

    private static func pages(for range: SlideRange, in doc: PDFDocument) -> [PDFPage] {
        let count = doc.pageCount
        guard count > 0 else { return [] }
        let indices: [Int]
        switch range {
        case .all:                 indices = Array(0 ..< count)
        case .first(let n):        indices = Array(0 ..< min(n, count))
        case .suffix(let f):       indices = Array(max(0, f - 1) ..< count)
        case .range(let a, let b): indices = Array(max(0, a - 1) ..< min(b, count))
        }
        return indices.compactMap { doc.page(at: $0) }
    }
}

// MARK: - Helpers

private extension PDFDocument {
    var allPages: [PDFPage] { (0 ..< pageCount).compactMap { page(at: $0) } }
}

private extension Comparable {
    func clamped(to range: Range<Self>) -> Self {
        Swift.max(range.lowerBound, Swift.min(self, range.upperBound))
    }
}
