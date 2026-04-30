import Foundation

/// Shared singleton used to hand a .speakplan URL from the AppDelegate
/// to ContentView at launch or when a file is opened from Finder.
@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()
    private init() {}

    @Published var pendingPlanURL: URL?
    @Published var pendingPDFURL: URL?

    func open(_ url: URL) {
        switch url.pathExtension.lowercased() {
        case "speakplan": pendingPlanURL = url
        case "pdf":       pendingPDFURL  = url
        default:          break
        }
    }
}
