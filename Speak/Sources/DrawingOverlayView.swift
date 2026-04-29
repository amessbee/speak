import SwiftUI
import AppKit

struct DrawingOverlayView: View {
    @ObservedObject var drawing: DrawingViewModel
    let slideIndex: Int

    var body: some View {
        Canvas { ctx, _ in
            for stroke in drawing.strokes(for: slideIndex) {
                render(stroke, in: ctx)
            }
            if let current = drawing.currentStroke {
                render(current, in: ctx)
            }
        }
        .allowsHitTesting(drawing.isPenMode)
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .onChanged { value in
                    if drawing.currentStroke == nil {
                        drawing.startStroke(at: value.location)
                    } else {
                        drawing.addPoint(value.location)
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

    private func render(_ stroke: DrawingViewModel.Stroke, in ctx: GraphicsContext) {
        guard !stroke.points.isEmpty else { return }

        let shading: GraphicsContext.Shading = stroke.isHighlight
            ? .color(stroke.color.opacity(0.38))
            : .color(stroke.color)
        let style = StrokeStyle(
            lineWidth: stroke.width,
            lineCap: stroke.isHighlight ? .square : .round,
            lineJoin: stroke.isHighlight ? .miter : .round
        )

        if stroke.points.count == 1 {
            let p = stroke.points[0], r = stroke.width / 2
            var shape = Path()
            if stroke.isHighlight {
                shape.addRect(CGRect(x: p.x - r, y: p.y - r, width: stroke.width, height: stroke.width))
            } else {
                shape.addEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: stroke.width, height: stroke.width))
            }
            ctx.fill(shape, with: shading)
        } else {
            var path = Path()
            path.move(to: stroke.points[0])
            stroke.points.dropFirst().forEach { path.addLine(to: $0) }
            ctx.stroke(path, with: shading, style: style)
        }
    }
}
