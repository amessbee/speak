import SwiftUI

struct DrawingToolPanel: View {
    @ObservedObject var drawing: DrawingViewModel
    let slideIndex: Int

    private let penColors: [Color]     = [.white, .yellow, .red, .orange, .green, .cyan, .blue, .black]
    private let penWidths: [CGFloat]   = [2, 5, 10, 18]

    private let highlightColors: [Color]   = [.yellow, Color(red: 0.6, green: 1.0, blue: 0.3),
                                               .cyan,   Color(red: 1.0, green: 0.5, blue: 0.85),
                                               .orange, Color(red: 0.75, green: 0.5, blue: 1.0)]
    private let highlightWidths: [CGFloat] = [10, 20, 30, 40]

    private var isPen: Bool { drawing.drawMode == .pen }
    private var colors:  [Color]   { isPen ? penColors      : highlightColors  }
    private var widths:  [CGFloat] { isPen ? penWidths       : highlightWidths  }
    private var selColor: Color    { isPen ? drawing.penColor : drawing.highlightColor }
    private var selWidth: CGFloat  { isPen ? drawing.penWidth : drawing.highlightWidth }

    var body: some View {
        VStack(spacing: 12) {

            // MARK: Mode toggle
            VStack(spacing: 4) {
                modeButton("pencil.tip",  active: isPen)          { drawing.activatePen() }
                modeButton("highlighter", active: !isPen)         { drawing.activateHighlight() }
            }

            divider()

            // MARK: Width bars
            VStack(spacing: 10) {
                ForEach(widths, id: \.self) { w in
                    Button { setWidth(w) } label: {
                        let maxW = widths.max() ?? 1
                        let h   = max(w / maxW * 18, 2)
                        RoundedRectangle(cornerRadius: h / 2)
                            .fill(selWidth == w ? selColor : Color.white.opacity(0.5))
                            .frame(width: 26, height: h)
                            .frame(width: 30, height: 22)
                            .background(selWidth == w
                                ? RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.12))
                                : nil)
                    }
                    .buttonStyle(.plain)
                }
            }

            divider()

            // MARK: Color swatches
            VStack(spacing: 8) {
                ForEach(colors, id: \.self) { c in
                    Button { setColor(c) } label: {
                        Circle()
                            .fill(c)
                            .frame(width: 22, height: 22)
                            .overlay(Circle().strokeBorder(
                                selColor == c ? Color.white : Color.white.opacity(0.25),
                                lineWidth: selColor == c ? 2 : 0.5))
                    }
                    .buttonStyle(.plain)
                }
            }

            divider()

            // MARK: Actions
            actionButton("arrow.uturn.backward", help: "Undo last stroke (⌘Z)") { drawing.undo() }
            actionButton("trash",                help: "Clear drawings on this slide") { drawing.clearStrokes(for: slideIndex) }
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

    // MARK: - Helpers

    private func setWidth(_ w: CGFloat) {
        if isPen { drawing.penWidth = w } else { drawing.highlightWidth = w }
    }

    private func setColor(_ c: Color) {
        if isPen { drawing.penColor = c } else { drawing.highlightColor = c }
    }

    @ViewBuilder
    private func modeButton(_ icon: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(active ? Color.white : Color.white.opacity(0.38))
                .frame(width: 30, height: 26)
                .background(active ? RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.15)) : nil)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func actionButton(_ icon: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.55))
                .frame(width: 30, height: 26)
        }
        .buttonStyle(.plain)
        .help(help)
    }

    @ViewBuilder
    private func divider() -> some View {
        Rectangle()
            .fill(Color.white.opacity(0.12))
            .frame(width: 28, height: 1)
    }
}
