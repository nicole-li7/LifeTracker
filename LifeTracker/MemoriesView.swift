import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers

/// The Memories page: a "photo a day" diary. Each day of the month is a tile —
/// add one photo per day and watch your months fill up.
struct MemoriesView: View {
    @Environment(\.modelContext) private var context
    @Query private var photos: [DailyPhoto]

    @State private var visibleMonth: Date = .now
    @State private var pickerDay: Date?      // which day we're choosing a photo for
    @State private var showImporter = false
    @State private var zoomDay: Date?        // which day's photo is enlarged

    private var cal: Calendar { Calendar.current }

    var body: some View {
        ZStack {
            Color.pagePink.ignoresSafeArea()

            VStack(spacing: 12) {
                header
                monthGrid
            }
            .padding()

            if let day = zoomDay, let photo = photo(for: day) {
                zoomOverlay(day: day, photo: photo)
            }
        }
        .navigationTitle("Memories")
        .fileImporter(isPresented: $showImporter,
                      allowedContentTypes: [.image],
                      allowsMultipleSelection: false) { result in
            handleImport(result)
        }
    }

    // MARK: Header

    private var header: some View {
        HStack {
            Button { changeMonth(by: -1) } label: { Image(systemName: "chevron.left") }
                .buttonStyle(.plain)
            Spacer()
            Text(visibleMonth.formatted(.dateTime.month(.wide).year()))
                .font(.title2.bold())
            Spacer()
            Button { changeMonth(by: 1) } label: { Image(systemName: "chevron.right") }
                .buttonStyle(.plain)
            Button {
                pickerDay = cal.startOfDay(for: .now)
                showImporter = true
            } label: {
                Label("Add Today's Photo", systemImage: "camera.fill")
                    .font(.subheadline.bold())
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Color.brandPink, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .font(.title3)
        .foregroundStyle(Color.inkOnPink)
    }

    /// Landscape shape for each day's tile — wider than it is tall.
    private static let tileAspect: CGFloat = 4.0 / 3.0

    /// Weekday names plus the day tiles, sized so the whole month always fits
    /// the space available. Tiles keep their landscape shape and take whichever
    /// is smaller — the width a column can have, or the width a row's height
    /// allows — so a short window shrinks them instead of pushing the last week
    /// off-screen.
    private var monthGrid: some View {
        GeometryReader { geo in
            let spacing: CGFloat = 6
            let rows = max(1, gridDays.count / 7)
            let headerHeight: CGFloat = 18
            let cellWidth = (geo.size.width - spacing * 6) / 7
            let cellHeight = (geo.size.height - headerHeight - spacing * CGFloat(rows))
                / CGFloat(rows)
            let tileWidth = max(36, min(cellWidth, cellHeight * Self.tileAspect))
            let tileHeight = tileWidth / Self.tileAspect

            VStack(spacing: spacing) {
                HStack(spacing: spacing) {
                    ForEach(orderedWeekdaySymbols, id: \.self) { symbol in
                        Text(symbol)
                            .font(.caption.bold())
                            .foregroundStyle(Color.inkOnPink.opacity(0.6))
                            .frame(width: tileWidth)
                    }
                }
                .frame(height: headerHeight)

                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: spacing) {
                        ForEach(0..<7, id: \.self) { column in
                            let index = row * 7 + column
                            if index < gridDays.count {
                                dayTile(gridDays[index])
                                    .frame(width: tileWidth, height: tileHeight)
                            }
                        }
                    }
                }
            }
            .frame(width: tileWidth * 7 + spacing * 6)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    // MARK: Day tile

    private func dayTile(_ date: Date) -> some View {
        let inMonth = cal.isDate(date, equalTo: visibleMonth, toGranularity: .month)
        let isToday = cal.isDateInToday(date)
        let dayNum = cal.component(.day, from: date)
        let existing = photo(for: date)

        return Color.hoverPink
            .overlay {
                if let existing, let img = NSImage(data: existing.imageData) {
                    Image(nsImage: img).resizable().scaledToFill()
                }
            }
            .overlay(alignment: .topLeading) {
                Text("\(dayNum)")
                    .font(.caption2.bold())
                    .foregroundStyle(existing == nil ? Color.inkOnPink.opacity(0.6) : .white)
                    .padding(4)
                    .background(existing == nil ? Color.clear : Color.black.opacity(0.35),
                                in: Capsule())
                    .padding(4)
            }
            .overlay {
                if existing == nil && inMonth {
                    Image(systemName: "plus")
                        .foregroundStyle(Color.inkOnPink.opacity(0.35))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isToday ? Color.brandPink : Color.clear, lineWidth: 2)
            )
            .opacity(inMonth ? 1 : 0.4)
            .contentShape(RoundedRectangle(cornerRadius: 8))
            .onTapGesture {
                if existing != nil {
                    zoomDay = date
                } else {
                    pickerDay = cal.startOfDay(for: date)
                    showImporter = true
                }
            }
    }

    // MARK: Zoom overlay

    private func zoomOverlay(day: Date, photo: DailyPhoto) -> some View {
        ZStack {
            Color.black.opacity(0.9).ignoresSafeArea()
                .onTapGesture { zoomDay = nil }
            VStack(spacing: 16) {
                Text(day.formatted(.dateTime.weekday(.wide).month().day().year()))
                    .font(.headline)
                    .foregroundStyle(.white)
                if let img = NSImage(data: photo.imageData) {
                    Image(nsImage: img).resizable().scaledToFit()
                        .frame(maxHeight: 560)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                HStack(spacing: 14) {
                    Button {
                        pickerDay = cal.startOfDay(for: day)
                        zoomDay = nil
                        showImporter = true
                    } label: {
                        Label("Change", systemImage: "arrow.triangle.2.circlepath")
                    }
                    Button(role: .destructive) {
                        context.delete(photo)
                        zoomDay = nil
                    } label: {
                        Label("Remove", systemImage: "trash")
                    }
                    Button("Close") { zoomDay = nil }
                }
                .buttonStyle(.borderedProminent)
                .tint(.brandPink)
            }
            .padding(40)
        }
        .transition(.opacity)
    }

    // MARK: Import

    private func handleImport(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result,
              let url = urls.first,
              let day = pickerDay else { return }
        guard let data = ImageTools.jpegFromPickedFile(url) else { return }

        if let existing = photo(for: day) {
            existing.imageData = data
        } else {
            context.insert(DailyPhoto(day: day, imageData: data))
        }
        pickerDay = nil
    }

    // MARK: Data helpers

    private func photo(for date: Date) -> DailyPhoto? {
        let start = cal.startOfDay(for: date)
        return photos.first { cal.isDate($0.day, inSameDayAs: start) }
    }

    private var orderedWeekdaySymbols: [String] {
        let symbols = cal.shortWeekdaySymbols
        let first = cal.firstWeekday - 1
        return (0..<7).map { symbols[(first + $0) % 7] }
    }

    private var gridDays: [Date] {
        guard let monthStart = cal.dateInterval(of: .month, for: visibleMonth)?.start else { return [] }
        let weekday = cal.component(.weekday, from: monthStart)
        let offset = (weekday - cal.firstWeekday + 7) % 7
        guard let gridStart = cal.date(byAdding: .day, value: -offset, to: monthStart) else { return [] }
        // Only as many whole weeks as this month actually needs — most months
        // want five rows, not a fixed six.
        let daysInMonth = cal.range(of: .day, in: .month, for: monthStart)?.count ?? 30
        let weeks = Int((Double(offset + daysInMonth) / 7).rounded(.up))
        return (0..<(weeks * 7)).compactMap { cal.date(byAdding: .day, value: $0, to: gridStart) }
    }

    private func changeMonth(by months: Int) {
        if let d = cal.date(byAdding: .month, value: months, to: visibleMonth) {
            visibleMonth = d
        }
    }
}
