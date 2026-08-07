import SwiftUI
import SwiftData
import AppKit

/// The School page. Two screens: a grid of big class cards, and — once you
/// press one — that class's own page with a back button to return to the grid.
struct SchoolView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Course.createdAt) private var courses: [Course]

    /// `nil` shows the grid of classes; non-nil shows that class's page.
    @State private var openCourse: Course?

    private static let cardWidth: CGFloat = 330
    private static let cardSpacing: CGFloat = 22

    var body: some View {
        Group {
            if let course = openCourse {
                coursePage(course)
            } else {
                classGrid
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.pagePink)
        .navigationTitle("School")
    }

    // MARK: - Grid of classes

    private var classGrid: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Classes")
                    .font(.largeTitle.bold())
                    .foregroundStyle(Color.inkOnPink)
                Spacer()
                Button(action: addClass) {
                    Label("Add Class", systemImage: "plus")
                        .font(.callout.weight(.medium))
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(Color.brandPink, in: RoundedRectangle(cornerRadius: 8))
                        .foregroundStyle(Color.inkOnPink)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24).padding(.top, 20).padding(.bottom, 16)

            if courses.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "graduationcap")
                        .font(.system(size: 44))
                        .foregroundStyle(Color.inkOnPink.opacity(0.4))
                    Text("No classes yet.")
                        .font(.title3)
                        .foregroundStyle(Color.inkOnPink.opacity(0.6))
                    Text("Press “Add Class” to make your first one.")
                        .font(.subheadline)
                        .foregroundStyle(Color.inkOnPink.opacity(0.5))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                GeometryReader { geo in
                    // Cards keep a fixed width and start at the left edge, so
                    // they don't stretch as the window resizes.
                    let available = max(0, geo.size.width - 48)
                    let fitting = max(1, Int((available + Self.cardSpacing)
                                             / (Self.cardWidth + Self.cardSpacing)))
                    let columns = max(1, min(fitting, courses.count))
                    let gridWidth = CGFloat(columns) * Self.cardWidth
                        + CGFloat(columns - 1) * Self.cardSpacing

                    ScrollView {
                        LazyVGrid(
                            columns: Array(repeating: GridItem(.fixed(Self.cardWidth),
                                                               spacing: Self.cardSpacing),
                                           count: columns),
                            spacing: Self.cardSpacing
                        ) {
                            ForEach(courses) { course in
                                ClassCard(course: course) { openCourse = course }
                                    .contextMenu {
                                        Button(role: .destructive) { delete(course) } label: {
                                            Label("Delete Class", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                        .frame(width: gridWidth)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                    }
                }
            }
        }
    }

    // MARK: - One class's page

    private func coursePage(_ course: Course) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button { openCourse = nil } label: {
                    Label("All Classes", systemImage: "chevron.left")
                        .font(.callout.weight(.medium))
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(.white, in: RoundedRectangle(cornerRadius: 8))
                        .foregroundStyle(Color.inkOnPink)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape, modifiers: [])

                Spacer()

                Button(role: .destructive) { delete(course) } label: {
                    Label("Delete Class", systemImage: "trash")
                        .font(.callout)
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .foregroundStyle(Color.expenseRose)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24).padding(.top, 18).padding(.bottom, 6)

            CourseDetail(course: course)
        }
    }

    /// The built-in cover photos, handed out to new classes in this order and
    /// cycled once they run out.
    private static let stockPhotos = ["gr1", "gr6", "gr3", "gr4", "gr5"]

    private func addClass() {
        let course = Course()
        let name = Self.stockPhotos[courses.count % Self.stockPhotos.count]
        course.photoData = ImageTools.bundledJPEG(named: name)
        // A little zoom on the banner so the wide strip shows the middle of the
        // picture rather than a thin sliver of it.
        course.bannerScale = 1.3
        context.insert(course)
        openCourse = course
    }

    private func delete(_ course: Course) {
        if openCourse == course { openCourse = nil }
        context.delete(course)
    }
}

/// Draws a class's cover photo with its saved zoom/pan applied. Fills whatever
/// frame it's given, so the portrait grid card and the wide banner on the class
/// page both centre the same part of the picture at the same zoom. Shows a
/// tinted placeholder when the class has no photo yet.
struct CoverPhoto: View {
    let course: Course
    /// Which of the class's two framings to draw with.
    var mode: Mode = .card

    enum Mode { case card, banner }

