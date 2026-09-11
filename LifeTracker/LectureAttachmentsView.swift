import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers

/// Reading files in and back out for lecture-note attachments.
enum AttachmentTools {
    /// Anything bigger than this is refused. Lecture handouts are small; a
    /// stray video would bloat the database's external storage folder for no
    /// good reason.
    static let maxBytes = 50 * 1024 * 1024

    /// Whether a file on disk is a picture, judged by its type rather than its
    /// extension so odd spellings (.JPEG, .heic) still count.
    static func isImage(_ url: URL) -> Bool {
        let type = (try? url.resourceValues(forKeys: [.contentTypeKey]).contentType)
            ?? UTType(filenameExtension: url.pathExtension)
        return type?.conforms(to: .image) ?? false
    }

    /// Builds an attachment from a file the user picked or dragged in.
    ///
    /// Pictures are re-encoded as a JPEG no wider than 2000px — big enough to
    /// read the text on a lecture slide, small enough not to weigh the app
    /// down. Everything else is stored byte-for-byte, since a PDF or a
    /// spreadsheet only opens correctly as its original self.
    static func attachment(from url: URL) -> LectureAttachment? {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }

        if isImage(url) {
            guard let data = ImageTools.downscaledJPEG(from: url, maxDimension: 2000) else { return nil }
            let name = url.deletingPathExtension().lastPathComponent
            return LectureAttachment(filename: "\(name).jpg", fileData: data, isImage: true)
        }

        guard let data = try? Data(contentsOf: url), !data.isEmpty, data.count <= maxBytes else { return nil }
        return LectureAttachment(filename: url.lastPathComponent, fileData: data, isImage: false)
    }

    /// Pulls whatever is on the clipboard into an attachment: a copied file
    /// first (Finder puts a URL there), otherwise a raw picture such as a
    /// screenshot. Returns nil when the clipboard holds neither.
    static func attachmentFromClipboard(_ pasteboard: NSPasteboard = .general) -> LectureAttachment? {
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL],
           let url = urls.first,
           let attachment = attachment(from: url) {
            return attachment
        }
        guard let data = ImageTools.jpegFromPasteboard(pasteboard, maxDimension: 2000) else { return nil }
        return LectureAttachment(filename: "Pasted image.jpg", fileData: data, isImage: true)
    }

    /// Writes an attachment to a scratch folder and hands it to whichever app
    /// opens that kind of file. Each one gets its own folder so two handouts
    /// with the same name don't overwrite each other.
    static func open(_ attachment: LectureAttachment) {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("LectureAttachments", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let url = folder.appendingPathComponent(attachment.filename)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try attachment.fileData.write(to: url)
            NSWorkspace.shared.open(url)
        } catch {
            NSLog("LifeTracker: could not open attachment \(attachment.filename): \(error)")
        }
    }

    /// "Save a copy…" — puts the original file back on disk wherever the user
    /// wants it, so an attachment is never trapped inside the app.
    static func saveCopy(of attachment: LectureAttachment) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = attachment.filename
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try attachment.fileData.write(to: url)
        } catch {
            NSLog("LifeTracker: could not save a copy of \(attachment.filename): \(error)")
        }
    }
}

/// The attachments area under a lecture's notes: image thumbnails, file chips,
/// and the three ways of adding something — paste, drag in, or browse.
struct LectureAttachmentsStrip: View {
    @Bindable var lecture: LectureNote
    /// Only the hovered lecture claims ⇧⌘V. Several lectures can be open at
    /// once, and a shortcut registered by all of them would be ambiguous.
    let ownsPasteShortcut: Bool

    @Environment(\.modelContext) private var context

    @State private var showImageImporter = false
    @State private var showFileImporter = false
    @State private var dropTargeted = false
    @State private var zoomed: LectureAttachment?
    @State private var problem: String?

    private var images: [LectureAttachment] {
        lecture.attachments.filter(\.isImage).sorted { $0.createdAt < $1.createdAt }
    }

