import SwiftUI
import AppKit

struct DrawingOverlayView: View {
    @ObservedObject var drawing: DrawingViewModel
    let slideIndex: Int

    // Tracks the overlay's current size so incoming touch points can be normalised.
    @State private var canvasSize: CGSize = CGSize(width: 1, height: 1)

    var body: some View {
        Canvas { ctx, size in
            for stroke in drawing.strokes(for: slideIndex) {
                render(stroke, in: ctx, size: size)
            }
            if let current = drawing.currentStroke {
                render(current, in: ctx, size: size)
            }
        }
        // Keep canvasSize in sync so normalisation uses the live dimensions.
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { canvasSize = geo.size }
                    .onChange(of: geo.size) { _, size in canvasSize = size }
            }
        )
        .allowsHitTesting(drawing.isPenMode)
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .onChanged { value in
                    let pt = normalise(value.location)
                    if drawing.currentStroke == nil {
                        drawing.startStroke(at: pt)
                    } else {
                        drawing.addPoint(pt)
                    }
                }
                .onEnded { _ in
                    drawing.endStroke(slideIndex: slideIndex)
                }
        )
        .onChange(of: drawing.isPenMode) { _, isPen in
            if !isPen { NSCursor.arrow.set() }
        }
    }

    // MARK: - Coordinate helpers

    /// Converts a point in the view's current pixel space to the [0,1]×[0,1] unit square.
    private func normalise(_ point: CGPoint) -> CGPoint {
        CGPoint(x: point.x / max(canvasSize.width,  1),
                y: point.y / max(canvasSize.height, 1))
    }

    // MARK: - Rendering

    /// Renders a stroke whose points are in normalised coordinates, scaling to `size`.
    private func render(_ stroke: DrawingViewModel.Stroke,
                        in ctx: GraphicsContext,
                        size: CGSize) {
        guard !stroke.points.isEmpty else { return }

        let pts = stroke.points.map {
            CGPoint(x: $0.x * size.width, y: $0.y * size.height)
        }

        let shading: GraphicsContext.Shading = stroke.isHighlight
            ? .color(stroke.color.opacity(0.38))
            : .color(stroke.color)
        let style = StrokeStyle(
            lineWidth: stroke.width,
            lineCap:  stroke.isHighlight ? .square : .round,
            lineJoin: stroke.isHighlight ? .miter  : .round
        )

        if pts.count == 1 {
            let p = pts[0], r = stroke.width / 2
            var shape = Path()
            if stroke.isHighlight {
                shape.addRect(CGRect(x: p.x - r, y: p.y - r,
                                    width: stroke.width, height: stroke.width))
            } else {
                shape.addEllipse(in: CGRect(x: p.x - r, y: p.y - r,
                                            width: stroke.width, height: stroke.width))
            }
            ctx.fill(shape, with: shading)
        } else {
            var path = Path()
            path.move(to: pts[0])
            pts.dropFirst().forEach { path.addLine(to: $0) }
            ctx.stroke(path, with: shading, style: style)
        }
    }
}
