import Foundation
import SwiftData

/// A pre-defined exercise used to auto-fill a workout template.
struct ExerciseTemplate {
    let name: String
    let note: String
    let setCount: Int
    let defaultReps: Int
    let defaultWeight: Double

    init(_ name: String, note: String, sets: Int = 3, reps: Int = 8, weight: Double = 0) {
        self.name = name
        self.note = note
        self.setCount = sets
        self.defaultReps = reps
        self.defaultWeight = weight
    }
}

/// The three workout day types. Picking one auto-fills its exercises.
enum WorkoutType: String, CaseIterable, Identifiable {
    case push = "Push"
    case pull = "Pull"
    case glutes = "Glutes"

    var id: String { rawValue }

    var exercises: [ExerciseTemplate] {
        switch self {
        case .push:
            return [
                ExerciseTemplate("Dumbbell Bench Press", note: "3×6–8 to failure"),
                ExerciseTemplate("Chest Fly (machine preferred, dumbbell if taken)", note: "3×6–8 to failure"),
                ExerciseTemplate("Tricep Rope Pushdown", note: "3×6–8 to failure"),
                ExerciseTemplate("Lateral Raises or Shoulder Press", note: "3×6–8 to failure"),
            ]
        case .pull:
            return [
                ExerciseTemplate("Lat Pulldown (cable)", note: "3×6–8 to failure"),
                ExerciseTemplate("Seated Row (cable)", note: "3×6–8 to failure"),
                ExerciseTemplate("Bicep Curl (dumbbell)", note: "3×6–8 to failure"),
                ExerciseTemplate("Hammer / Preacher Curl (dumbbell)", note: "3×6–8 to failure"),
            ]
        case .glutes:
            return [
                ExerciseTemplate("Hip Thrust Machine (or barbell)", note: "3×6–8 to failure", weight: 45),
                ExerciseTemplate("Bulgarian Split Squat (smith machine)", note: "3×6–8/side to failure"),
                ExerciseTemplate("Cable Kickback", note: "3×6–8/side to failure"),
                ExerciseTemplate("Hip Abduction Machine", note: "3×6–8 to failure"),
                ExerciseTemplate("Leg Press", note: "3×6–8 to failure", weight: 55),
            ]
        }
    }
}

/// Core work appended to the end of every session.
let coreExercises: [ExerciseTemplate] = [
    ExerciseTemplate("Cable Crunches", note: "3×15", reps: 15),
    ExerciseTemplate("In & Outs", note: "3×15", reps: 15),
    ExerciseTemplate("Leg Raises", note: "3×12–15", reps: 15),
    ExerciseTemplate("Single Leg Dead Bugs", note: "3×10/side", reps: 10),
    ExerciseTemplate("Weighted Dead Bugs", note: "3×10/side", reps: 10),
    ExerciseTemplate("Plank", note: "1×60 sec", sets: 1, reps: 60),
]

/// Builds a fully populated workout for the given type (its exercises + core).
@MainActor
func buildWorkout(type: WorkoutType, in context: ModelContext) -> Workout {
    let workout = Workout(name: "\(type.rawValue) Day", date: .now)
    context.insert(workout)

    var exerciseOrder = 0
    func add(_ templates: [ExerciseTemplate]) {
        for t in templates {
            let exercise = Exercise(name: t.name, note: t.note, order: exerciseOrder)
            exerciseOrder += 1
            exercise.workout = workout
            context.insert(exercise)
            for i in 0..<t.setCount {
                let set = ExerciseSet(reps: t.defaultReps, weight: t.defaultWeight, order: i)
                set.exercise = exercise
                context.insert(set)
            }
        }
    }

    add(type.exercises)
    add(coreExercises)
    return workout
}
