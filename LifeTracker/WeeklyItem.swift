import Foundation
import SwiftData

/// A task on the Weekly Schedule page. Non-repeating items are erased every
/// Sunday at 12 AM; repeating items stay (and get unchecked for the new week).
@Model
final class WeeklyItem {
    var title: String
    var isDone: Bool
    var repeatsWeekly: Bool
    /// Which day box this task lives in: 0 = Monday … 6 = Sunday.
    var weekday: Int
    var createdAt: Date

    init(title: String, isDone: Bool = false, repeatsWeekly: Bool = false, weekday: Int = 0) {
        self.title = title
        self.isDone = isDone
        self.repeatsWeekly = repeatsWeekly
        self.weekday = weekday
        self.createdAt = .now
    }
}
