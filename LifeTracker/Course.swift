import Foundation
import SwiftData

/// A class/course the user is taking, with its meeting times and notes.
@Model
final class Course {
    var name: String
    var instructor: String
    var instructorEmail: String = ""
    var location: String
    /// Link to the syllabus (Canvas file, Google Doc, PDF on the web, …).
    var syllabusLink: String = ""
    /// Link to this class's Canvas page.
    var canvasLink: String = ""
    /// Hex color used for the class's dot/accent.
    var colorHex: String
    /// Optional cover photo shown on the class's card, stored outside the main
    /// database file so big images don't slow it down.
    @Attribute(.externalStorage) var photoData: Data?
    /// How the cover photo is framed on the grid card. The original image is
    /// never modified — these say how to zoom and shift it inside the card's
    /// 4:3 window, so the crop can be readjusted any time. Offsets are
    /// fractions of the window's own width/height, so the framing looks the
    /// same at any display size.
    var photoScale: Double = 1
    var photoOffsetX: Double = 0
    var photoOffsetY: Double = 0
    /// The same, for the wide banner on the class page. Kept separate from the
    /// card's framing because the two windows are very different shapes — the
    /// banner might want the bottom of a photo whose card shows the middle.
    var bannerScale: Double = 1
    var bannerOffsetX: Double = 0
    var bannerOffsetY: Double = 0
    /// Legacy free-form notes from before per-lecture notes existed. Kept so
    /// nothing is lost; migrated into a `LectureNote` the first time the class
    /// page is opened.
    var notes: String
    var createdAt: Date
    @Relationship(deleteRule: .cascade, inverse: \ClassMeeting.course)
    var meetings: [ClassMeeting] = []
    @Relationship(deleteRule: .cascade, inverse: \Assessment.course)
    var assessments: [Assessment] = []
    @Relationship(deleteRule: .cascade, inverse: \LectureNote.course)
    var lectures: [LectureNote] = []

    init(name: String = "New Class",
         instructor: String = "",
         instructorEmail: String = "",
         location: String = "",
         syllabusLink: String = "",
         canvasLink: String = "",
         colorHex: String = "F3D0D7",
         notes: String = "") {
        self.name = name
        self.instructor = instructor
        self.instructorEmail = instructorEmail
        self.location = location
        self.syllabusLink = syllabusLink
        self.canvasLink = canvasLink
        self.colorHex = colorHex
        self.notes = notes
        self.createdAt = .now
    }
}

/// One lecture's notes inside a class: a title (“Lecture 3 — recursion”) and a
/// free-form body you can collapse when you're not reading it.
@Model
final class LectureNote {
    var title: String
    var text: String
    /// Persisted so a class reopens with the same notes folded away.
    var isCollapsed: Bool
    var createdAt: Date
    var course: Course?

    init(title: String = "", text: String = "", isCollapsed: Bool = false) {
        self.title = title
        self.text = text
        self.isCollapsed = isCollapsed
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
