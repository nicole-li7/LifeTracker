import SwiftUI
import SwiftData

/// The Calendar page: a month grid on the left, and the selected day's events
/// on the right where you can add and remove them.
struct CalendarView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \CalendarEvent.createdAt) private var events: [CalendarEvent]
    @Query private var assessments: [Assessment]

    @State private var visibleMonth: Date = .now
    @State private var selectedDay: Date = Calendar.current.startOfDay(for: .now)

    private var cal: Calendar { Calendar.current }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            monthSection
                .frame(maxWidth: .infinity)
            Divider().opacity(0.3)
            DayEventsPanel(day: selectedDay,
                           events: eventsByDay[selectedDay] ?? [],
                           assessments: assessmentsByDay[selectedDay] ?? [])
                .frame(width: 300)
        }
        .background(Color.pagePink)
        .navigationTitle("Calendar")
    }

    // MARK: Month grid

    private var monthSection: some View {
        VStack(spacing: 12) {
            monthHeader
            weekdayHeader
            grid
            Spacer(minLength: 0)
        }
        .padding()
    }

    private var monthHeader: some View {
        HStack {
            Button { changeMonth(by: -1) } label: { Image(systemName: "chevron.left") }
                .buttonStyle(.plain)
            Spacer()
            Text(visibleMonth.formatted(.dateTime.month(.wide).year()))
                .font(.title2.bold())
            Spacer()
            Button { changeMonth(by: 1) } label: { Image(systemName: "chevron.right") }
                .buttonStyle(.plain)
            Button("Today") {
                visibleMonth = .now
                selectedDay = cal.startOfDay(for: .now)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(Color.brandPink, in: Capsule())
        }
        .font(.title3)
        .foregroundStyle(Color.inkOnPink)
    }

    private var weekdayHeader: some View {
        HStack(spacing: 6) {
            ForEach(orderedWeekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.caption.bold())
                    .foregroundStyle(Color.inkOnPink.opacity(0.6))
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var grid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
            ForEach(gridDays, id: \.self) { date in
                DayCell(
                    date: date,
                    events: eventsByDay[cal.startOfDay(for: date)] ?? [],
                    assessments: assessmentsByDay[cal.startOfDay(for: date)] ?? [],
                    inMonth: cal.isDate(date, equalTo: visibleMonth, toGranularity: .month),
                    isToday: cal.isDateInToday(date),
                    isSelected: cal.isDate(date, inSameDayAs: selectedDay)
                )
                .onTapGesture {
                    selectedDay = cal.startOfDay(for: date)
                    if !cal.isDate(date, equalTo: visibleMonth, toGranularity: .month) {
                        visibleMonth = date
                    }
                }
            }
        }
    }

    // MARK: Data helpers

    /// Groups all events by their day (start of day) for quick lookup.
    private var eventsByDay: [Date: [CalendarEvent]] {
        var map: [Date: [CalendarEvent]] = [:]
        for e in events {
            map[e.day, default: []].append(e)
        }
        // Sort each day: all-day first, then by start time.
        for key in map.keys {
            map[key]?.sort { a, b in
                switch (a.startTime, b.startTime) {
                case (nil, nil): return a.createdAt < b.createdAt
                case (nil, _):   return true
                case (_, nil):   return false
                case let (x?, y?): return x < y
                }
            }
        }
        return map
    }

    /// Groups all exams/midterms by their day for quick lookup.
    private var assessmentsByDay: [Date: [Assessment]] {
        var map: [Date: [Assessment]] = [:]
        for a in assessments {
            map[cal.startOfDay(for: a.date), default: []].append(a)
        }
        for key in map.keys {
            map[key]?.sort { $0.date < $1.date }
        }
        return map
    }

    private var orderedWeekdaySymbols: [String] {
        let symbols = cal.shortWeekdaySymbols            // index 0 = Sunday
        let first = cal.firstWeekday - 1                 // 0-based
        return (0..<7).map { symbols[(first + $0) % 7] }
    }

    /// The 42 days (6 weeks) shown in the grid for the visible month.
    private var gridDays: [Date] {
        guard let monthStart = cal.dateInterval(of: .month, for: visibleMonth)?.start
        else { return [] }
        let weekday = cal.component(.weekday, from: monthStart)
        let offset = (weekday - cal.firstWeekday + 7) % 7
        guard let gridStart = cal.date(byAdding: .day, value: -offset, to: monthStart)
        else { return [] }
        return (0..<42).compactMap { cal.date(byAdding: .day, value: $0, to: gridStart) }
    }

    private func changeMonth(by months: Int) {
        if let d = cal.date(byAdding: .month, value: months, to: visibleMonth) {
            visibleMonth = d
        }
    }
}

