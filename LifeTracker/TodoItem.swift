import Foundation
import SwiftData

/// A single to-do item. `@Model` tells SwiftData to save this to disk
/// automatically. We'll use it for the daily To-Do lists in Phase 2.
@Model
final class TodoItem {
    var title: String
    var isDone: Bool
    /// The day this to-do belongs to (start of that day).
    var day: Date
    var createdAt: Date

    init(title: String, isDone: Bool = false, day: Date = .now) {
        self.title = title
        self.isDone = isDone
        self.day = Calendar.current.startOfDay(for: day)
        self.createdAt = .now
    }
}
