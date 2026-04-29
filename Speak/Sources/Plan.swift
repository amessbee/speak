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

// MARK: - Plan Actions

enum PlanAction: Identifiable, Codable {
    case pdfSlides(PDFSlidesAction)
    case video(SingleSourceAction)
    case image(SingleSourceAction)
    case conditional(ConditionalAction)

    var id: UUID {
        switch self {
        case .pdfSlides(let a):  return a.id
        case .video(let a):      return a.id
        case .image(let a):      return a.id
        case .conditional(let a): return a.id
        }
    }

    var displayName: String {
        switch self {
        case .pdfSlides(let a):
            return "PDF slides from \"\(a.sourceAlias)\" \(a.range.displayString)"
        case .video(let a):
            return "Video: \"\(a.sourceAlias)\""
        case .image(let a):
            return "Image: \"\(a.sourceAlias)\""
        case .conditional(let a):
            return "If [\(a.triggerKey)] → \(a.ifBranch.displayString) else → \(a.elseBranch.displayString)"
        }
    }

    var systemImage: String {
        switch self {
        case .pdfSlides:   return "doc.richtext"
        case .video:       return "play.rectangle"
        case .image:       return "photo"
        case .conditional: return "arrow.triangle.branch"
        }
    }

    // MARK: Codable

    private enum CodingKeys: String, CodingKey { case type, payload }
    private enum ActionType: String, Codable { case pdfSlides, video, image, conditional }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(ActionType.self, forKey: .type)
        switch type {
        case .pdfSlides:   self = .pdfSlides(try c.decode(PDFSlidesAction.self, forKey: .payload))
        case .video:       self = .video(try c.decode(SingleSourceAction.self, forKey: .payload))
        case .image:       self = .image(try c.decode(SingleSourceAction.self, forKey: .payload))
        case .conditional: self = .conditional(try c.decode(ConditionalAction.self, forKey: .payload))
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .pdfSlides(let a):
            try c.encode(ActionType.pdfSlides, forKey: .type)
            try c.encode(a, forKey: .payload)
        case .video(let a):
            try c.encode(ActionType.video, forKey: .type)
            try c.encode(a, forKey: .payload)
        case .image(let a):
            try c.encode(ActionType.image, forKey: .type)
            try c.encode(a, forKey: .payload)
        case .conditional(let a):
            try c.encode(ActionType.conditional, forKey: .type)
            try c.encode(a, forKey: .payload)
        }
    }
}

// MARK: - Concrete Action Types

struct PDFSlidesAction: Identifiable, Codable {
    var id: UUID = UUID()
    var sourceAlias: String
    var range: SlideRange
}

struct SingleSourceAction: Identifiable, Codable {
    var id: UUID = UUID()
    var sourceAlias: String
}

struct ConditionalAction: Identifiable, Codable {
    var id: UUID = UUID()
    var triggerKey: String    // single character string, e.g. "b"
    var ifBranch: BranchSpec
    var elseBranch: BranchSpec
}

// MARK: - Slide Range

enum SlideRange: Codable, Equatable {
    case all
    case first(Int)
    case suffix(from: Int)
    case range(Int, Int)

    var displayString: String {
        switch self {
        case .all:             return "(all pages)"
        case .first(let n):    return "(pages 1–\(n))"
        case .suffix(let f):   return "(pages \(f)–end)"
        case .range(let a, let b): return "(pages \(a)–\(b))"
        }
    }

    private enum CodingKeys: String, CodingKey { case type, count, from, to }
    private enum RangeType: String, Codable { case all, first, suffix, range }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(RangeType.self, forKey: .type)
        switch type {
        case .all:    self = .all
        case .first:  self = .first(try c.decode(Int.self, forKey: .count))
        case .suffix: self = .suffix(from: try c.decode(Int.self, forKey: .from))
        case .range:
            let a = try c.decode(Int.self, forKey: .from)
            let b = try c.decode(Int.self, forKey: .to)
            self = .range(a, b)
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .all:
            try c.encode(RangeType.all, forKey: .type)
        case .first(let n):
            try c.encode(RangeType.first, forKey: .type)
            try c.encode(n, forKey: .count)
        case .suffix(let f):
            try c.encode(RangeType.suffix, forKey: .type)
            try c.encode(f, forKey: .from)
        case .range(let a, let b):
            try c.encode(RangeType.range, forKey: .type)
            try c.encode(a, forKey: .from)
            try c.encode(b, forKey: .to)
        }
    }
}

// MARK: - Branch Spec

enum BranchSpec: Codable, Equatable {
    case advance
    case jumpBy(Int)
    case playThenAdvance(alias: String)

    var displayString: String {
        switch self {
        case .advance:                  return "advance"
        case .jumpBy(let n):            return "jump \(n > 0 ? "+\(n)" : "\(n)")"
        case .playThenAdvance(let a):   return "play \"\(a)\" then advance"
        }
    }

    private enum CodingKeys: String, CodingKey { case type, offset, alias }
    private enum SpecType: String, Codable { case advance, jumpBy, playThenAdvance }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(SpecType.self, forKey: .type)
        switch type {
        case .advance:         self = .advance
        case .jumpBy:          self = .jumpBy(try c.decode(Int.self, forKey: .offset))
        case .playThenAdvance: self = .playThenAdvance(alias: try c.decode(String.self, forKey: .alias))
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .advance:
            try c.encode(SpecType.advance, forKey: .type)
        case .jumpBy(let n):
            try c.encode(SpecType.jumpBy, forKey: .type)
            try c.encode(n, forKey: .offset)
        case .playThenAdvance(let a):
            try c.encode(SpecType.playThenAdvance, forKey: .type)
            try c.encode(a, forKey: .alias)
        }
    }
}
