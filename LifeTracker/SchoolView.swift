import SwiftUI
import SwiftData

/// The School page: a list of classes on the left, and the selected class's
/// details (schedule, instructor, room, notes) on the right.
struct SchoolView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Course.createdAt) private var courses: [Course]

    @State private var selection: Course?

    var body: some View {
        HStack(spacing: 0) {
            classList
                .frame(width: 240)
            Divider().opacity(0.3)
            Group {
                if let course = selection ?? courses.first {
                    CourseDetail(course: course)
                } else {
                    Text("Add a class to get started.")
                        .font(.title3)
                        .foregroundStyle(Color.inkOnPink.opacity(0.6))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .background(Color.pagePink)
        .navigationTitle("School")
    }

    private var classList: some View {
        VStack(spacing: 10) {
            Button(action: addClass) {
                Label("Add Class", systemImage: "plus")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.brandPink, in: RoundedRectangle(cornerRadius: 8))
                    .foregroundStyle(Color.inkOnPink)
            }
            .buttonStyle(.plain)

            if courses.isEmpty {
                Spacer()
                Text("No classes yet.")
                    .font(.subheadline)
                    .foregroundStyle(Color.inkOnPink.opacity(0.6))
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(courses) { course in
                            classRow(course)
                        }
                    }
                }
            }
        }
        .padding()
    }

    private func classRow(_ course: Course) -> some View {
        let isSelected = (selection ?? courses.first) == course
        return HStack(spacing: 8) {
            Circle()
                .fill(Color(hex: course.colorHex))
                .frame(width: 12, height: 12)
            Text(course.name.isEmpty ? "Untitled" : course.name)
                .font(.callout.weight(.medium))
                .foregroundStyle(Color.inkOnPink)
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(isSelected ? Color.hoverPink : .white, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(isSelected ? Color.brandPink : Color.clear, lineWidth: 2)
        )
        .contentShape(Rectangle())
        .onTapGesture { selection = course }
        .contextMenu {
            Button(role: .destructive) { delete(course) } label: {
                Label("Delete Class", systemImage: "trash")
            }
        }
    }

    private func addClass() {
        let course = Course()
        context.insert(course)
        selection = course
    }

    private func delete(_ course: Course) {
        if selection == course { selection = nil }
        context.delete(course)
    }
}

/// Editable detail for one class.
struct CourseDetail: View {
    @Environment(\.modelContext) private var context
    @Bindable var course: Course

    private let palette = ["F3D0D7", "F3D7CA", "F5EEE6", "C8E6D4", "CFE0F0", "E5D4F0"]
    private let dayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    private var sortedMeetings: [ClassMeeting] {
        course.meetings.sorted {
            ($0.weekday, $0.startTime) < ($1.weekday, $1.startTime)
        }
    }

    private var sortedAssessments: [Assessment] {
        course.assessments.sorted { $0.date < $1.date }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Title + color
                HStack {
                    TextField("Class name", text: $course.name)
                        .textFieldStyle(.plain)
                        .font(.title.bold())
                        .foregroundStyle(Color.inkOnPink)
                    Spacer()
                    colorPicker
                }

                // Instructor + location
                HStack(spacing: 10) {
                    field(icon: "person", placeholder: "Instructor", text: $course.instructor)
                    field(icon: "mappin.and.ellipse", placeholder: "Room / location", text: $course.location)
                }

                // Schedule
                sectionHeader("Schedule")
                VStack(spacing: 6) {
                    ForEach(sortedMeetings) { meeting in
                        MeetingRow(meeting: meeting, dayNames: dayNames,
                                   onDelete: { context.delete(meeting) })
                    }
                    Button(action: addMeeting) {
                        Label("Add meeting time", systemImage: "plus.circle")
                            .font(.callout)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.inkOnPink.opacity(0.8))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 2)
                }

