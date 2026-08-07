import SwiftUI
import SwiftData

/// The Notes page: a board of small free-form notes. Pin the ones you want at
/// the top, colour them however you like, and search when the board gets long.
struct NotesView: View {
    @Environment(\.modelContext) private var context
    @Query private var notes: [StickyNote]

    @State private var editingNote: StickyNote?
    @State private var search = ""

    /// Pinned notes first, then most recently edited.
    private var sortedNotes: [StickyNote] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let matching = query.isEmpty ? notes : notes.filter {
            $0.title.lowercased().contains(query) || $0.text.lowercased().contains(query)
        }
        return matching.sorted { a, b in
            if a.isPinned != b.isPinned { return a.isPinned }
            return a.updatedAt > b.updatedAt
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            if notes.isEmpty {
                empty(icon: "note.text",
                      title: "No notes yet.",
                      detail: "Press “New Note” to jot something down.")
            } else if sortedNotes.isEmpty {
                empty(icon: "magnifyingglass",
                      title: "Nothing matches “\(search)”.",
                      detail: "Try a different word.")
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 220), spacing: 16)],
                        spacing: 16
                    ) {
                        ForEach(sortedNotes) { note in
                            NoteCard(note: note) { editingNote = note }
                                .contextMenu {
                                    Button {
                                        note.isPinned.toggle()
                                        note.updatedAt = .now
                                    } label: {
                                        Label(note.isPinned ? "Unpin" : "Pin",
                                              systemImage: note.isPinned ? "pin.slash" : "pin")
                                    }
                                    Button(role: .destructive) {
                                        context.delete(note)
                                    } label: {
                                        Label("Delete Note", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.pagePink)
        .navigationTitle("Notes")
        .sheet(item: $editingNote) { note in
            NoteEditor(note: note) { context.delete(note) }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text("Notes")
                .font(.largeTitle.bold())
                .foregroundStyle(Color.inkOnPink)

            Spacer()

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color.inkOnPink.opacity(0.5))
                TextField("Search notes", text: $search)
                    .textFieldStyle(.plain)
                    .foregroundStyle(Color.inkOnPink)
                    .frame(width: 160)
                if !search.isEmpty {
                    Button { search = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.inkOnPink.opacity(0.4))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(.white, in: Capsule())

            Button(action: addNote) {
                Label("New Note", systemImage: "plus")
                    .font(.callout.weight(.medium))
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Color.brandPink, in: RoundedRectangle(cornerRadius: 8))
                    .foregroundStyle(Color.inkOnPink)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24).padding(.top, 20).padding(.bottom, 16)
    }

    private func empty(icon: String, title: String, detail: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 44))
                .foregroundStyle(Color.inkOnPink.opacity(0.4))
            Text(title)
                .font(.title3)
                .foregroundStyle(Color.inkOnPink.opacity(0.6))
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(Color.inkOnPink.opacity(0.5))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func addNote() {
        let note = StickyNote()
        context.insert(note)
        editingNote = note
    }
}

/// One note on the board — a preview only; editing happens in `NoteEditor`.
struct NoteCard: View {
    let note: StickyNote
    let onOpen: () -> Void

    @State private var hovering = false

    private var accent: Color { Color(hex: note.colorHex) }

    /// First attached picture, shown as a preview at the top of the card.
    private var previewImage: NoteImage? {
        note.images.min { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 6) {
                if let preview = previewImage, let img = NSImage(data: preview.imageData) {
                    Image(nsImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 110)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(alignment: .bottomTrailing) {
                            if note.images.count > 1 {
                                Text("+\(note.images.count - 1)")
                                    .font(.caption2.bold())
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(.black.opacity(0.45), in: Capsule())
                                    .padding(6)
                            }
                        }
                        .padding(.bottom, 2)
                }

                HStack(alignment: .top, spacing: 6) {
                    Text(note.title.isEmpty ? "Untitled" : note.title)
                        .font(.headline)
                        .foregroundStyle(Color.inkOnPink)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                    if note.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption)
                            .foregroundStyle(Color.inkOnPink.opacity(0.55))
                    }
                }

                if !note.text.isEmpty {
                    Text(note.text)
                        .font(.subheadline)
                        .foregroundStyle(Color.inkOnPink.opacity(0.8))
                        .lineLimit(8)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)

                Text(note.updatedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(Color.inkOnPink.opacity(0.45))
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 130, alignment: .topLeading)
            .background(accent.opacity(hovering ? 0.85 : 0.6),
                        in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(accent, lineWidth: hovering ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .onHover { hovering = $0 }
    }
}

/// Full editor for one note: title, body, colour, pin, delete.
struct NoteEditor: View {
    @Bindable var note: StickyNote
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var showImporter = false
    @State private var dropTargeted = false
    @State private var zoomed: NoteImage?
    @State private var pasteFailed = false

    private let palette = ["FBC3C1", "F3D7CA", "FDF3C7", "C8E6D4", "CFE0F0", "E5D4F0", "F5EEE6"]

    private var sortedImages: [NoteImage] {
        note.images.sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    TextField("Title", text: $note.title)
                        .textFieldStyle(.plain)
                        .font(.title2.bold())
                        .foregroundStyle(Color.inkOnPink)
                    Spacer()
                    Button {
                        note.isPinned.toggle()
                    } label: {
                        Image(systemName: note.isPinned ? "pin.fill" : "pin")
                            .foregroundStyle(Color.inkOnPink.opacity(note.isPinned ? 0.9 : 0.45))
                    }
                    .buttonStyle(.plain)
                    .help(note.isPinned ? "Unpin from the top" : "Pin to the top")
                }

                TextEditor(text: $note.text)
                    .font(.body)
                    .foregroundStyle(Color.inkOnPink)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 180)
                    .padding(10)
                    .background(.white.opacity(0.75), in: RoundedRectangle(cornerRadius: 10))

                photos

                HStack(spacing: 8) {
                    ForEach(palette, id: \.self) { hex in
                        Circle()
                            .fill(Color(hex: hex))
                            .frame(width: 22, height: 22)
                            .overlay(
                                Circle().strokeBorder(Color.inkOnPink,
                                                      lineWidth: note.colorHex == hex ? 2 : 0)
                            )
                            .onTapGesture { note.colorHex = hex }
                    }
                    Spacer()
                }

                HStack {
                    Button(role: .destructive) {
                        onDelete()
                        dismiss()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    Spacer()
                    Button("Done") { dismiss() }
                        .keyboardShortcut(.defaultAction)
                }
            }
            .padding(22)
        }
        .frame(width: 480, height: 620)
        .background(Color(hex: note.colorHex).opacity(0.45))
        .background(Color.pagePink)
        .fileImporter(isPresented: $showImporter,
                      allowedContentTypes: [.image],
                      allowsMultipleSelection: true) { result in
            guard case .success(let urls) = result else { return }
            for url in urls {
                if let data = ImageTools.jpegFromPickedFile(url) { attach(data) }
            }
        }
        .sheet(item: $zoomed) { image in
            imageViewer(image)
        }
        // Any edit bumps the note to the front of the board.
        .onDisappear { note.updatedAt = .now }
    }

    // MARK: Photos

    private var photos: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !sortedImages.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], spacing: 8) {
                    ForEach(sortedImages) { image in
                        thumbnail(image)
                    }
                }
            }

            HStack(spacing: 10) {
                Button { showImporter = true } label: {
                    Label("Add photo", systemImage: "photo.badge.plus")
                }
                Button(action: pasteImage) {
                    Label("Paste image", systemImage: "doc.on.clipboard")
                }
                .keyboardShortcut("v", modifiers: [.command, .shift])
                .help("Paste a screenshot from the clipboard (⇧⌘V)")
                Spacer()
            }
            .buttonStyle(.plain)
            .font(.callout)
            .foregroundStyle(Color.inkOnPink.opacity(0.85))

            if pasteFailed {
                Text("There's no picture on the clipboard right now.")
                    .font(.caption)
                    .foregroundStyle(Color.expenseRose)
            } else if sortedImages.isEmpty {
                Text("Copy a screenshot and press ⇧⌘V, or drag an image in here.")
                    .font(.caption)
                    .foregroundStyle(Color.inkOnPink.opacity(0.5))
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(dropTargeted ? Color.brandPink : Color.clear, lineWidth: 2)
        )
        .dropDestination(for: URL.self) { urls, _ in
            var added = false
            for url in urls {
                if let data = ImageTools.jpegFromPickedFile(url) {
                    attach(data)
                    added = true
                }
            }
            return added
        } isTargeted: { dropTargeted = $0 }
    }

    private func thumbnail(_ image: NoteImage) -> some View {
        ZStack(alignment: .topTrailing) {
            if let img = NSImage(data: image.imageData) {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 96, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .contentShape(RoundedRectangle(cornerRadius: 8))
                    .onTapGesture { zoomed = image }
            }
            Button {
                context.delete(image)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.white, Color.inkOnPink.opacity(0.8))
            }
            .buttonStyle(.plain)
            .padding(4)
        }
    }

    private func imageViewer(_ image: NoteImage) -> some View {
        VStack(spacing: 14) {
            if let img = NSImage(data: image.imageData) {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 820, maxHeight: 620)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            HStack(spacing: 12) {
                Button(role: .destructive) {
                    context.delete(image)
                    zoomed = nil
                } label: {
                    Label("Delete photo", systemImage: "trash")
                }
                Button("Close") { zoomed = nil }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .background(Color.pagePink)
    }

    private func pasteImage() {
        guard let data = ImageTools.jpegFromPasteboard() else {
            pasteFailed = true
            return
        }
        pasteFailed = false
        attach(data)
    }

    private func attach(_ data: Data) {
        let image = NoteImage(imageData: data)
        image.note = note
        context.insert(image)
        note.updatedAt = .now
    }
}
