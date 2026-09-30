import Foundation

/// Download list helpers.
extension DownloadRecord {
    /// A file symbol chosen from the extension.
    var symbolName: String {
        switch (filename as NSString).pathExtension.lowercased() {
        case "pdf": return "doc.richtext"
        case "png", "jpg", "jpeg", "gif", "heic", "webp", "tif", "tiff": return "photo"
        case "mp3", "m4a", "wav", "aac", "flac": return "music.note"
        case "mp4", "mov", "m4v", "mkv": return "film"
        case "zip", "gz", "tar", "7z", "rar": return "doc.zipper"
        case "txt", "md", "rtf", "doc", "docx", "pages": return "doc.text"
        case "xls", "xlsx", "csv", "numbers": return "tablecells"
        default: return "doc"
        }
    }
}
