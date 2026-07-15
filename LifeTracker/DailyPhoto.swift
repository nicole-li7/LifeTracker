import Foundation
import SwiftData

/// One photo for a given day — your "photo a day" life diary.
@Model
final class DailyPhoto {
    /// The day this photo belongs to (start of that day). One photo per day.
    var day: Date
    /// The image bytes, stored outside the main database file for efficiency.
    @Attribute(.externalStorage) var imageData: Data
    var createdAt: Date

    init(day: Date, imageData: Data) {
        self.day = Calendar.current.startOfDay(for: day)
        self.imageData = imageData
        self.createdAt = .now
    }
}
