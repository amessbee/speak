import Foundation
import PDFKit

/// A single renderable slide in the presentation.
enum Slide {
    case pdfPage(PDFPage)
    case video(URL)
    case image(URL)
    case youtube(String)   // YouTube video URL string
}
