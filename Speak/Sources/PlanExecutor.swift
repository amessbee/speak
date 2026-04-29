import Foundation
import PDFKit

// MARK: - Executable Items

enum ExecutableItem {
    case pdfPage(PDFPage)
    case video(URL)
    case image(URL)
    case decision(Decision)
}

struct Decision {
    let triggerKey: Character
    let ifInserts: [ExecutableItem]
    let elseJumpOffset: Int
}

// MARK: - Errors

enum ExecutorError: LocalizedError {
    case emptyPlan
    case sourceNotFound(String)
    case fileUnreadable(String, String)

    var errorDescription: String? {
        switch self {
        case .emptyPlan:
            return "The plan has no actions."
        case .sourceNotFound(let alias):
            return "Source \"\(alias)\" not found in source list."
        case .fileUnreadable(let alias, let path):
            return "Cannot read file for \"\(alias)\" at \(path)."
        }
    }
}

// MARK: - PlanExecutor

final class PlanExecutor {

    let items: [ExecutableItem]
    private let retainedDocuments: [PDFDocument]

    init(plan: Plan) throws {
        guard !plan.actions.isEmpty else { throw ExecutorError.emptyPlan }

        let sourceMap = Dictionary(uniqueKeysWithValues: plan.sources.map { ($0.alias, $0) })

        var docs: [PDFDocument] = []
        var result: [ExecutableItem] = []

        for action in plan.actions {
            let newItems = try PlanExecutor.compile(
                action: action,
                sourceMap: sourceMap,
                docs: &docs
            )
            result.append(contentsOf: newItems)
        }

        self.items = result
        self.retainedDocuments = docs
    }

    // MARK: - Private compile

    private static func compile(
        action: PlanAction,
        sourceMap: [String: SourceFile],
        docs: inout [PDFDocument]
    ) throws -> [ExecutableItem] {
        switch action {
        case .pdfSlides(let a):
            guard let src = sourceMap[a.sourceAlias] else {
                throw ExecutorError.sourceNotFound(a.sourceAlias)
            }
            let url = URL(fileURLWithPath: src.path)
            guard let doc = PDFDocument(url: url) else {
                throw ExecutorError.fileUnreadable(a.sourceAlias, src.path)
            }
            docs.append(doc)
            let pages = Self.pages(for: a.range, in: doc)
            return pages.map { .pdfPage($0) }

        case .video(let a):
            guard let src = sourceMap[a.sourceAlias] else {
                throw ExecutorError.sourceNotFound(a.sourceAlias)
            }
            return [.video(URL(fileURLWithPath: src.path))]

        case .image(let a):
            guard let src = sourceMap[a.sourceAlias] else {
                throw ExecutorError.sourceNotFound(a.sourceAlias)
            }
            return [.image(URL(fileURLWithPath: src.path))]

        case .conditional(let a):
            guard let triggerChar = a.triggerKey.first else { return [] }

            let ifItems = try compileInserts(branch: a.ifBranch, sourceMap: sourceMap, docs: &docs)
            let elseOffset = elseJumpOffset(for: a.elseBranch)

            let decision = Decision(triggerKey: triggerChar, ifInserts: ifItems, elseJumpOffset: elseOffset)
            return [.decision(decision)]
        }
    }

    private static func compileInserts(
        branch: BranchSpec,
        sourceMap: [String: SourceFile],
        docs: inout [PDFDocument]
    ) throws -> [ExecutableItem] {
        switch branch {
        case .advance, .jumpBy:
            return []
        case .playThenAdvance(let alias):
            guard let src = sourceMap[alias] else {
                throw ExecutorError.sourceNotFound(alias)
            }
            switch src.kind {
            case .video:
                let url = URL(fileURLWithPath: src.path)
                guard FileManager.default.fileExists(atPath: src.path) else {
                    throw ExecutorError.fileUnreadable(alias, src.path)
                }
                return [.video(url)]
            case .image:
                let url = URL(fileURLWithPath: src.path)
                guard FileManager.default.fileExists(atPath: src.path) else {
                    throw ExecutorError.fileUnreadable(alias, src.path)
                }
                return [.image(url)]
            case .pdf:
                guard let doc = PDFDocument(url: URL(fileURLWithPath: src.path)) else {
                    throw ExecutorError.fileUnreadable(alias, src.path)
                }
                docs.append(doc)
                return doc.pages.map { .pdfPage($0) }
            }
        }
    }

    private static func elseJumpOffset(for branch: BranchSpec) -> Int {
        switch branch {
        case .advance:          return 1
        case .jumpBy(let n):    return n
        case .playThenAdvance:  return 1
        }
    }

    private static func pages(for range: SlideRange, in doc: PDFDocument) -> [PDFPage] {
        let count = doc.pageCount
        guard count > 0 else { return [] }

        let indices: [Int]
        switch range {
        case .all:
            indices = Array(0..<count)
        case .first(let n):
            indices = Array(0..<min(n, count))
        case .suffix(let from):
            let start = max(0, from - 1)
            indices = Array(start..<count)
        case .range(let a, let b):
            let start = max(0, a - 1)
            let end = min(b, count)
            indices = start < end ? Array(start..<end) : []
        }

        return indices.compactMap { doc.page(at: $0) }
    }
}

// MARK: - PDFDocument pages helper

private extension PDFDocument {
    var pages: [PDFPage] {
        (0..<pageCount).compactMap { page(at: $0) }
    }
}
