import Foundation

enum DownloadState: String, Codable, Equatable {
    case downloading
    case completed
    case failed
}

struct DownloadRecord: Identifiable, Codable, Equatable {
    var id: UUID
    var filename: String
    var sourceURL: URL
    var localRelativePath: String?
    var date: Date
    var byteCount: Int64?
    var state: DownloadState
    var isPrivate: Bool
    var errorMessage: String?

    var localFileURL: URL? {
        guard let localRelativePath else { return nil }
        return DownloadsStore.downloadsDirectory.appendingPathComponent(localRelativePath)
    }

    init(
        id: UUID = UUID(),
        filename: String,
        sourceURL: URL,
        localRelativePath: String? = nil,
        date: Date = Date(),
        byteCount: Int64? = nil,
        state: DownloadState = .downloading,
        isPrivate: Bool = false,
        errorMessage: String? = nil
    ) {
        self.id = id
        self.filename = filename
        self.sourceURL = sourceURL
        self.localRelativePath = localRelativePath
        self.date = date
        self.byteCount = byteCount
        self.state = state
        self.isPrivate = isPrivate
        self.errorMessage = errorMessage
    }
}

enum DownloadsStore {
    static let manifestName = "downloads.json"

    static var supportDirectory: URL {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Zalla", isDirectory: true)
        return directory
    }

    static var downloadsDirectory: URL {
        supportDirectory.appendingPathComponent("Downloads", isDirectory: true)
    }

    private static var manifestURL: URL {
        supportDirectory.appendingPathComponent(manifestName)
    }

    static func prepareDirectories() throws {
        let fm = FileManager.default
        try fm.createDirectory(at: supportDirectory, withIntermediateDirectories: true)
        try fm.createDirectory(at: downloadsDirectory, withIntermediateDirectories: true)
        var excluded = supportDirectory
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? excluded.setResourceValues(values)
        var downloadsExcluded = downloadsDirectory
        try? downloadsExcluded.setResourceValues(values)
    }

    static func load() -> [DownloadRecord] {
        do {
            try prepareDirectories()
            guard FileManager.default.fileExists(atPath: manifestURL.path) else { return [] }
            return try JSONDecoder().decode([DownloadRecord].self, from: Data(contentsOf: manifestURL))
        } catch {
            return []
        }
    }

    static func save(_ records: [DownloadRecord]) throws {
        try prepareDirectories()
        let data = try JSONEncoder().encode(records)
        try data.write(to: manifestURL, options: [.atomic, .completeFileProtection])
    }

    static func uniqueDestination(for filename: String) -> (url: URL, relative: String) {
        let safe = sanitizeFilename(filename)
        var relative = safe
        var url = downloadsDirectory.appendingPathComponent(relative)
        var index = 1
        let name = (safe as NSString).deletingPathExtension
        let ext = (safe as NSString).pathExtension
        while FileManager.default.fileExists(atPath: url.path) {
            let suffix = ext.isEmpty ? "\(name)-\(index)" : "\(name)-\(index).\(ext)"
            relative = suffix
            url = downloadsDirectory.appendingPathComponent(relative)
            index += 1
        }
        return (url, relative)
    }

    static func sanitizeFilename(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleaned = trimmed.replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        return cleaned.isEmpty ? "download" : cleaned
    }

    static func suggestedFilename(from response: URLResponse, sourceURL: URL) -> String {
        if let suggested = response.suggestedFilename, !suggested.isEmpty {
            return sanitizeFilename(suggested)
        }
        if sourceURL.scheme?.lowercased() == "blob" {
            if let mime = response.mimeType?.lowercased() {
                return sanitizeFilename("download.\(fileExtension(forMIME: mime))")
            }
            return "download"
        }
        let last = sourceURL.lastPathComponent
        if !last.isEmpty, last != "/" { return sanitizeFilename(last) }
        if let mime = response.mimeType?.lowercased() {
            return sanitizeFilename("download.\(fileExtension(forMIME: mime))")
        }
        return "download"
    }

    static func fileExtension(forMIME mime: String) -> String {
        switch mime {
        case "application/pdf": return "pdf"
        case "application/zip", "application/x-zip-compressed": return "zip"
        case "application/json": return "json"
        case "text/csv": return "csv"
        case "image/png": return "png"
        case "image/jpeg": return "jpg"
        case "image/webp": return "webp"
        case "application/msword": return "doc"
        case let value where value.hasPrefix("application/vnd.openxmlformats-officedocument.wordprocessingml"):
            return "docx"
        case let value where value.hasPrefix("application/vnd.openxmlformats-officedocument.spreadsheetml"):
            return "xlsx"
        case let value where value.hasPrefix("application/vnd.openxmlformats-officedocument.presentationml"):
            return "pptx"
        default:
            return "bin"
        }
    }

    /// Heuristic for responses that should become downloads rather than inline navigation.
    static func isLikelyDownload(response: URLResponse) -> Bool {
        if let http = response as? HTTPURLResponse {
            if let disposition = http.value(forHTTPHeaderField: "Content-Disposition")?.lowercased(),
               disposition.contains("attachment") {
                return true
            }
        }
        let url = response.url
        if url?.scheme?.lowercased() == "blob" {
            return true
        }
        guard let mime = response.mimeType?.lowercased() else {
            // Missing MIME with a file-like path often indicates a download.
            if let path = url?.path.lowercased(), pathContainsDownloadExtension(path) {
                return true
            }
            return false
        }
        let inlineTypes = [
            "text/html", "text/plain", "text/css", "text/javascript",
            "application/javascript", "application/xhtml+xml",
            "application/json", "image/png", "image/jpeg", "image/gif",
            "image/webp", "image/svg+xml", "audio/", "video/",
            "application/xhtml", "multipart/x-mixed-replace"
        ]
        if inlineTypes.contains(where: { mime.hasPrefix($0) || mime == $0 }) {
            // JSON/plain can still be attachments when Content-Disposition said so above.
            return false
        }
        let downloadTypes = [
            "application/pdf",
            "application/zip",
            "application/x-zip-compressed",
            "application/octet-stream",
            "application/msword",
            "application/vnd.",
            "application/x-msdownload",
            "application/x-apple-diskimage",
            "application/x-7z-compressed",
            "application/gzip",
            "application/x-tar",
            "application/x-rar-compressed",
            "binary/"
        ]
        if downloadTypes.contains(where: { mime.hasPrefix($0) || mime == $0 }) {
            return true
        }
        if let path = url?.path.lowercased(), pathContainsDownloadExtension(path) {
            return true
        }
        return false
    }

    private static func pathContainsDownloadExtension(_ path: String) -> Bool {
        let extensions = [
            ".pdf", ".zip", ".dmg", ".pkg", ".exe", ".msi", ".7z", ".rar",
            ".tar", ".gz", ".doc", ".docx", ".xls", ".xlsx", ".ppt", ".pptx",
            ".csv", ".ical", ".ics", ".apk", ".ipa"
        ]
        return extensions.contains(where: { path.hasSuffix($0) })
    }
}
