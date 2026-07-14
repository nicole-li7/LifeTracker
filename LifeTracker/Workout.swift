import Foundation
import SwiftData

/// A workout session on a given day, containing exercises.
@Model
final class Workout {
    var name: String
    var date: Date
    var createdAt: Date
    @Relationship(deleteRule: .cascade, inverse: \Exercise.workout)
    var exercises: [Exercise] = []

    init(name: String = "Workout", date: Date = .now) {
        self.name = name
        self.date = date
        self.createdAt = .now
    }
}

/// One exercise within a workout, containing sets.
@Model
final class Exercise {
    var name: String
    /// Target scheme shown as guidance, e.g. "3×6–8 to failure".
    var note: String = ""
    var order: Int = 0
    var createdAt: Date
    var workout: Workout?
    @Relationship(deleteRule: .cascade, inverse: \ExerciseSet.exercise)
    var sets: [ExerciseSet] = []

    init(name: String, note: String = "", order: Int = 0) {
        self.name = name
        self.note = note
        self.order = order
        self.createdAt = .now
    }
}

/// A single set: reps at a given weight.
@Model
final class ExerciseSet {
    var reps: Int
    var weight: Double
    var order: Int = 0
    var createdAt: Date
    var exercise: Exercise?

    init(reps: Int, weight: Double, order: Int = 0) {
        self.reps = reps
        self.weight = weight
        self.order = order
        self.createdAt = .now
    }
}
