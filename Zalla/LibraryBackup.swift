import Foundation

/// Build 40: how Zalla's own files (bookmarks and history, the downloads list) are written, and what happens when one
/// cannot be read.
enum LibraryBackup {
    /// Protected until the first unlock after a restart, like the saved tabs. Full protection blocked saves while the
    /// iPhone was locked, for example when a page kept playing audio or a download finished in the background.
    static let writeOptions: Data.WritingOptions = [.atomic, .completeFileProtectionUntilFirstUserAuthentication]

    /// Where a copy of an unreadable file goes: next to it, with "unreadable" and a timestamp in the name.
    static func copyURL(for fileURL: URL, date: Date = Date()) -> URL {
        let stamp = Int(date.timeIntervalSince1970)
        let base = fileURL.deletingPathExtension().lastPathComponent
        let ext = fileURL.pathExtension
        let name = ext.isEmpty ? "\(base)-unreadable-\(stamp)" : "\(base)-unreadable-\(stamp).\(ext)"
        return fileURL.deletingLastPathComponent().appendingPathComponent(name)
    }

    /// Keeps a copy of a file Zalla could not read, so nothing is lost even if the original is later replaced.
    static func keepCopy(of fileURL: URL) {
        try? FileManager.default.copyItem(at: fileURL, to: copyURL(for: fileURL))
    }

    /// Moves an existing file to the same protection class new saves use. Fails quietly while the iPhone is locked.
    static func relaxProtection(of fileURL: URL) {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        try? FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: fileURL.path
        )
    }
}
