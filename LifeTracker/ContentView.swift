import SwiftUI
import AppKit

/// The six sections of the app, shown in the sidebar. Adding a new page later
/// is as simple as adding a case here and a view in `detail(for:)`.
enum Page: String, CaseIterable, Identifiable {
    case calendar = "Calendar"
    case todo = "To-Do"
    case weekly = "Weekly Schedule"
    case budget = "Budget"
    case gym = "Gym"
    case school = "School"

    var id: String { rawValue }

    /// SF Symbol icon shown next to the name in the sidebar.
    var icon: String {
        switch self {
        case .calendar: return "calendar"
        case .todo:     return "checklist"
        case .weekly:   return "calendar.day.timeline.left"
        case .budget:   return "dollarsign.circle"
        case .gym:      return "figure.strengthtraining.traditional"
        case .school:   return "graduationcap"
        }
    }
}

struct ContentView: View {
    @State private var selection: Page? = .todo

    var body: some View {
        NavigationSplitView {
            List(Page.allCases, selection: $selection) { page in
                Label(page.rawValue, systemImage: page.icon)
                    .foregroundStyle(Color.inkOnPink)
                    .fontWeight(.medium)
                    .tag(page)
            }
            .navigationTitle("Life Tracker")
            .frame(minWidth: 200)
            .scrollContentBackground(.hidden)
            .background(Color.sidebarPink)
        } detail: {
            ZStack {
                Color.pagePink.ignoresSafeArea()
                if let selection {
                    detail(for: selection)
                } else {
                    Text("Choose a section from the sidebar.")
                        .font(.title3)
                        .foregroundStyle(Color.inkOnPink)
                }
            }
        }
        .tint(.brandPink)
        // Open large (about 90% of the screen), centered.
        .background(WindowSizer())
        // Keep the app in its light appearance so the warm palette reads correctly
        // even when the Mac is set to dark mode.
        .preferredColorScheme(.light)
        // Paint the window's top bar pink with dark text.
        .toolbarBackground(Color.barPink, for: .windowToolbar)
        .toolbarBackground(.visible, for: .windowToolbar)
        .toolbarColorScheme(.light, for: .windowToolbar)
    }

    /// Maps each sidebar page to the view that fills the main area.
    @ViewBuilder
    private func detail(for page: Page) -> some View {
        switch page {
        case .calendar: CalendarView()
        case .todo:     TodoView()
        case .weekly:   WeeklyView()
        case .budget:   BudgetView()
        case .gym:      GymView()
        case .school:   SchoolView()
        }
    }
}

/// Temporary placeholder shown for pages we haven't built yet. Each phase
/// replaces one of these with the real feature.
struct ComingSoonPage: View {
    let page: Page

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: page.icon)
                .font(.system(size: 52))
                .foregroundStyle(Color.inkOnPink)
            Text(page.rawValue)
                .font(.largeTitle.bold())
                .foregroundStyle(Color.inkOnPink)
            Text("This page is coming soon — we'll build it in an upcoming phase.")
                .font(.title3)
                .foregroundStyle(Color.inkOnPink.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.pagePink)
        .navigationTitle(page.rawValue)
    }
}

/// Sizes the window to ~90% of the screen and centers it when the app opens.
struct WindowSizer: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window,
                  let screen = window.screen ?? NSScreen.main else { return }
            let visible = screen.visibleFrame
            let margin: CGFloat = 0.05          // 5% margin on each side → 90% size
            let width = visible.width * (1 - margin * 2)
            let height = visible.height * (1 - margin * 2)
            let x = visible.minX + (visible.width - width) / 2
            let y = visible.minY + (visible.height - height) / 2
            window.setFrame(NSRect(x: x, y: y, width: width, height: height),
                            display: true, animate: false)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

#Preview {
    ContentView()
}
