import SwiftUI
import SwiftData

/// The Gym page: a list of workout sessions on the left, and the selected
/// workout's exercises + sets on the right.
struct GymView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Workout.date, order: .reverse) private var workouts: [Workout]

    @State private var selection: Workout?

    var body: some View {
        HStack(spacing: 0) {
            workoutList
                .frame(width: 260)
            Divider().opacity(0.3)
            Group {
                if let workout = selection ?? workouts.first {
                    WorkoutDetail(workout: workout)
                } else {
                    emptyDetail
                }
            }
            .frame(maxWidth: .infinity)
        }
        .background(Color.pagePink)
        .navigationTitle("Gym")
    }

    // MARK: Workout list

    private var workoutList: some View {
        VStack(spacing: 10) {
            Menu {
                ForEach(WorkoutType.allCases) { type in
                    Button("\(type.rawValue) Day") { newWorkout(type: type) }
                }
                Divider()
                Button("Blank Workout", action: addBlank)
            } label: {
                Label("New Workout", systemImage: "plus")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.brandPink, in: RoundedRectangle(cornerRadius: 8))
                    .foregroundStyle(Color.inkOnPink)
            }
            .menuStyle(.borderlessButton)
            .fixedSize(horizontal: false, vertical: true)

            if workouts.isEmpty {
                Spacer()
                Text("No workouts yet.\nCreate one to start logging.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.inkOnPink.opacity(0.6))
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(workouts) { workout in
                            workoutRow(workout)
                        }
                    }
                }
            }
        }
        .padding()
    }

    private func workoutRow(_ workout: Workout) -> some View {
        let isSelected = (selection ?? workouts.first) == workout
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(workout.name.isEmpty ? "Workout" : workout.name)
                    .font(.callout.bold())
                    .foregroundStyle(Color.inkOnPink)
                Text("\(workout.date.formatted(.dateTime.month(.abbreviated).day())) · \(workout.exercises.count) exercises")
                    .font(.caption)
                    .foregroundStyle(Color.inkOnPink.opacity(0.6))
            }
            Spacer()
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(isSelected ? Color.hoverPink : .white, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(isSelected ? Color.brandPink : Color.clear, lineWidth: 2)
        )
        .contentShape(Rectangle())
        .onTapGesture { selection = workout }
        .contextMenu {
            Button(role: .destructive) { delete(workout) } label: {
                Label("Delete Workout", systemImage: "trash")
            }
        }
    }

    private var emptyDetail: some View {
        Text("Select or create a workout.")
            .font(.title3)
            .foregroundStyle(Color.inkOnPink.opacity(0.6))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Actions

    private func newWorkout(type: WorkoutType) {
        selection = buildWorkout(type: type, in: context)
    }

    private func addBlank() {
        let workout = Workout(name: "Workout", date: .now)
        context.insert(workout)
        selection = workout
    }

    private func delete(_ workout: Workout) {
        if selection == workout { selection = nil }
        context.delete(workout)
    }
}

/// Editable detail for one workout: name, date, and its exercises.
struct WorkoutDetail: View {
    @Environment(\.modelContext) private var context
    @Bindable var workout: Workout

    @State private var newExerciseName = ""

    private var sortedExercises: [Exercise] {
        workout.exercises.sorted { ($0.order, $0.createdAt) < ($1.order, $1.createdAt) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Workout header
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Workout name", text: $workout.name)
                        .textFieldStyle(.plain)
                        .font(.title2.bold())
                        .foregroundStyle(Color.inkOnPink)
                    DatePicker("Date", selection: $workout.date, displayedComponents: .date)
                        .foregroundStyle(Color.inkOnPink)
                        .frame(maxWidth: 240)
                }

                // Exercises
                ForEach(sortedExercises) { exercise in
                    ExerciseCard(exercise: exercise, onDelete: { context.delete(exercise) })
                }

                // Add exercise
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .foregroundStyle(Color.inkOnPink.opacity(0.6))
                    TextField("Add exercise…", text: $newExerciseName)
                        .textFieldStyle(.plain)
                        .foregroundStyle(Color.inkOnPink)
                        .onSubmit(addExercise)
                }
                .padding(12)
                .background(.white, in: RoundedRectangle(cornerRadius: 10))
            }
            .padding()
        }
    }

    private func addExercise() {
        let trimmed = newExerciseName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let exercise = Exercise(name: trimmed, order: workout.exercises.count)
        exercise.workout = workout
        context.insert(exercise)
        newExerciseName = ""
    }
}