/// One day cell in the month grid.
struct DayCell: View {
    let date: Date
    let events: [CalendarEvent]
    let assessments: [Assessment]
    let inMonth: Bool
    let isToday: Bool
    let isSelected: Bool

    private var dayNumber: String {
        "\(Calendar.current.component(.day, from: date))"
    }

    /// How many items total, and how many we can show (up to 2).
    private var totalItems: Int { assessments.count + events.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(dayNumber)
                .font(.callout.weight(isToday ? .bold : .regular))
                .foregroundStyle(isToday ? .white : Color.inkOnPink)
                .frame(width: 24, height: 24)
                .background(isToday ? Color.brandPink : Color.clear, in: Circle())

            // Exams first (with class color + cap icon), then events. Max 2 shown.
            ForEach(Array(assessments.prefix(2))) { exam in
                chip(exam.title,
                     color: Color(hex: exam.course?.colorHex ?? "F3D0D7"),
                     isExam: true)
            }
            ForEach(Array(events.prefix(max(0, 2 - assessments.count)))) { event in
                chip(event.title, color: Color.hoverPink, isExam: false)
            }
            if totalItems > 2 {
                Text("+\(totalItems - 2) more")
                    .font(.system(size: 9))
                    .foregroundStyle(Color.inkOnPink.opacity(0.6))
            }
            Spacer(minLength: 0)
        }
        .padding(6)
        .frame(maxWidth: .infinity, minHeight: 78, alignment: .topLeading)
        .background(inMonth ? .white : Color.white.opacity(0.4),
                    in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(isSelected ? Color.brandPink : Color.clear, lineWidth: 2)
        )
        .opacity(inMonth ? 1 : 0.6)
        .contentShape(Rectangle())
    }

    private func chip(_ title: String, color: Color, isExam: Bool) -> some View {
        HStack(spacing: 2) {
            if isExam {
                Image(systemName: "graduationcap.fill").font(.system(size: 7))
            }
            Text(title).lineLimit(1)
        }
        .font(.system(size: 10))
        .foregroundStyle(Color.inkOnPink)
        .padding(.horizontal, 4).padding(.vertical, 1)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color, in: RoundedRectangle(cornerRadius: 4))
    }
}

/// The right-hand panel showing the selected day's events, with add/remove.
struct DayEventsPanel: View {
    @Environment(\.modelContext) private var context
    let day: Date
    let events: [CalendarEvent]
    let assessments: [Assessment]

