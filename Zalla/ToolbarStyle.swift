import Foundation

enum ToolbarStyle: String, CaseIterable, Identifiable, Codable {
    case classic = "Classic"
    case compact = "Compact"

    var id: String { rawValue }

    static let storageKey = "toolbarStyle"
}