/// One exercise: its name and a small table of sets (reps × weight).
struct ExerciseCard: View {
    @Environment(\.modelContext) private var context
    @Bindable var exercise: Exercise
    let onDelete: () -> Void

    private var sortedSets: [ExerciseSet] {
        exercise.sets.sorted { ($0.order, $0.createdAt) < ($1.order, $1.createdAt) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    TextField("Exercise name", text: $exercise.name)
                        .textFieldStyle(.plain)
                        .font(.headline)
                        .foregroundStyle(Color.inkOnPink)
                    if !exercise.note.isEmpty {
                        Text(exercise.note)
                            .font(.caption)
                            .foregroundStyle(Color.inkOnPink.opacity(0.6))
                    }
                }
                Spacer()
                Button(action: onDelete) {
                    Image(systemName: "trash").font(.caption)
                        .foregroundStyle(Color.inkOnPink.opacity(0.5))
                }
                .buttonStyle(.plain)
            }

            // Column headers
            HStack {
                Text("Set").frame(width: 40, alignment: .leading)
                Text("Reps").frame(width: 70, alignment: .leading)
                Text("Weight").frame(width: 80, alignment: .leading)
                Spacer()
            }
            .font(.caption.bold())
            .foregroundStyle(Color.inkOnPink.opacity(0.5))

            ForEach(Array(sortedSets.enumerated()), id: \.element.id) { index, set in
                SetRow(set: set, number: index + 1, onDelete: { context.delete(set) })
            }

            Button(action: addSet) {
                Label("Add set", systemImage: "plus.circle")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.inkOnPink.opacity(0.8))
            .padding(.top, 2)
        }
        .padding(12)
        .background(.white, in: RoundedRectangle(cornerRadius: 10))
    }

    private func addSet() {
        // Default the new set to the previous one's values for quick logging.
        let last = sortedSets.last
        let set = ExerciseSet(reps: last?.reps ?? 10, weight: last?.weight ?? 0,
                              order: exercise.sets.count)
        set.exercise = exercise
        context.insert(set)
    }
}

/// One editable set row: number, reps field, weight field, delete.
struct SetRow: View {
    @Bindable var set: ExerciseSet
    let number: Int
    let onDelete: () -> Void

    @State private var hovering = false

    var body: some View {
        HStack {
            Text("\(number)")
                .font(.callout.monospacedDigit())
                .foregroundStyle(Color.inkOnPink.opacity(0.7))
                .frame(width: 40, alignment: .leading)

            TextField("0", value: $set.reps, format: .number)
                .textFieldStyle(.plain)
                .frame(width: 70, alignment: .leading)
                .foregroundStyle(Color.inkOnPink)

            HStack(spacing: 4) {
                TextField("0", value: $set.weight, format: .number)
                    .textFieldStyle(.plain)
                    .frame(width: 60, alignment: .leading)
                    .foregroundStyle(Color.inkOnPink)
                Text("lb").font(.caption).foregroundStyle(Color.inkOnPink.opacity(0.5))
            }
            .frame(width: 80, alignment: .leading)

            Spacer()

            if hovering {
                Button(action: onDelete) {
                    Image(systemName: "minus.circle").font(.caption)
                        .foregroundStyle(Color.inkOnPink.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(hovering ? Color.hoverPink : Color.clear, in: RoundedRectangle(cornerRadius: 6))
        .onHover { hovering = $0 }
    }
}
