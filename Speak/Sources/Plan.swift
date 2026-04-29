import Foundation

// MARK: - Top-level Plan

struct Plan: Codable {
    var version: Int = 1
    var sources: [SourceFile] = []
    var actions: [PlanAction] = []

    static let empty = Plan()
}

// MARK: - Source File

struct SourceFile: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var alias: String
    var path: String
    var kind: SourceKind
}

enum SourceKind: String, Codable, CaseIterable {
    case pdf, image, video

    var label: String {
        switch self {
        case .pdf:   return "PDF"
        case .image: return "Image"
        case .video: return "Video"
        }
    }

    var systemImage: String {
        switch self {
        case .pdf:   return "doc.richtext"
        case .image: return "photo"
        case .video: return "play.rectangle"
        }
    }

    var aliasPrefix: String {
        switch self {
        case .pdf:   return "pdf"
        case .image: return "image"
        case .video: return "video"
        }
    }

    var allowedExtensions: [String] {
        switch self {
        case .pdf:   return ["pdf"]
        case .image: return ["png", "jpg", "jpeg", "heic", "tiff", "gif", "bmp", "webp"]
        case .video: return ["mov", "mp4", "m4v", "avi"]
        }
    }
}

// MARK: - Hotkeys

struct HotkeyBehavior: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var key: String       // single character, e.g. "b"
    var action: HotkeyAction
}

enum HotkeyAction: Codable, Equatable {
    /// Jump to 1-based page N within the current PDF action block.
    case jumpToPage(Int)
    /// Restart playback of the current video or image from the beginning.
    case replayFromStart
    /// Play a media alias as a detour, then return to the next item in the main sequence.
    case playDetour(alias: String)
    /// Skip the rest of this action and jump to the first item of the next action.
    case skipToNextAction
    /// Jump to the first item of the previous action.
    case goBackToPreviousAction

    var displayString: String {
        switch self {
        case .jumpToPage(let n):       return "Jump to page \(n)"
        case .replayFromStart:          return "Replay from start"
        case .playDetour(let a):       return "Play \"\(a)\" then return"
        case .skipToNextAction:         return "Skip to next"
        case .goBackToPreviousAction:   return "Go back"
        }
    }

    private enum CodingKeys: String, CodingKey { case type, page, alias }
    private enum HKType: String, Codable {
        case jumpToPage, replayFromStart, playDetour, skipToNextAction, goBackToPreviousAction
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(HKType.self, forKey: .type) {
        case .jumpToPage:            self = .jumpToPage(try c.decode(Int.self, forKey: .page))
        case .replayFromStart:        self = .replayFromStart
        case .playDetour:            self = .playDetour(alias: try c.decode(String.self, forKey: .alias))
        case .skipToNextAction:       self = .skipToNextAction
        case .goBackToPreviousAction: self = .goBackToPreviousAction
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .jumpToPage(let n):
            try c.encode(HKType.jumpToPage, forKey: .type); try c.encode(n, forKey: .page)
        case .replayFromStart:
            try c.encode(HKType.replayFromStart, forKey: .type)
        case .playDetour(let a):
            try c.encode(HKType.playDetour, forKey: .type); try c.encode(a, forKey: .alias)
        case .skipToNextAction:
            try c.encode(HKType.skipToNextAction, forKey: .type)
        case .goBackToPreviousAction:
            try c.encode(HKType.goBackToPreviousAction, forKey: .type)
        }
    }
}

// MARK: - Plan Actions

enum PlanAction: Identifiable, Codable {
    case pdfSlides(PDFSlidesAction)
    case video(SingleSourceAction)
    case image(SingleSourceAction)

    var id: UUID {
        switch self {
        case .pdfSlides(let a): return a.id
        case .video(let a):     return a.id
        case .image(let a):     return a.id
        }
    }

    var hotkeys: [HotkeyBehavior] {
        switch self {
        case .pdfSlides(let a): return a.hotkeys
        case .video(let a):     return a.hotkeys
        case .image(let a):     return a.hotkeys
        }
    }

    var displayName: String {
        switch self {
        case .pdfSlides(let a):
            let hk = hotkeySuffix(a.hotkeys)
            return "PDF slides from \"\(a.sourceAlias)\" \(a.range.displayString)\(hk)"
        case .video(let a):
            return "Video: \"\(a.sourceAlias)\"\(hotkeySuffix(a.hotkeys))"
        case .image(let a):
            return "Image: \"\(a.sourceAlias)\"\(hotkeySuffix(a.hotkeys))"
        }
    }

    var systemImage: String {
        switch self {
        case .pdfSlides: return "doc.richtext"
        case .video:     return "play.rectangle"
        case .image:     return "photo"
        }
    }

    private func hotkeySuffix(_ hks: [HotkeyBehavior]) -> String {
        guard !hks.isEmpty else { return "" }
        return " · \(hks.count) hotkey\(hks.count == 1 ? "" : "s")"
    }

    // MARK: Codable

    private enum CodingKeys: String, CodingKey { case type, payload }
    private enum ActionType: String, Codable { case pdfSlides, video, image }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(ActionType.self, forKey: .type) {
        case .pdfSlides: self = .pdfSlides(try c.decode(PDFSlidesAction.self, forKey: .payload))
        case .video:     self = .video(try c.decode(SingleSourceAction.self, forKey: .payload))
        case .image:     self = .image(try c.decode(SingleSourceAction.self, forKey: .payload))
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .pdfSlides(let a):
            try c.encode(ActionType.pdfSlides, forKey: .type); try c.encode(a, forKey: .payload)
        case .video(let a):
            try c.encode(ActionType.video, forKey: .type); try c.encode(a, forKey: .payload)
        case .image(let a):
            try c.encode(ActionType.image, forKey: .type); try c.encode(a, forKey: .payload)
        }
    }
}

// MARK: - Concrete Action Types

struct PDFSlidesAction: Identifiable, Codable {
    var id: UUID = UUID()
    var sourceAlias: String
    var range: SlideRange
    var hotkeys: [HotkeyBehavior] = []
}

struct SingleSourceAction: Identifiable, Codable {
    var id: UUID = UUID()
    var sourceAlias: String
    var hotkeys: [HotkeyBehavior] = []
}

// MARK: - Slide Range

enum SlideRange: Codable, Equatable {
    case all
    case first(Int)
    case suffix(from: Int)
    case range(Int, Int)

    var displayString: String {
        switch self {
        case .all:                 return "(all pages)"
        case .first(let n):        return "(pages 1–\(n))"
        case .suffix(let f):       return "(pages \(f)–end)"
        case .range(let a, let b): return "(pages \(a)–\(b))"
        }
    }

    private enum CodingKeys: String, CodingKey { case type, count, from, to }
    private enum RangeType: String, Codable { case all, first, suffix, range }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(RangeType.self, forKey: .type) {
        case .all:    self = .all
        case .first:  self = .first(try c.decode(Int.self, forKey: .count))
        case .suffix: self = .suffix(from: try c.decode(Int.self, forKey: .from))
        case .range:  self = .range(try c.decode(Int.self, forKey: .from), try c.decode(Int.self, forKey: .to))
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .all:
            try c.encode(RangeType.all, forKey: .type)
        case .first(let n):
            try c.encode(RangeType.first, forKey: .type); try c.encode(n, forKey: .count)
        case .suffix(let f):
            try c.encode(RangeType.suffix, forKey: .type); try c.encode(f, forKey: .from)
        case .range(let a, let b):
            try c.encode(RangeType.range, forKey: .type)
            try c.encode(a, forKey: .from); try c.encode(b, forKey: .to)
        }
    }
}
