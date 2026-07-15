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
                weekdayHeader
                grid
                Spacer(minLength: 0)
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
                dayTile(date)
            }
        }
    }

    // MARK: Day tile

    private func dayTile(_ date: Date) -> some View {
        let inMonth = cal.isDate(date, equalTo: visibleMonth, toGranularity: .month)
        let isToday = cal.isDateInToday(date)
        let dayNum = cal.component(.day, from: date)
        let existing = photo(for: date)

        return Color.hoverPink
            .aspectRatio(1, contentMode: .fit)
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
        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
        guard let data = downscaledJPEG(from: url) else { return }

        if let existing = photo(for: day) {
            existing.imageData = data
        } else {
            context.insert(DailyPhoto(day: day, imageData: data))
        }
        pickerDay = nil
    }

    /// Loads an image and re-encodes it as a reasonably sized JPEG.
    private func downscaledJPEG(from url: URL, maxDimension: CGFloat = 1600) -> Data? {
        guard let image = NSImage(contentsOf: url) else { return nil }
        let size = image.size
        guard size.width > 0, size.height > 0 else { return nil }
        let scale = min(1, maxDimension / max(size.width, size.height))
        let target = NSSize(width: size.width * scale, height: size.height * scale)

        let resized = NSImage(size: target)
        resized.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: target))
        resized.unlockFocus()

        guard let tiff = resized.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .jpeg, properties: [.compressionFactor: 0.85])
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
        return (0..<42).compactMap { cal.date(byAdding: .day, value: $0, to: gridStart) }
    }

    private func changeMonth(by months: Int) {
        if let d = cal.date(byAdding: .month, value: months, to: visibleMonth) {
            visibleMonth = d
        }
    }
}
