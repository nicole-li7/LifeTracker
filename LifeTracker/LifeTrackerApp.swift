import SwiftUI
import SwiftData
import AppKit

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
            LectureNote.self,
            StickyNote.self,
            NoteImage.self,
            DailyPhoto.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create the app's data store: \(error)")
        }
    }()

    // Watches for the app quitting / going to the background so we can write
    // everything to disk first. Without this we'd be relying on SwiftData's
    // automatic saving, which doesn't always get a chance to run before the
    // app closes — which is how edits went missing after a quit.
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear { appDelegate.modelContainer = modelContainer }
        }
        .modelContainer(modelContainer)
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            // A manual "Save" (⌘S) as a belt-and-braces option.
            CommandGroup(after: .saveItem) {
                Button("Save Now") { appDelegate.saveEverything() }
                    .keyboardShortcut("s", modifiers: .command)
            }
        }
    }
}

/// Flushes unsaved changes to disk at the moments the app is most likely to
/// lose them: quitting, hiding, and switching to another app.
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Set once the app's scene appears (see `onAppear` above).
    var modelContainer: ModelContainer?

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        saveEverything()
        return .terminateNow
    }

    func applicationWillTerminate(_ notification: Notification) {
        saveEverything()
    }

    func applicationDidResignActive(_ notification: Notification) {
        saveEverything()
    }

    func applicationDidHide(_ notification: Notification) {
        saveEverything()
    }

    /// Commits whatever is being typed right now, then writes the database.
    func saveEverything() {
        MainActor.assumeIsolated {
            // A text field that still has focus hasn't handed its text to the
            // model yet. Dropping focus makes it commit, so the value we save
            // includes whatever was just typed.
            for window in NSApp.windows where window.isVisible {
                window.makeFirstResponder(nil)
            }

            guard let context = modelContainer?.mainContext, context.hasChanges else { return }
            do {
                try context.save()
            } catch {
                NSLog("LifeTracker: could not save changes on quit: \(error)")
            }
        }
    }
}
