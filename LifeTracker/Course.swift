import Foundation
import SwiftData

/// A class/course the user is taking, with its meeting times and notes.
@Model
final class Course {
    var name: String
    var instructor: String
    var location: String
    /// Hex color used for the class's dot/accent.
    var colorHex: String
    var notes: String
    var createdAt: Date
    @Relationship(deleteRule: .cascade, inverse: \ClassMeeting.course)
    var meetings: [ClassMeeting] = []
    @Relationship(deleteRule: .cascade, inverse: \Assessment.course)
    var assessments: [Assessment] = []

    init(name: String = "New Class",
         instructor: String = "",
         location: String = "",
         colorHex: String = "F3D0D7",
         notes: String = "") {
        self.name = name
        self.instructor = instructor
        self.location = location
        self.colorHex = colorHex
        self.notes = notes
        self.createdAt = .now
    }
}

/// A single weekly meeting time for a class.
@Model
final class ClassMeeting {
    /// 0 = Monday … 6 = Sunday.
    var weekday: Int
    var startTime: Date
    var endTime: Date
    var location: String
    var createdAt: Date
    var course: Course?

    init(weekday: Int, startTime: Date, endTime: Date, location: String = "") {
        self.weekday = weekday
        self.startTime = startTime
        self.endTime = endTime
        self.location = location
        self.createdAt = .now
    }
}

/// An exam, midterm, quiz, or other dated assessment for a class.
@Model
final class Assessment {
    var title: String
    var date: Date
    var location: String
    var createdAt: Date
    var course: Course?

    init(title: String = "Exam", date: Date = .now, location: String = "") {
        self.title = title
        self.date = date
        self.location = location
        self.createdAt = .now
    }
}