    private var files: [LectureAttachment] {
        lecture.attachments.filter { !$0.isImage }.sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !images.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], spacing: 8) {
                    ForEach(images) { image in
                        thumbnail(image)
                    }
                }
            }

            if !files.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(files) { file in
                        fileChip(file)
                    }
                }
            }

            HStack(spacing: 12) {
                Button(action: paste) {
                    Label("Paste", systemImage: "doc.on.clipboard")
                }
                .keyboardShortcut(ownsPasteShortcut ? KeyboardShortcut("v", modifiers: [.command, .shift]) : nil)
                .help("Paste a copied screenshot or file (⇧⌘V while this lecture is under the pointer)")

                Button { showImageImporter = true } label: {
                    Label("Add image", systemImage: "photo.badge.plus")
                }

                Button { showFileImporter = true } label: {
                    Label("Upload file", systemImage: "paperclip")
                }

                Spacer()
            }
            .buttonStyle(.plain)
            .font(.caption)
            .foregroundStyle(Color.inkOnPink.opacity(0.85))

            if let problem {
                Text(problem)
                    .font(.caption)
                    .foregroundStyle(Color.expenseRose)
            } else if lecture.attachments.isEmpty {
                Text("Paste a screenshot with ⇧⌘V, or drag slides and handouts in here.")
                    .font(.caption)
                    .foregroundStyle(Color.inkOnPink.opacity(0.5))
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.pagePink.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(dropTargeted ? Color.brandPink : Color.clear, lineWidth: 2)
        )
        .dropDestination(for: URL.self) { urls, _ in
            var added = false
            for url in urls {
                if let attachment = AttachmentTools.attachment(from: url) {
                    attach(attachment)
                    added = true
                } else {
                    problem = "“\(url.lastPathComponent)” couldn't be added — it may be empty or over 50 MB."
                }
            }
            return added
        } isTargeted: { dropTargeted = $0 }
        .fileImporter(isPresented: $showImageImporter,
                      allowedContentTypes: [.image],
                      allowsMultipleSelection: true) { result in
            add(from: result)
        }
        .fileImporter(isPresented: $showFileImporter,
                      allowedContentTypes: [.item],
                      allowsMultipleSelection: true) { result in
            add(from: result)
        }
        .sheet(item: $zoomed) { image in
            imageViewer(image)
        }
    }

    // MARK: Pieces

    private func thumbnail(_ image: LectureAttachment) -> some View {
        ZStack(alignment: .topTrailing) {
            if let img = NSImage(data: image.fileData) {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 96, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .contentShape(RoundedRectangle(cornerRadius: 8))
                    .onTapGesture { zoomed = image }
                    .help(image.filename)
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
        .contextMenu {
            Button("Save a Copy…") { AttachmentTools.saveCopy(of: image) }
            Button("Remove", role: .destructive) { context.delete(image) }
        }
    }

    private func fileChip(_ file: LectureAttachment) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon(for: file.filename))
                .foregroundStyle(Color.inkOnPink.opacity(0.7))
            Text(file.filename)
                .font(.caption)
                .foregroundStyle(Color.inkOnPink)
                .lineLimit(1)
            Text(sizeText(file))
                .font(.caption2)
                .foregroundStyle(Color.inkOnPink.opacity(0.45))
            Spacer(minLength: 0)
            Button {
                context.delete(file)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.white, Color.inkOnPink.opacity(0.8))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 6))
        .contentShape(RoundedRectangle(cornerRadius: 6))
        .onTapGesture { AttachmentTools.open(file) }
        .help("Open “\(file.filename)”")
        .contextMenu {
            Button("Open") { AttachmentTools.open(file) }
            Button("Save a Copy…") { AttachmentTools.saveCopy(of: file) }
            Button("Remove", role: .destructive) { context.delete(file) }
        }
    }

    private func imageViewer(_ image: LectureAttachment) -> some View {
        VStack(spacing: 14) {
            if let img = NSImage(data: image.fileData) {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 900, maxHeight: 660)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            HStack(spacing: 12) {
                Button(role: .destructive) {
                    context.delete(image)
                    zoomed = nil
                } label: {
                    Label("Delete image", systemImage: "trash")
                }
                Button("Save a Copy…") { AttachmentTools.saveCopy(of: image) }
                Button("Close") { zoomed = nil }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .background(Color.pagePink)
    }

    /// A rough icon per kind of file, so a PDF handout and a spreadsheet don't
    /// look identical in the list.
    private func icon(for filename: String) -> String {
        switch (filename as NSString).pathExtension.lowercased() {
        case "pdf": return "doc.richtext"
        case "doc", "docx", "pages", "txt", "rtf", "md": return "doc.text"
        case "xls", "xlsx", "numbers", "csv": return "tablecells"
        case "ppt", "pptx", "key": return "rectangle.on.rectangle"
        case "zip": return "doc.zipper"
        case "mp3", "m4a", "wav": return "waveform"
        case "mp4", "mov": return "film"
        default: return "doc"
        }
    }

    private func sizeText(_ file: LectureAttachment) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(file.fileData.count), countStyle: .file)
    }

    // MARK: Adding

    private func paste() {
        guard let attachment = AttachmentTools.attachmentFromClipboard() else {
            problem = "There's no picture or file on the clipboard right now."
            return
        }
        attach(attachment)
    }

    private func add(from result: Result<[URL], Error>) {
        guard case .success(let urls) = result else { return }
        for url in urls {
            if let attachment = AttachmentTools.attachment(from: url) {
                attach(attachment)
            } else {
                problem = "“\(url.lastPathComponent)” couldn't be added — it may be empty or over 50 MB."
            }
        }
    }

    private func attach(_ attachment: LectureAttachment) {
        problem = nil
        attachment.lecture = lecture
        context.insert(attachment)
    }
}
