import SwiftUI
import SwiftData

/// The Weekly Schedule page: one box per day (Mon–Sun). Tasks accumulate through
/// the week and clear every Sunday at 12 AM, unless marked to repeat.
struct WeeklyView: View {
    @Environment(\.modelContext) private var context
    @Query private var allItems: [WeeklyItem]

    // Remembers which week we last reset for (stored as a number on disk).
    @AppStorage("weeklyResetWeekStart") private var storedWeekStartRaw: Double = 0

    private let dayNames = ["Monday", "Tuesday", "Wednesday", "Thursday",
                            "Friday", "Saturday", "Sunday"]

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.3)
            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 240), spacing: 16, alignment: .top)],
                    alignment: .leading,
                    spacing: 16
                ) {
                    ForEach(0..<7, id: \.self) { index in
                        DayColumn(index: index,
                                  name: dayNames[index],
                                  isToday: index == todayIndex)
                    }
                }
                .padding()
            }
        }
        .background(Color.pagePink)
        .navigationTitle("Weekly Schedule")
        .onAppear(perform: resetIfNeeded)
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: 4) {
            Text("This Week")
                .font(.title2.bold())
            Text(weekRangeText)
                .font(.subheadline)
                .opacity(0.75)
            Label("Resets Sunday at 12 AM · mark tasks with 🔁 to keep them", systemImage: "arrow.triangle.2.circlepath")
                .font(.caption)
                .opacity(0.6)
                .padding(.top, 2)
        }
        .foregroundStyle(Color.inkOnPink)
        .frame(maxWidth: .infinity)
        .padding()
    }

    // MARK: Dates

    /// Today as an index where 0 = Monday … 6 = Sunday.
    private var todayIndex: Int {
        let calWeekday = Calendar.current.component(.weekday, from: .now) // 1=Sun … 7=Sat
        return (calWeekday + 5) % 7
    }

    /// The Sunday-at-midnight that starts the week containing `date`.
    private func weekStart(for date: Date) -> Date {
        var cal = Calendar.current
        cal.firstWeekday = 1 // 1 = Sunday
        return cal.dateInterval(of: .weekOfYear, for: date)?.start
            ?? cal.startOfDay(for: date)
    }

    private var weekRangeText: String {
        let start = weekStart(for: .now)
        let end = Calendar.current.date(byAdding: .day, value: 6, to: start) ?? start
        let fmt = Date.FormatStyle.dateTime.month(.abbreviated).day()
        return "\(start.formatted(fmt)) – \(end.formatted(fmt))"
    }

    // MARK: Weekly reset

    /// Runs on appear. If we've crossed into a new week since last time,
    /// delete non-repeating tasks and uncheck the repeating ones.
    private func resetIfNeeded() {
        let currentStart = weekStart(for: .now).timeIntervalSinceReferenceDate

        if storedWeekStartRaw == 0 {
            storedWeekStartRaw = currentStart
            return
        }

        if currentStart > storedWeekStartRaw {
            for item in allItems {
                if item.repeatsWeekly {
                    item.isDone = false
                } else {
                    context.delete(item)
                }
            }
            storedWeekStartRaw = currentStart
        }
    }
}

/// A single day's box: the day name, an add field, and that day's tasks.
struct DayColumn: View {
    @Environment(\.modelContext) private var context
    @Query private var items: [WeeklyItem]

    let index: Int
    let name: String
    let isToday: Bool

    @State private var newTitle = ""

    init(index: Int, name: String, isToday: Bool) {
        self.index = index
        self.name = name
        self.isToday = isToday
        let day = index
        _items = Query(
            filter: #Predicate<WeeklyItem> { $0.weekday == day },
            sort: \WeeklyItem.createdAt
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Day title (highlighted if it's today)
            Text(name)
                .font(.headline)
                .foregroundStyle(Color.inkOnPink)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(isToday ? Color.brandPink : Color.clear,
                            in: RoundedRectangle(cornerRadius: 8))

            // Add field
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.footnote)
                    .foregroundStyle(Color.inkOnPink.opacity(0.5))
                TextField("Add task", text: $newTitle)
                    .textFieldStyle(.plain)
                    .foregroundStyle(Color.inkOnPink)
                    .onSubmit(add)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.hoverPink, in: RoundedRectangle(cornerRadius: 8))

            // Tasks
            if items.isEmpty {
                Text("—")
                    .font(.footnote)
                    .foregroundStyle(Color.inkOnPink.opacity(0.3))
                    .padding(.vertical, 4)
            } else {
                ForEach(items) { item in
                    DayTaskRow(item: item, onDelete: { context.delete(item) })
                }
            }
        }
        .padding(12)
        .background(.white, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isToday ? Color.brandPink : Color.clear, lineWidth: 2)
        )
    }

    private func add() {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        context.insert(WeeklyItem(title: trimmed, weekday: index))
        newTitle = ""
    }
}

/// A compact task row inside a day box: checkbox, title, repeat toggle, delete.
struct DayTaskRow: View {
    @Bindable var item: WeeklyItem
    let onDelete: () -> Void

    @State private var hovering = false

    var body: some View {
        HStack(spacing: 8) {
            Button {
                item.isDone.toggle()
            } label: {
                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(item.isDone ? Color.brandPink : Color.inkOnPink.opacity(0.5))
            }
            .buttonStyle(.plain)

            Text(item.title)
                .font(.callout)
                .strikethrough(item.isDone)
                .foregroundStyle(item.isDone ? Color.inkOnPink.opacity(0.5) : Color.inkOnPink)
                .lineLimit(2)

            Spacer(minLength: 4)

            Button {
                item.repeatsWeekly.toggle()
            } label: {
                Image(systemName: "repeat")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(item.repeatsWeekly ? Color.brandPink : Color.inkOnPink.opacity(0.25))
            }
            .buttonStyle(.plain)
            .help(item.repeatsWeekly
                  ? "Repeats weekly — won't be erased on Sunday. Click to stop."
                  : "Click to repeat this task every week.")

            if hovering {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundStyle(Color.inkOnPink.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(hovering ? Color.hoverPink : Color.clear,
                    in: RoundedRectangle(cornerRadius: 6))
        .onHover { hovering = $0 }
    }
}
