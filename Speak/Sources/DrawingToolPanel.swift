import SwiftUI

struct DrawingToolPanel: View {
    @ObservedObject var drawing: DrawingViewModel
    let slideIndex: Int

    private let colors: [Color] = [
        .white, .yellow, .red, .orange, .green, .cyan, .blue, .black
    ]
    private let widths: [CGFloat] = [2, 5, 10, 18]

    var body: some View {
        VStack(spacing: 12) {

            // Pen width — bars of increasing thickness
            VStack(spacing: 10) {
                ForEach(widths, id: \.self) { width in
                    Button { drawing.penWidth = width } label: {
                        RoundedRectangle(cornerRadius: width / 2)
                            .fill(drawing.penWidth == width ? drawing.penColor : Color.white.opacity(0.5))
                            .frame(width: 26, height: max(width, 2))
                            .frame(width: 30, height: 22)
                            .background(
                                drawing.penWidth == width
                                    ? RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.12))
                                    : nil
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider().frame(width: 28).background(Color.white.opacity(0.15))

            // Color swatches
            VStack(spacing: 8) {
                ForEach(colors, id: \.self) { color in
                    Button { drawing.penColor = color } label: {
                        Circle()
                            .fill(color)
                            .frame(width: 22, height: 22)
                            .overlay(
                                Circle().strokeBorder(
                                    drawing.penColor == color ? Color.white : Color.white.opacity(0.25),
                                    lineWidth: drawing.penColor == color ? 2 : 0.5
                                )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider().frame(width: 28).background(Color.white.opacity(0.15))

            // Clear drawings on current slide
            Button { drawing.clearStrokes(for: slideIndex) } label: {
                Image(systemName: "trash")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.55))
                    .frame(width: 30, height: 26)
            }
            .buttonStyle(.plain)
            .help("Clear drawings on this slide")
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.5), radius: 12, y: 4)
        )
        .frame(width: 46)
    }
}
