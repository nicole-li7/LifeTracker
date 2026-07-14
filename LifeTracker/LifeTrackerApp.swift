import SwiftUI
import SwiftData

@main
struct LifeTrackerApp: App {
    // The SwiftData "container" is the on-disk database that stores everything
    // (to-dos, budget entries, etc.). We list every @Model type in the schema.
    // As we add features in later phases, we'll add their models here.
    let modelContainer: ModelContainer = {
        let schema = Schema([
            TodoItem.self,
            WeeklyItem.self,
            CalendarEvent.self,
            BudgetEntry.self,
            Workout.self,
            Exercise.self,
            ExerciseSet.self,
            Course.self,
            ClassMeeting.self,
            Assessment.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create the app's data store: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
    }
}
