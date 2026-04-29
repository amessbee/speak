import SwiftUI
import PDFKit

/// Renders a single PDFPage using PDFKit's native PDFView.
/// Supports text selection, copy, and find — identical to Preview.app.
struct PDFPageView: NSViewRepresentable {
    let page: PDFPage

    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.displayMode = .singlePage
        view.autoScales = true
        view.backgroundColor = .black
        view.displaysPageBreaks = false
        view.displayBox = .mediaBox
        return view
    }

    func updateNSView(_ nsView: PDFView, context: Context) {
        if nsView.document !== page.document {
            nsView.document = page.document
        }
        nsView.go(to: page)
    }
}
