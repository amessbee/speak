import SwiftUI
import AppKit

struct ImageSlideView: View {
    let url: URL

    @State private var image: NSImage? = nil
    @State private var failed = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geo.size.width, height: geo.size.height)
                } else if failed {
                    Text("Cannot load image")
                        .foregroundStyle(.white.opacity(0.4))
                } else {
                    ProgressView()
                        .controlSize(.large)
                        .tint(.white.opacity(0.5))
                }
            }
        }
        // Re-runs whenever url changes, keeping the view snappy when navigating.
        .task(id: url) {
            image = nil
            failed = false
            let loaded = await Task.detached(priority: .userInitiated) {
                NSImage(contentsOf: url)
            }.value
            if let loaded {
                image = loaded
            } else {
                failed = true
            }
        }
    }
}
