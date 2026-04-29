import SwiftUI
import AppKit

struct ImageSlideView: View {
    let url: URL

    var body: some View {
        GeometryReader { geo in
            if let nsImage = NSImage(contentsOf: url) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geo.size.width, height: geo.size.height)
            } else {
                Color.black.overlay(
                    Text("Cannot load image")
                        .foregroundStyle(.white.opacity(0.4))
                )
            }
        }
    }
}