    /// The card's shape. Squarer than the banner, so the photo gets more of
    /// the card's height.
    static let cardAspect: CGFloat = 6.0 / 5.0
    /// The class page banner's shape. The banner is locked to this ratio rather
    /// than a fixed height, so the crop editor's preview always shows the same
    /// framing the real banner will — a taller or shorter window can't secretly
    /// zoom the picture in or out.
    static let bannerAspect: CGFloat = 5.0

    private var scale: Double {
        mode == .card ? course.photoScale : course.bannerScale
    }
    private var offsetX: Double {
        mode == .card ? course.photoOffsetX : course.bannerOffsetX
    }
    private var offsetY: Double {
        mode == .card ? course.photoOffsetY : course.bannerOffsetY
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(hex: course.colorHex).opacity(0.5)
                if let data = course.photoData, let img = NSImage(data: data) {
                    Image(nsImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .scaleEffect(scale)
                        .offset(x: offsetX * geo.size.width,
                                y: offsetY * geo.size.height)
                } else {
                    Image(systemName: "photo")
                        .font(.system(size: 30))
                        .foregroundStyle(Color.inkOnPink.opacity(0.35))
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
    }
}

/// Pan-and-zoom editor for a class's cover photo. The card and the banner are
/// framed separately — they're very different shapes, so the part of the photo
/// that suits one often isn't the part that suits the other. Works on copies of
/// the framing values, so backing out leaves the saved crop alone.
struct PhotoCropEditor: View {
    let course: Course
    @Environment(\.dismiss) private var dismiss

    @State private var cardScale: Double
    @State private var cardOffsetX: Double
    @State private var cardOffsetY: Double
    @State private var bannerScale: Double
    @State private var bannerOffsetX: Double
    @State private var bannerOffsetY: Double

    private let paneWidth: CGFloat = 440

    init(course: Course) {
        self.course = course
        _cardScale = State(initialValue: course.photoScale)
        _cardOffsetX = State(initialValue: course.photoOffsetX)
        _cardOffsetY = State(initialValue: course.photoOffsetY)
        _bannerScale = State(initialValue: course.bannerScale)
        _bannerOffsetX = State(initialValue: course.bannerOffsetX)
        _bannerOffsetY = State(initialValue: course.bannerOffsetY)
    }

    private var image: NSImage? {
        guard let data = course.photoData else { return nil }
        return NSImage(data: data)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                VStack(spacing: 4) {
                    Text("Adjust the photo")
                        .font(.title3.bold())
                        .foregroundStyle(Color.inkOnPink)
                    Text("Drag each picture to choose what shows, and zoom with the slider or a pinch. The card and the banner are set separately.")
                        .font(.subheadline)
                        .foregroundStyle(Color.inkOnPink.opacity(0.75))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: paneWidth)
                }

                pane(title: "On the class card",
                     aspect: CoverPhoto.cardAspect,
                     width: 300,
                     scale: $cardScale, offsetX: $cardOffsetX, offsetY: $cardOffsetY)

                pane(title: "On the class page banner",
                     aspect: CoverPhoto.bannerAspect,
                     width: paneWidth,
                     scale: $bannerScale, offsetX: $bannerOffsetX, offsetY: $bannerOffsetY)

                HStack {
                    Button("Reset both") {
                        cardScale = 1; cardOffsetX = 0; cardOffsetY = 0
                        bannerScale = 1; bannerOffsetX = 0; bannerOffsetY = 0
                    }
                    Spacer()
                    Button("Cancel") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                    Button("Save") { save() }
                        .keyboardShortcut(.defaultAction)
                }
                .frame(width: paneWidth)
            }
            .padding(24)
        }
        .frame(minWidth: paneWidth + 48, minHeight: 640)
        .background(Color.pagePink)
    }

    private func pane(title: String, aspect: CGFloat, width: CGFloat,
                      scale: Binding<Double>,
                      offsetX: Binding<Double>, offsetY: Binding<Double>) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.inkOnPink.opacity(0.7))
            CropPane(image: image, aspect: aspect, width: width,
                     scale: scale, offsetX: offsetX, offsetY: offsetY)
        }
    }

    private func save() {
        course.photoScale = cardScale
        course.photoOffsetX = cardOffsetX
        course.photoOffsetY = cardOffsetY
        course.bannerScale = bannerScale
        course.bannerOffsetX = bannerOffsetX
        course.bannerOffsetY = bannerOffsetY
        dismiss()
    }
}

/// One draggable, zoomable window onto the photo, with its own zoom slider.
/// Clamped to its own shape only, so a wide banner can roam up and down a tall
/// photo even when the square-ish card has no room to move.
private struct CropPane: View {
    let image: NSImage?
    let aspect: CGFloat
    let width: CGFloat
    @Binding var scale: Double
    @Binding var offsetX: Double
    @Binding var offsetY: Double

