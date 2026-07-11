import SwiftUI
import SwiftData

/// The To-Do page: pick a day, add tasks for that day, check them off, delete them.
struct TodoView: View {
    @State private var selectedDay: Date = .now

    var body: some View {
        VStack(spacing: 0) {
            dayHeader
            Divider().opacity(0.3)
            // The actual list lives in a subview so it can query SwiftData
            // for just the selected day.
            DayTodoList(day: selectedDay)
        }
        .background(Color.pagePink)
        .navigationTitle("To-Do")
    }

    // MARK: Day navigation bar

    private var dayHeader: some View {
        HStack(spacing: 12) {
            Button { changeDay(by: -1) } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.plain)

            VStack(spacing: 2) {
                Text(relativeLabel)
                    .font(.title2.bold())
                Text(selectedDay.formatted(.dateTime.weekday(.wide).month().day()))
                    .font(.subheadline)
                    .opacity(0.7)
            }
            .frame(minWidth: 220)

            Button { changeDay(by: 1) } label: {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.plain)

            Spacer()

            Button("Today") { selectedDay = .now }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.brandPink, in: Capsule())
                .foregroundStyle(Color.inkOnPink)
        }
        .font(.title3)
        .foregroundStyle(Color.inkOnPink)
        .padding()
    }

    /// "Today" / "Yesterday" / "Tomorrow", otherwise a short date.
    private var relativeLabel: String {
        let cal = Calendar.current
        if cal.isDateInToday(selectedDay) { return "Today" }
        if cal.isDateInYesterday(selectedDay) { return "Yesterday" }
        if cal.isDateInTomorrow(selectedDay) { return "Tomorrow" }
        return selectedDay.formatted(.dateTime.month(.abbreviated).day())
    }

    private func changeDay(by days: Int) {
        if let d = Calendar.current.date(byAdding: .day, value: days, to: selectedDay) {
            selectedDay = d
        }
    }
}

/// Shows and edits the to-dos for one specific day. It rebuilds its SwiftData
/// query whenever `day` changes.
struct DayTodoList: View {
    @Environment(\.modelContext) private var context
    @Query private var items: [TodoItem]
    let day: Date

    @State private var newTitle = ""

    init(day: Date) {
        self.day = day
        let start = Calendar.current.startOfDay(for: day)
        _items = Query(
            filter: #Predicate<TodoItem> { $0.day == start },
            sort: \TodoItem.createdAt
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            addBar
            if items.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(items) { item in
                            TodoRow(item: item, onDelete: { delete(item) })
                        }
                    }
                    .padding()
                }
            }
        }
    }

    private var addBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus")
                .foregroundStyle(Color.inkOnPink.opacity(0.6))
            TextField("Add a task…", text: $newTitle)
                .textFieldStyle(.plain)
                .font(.title3)
                .foregroundStyle(Color.inkOnPink)
                .onSubmit(add)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.white, in: RoundedRectangle(cornerRadius: 10))
        .padding()
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "checklist")
                .font(.system(size: 44))
            Text("No tasks yet for this day.")
                .font(.title3)
            Text("Type above and press Return to add one.")
                .font(.subheadline)
                .opacity(0.7)
        }
        .foregroundStyle(Color.inkOnPink.opacity(0.8))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func add() {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        context.insert(TodoItem(title: trimmed, day: day))
        newTitle = ""
    }

    private func delete(_ item: TodoItem) {
        context.delete(item)
    }
}

/// A single to-do row: a checkbox, the title, and a delete button on hover.
struct TodoRow: View {
    @Bindable var item: TodoItem
    let onDelete: () -> Void

    @State private var hovering = false

    var body: some View {
        HStack(spacing: 12) {
            Button {
                item.isDone.toggle()
            } label: {
                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(item.isDone ? Color.brandPink : Color.inkOnPink.opacity(0.5))
            }
            .buttonStyle(.plain)

            Text(item.title)
                .font(.title3)
                .strikethrough(item.isDone)
                .foregroundStyle(item.isDone ? Color.inkOnPink.opacity(0.5) : Color.inkOnPink)

            Spacer()

            if hovering {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundStyle(Color.inkOnPink.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(hovering ? Color.hoverPink : .white, in: RoundedRectangle(cornerRadius: 10))
        .onHover { hovering = $0 }
    }
}
