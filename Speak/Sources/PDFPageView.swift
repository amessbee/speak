import SwiftUI
import PDFKit

/// Renders a single PDFPage using PDFKit's native renderer.
/// This gives identical quality to Preview.app — fully Retina-aware.
struct PDFPageView: NSViewRepresentable {
    let page: PDFPage

    func makeNSView(context: Context) -> PDFSinglePageView {
        let view = PDFSinglePageView()
        view.page = page
        return view
    }

    func updateNSView(_ nsView: PDFSinglePageView, context: Context) {
        nsView.page = page
        nsView.needsDisplay = true
    }
}

/// Custom NSView that renders exactly one PDF page, scaled to fit,
/// with full Retina support via the backing scale factor.
final class PDFSinglePageView: NSView {
    
    var page: PDFPage? {
        didSet { needsLayout = true; needsDisplay = true }
    }
    
    override var isFlipped: Bool { true }
    override var wantsUpdateLayer: Bool { false }
    
    override func draw(_ dirtyRect: NSRect) {
        guard let page = page, let ctx = NSGraphicsContext.current?.cgContext else { return }
        
        // Fill background
        NSColor.black.setFill()
        dirtyRect.fill()
        
        let pageBounds = page.bounds(for: .mediaBox)
        guard pageBounds.width > 0, pageBounds.height > 0 else { return }
        
        // Calculate scale to fit while preserving aspect ratio
        let scaleX = bounds.width / pageBounds.width
        let scaleY = bounds.height / pageBounds.height
        let scale = min(scaleX, scaleY)
        
        let scaledWidth = pageBounds.width * scale
        let scaledHeight = pageBounds.height * scale
        
        // Center in view
        let offsetX = (bounds.width - scaledWidth) / 2
        let offsetY = (bounds.height - scaledHeight) / 2
        
        // White slide background
        ctx.saveGState()
        ctx.setFillColor(NSColor.white.cgColor)
        ctx.fill(CGRect(x: offsetX, y: offsetY, width: scaledWidth, height: scaledHeight))
        
        // Transform: move to top-left of PDF area, then flip vertically
        ctx.translateBy(x: offsetX, y: offsetY + scaledHeight)
        ctx.scaleBy(x: scale, y: -scale)
        
        page.draw(with: .mediaBox, to: ctx)
        ctx.restoreGState()
    }
}