    @State private var dragStart: (x: Double, y: Double)?
    @State private var magnifyStart: Double?

    private var height: CGFloat { width / aspect }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Color.hoverPink
                if let img = image {
                    Image(nsImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: width, height: height)
                        .scaleEffect(scale)
                        .offset(x: offsetX * width, y: offsetY * height)
                }
            }
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.brandPink, lineWidth: 2)
            )
            // High priority so the surrounding scroll view can't swallow a
            // vertical drag and scroll the sheet instead of moving the photo.
            .highPriorityGesture(
                DragGesture()
                    .onChanged { value in
                        let start = dragStart ?? (offsetX, offsetY)
                        if dragStart == nil { dragStart = start }
                        offsetX = start.x + value.translation.width / width
                        offsetY = start.y + value.translation.height / height
                        clampOffsets()
                    }
                    .onEnded { _ in dragStart = nil }
            )
            .simultaneousGesture(
                MagnifyGesture()
                    .onChanged { value in
                        let start = magnifyStart ?? scale
                        if magnifyStart == nil { magnifyStart = start }
                        scale = min(4, max(1, start * value.magnification))
                        clampOffsets()
                    }
                    .onEnded { _ in magnifyStart = nil }
            )

            HStack(spacing: 10) {
                Image(systemName: "minus.magnifyingglass")
                    .foregroundStyle(Color.inkOnPink.opacity(0.6))
                Slider(value: $scale, in: 1...4)
                    .tint(.brandPink)
                Image(systemName: "plus.magnifyingglass")
                    .foregroundStyle(Color.inkOnPink.opacity(0.6))
            }
            .frame(width: width)
            .onChange(of: scale) { _, _ in clampOffsets() }

            // When the picture exactly fills this shape there is nothing to
            // slide around, which otherwise just feels broken.
            if !canPan {
                Text("Zoom in to move the picture around.")
                    .font(.caption)
                    .foregroundStyle(Color.inkOnPink.opacity(0.55))
            }
        }
    }

    /// Whether the picture overhangs this window at all at the current zoom.
    private var canPan: Bool {
        guard let img = image, img.size.width > 0, img.size.height > 0 else { return false }
        let imageAspect = img.size.width / img.size.height
        let overhangX = imageAspect > aspect ? (imageAspect / aspect * scale - 1) : (scale - 1)
        let overhangY = imageAspect > aspect ? (scale - 1) : (aspect / imageAspect * scale - 1)
        return overhangX > 0.001 || overhangY > 0.001
    }

    /// Keeps the picture covering this window — you can't drag a blank edge in.
    private func clampOffsets() {
        guard let img = image, img.size.width > 0, img.size.height > 0 else { return }
        let imageAspect = img.size.width / img.size.height

        // How far the picture overhangs the window on each side, as a fraction
        // of the window, once `scaledToFill` has covered it.
        let overhangX: CGFloat
        let overhangY: CGFloat
        if imageAspect > aspect {
            overhangX = (imageAspect / aspect * scale - 1) / 2
            overhangY = (scale - 1) / 2
        } else {
            overhangX = (scale - 1) / 2
            overhangY = (aspect / imageAspect * scale - 1) / 2
        }

        let slackX = max(0, overhangX)
        let slackY = max(0, overhangY)
        offsetX = min(slackX, max(-slackX, offsetX))
        offsetY = min(slackY, max(-slackY, offsetY))
    }
}

/// One big pressable class card in the grid: name, instructor, meeting days,
/// and a countdown to the next exam if there is one.
struct ClassCard: View {
    let course: Course
    let onOpen: () -> Void

    @State private var hovering = false

    private static let dayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    /// "Mon · Wed · Fri" — each day the class meets, in week order, no repeats.
    private var daysSummary: String {
        let days = Set(course.meetings.map(\.weekday)).sorted()
        guard !days.isEmpty else { return "No meeting times yet" }
        return days.compactMap { Self.dayNames.indices.contains($0) ? Self.dayNames[$0] : nil }
            .joined(separator: " · ")
    }

    /// The soonest exam that hasn't happened yet, if any.
    private var nextAssessment: Assessment? {
        let today = Calendar.current.startOfDay(for: .now)
        return course.assessments
            .filter { $0.date >= today }
            .min { $0.date < $1.date }
    }

