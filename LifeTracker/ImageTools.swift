import AppKit
import Foundation

/// Shared image handling for the pages that store photos in SwiftData
/// (Memories' photo-a-day, School's class covers).
enum ImageTools {
    /// Loads an image from disk and re-encodes it as a reasonably sized JPEG,
    /// so full-resolution camera files don't bloat the database.
    static func downscaledJPEG(from url: URL, maxDimension: CGFloat = 1600) -> Data? {
        guard let image = NSImage(contentsOf: url) else { return nil }
        return downscaledJPEG(from: image, maxDimension: maxDimension)
    }

    static func downscaledJPEG(from image: NSImage, maxDimension: CGFloat = 1600) -> Data? {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return nil }
        let scale = min(1, maxDimension / max(size.width, size.height))
        let target = NSSize(width: size.width * scale, height: size.height * scale)

        let resized = NSImage(size: target)
        resized.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: target))
        resized.unlockFocus()

        guard let tiff = resized.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .jpeg, properties: [.compressionFactor: 0.85])
    }

    /// Loads one of the app's built-in class cover photos by name.
    static func bundledJPEG(named name: String, maxDimension: CGFloat = 1600) -> Data? {
        // Synchronized folders may land flat in Resources or keep their folder,
        // so try both before giving up.
        let url = Bundle.main.url(forResource: name, withExtension: "jpg")
            ?? Bundle.main.url(forResource: name, withExtension: "jpg", subdirectory: "ClassPhotos")
        guard let url else { return nil }
        return downscaledJPEG(from: url, maxDimension: maxDimension)
    }

    /// Pulls a picture off the clipboard — a screenshot, a copied image, or a
    /// copied image file — and encodes it for storage. Returns nil when the
    /// clipboard holds something that isn't a picture.
    static func jpegFromPasteboard(_ pasteboard: NSPasteboard = .general,
                                   maxDimension: CGFloat = 1600) -> Data? {
        guard let image = NSImage(pasteboard: pasteboard) else { return nil }
        return downscaledJPEG(from: image, maxDimension: maxDimension)
    }

    /// Reads a file the user picked or dragged in, handling the security scope
    /// that sandboxed drops come wrapped in.
    static func jpegFromPickedFile(_ url: URL, maxDimension: CGFloat = 1600) -> Data? {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
        return downscaledJPEG(from: url, maxDimension: maxDimension)
    }
}
