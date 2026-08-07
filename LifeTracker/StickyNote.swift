import Foundation
import SwiftData

/// A small free-form note on the Notes page — a reminder, a code, a scrap of
/// something worth keeping. Deliberately unstructured.
@Model
final class StickyNote {
    var title: String
    var text: String
    /// Hex color of the note card.
    var colorHex: String
    /// Pinned notes sort to the top of the board.
    var isPinned: Bool
    var createdAt: Date
    /// Bumped on every edit; the board sorts by this so recent notes lead.
    var updatedAt: Date
    @Relationship(deleteRule: .cascade, inverse: \NoteImage.note)
    var images: [NoteImage] = []

    init(title: String = "",
         text: String = "",
         colorHex: String = "FBC3C1",
         isPinned: Bool = false) {
        self.title = title
        self.text = text
        self.colorHex = colorHex
        self.isPinned = isPinned
        self.createdAt = .now
        self.updatedAt = .now
    }
}

/// A picture attached to a note — a pasted screenshot, a dragged-in photo.
/// Stored outside the main database file so big images don't slow it down.
@Model
final class NoteImage {
    @Attribute(.externalStorage) var imageData: Data
    var createdAt: Date
    var note: StickyNote?

    init(imageData: Data) {
        self.imageData = imageData
        self.createdAt = .now
    }
}