    private var accent: Color { Color(hex: course.colorHex) }

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 0) {
                photoArea
                infoArea
            }
            .background(accent.opacity(hovering ? 0.4 : 0.24))
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(accent, lineWidth: hovering ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: 14))
        .onHover { hovering = $0 }
    }

    /// The cover photo across the top, inset so the card shows around it.
    /// Its 4:3 shape is what makes the whole card taller than wide.
    private var photoArea: some View {
        CoverPhoto(course: course)
            .aspectRatio(CoverPhoto.cardAspect, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 10)
            .padding(.top, 10)
    }

    private var infoArea: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle()
                    .fill(accent)
                    .frame(width: 14, height: 14)
                Text(course.name.isEmpty ? "Untitled" : course.name)
                    .font(.title3.bold())
                    .foregroundStyle(Color.inkOnPink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.inkOnPink.opacity(hovering ? 0.7 : 0.35))
            }

            if !course.instructor.isEmpty {
                label("person", course.instructor)
            }
            label("clock", daysSummary)
            if let next = nextAssessment {
                label("graduationcap.fill",
                      "\(next.title.isEmpty ? "Exam" : next.title) — \(Self.countdown(to: next.date))")
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
    }

    private func label(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(Color.inkOnPink.opacity(0.55))
            Text(text)
                .font(.subheadline)
                .foregroundStyle(Color.inkOnPink.opacity(0.8))
                .lineLimit(1)
        }
    }

    private static func countdown(to date: Date) -> String {
        let cal = Calendar.current
        let days = cal.dateComponents([.day],
                                      from: cal.startOfDay(for: .now),
                                      to: cal.startOfDay(for: date)).day ?? 0
        if days == 0 { return "today" }
        if days == 1 { return "tomorrow" }
        return "in \(days) days"
    }
}

/// Editable detail for one class.
struct CourseDetail: View {
    @Environment(\.modelContext) private var context
    @Bindable var course: Course

    @State private var showPhotoImporter = false
    @State private var showCropEditor = false
    @State private var dropTargeted = false

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