    @State private var newTitle = ""
    @State private var newAllDay = true
    @State private var newStart = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: .now) ?? .now
    @State private var newEnd = Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: .now) ?? .now

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(day.formatted(.dateTime.weekday(.wide).month().day()))
                .font(.title3.bold())
                .foregroundStyle(Color.inkOnPink)

            // Exams/midterms on this day (read-only — edit on the School page)
            if !assessments.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(assessments) { exam in
                        HStack(spacing: 8) {
                            Image(systemName: "graduationcap.fill")
                                .font(.caption)
                                .foregroundStyle(Color(hex: exam.course?.colorHex ?? "F3D0D7"))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(exam.title)
                                    .font(.callout)
                                    .foregroundStyle(Color.inkOnPink)
                                Text([exam.course?.name, exam.date.formatted(date: .omitted, time: .shortened)]
                                        .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                                    .font(.caption)
                                    .foregroundStyle(Color.inkOnPink.opacity(0.6))
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 10).padding(.vertical, 8)
                        .background(Color(hex: exam.course?.colorHex ?? "F3D0D7").opacity(0.35),
                                    in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }

            // Add area
            VStack(alignment: .leading, spacing: 8) {
                TextField("Add event…", text: $newTitle)
                    .textFieldStyle(.plain)
                    .foregroundStyle(Color.inkOnPink)
                    .onSubmit(add)

                Toggle("All day", isOn: $newAllDay)
                    .toggleStyle(.checkbox)
                    .foregroundStyle(Color.inkOnPink)

                if !newAllDay {
                    HStack {
                        Text("Start").font(.caption).foregroundStyle(Color.inkOnPink.opacity(0.7))
                        Spacer()
                        DatePicker("", selection: $newStart, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                    }
                    HStack {
                        Text("End").font(.caption).foregroundStyle(Color.inkOnPink.opacity(0.7))
                        Spacer()
                        DatePicker("", selection: $newEnd, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                    }
                }

                Button(action: add) {
                    Label("Add", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.inkOnPink)
                .background(Color.brandPink, in: RoundedRectangle(cornerRadius: 8))
            }
            .padding(12)
            .background(.white, in: RoundedRectangle(cornerRadius: 10))

            // Event list
            if events.isEmpty {
                Spacer()
                Text("No events on this day.")
                    .font(.subheadline)
                    .foregroundStyle(Color.inkOnPink.opacity(0.6))
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(events) { event in
                            EventRow(event: event, onDelete: { context.delete(event) })
                        }
                    }
                }
            }
        }
        .padding()
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func add() {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if newAllDay {
            context.insert(CalendarEvent(title: trimmed, day: day, isAllDay: true))
        } else {
            let start = combine(day: day, time: newStart)
            var end = combine(day: day, time: newEnd)
            // Ensure the end isn't before the start.
            if end <= start {
                end = Calendar.current.date(byAdding: .hour, value: 1, to: start) ?? start
            }
            context.insert(CalendarEvent(title: trimmed, day: day,
                                         isAllDay: false, startTime: start, endTime: end))
        }
        newTitle = ""
    }

    private func combine(day: Date, time: Date) -> Date {
        let cal = Calendar.current
        let d = cal.dateComponents([.year, .month, .day], from: day)
        let t = cal.dateComponents([.hour, .minute], from: time)
        var c = DateComponents()
        c.year = d.year; c.month = d.month; c.day = d.day
        c.hour = t.hour; c.minute = t.minute
        return cal.date(from: c) ?? day
    }
}

/// One event row in the day panel.
struct EventRow: View {
    let event: CalendarEvent
    let onDelete: () -> Void

    @State private var hovering = false

    private var timeText: String {
        if event.isAllDay { return "All day" }
        let start = event.startTime?.formatted(date: .omitted, time: .shortened) ?? ""
        let end = event.endTime?.formatted(date: .omitted, time: .shortened) ?? ""
        return end.isEmpty ? start : "\(start) – \(end)"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(timeText)
                .font(.caption)
                .foregroundStyle(Color.inkOnPink.opacity(0.7))
                .frame(width: 92, alignment: .leading)

            Text(event.title)
                .font(.callout)
                .foregroundStyle(Color.inkOnPink)
                .lineLimit(2)

            Spacer(minLength: 4)

            if hovering {
                Button(action: onDelete) {
                    Image(systemName: "trash").font(.caption)
                        .foregroundStyle(Color.inkOnPink.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(hovering ? Color.hoverPink : .white, in: RoundedRectangle(cornerRadius: 8))
        .onHover { hovering = $0 }
    }
}