                // Exams & midterms
                sectionHeader("Exams & Midterms")
                VStack(spacing: 6) {
                    ForEach(sortedAssessments) { assessment in
                        AssessmentRow(assessment: assessment,
                                      onDelete: { context.delete(assessment) })
                    }
                    Button(action: addAssessment) {
                        Label("Add exam / midterm", systemImage: "plus.circle")
                            .font(.callout)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.inkOnPink.opacity(0.8))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 2)
                }

                // Notes
                sectionHeader("Notes & assignments")
                TextEditor(text: $course.notes)
                    .font(.body)
                    .foregroundStyle(Color.inkOnPink)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 120)
                    .padding(8)
                    .background(.white, in: RoundedRectangle(cornerRadius: 10))
            }
            .padding()
        }
    }

    private var colorPicker: some View {
        HStack(spacing: 6) {
            ForEach(palette, id: \.self) { hex in
                Circle()
                    .fill(Color(hex: hex))
                    .frame(width: 20, height: 20)
                    .overlay(
                        Circle().strokeBorder(Color.inkOnPink,
                                              lineWidth: course.colorHex == hex ? 2 : 0)
                    )
                    .onTapGesture { course.colorHex = hex }
            }
        }
    }

    private func field(icon: String, placeholder: String, text: Binding<String>) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).foregroundStyle(Color.inkOnPink.opacity(0.6))
            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .foregroundStyle(Color.inkOnPink)
        }
        .padding(10)
        .background(.white, in: RoundedRectangle(cornerRadius: 8))
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(Color.inkOnPink)
    }

    private func addMeeting() {
        let cal = Calendar.current
        let start = cal.date(bySettingHour: 9, minute: 0, second: 0, of: .now) ?? .now
        let end = cal.date(bySettingHour: 10, minute: 0, second: 0, of: .now) ?? .now
        let meeting = ClassMeeting(weekday: 0, startTime: start, endTime: end)
        meeting.course = course
        context.insert(meeting)
    }

    private func addAssessment() {
        let cal = Calendar.current
        let date = cal.date(bySettingHour: 9, minute: 0, second: 0, of: .now) ?? .now
        let assessment = Assessment(title: "Exam", date: date)
        assessment.course = course
        context.insert(assessment)
    }
}

/// One editable exam/midterm row: title, date & time, room, and a countdown.
struct AssessmentRow: View {
    @Bindable var assessment: Assessment
    let onDelete: () -> Void

    @State private var hovering = false

    private var countdown: String {
        let cal = Calendar.current
        let days = cal.dateComponents([.day],
                                      from: cal.startOfDay(for: .now),
                                      to: cal.startOfDay(for: assessment.date)).day ?? 0
        if days == 0 { return "Today" }
        if days == 1 { return "Tomorrow" }
        if days > 1 { return "in \(days) days" }
        return "past"
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "graduationcap.fill")
                .font(.caption)
                .foregroundStyle(Color.expenseRose)

            TextField("Exam name", text: $assessment.title)
                .textFieldStyle(.plain)
                .foregroundStyle(Color.inkOnPink)
                .frame(minWidth: 90)

            DatePicker("", selection: $assessment.date,
                       displayedComponents: [.date, .hourAndMinute])
                .labelsHidden()

            Text(countdown)
                .font(.caption.bold())
                .foregroundStyle(Color.inkOnPink.opacity(0.7))

            TextField("Room", text: $assessment.location)
                .textFieldStyle(.plain)
                .foregroundStyle(Color.inkOnPink)
                .frame(minWidth: 50)

            Spacer()

            if hovering {
                Button(action: onDelete) {
                    Image(systemName: "trash").font(.caption)
                        .foregroundStyle(Color.inkOnPink.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(hovering ? Color.hoverPink : .white, in: RoundedRectangle(cornerRadius: 8))
        .onHover { hovering = $0 }
    }
}

/// One editable meeting-time row: day, start, end, room.
struct MeetingRow: View {
    @Bindable var meeting: ClassMeeting
    let dayNames: [String]
    let onDelete: () -> Void

    @State private var hovering = false

    var body: some View {
        HStack(spacing: 8) {
            Picker("", selection: $meeting.weekday) {
                ForEach(0..<7, id: \.self) { i in Text(dayNames[i]).tag(i) }
            }
            .labelsHidden()
            .frame(width: 70)

            DatePicker("", selection: $meeting.startTime, displayedComponents: .hourAndMinute)
                .labelsHidden()
            Text("–").foregroundStyle(Color.inkOnPink.opacity(0.6))
            DatePicker("", selection: $meeting.endTime, displayedComponents: .hourAndMinute)
                .labelsHidden()

            TextField("Room", text: $meeting.location)
                .textFieldStyle(.plain)
                .foregroundStyle(Color.inkOnPink)
                .frame(minWidth: 60)

            Spacer()

            if hovering {
                Button(action: onDelete) {
                    Image(systemName: "trash").font(.caption)
                        .foregroundStyle(Color.inkOnPink.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(hovering ? Color.hoverPink : .white, in: RoundedRectangle(cornerRadius: 8))
        .onHover { hovering = $0 }
    }
}