    private var sortedLectures: [LectureNote] {
        course.lectures.sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                coverPhoto

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

                // Contact + links. Each opens in Mail / your browser once filled in.
                HStack(spacing: 10) {
                    linkField(icon: "envelope", placeholder: "Professor's email",
                              text: $course.instructorEmail, isEmail: true)
                    linkField(icon: "doc.text", placeholder: "Syllabus link",
                              text: $course.syllabusLink)
                    linkField(icon: "globe", placeholder: "Canvas link",
                              text: $course.canvasLink)
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

                // Notes — one collapsible entry per lecture.
                sectionHeader("Notes")
                VStack(spacing: 8) {
                    ForEach(sortedLectures) { lecture in
                        LectureNoteRow(lecture: lecture,
                                       onDelete: { context.delete(lecture) })
                    }
                    Button(action: addLecture) {
                        Label("Add lecture", systemImage: "plus.circle")
                            .font(.callout)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.inkOnPink.opacity(0.8))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 2)
                }
            }
            .padding()
        }
        .onAppear(perform: migrateLegacyNotes)
    }

    /// Old single-box notes predate per-lecture notes. Move that text into a
    /// lecture entry the first time we show the class so nothing is lost.
    private func migrateLegacyNotes() {
        let legacy = course.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !legacy.isEmpty, course.lectures.isEmpty else { return }
        let note = LectureNote(title: "Notes", text: course.notes)
        note.course = course
        context.insert(note)
        course.notes = ""
    }

    /// The class's cover photo — the same image the grid card shows. Click to
    /// pick one, or drag an image straight in from Finder or Photos.
    private var coverPhoto: some View {
        CoverPhoto(course: course, mode: .banner)
            .aspectRatio(CoverPhoto.bannerAspect, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay {
                if course.photoData == nil {
                    VStack(spacing: 6) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 26))
                        Text("Click or drag in a photo for this class")
                            .font(.subheadline)
                    }
                    .foregroundStyle(Color.inkOnPink.opacity(0.65))
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(dropTargeted ? Color.brandPink : Color.clear, lineWidth: 3)
            )
            .overlay(alignment: .bottomTrailing) {
                if course.photoData != nil {
                    HStack(spacing: 10) {
                        Button { showCropEditor = true } label: {
                            Label("Adjust crop", systemImage: "crop")
                        }
                        Button { showPhotoImporter = true } label: {
                            Label("Change", systemImage: "arrow.triangle.2.circlepath")
                        }
                        Button(role: .destructive) { setPhoto(nil) } label: {
                            Label("Remove", systemImage: "trash")
                        }
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(.white.opacity(0.92), in: Capsule())
                    .foregroundStyle(Color.inkOnPink)
                    .padding(12)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 12))
            .onTapGesture { if course.photoData == nil { showPhotoImporter = true } }
            .dropDestination(for: URL.self) { urls, _ in
                guard let url = urls.first,
                      let data = ImageTools.jpegFromPickedFile(url) else { return false }
                setPhoto(data)
                return true
            } isTargeted: { dropTargeted = $0 }
            .fileImporter(isPresented: $showPhotoImporter,
                      allowedContentTypes: [.image],
                      allowsMultipleSelection: false) { result in
            guard case .success(let urls) = result,
                  let url = urls.first,
                  let data = ImageTools.jpegFromPickedFile(url) else { return }
            setPhoto(data)
        }
        .sheet(isPresented: $showCropEditor) {
            PhotoCropEditor(course: course)
        }
    }

    /// Swapping the picture starts the framing over, since a crop meant for
    /// the old photo won't suit a new one.
    private func setPhoto(_ data: Data?) {
        course.photoData = data
        course.photoScale = 1
        course.photoOffsetX = 0
        course.photoOffsetY = 0
        course.bannerScale = 1
        course.bannerOffsetX = 0
        course.bannerOffsetY = 0
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

    /// Like `field`, but with a button that opens the value once it's filled in
    /// — Mail for an address, your browser for a link.
    private func linkField(icon: String, placeholder: String,
                           text: Binding<String>, isEmail: Bool = false) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).foregroundStyle(Color.inkOnPink.opacity(0.6))
            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .foregroundStyle(Color.inkOnPink)
            if let url = Self.url(from: text.wrappedValue, isEmail: isEmail) {
                Button {
                    NSWorkspace.shared.open(url)
                } label: {
                    Image(systemName: isEmail ? "paperplane" : "arrow.up.right.square")
                        .foregroundStyle(Color.brandPink)
                }
                .buttonStyle(.plain)
                .help(isEmail ? "Compose an email" : "Open link")
            }
        }
        .padding(10)
        .background(.white, in: RoundedRectangle(cornerRadius: 8))
    }

    /// Turns typed text into something openable, tolerating a bare "canvas.
    /// school.edu" with no scheme. Returns nil when there's nothing usable yet.
    private static func url(from raw: String, isEmail: Bool) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if isEmail {
            guard trimmed.contains("@") else { return nil }
            return URL(string: "mailto:\(trimmed)")
        }
        if trimmed.lowercased().hasPrefix("http://") || trimmed.lowercased().hasPrefix("https://") {
            return URL(string: trimmed)
        }
        return URL(string: "https://\(trimmed)")
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

    private func addLecture() {
        let lecture = LectureNote(title: "Lecture \(course.lectures.count + 1)")
        lecture.course = course
        context.insert(lecture)
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

/// One lecture's notes: a title you can rename and a body that folds away.
/// Press the header (or its chevron) to collapse and expand.
struct LectureNoteRow: View {
    @Bindable var lecture: LectureNote
    let onDelete: () -> Void

    @State private var hovering = false

    /// Shown beside the title when collapsed, so you can tell entries apart
    /// without opening them.
    private var preview: String {
        let firstLine = lecture.text
            .split(separator: "\n", omittingEmptySubsequences: true)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespaces) ?? ""
        return firstLine.isEmpty ? "Empty" : firstLine
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        lecture.isCollapsed.toggle()
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.inkOnPink.opacity(0.7))
                        .rotationEffect(.degrees(lecture.isCollapsed ? 0 : 90))
                        .frame(width: 14)
                }
                .buttonStyle(.plain)

                TextField("Lecture # / title", text: $lecture.title)
                    .textFieldStyle(.plain)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(Color.inkOnPink)
                    .frame(maxWidth: 260, alignment: .leading)

                if lecture.isCollapsed {
                    Text(preview)
                        .font(.caption)
                        .foregroundStyle(Color.inkOnPink.opacity(0.5))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                if hovering {
                    Button(action: onDelete) {
                        Image(systemName: "trash").font(.caption)
                            .foregroundStyle(Color.inkOnPink.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                    .help("Delete these notes")
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 8)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.18)) {
                    lecture.isCollapsed.toggle()
                }
            }

            if !lecture.isCollapsed {
                TextEditor(text: $lecture.text)
                    .font(.body)
                    .foregroundStyle(Color.inkOnPink)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 120)
                    .padding(8)
                    .background(Color.pagePink.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal, 10)
                    .padding(.bottom, 10)
            }
        }
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
