import Foundation
import SwiftData

/// A single calendar event on a given day. Either all-day, or with a start and
/// end time.
@Model
final class CalendarEvent {
    var title: String
    /// The day the event is on (start of that day).
    var day: Date
    var isAllDay: Bool
    /// Full date+time for the start / end (nil when all-day).
    var startTime: Date?
    var endTime: Date?
    var notes: String
    var createdAt: Date

    init(title: String,
         day: Date,
         isAllDay: Bool = true,
         startTime: Date? = nil,
         endTime: Date? = nil,
         notes: String = "") {
        self.title = title
        self.day = Calendar.current.startOfDay(for: day)
        self.isAllDay = isAllDay
        self.startTime = startTime
        self.endTime = endTime
        self.notes = notes
        self.createdAt = .now
    }
}
