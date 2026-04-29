import Foundation
import PDFKit
import AVFoundation

// MARK: - Slide Types

/// A single slide in the presentation sequence.
/// It's either a PDF page or a video clip.
enum Slide {
    case pdfPage(PDFPage)
    case video(URL)
}

// MARK: - Presentation Sequence

/// Builds the ordered sequence of slides from a PDF and a video.
/// Rule: first N pdf pages → video → remaining pdf pages.
struct PresentationSequence {
    let document: PDFDocument
    let slides: [Slide]
    let totalCount: Int

    /// - Parameters:
    ///   - pdfURL: URL of the PDF file
    ///   - videoURL: URL of the video file
    ///   - videoAfterPage: Insert the video after this many PDF pages (e.g. 5 = after page 5, so video is "slide 6")
    init?(pdfURL: URL, videoURL: URL, videoAfterPage: Int) {
        guard let pdf = PDFDocument(url: pdfURL) else {
            print("❌ Could not load PDF at \(pdfURL.path)")
            return nil
        }

        let pageCount = pdf.pageCount
        var sequence: [Slide] = []

        // First chunk: pages 0..<videoAfterPage
        let firstChunkEnd = min(videoAfterPage, pageCount)
        for i in 0..<firstChunkEnd {
            if let page = pdf.page(at: i) {
                sequence.append(.pdfPage(page))
            }
        }

        // Video slide
        sequence.append(.video(videoURL))

        // Second chunk: remaining pages
        for i in firstChunkEnd..<pageCount {
            if let page = pdf.page(at: i) {
                sequence.append(.pdfPage(page))
            }
        }

        self.document = pdf
        self.slides = sequence
        self.totalCount = sequence.count
    }
}
