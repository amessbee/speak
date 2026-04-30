#!/usr/bin/swift
import AppKit

// Draws directly into a pixel-exact CGContext so Retina display scaling never applies.

func makeIconData(pixels: Int) -> Data? {
    let n = pixels
    let s = CGFloat(n)
    let cs = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(data: nil, width: n, height: n,
                              bitsPerComponent: 8, bytesPerRow: 0,
                              space: cs,
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { return nil }

    // Attach an NSGraphicsContext so NSBezierPath / NSColor work
    let nsCtx = NSGraphicsContext(cgContext: ctx, flipped: false)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = nsCtx
    defer { NSGraphicsContext.restoreGraphicsState() }

    // ── Background ────────────────────────────────────────────────────────
    let bg = NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: s, height: s),
                          xRadius: s * 0.22, yRadius: s * 0.22)
    NSColor(red: 0.059, green: 0.059, blue: 0.094, alpha: 1.0).setFill()
    bg.fill()

    // ── Slide geometry (16:10, slightly below centre) ─────────────────────
    let sh = s * 0.50
    let sw = sh * 1.65
    let sx = (s - sw) / 2.0
    let sy = (s - sh) / 2.0 - s * 0.02

    // ── Ghost slide (behind, offset up-right) ─────────────────────────────
    let off = s * 0.065
    NSColor(red: 0.28, green: 0.26, blue: 0.52, alpha: 0.60).setFill()
    NSBezierPath(roundedRect: NSRect(x: sx + off, y: sy + off, width: sw, height: sh),
                 xRadius: s * 0.04, yRadius: s * 0.04).fill()

    // ── Primary slide – clipped gradient ─────────────────────────────────
    let slideRect = NSRect(x: sx, y: sy, width: sw, height: sh)
    let slidePath = NSBezierPath(roundedRect: slideRect, xRadius: s * 0.04, yRadius: s * 0.04)
    ctx.saveGState()
    slidePath.addClip()

    let c1 = CGColor(red: 0.545, green: 0.361, blue: 0.965, alpha: 1.0)  // #8b5cf6 purple
    let c2 = CGColor(red: 0.357, green: 0.431, blue: 0.961, alpha: 1.0)  // #5b6ef5 indigo
    let gradient = CGGradient(colorsSpace: cs, colors: [c1, c2] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(gradient,
                           start: CGPoint(x: sx, y: sy),
                           end:   CGPoint(x: sx, y: sy + sh), options: [])

    // Subtle top-of-slide highlight
    NSColor(white: 1.0, alpha: 0.07).setFill()
    NSBezierPath(rect: NSRect(x: sx, y: sy + sh * 0.65, width: sw, height: sh * 0.35)).fill()
    ctx.restoreGState()

    // ── Play triangle ─────────────────────────────────────────────────────
    let cx = sx + sw * 0.50
    let cy = sy + sh * 0.50
    let th = sh * 0.32
    let tw = th * 0.88
    let tri = NSBezierPath()
    tri.move(to:  NSPoint(x: cx - tw * 0.40, y: cy + th / 2))
    tri.line(to:  NSPoint(x: cx - tw * 0.40, y: cy - th / 2))
    tri.line(to:  NSPoint(x: cx + tw * 0.60, y: cy))
    tri.close()

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.012),
                  blur:   s * 0.030,
                  color:  CGColor(red: 0, green: 0, blue: 0, alpha: 0.40))
    NSColor(white: 1.0, alpha: 0.96).setFill()
    tri.fill()
    ctx.restoreGState()

    // ── Accent line beneath slide ─────────────────────────────────────────
    let lh = max(s * 0.018, 2.0)
    let lw = sw * 0.28
    NSColor(red: 0.357, green: 0.431, blue: 0.961, alpha: 0.45).setFill()
    NSBezierPath(roundedRect: NSRect(x: sx + (sw - lw) / 2,
                                     y: sy - lh - s * 0.04,
                                     width: lw, height: lh),
                 xRadius: lh / 2, yRadius: lh / 2).fill()

    // ── Export PNG ────────────────────────────────────────────────────────
    guard let cgImg = ctx.makeImage() else { return nil }
    let rep = NSBitmapImageRep(cgImage: cgImg)
    return rep.representation(using: .png, properties: [:])
}

func save(_ data: Data?, to path: String) {
    guard let data else { print("❌  \(path)"); return }
    do {
        try data.write(to: URL(fileURLWithPath: path))
        let kb = data.count / 1024
        print("✓  \(path)  (\(kb) KB)")
    } catch { print("❌  \(path): \(error)") }
}

let base = "Speak/Assets.xcassets/AppIcon.appiconset"
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

for (px, name) in slots { save(makeIconData(pixels: px), to: "\(base)/\(name).png") }

let contents = #"""
{
  "images": [
    { "size": "16x16",   "idiom": "mac", "filename": "icon_16x16.png",      "scale": "1x" },
    { "size": "16x16",   "idiom": "mac", "filename": "icon_16x16@2x.png",   "scale": "2x" },
    { "size": "32x32",   "idiom": "mac", "filename": "icon_32x32.png",      "scale": "1x" },
    { "size": "32x32",   "idiom": "mac", "filename": "icon_32x32@2x.png",   "scale": "2x" },
    { "size": "128x128", "idiom": "mac", "filename": "icon_128x128.png",    "scale": "1x" },
    { "size": "128x128", "idiom": "mac", "filename": "icon_128x128@2x.png", "scale": "2x" },
    { "size": "256x256", "idiom": "mac", "filename": "icon_256x256.png",    "scale": "1x" },
    { "size": "256x256", "idiom": "mac", "filename": "icon_256x256@2x.png", "scale": "2x" },
    { "size": "512x512", "idiom": "mac", "filename": "icon_512x512.png",    "scale": "1x" },
    { "size": "512x512", "idiom": "mac", "filename": "icon_512x512@2x.png", "scale": "2x" }
  ],
  "info": { "version": 1, "author": "xcode" }
}
"""#
try! contents.data(using: .utf8)!.write(to: URL(fileURLWithPath: "\(base)/Contents.json"))
print("✓  Contents.json")
