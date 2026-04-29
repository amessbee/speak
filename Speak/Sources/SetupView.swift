import SwiftUI
import UniformTypeIdentifiers

/// Setup screen: pick PDF, pick video, set the split point, then launch.
struct SetupView: View {
    @ObservedObject var vm: PresentationViewModel

//    @State private var pdfURL: URL?
//    @State private var videoURL: URL?
    @State private var pdfURL: URL? = URL(fileURLWithPath: "/Users/lupin/work/mudassir/s26/slides/main.pdf")
    @State private var videoURL: URL? = URL(fileURLWithPath: "/Users/lupin/work/mudassir/s26/slides/baby.mp4")
    @State private var videoAfterPage: Int = 21
    @State private var errorMessage: String?

    var canLaunch: Bool { pdfURL != nil && videoURL != nil }

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [Color(hex: "#0f0f14"), Color(hex: "#1a1a24")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 40) {

                // Title
                VStack(spacing: 6) {
                    Text("PDF Presenter")
                        .font(.system(size: 34, weight: .thin, design: .serif))
                        .foregroundStyle(.white)
                    Text("seamless pdf + video presentations")
                        .font(.system(size: 13, weight: .regular, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))
                        .tracking(2)
                }
                .padding(.top, 20)

                // File pickers
                VStack(spacing: 16) {
                    FilePicker(
                        label: "PDF File",
                        icon: "doc.richtext",
                        url: $pdfURL,
                        allowedTypes: ["pdf"]
                    )
                    FilePicker(
                        label: "Video File",
                        icon: "play.rectangle",
                        url: $videoURL,
                        allowedTypes: ["mov", "mp4", "m4v", "avi"]
                    )
                }

                // Video position stepper
                VStack(spacing: 10) {
                    Text("Insert video after page")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))

                    HStack(spacing: 0) {
                        Button(action: { if videoAfterPage > 1 { videoAfterPage -= 1 } }) {
                            Image(systemName: "minus")
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(StepperButtonStyle(side: .left))

                        Text("\(videoAfterPage)")
                            .font(.system(size: 22, weight: .light, design: .monospaced))
                            .foregroundStyle(.white)
                            .frame(width: 60, height: 44)
                            .background(Color.white.opacity(0.05))

                        Button(action: { videoAfterPage += 1 }) {
                            Image(systemName: "plus")
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(StepperButtonStyle(side: .right))
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(.white.opacity(0.12))
                    )
                }

                // Error
                if let error = errorMessage {
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundStyle(.red.opacity(0.8))
                }

                // Launch button
                Button(action: launch) {
                    HStack(spacing: 10) {
                        Image(systemName: "play.fill")
                        Text("Start Presentation")
                            .fontWeight(.medium)
                    }
                    .frame(width: 220, height: 48)
                    .background(
                        canLaunch
                        ? LinearGradient(colors: [Color(hex: "#5b6ef5"), Color(hex: "#8b5cf6")], startPoint: .leading, endPoint: .trailing)
                        : LinearGradient(colors: [Color.white.opacity(0.08), Color.white.opacity(0.08)], startPoint: .leading, endPoint: .trailing)
                    )
                    .foregroundStyle(canLaunch ? .white : .white.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .disabled(!canLaunch)
                .animation(.easeInOut(duration: 0.2), value: canLaunch)
            }
            .padding(48)
            .frame(maxWidth: 480)
        }
    }

    private func launch() {
        guard let pdf = pdfURL, let video = videoURL else { return }
        vm.load(pdfURL: pdf, videoURL: video, videoAfterPage: videoAfterPage)
        if !vm.isLoaded {
            errorMessage = "Could not load PDF. Please check the file."
        }
    }
}

// MARK: - File Picker Row

struct FilePicker: View {
    let label: String
    let icon: String
    @Binding var url: URL?
    let allowedTypes: [String]

    var body: some View {
        Button(action: pick) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .frame(width: 22)
                    .foregroundStyle(url != nil ? Color(hex: "#8b5cf6") : .white.opacity(0.4))

                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                    Text(url?.lastPathComponent ?? "Click to choose…")
                        .font(.system(size: 14))
                        .foregroundStyle(url != nil ? .white : .white.opacity(0.3))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer()

                Image(systemName: url != nil ? "checkmark.circle.fill" : "folder")
                    .foregroundStyle(url != nil ? Color(hex: "#8b5cf6") : .white.opacity(0.2))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(url != nil ? Color(hex: "#8b5cf6").opacity(0.4) : .white.opacity(0.08))
            )
        }
        .buttonStyle(.plain)
    }

    private func pick() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        
        // Convert file extensions to UTTypes
        var contentTypes: [UTType] = []
        for ext in allowedTypes {
            if ext == "pdf" {
                contentTypes.append(.pdf)
            } else if ext == "mov" {
                contentTypes.append(.movie)
            } else if ext == "mp4" || ext == "m4v" {
                contentTypes.append(.mpeg4Movie)
            } else if ext == "avi" {
                contentTypes.append(.avi)
            } else if let type = UTType(filenameExtension: ext) {
                contentTypes.append(type)
            }
        }
        
        panel.allowedContentTypes = contentTypes.isEmpty ? [.data] : contentTypes
        
        if panel.runModal() == .OK {
            url = panel.url
        }
    }
}

// MARK: - Button Styles

enum StepperSide { case left, right }

struct StepperButtonStyle: ButtonStyle {
    let side: StepperSide
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white.opacity(configuration.isPressed ? 0.4 : 0.7))
            .background(Color.white.opacity(configuration.isPressed ? 0.1 : 0.05))
    }
}

// MARK: - Color Hex Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - UTType extension removed (using explicit type mapping instead)
