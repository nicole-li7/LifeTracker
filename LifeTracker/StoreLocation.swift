import Foundation

/// Where the app's database lives on disk, and the automatic backups of it.
///
/// Layout (all under ~/Library/Application Support/LifeTracker/):
///   LifeTracker.store                  the database
///   .LifeTracker_SUPPORT/_EXTERNAL_DATA  large photos, stored by SwiftData as files
///   Backups/LifeTracker-<date>.store    copies made at every launch and quit
///   Backups/LifeTracker-<date>_SUPPORT  the matching photo files (hard links, so they cost no space)
enum StoreLocation {
    /// ~/Library/Application Support/LifeTracker
    static let folder: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("LifeTracker", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    static let storeURL = folder.appendingPathComponent("LifeTracker.store")
    static let externalDataURL = folder.appendingPathComponent(".LifeTracker_SUPPORT/_EXTERNAL_DATA", isDirectory: true)
    static let backupsFolder = folder.appendingPathComponent("Backups", isDirectory: true)

    /// How many backups to keep. Backups are taken on every launch and quit,
    /// so this is roughly a few weeks of normal use.
    static let backupsToKeep = 40

    /// Copies the database (and its journal and photo files) into `Backups/`,
    /// then removes the oldest backups beyond `backupsToKeep`.
    static func backUpStore() {
        let fm = FileManager.default
        guard fm.fileExists(atPath: storeURL.path) else { return }
        try? fm.createDirectory(at: backupsFolder, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let stamp = formatter.string(from: Date())
        let prefix = "LifeTracker-\(stamp)"

        // The database itself. SQLite keeps recent writes in the -wal file, so
        // it (and -shm) must travel with the store.
        for suffix in ["", "-wal", "-shm"] {
            let src = URL(fileURLWithPath: storeURL.path + suffix)
            guard fm.fileExists(atPath: src.path) else { continue }
            let dst = backupsFolder.appendingPathComponent("\(prefix).store\(suffix)")
            try? fm.copyItem(at: src, to: dst)
        }

        // Photos stored outside the database. Hard links share the bytes with
        // the originals, so 40 backups of the photos take no extra space; if
        // the original is later deleted the link still holds the data.
        if let names = try? fm.contentsOfDirectory(atPath: externalDataURL.path), !names.isEmpty {
            let dstDir = backupsFolder.appendingPathComponent("\(prefix)_SUPPORT/_EXTERNAL_DATA", isDirectory: true)
            try? fm.createDirectory(at: dstDir, withIntermediateDirectories: true)
            for name in names where !name.hasPrefix(".") {
                let src = externalDataURL.appendingPathComponent(name)
                let dst = dstDir.appendingPathComponent(name)
                if (try? fm.linkItem(at: src, to: dst)) == nil {
                    try? fm.copyItem(at: src, to: dst)
                }
            }
        }

        writeReadme()
        prune()
    }

    /// Deletes the oldest backups so only `backupsToKeep` remain.
    private static func prune() {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(atPath: backupsFolder.path) else { return }
        // Each backup is identified by its date stamp: "LifeTracker-<stamp>.store", "<stamp>.store-wal", "<stamp>_SUPPORT" …
        var stamps = Set<String>()
        for name in entries where name.hasPrefix("LifeTracker-") {
            let rest = name.dropFirst("LifeTracker-".count)
            if let end = rest.firstIndex(where: { $0 == "." || $0 == "_" }) {
                stamps.insert(String(rest[..<end]))
            }
        }
        let expired = stamps.sorted().dropLast(backupsToKeep)
        for stamp in expired {
            for name in entries where name.hasPrefix("LifeTracker-\(stamp)") {
                try? fm.removeItem(at: backupsFolder.appendingPathComponent(name))
            }
        }
    }

    private static func writeReadme() {
        let url = backupsFolder.appendingPathComponent("HOW TO RESTORE.txt")
        guard !FileManager.default.fileExists(atPath: url.path) else { return }
        let text = """
        LifeTracker makes a backup of its database here every time it launches and quits.

        To go back to one of them:
          1. Quit LifeTracker.
          2. In the folder above this one (Application Support/LifeTracker), move aside
             LifeTracker.store, LifeTracker.store-wal, LifeTracker.store-shm and the hidden
             .LifeTracker_SUPPORT folder (press Cmd-Shift-. in Finder to see hidden files).
          3. Copy the backup you want back in, renaming it:
                LifeTracker-<date>.store       ->  LifeTracker.store
                LifeTracker-<date>.store-wal   ->  LifeTracker.store-wal   (if present)
                LifeTracker-<date>.store-shm   ->  LifeTracker.store-shm   (if present)
                LifeTracker-<date>_SUPPORT     ->  .LifeTracker_SUPPORT
          4. Open LifeTracker again.
        """
        try? text.write(to: url, atomically: true, encoding: .utf8)
    }
}
