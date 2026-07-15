import SwiftUI
import AppKit

/// Loads slideshow photos from a folder in Application Support. Photos can be
/// added to that folder any time (the app just reads whatever images are there).
@MainActor
final class PhotoStore: ObservableObject {
    static let shared = PhotoStore()

    @Published var images: [NSImage] = []

    /// ~/Library/Application Support/LifeTracker/Slideshow
    static var folderURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                            in: .userDomainMask).first!
        let dir = base.appendingPathComponent("LifeTracker/Slideshow", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private init() { reload() }

    func reload() {
        let exts: Set<String> = ["jpg", "jpeg", "png", "heic", "gif", "tiff", "bmp", "webp"]
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: Self.folderURL, includingPropertiesForKeys: nil)) ?? []
        images = urls
            .filter { exts.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .compactMap { NSImage(contentsOf: $0) }
    }
}
