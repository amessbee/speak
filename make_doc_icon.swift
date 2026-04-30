#!/usr/bin/swift
import AppKit

// Document icon: portrait page with folded top-right corner.
// Body: very dark navy (matches app). Fold: white triangle.
// Centre: a miniature slide with play triangle.

func makeDocIconData(pixels n: Int) -> Data? {
    let s = CGFloat(n)
    let cs = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(data: nil, width: n, height: n,
                              bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { return nil }

    let nsCtx = NSGraphicsContext(cgContext: ctx, flipped: false)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = nsCtx
    defer { NSGraphicsContext.restoreGraphicsState() }

    // ── Page geometry ─────────────────────────────────────────────────────
    let pageW = s * 0.72
    let pageH = s * 0.84
    let pageX = (s - pageW) / 2
    let pageY = (s - pageH) / 2
    let fold  = s * 0.18          // size of the folded corner
    let r     = s * 0.04          // corner radius

    // ── Page body (dark, clipped to page shape) ───────────────────────────
    // Build page path: rect with top-right corner cut at 45°
    let body = NSBezierPath()
    body.move(to:    NSPoint(x: pageX + r,           y: pageY))
    body.line(to:    NSPoint(x: pageX + pageW - fold, y: pageY))
    body.line(to:    NSPoint(x: pageX + pageW,        y: pageY + fold))
    body.line(to:    NSPoint(x: pageX + pageW,        y: pageY + pageH - r))
    // top-right rounded corner (already cut, so this is actually top-left of that corner)
    body.appendArc(withCenter: NSPoint(x: pageX + pageW - r, y: pageY + pageH - r),
                   radius: r, startAngle: 0, endAngle: 90)
    body.line(to:    NSPoint(x: pageX + r,            y: pageY + pageH))
    body.appendArc(withCenter: NSPoint(x: pageX + r,  y: pageY + pageH - r),
                   radius: r, startAngle: 90, endAngle: 180)
    body.line(to:    NSPoint(x: pageX,                y: pageY + r))
    body.appendArc(withCenter: NSPoint(x: pageX + r,  y: pageY + r),
                   radius: r, startAngle: 180, endAngle: 270)
    body.close()

    // Drop shadow behind page
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.025),
                  blur: s * 0.06,
                  color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.45))
    NSColor(red: 0.072, green: 0.072, blue: 0.115, alpha: 1.0).setFill()
    body.fill()
    ctx.restoreGState()

    // ── Clipped content inside the page ───────────────────────────────────
    ctx.saveGState()
    body.addClip()

    // Page background
    NSColor(red: 0.072, green: 0.072, blue: 0.115, alpha: 1.0).setFill()
    body.fill()

    // Mini slide
    let msh = pageH * 0.36
    let msw = msh * 1.6
    let msx = pageX + (pageW - msw) / 2
    let msy = pageY + pageH * 0.28
    let msr = s * 0.03

    let mSlide = NSBezierPath(roundedRect: NSRect(x: msx, y: msy, width: msw, height: msh),
                              xRadius: msr, yRadius: msr)
    ctx.saveGState()
    mSlide.addClip()
    let c1 = CGColor(red: 0.545, green: 0.361, blue: 0.965, alpha: 1.0)
    let c2 = CGColor(red: 0.357, green: 0.431, blue: 0.961, alpha: 1.0)
    let grad = CGGradient(colorsSpace: cs, colors: [c1, c2] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(grad,
                           start: CGPoint(x: msx, y: msy),
                           end:   CGPoint(x: msx, y: msy + msh), options: [])
    NSColor(white: 1.0, alpha: 0.07).setFill()
    NSBezierPath(rect: NSRect(x: msx, y: msy + msh * 0.65, width: msw, height: msh * 0.35)).fill()
    ctx.restoreGState()

    // Mini play triangle
    let mcx = msx + msw * 0.50
    let mcy = msy + msh * 0.50
    let mth = msh * 0.30
    let mtw = mth * 0.86
    let mTri = NSBezierPath()
    mTri.move(to:  NSPoint(x: mcx - mtw * 0.40, y: mcy + mth / 2))
    mTri.line(to:  NSPoint(x: mcx - mtw * 0.40, y: mcy - mth / 2))
    mTri.line(to:  NSPoint(x: mcx + mtw * 0.60, y: mcy))
    mTri.close()
    NSColor(white: 1.0, alpha: 0.94).setFill()
    mTri.fill()

    ctx.restoreGState()

    // ── Fold triangle (white) ─────────────────────────────────────────────
    let foldTri = NSBezierPath()
    foldTri.move(to:  NSPoint(x: pageX + pageW - fold, y: pageY))
    foldTri.line(to:  NSPoint(x: pageX + pageW,        y: pageY + fold))
    foldTri.line(to:  NSPoint(x: pageX + pageW - fold, y: pageY + fold))
    foldTri.close()
    NSColor(white: 1.0, alpha: 0.88).setFill()
    foldTri.fill()

    // Fold crease shadow
    let crease = NSBezierPath()
    crease.move(to:  NSPoint(x: pageX + pageW - fold, y: pageY))
    crease.line(to:  NSPoint(x: pageX + pageW - fold, y: pageY + fold))
    crease.line(to:  NSPoint(x: pageX + pageW,        y: pageY + fold))
    NSColor(white: 0.0, alpha: 0.18).setStroke()
    crease.lineWidth = max(s * 0.008, 1)
    crease.stroke()

    guard let cgImg = ctx.makeImage() else { return nil }
    return NSBitmapImageRep(cgImage: cgImg).representation(using: .png, properties: [:])
}

func save(_ data: Data?, to path: String) {
    guard let data else { print("❌  \(path)"); return }
    do {
        try data.write(to: URL(fileURLWithPath: path))
        print("✓  \(path)  (\(data.count / 1024) KB)")
    } catch { print("❌  \(path): \(error)") }
}

let fm = FileManager.default
let iconset = "SpeakDoc.iconset"
try? fm.createDirectory(atPath: iconset, withIntermediateDirectories: true)

let slots: [(Int, String)] = [
    (16,   "icon_16x16"),
    (32,   "icon_16x16@2x"),
    (32,   "icon_32x32"),
    (64,   "icon_32x32@2x"),
    (128,  "icon_128x128"),
    (256,  "icon_128x128@2x"),
    (256,  "icon_256x256"),
    (512,  "icon_256x256@2x"),
    (512,  "icon_512x512"),
    (1024, "icon_512x512@2x"),
]
for (px, name) in slots {
    save(makeDocIconData(pixels: px), to: "\(iconset)/\(name).png")
}
print("Run: iconutil -c icns SpeakDoc.iconset -o Speak/SpeakDoc.icns")
