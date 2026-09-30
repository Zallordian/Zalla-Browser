import Foundation
import LocalAuthentication
import SwiftUI

// MARK: - Face ID for private tabs

/// Zalla Unlock: ask for Face ID (or the device passcode) before private tabs open.
enum PrivateTabLock {
    static let storageKey = "faceIDPrivateTabs"

    static func isEnabled(_ defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: storageKey)
    }

    /// The lock only applies with Zalla Unlock and the setting on.
    static func isRequired(unlocked: Bool, defaults: UserDefaults = .standard) -> Bool {
        unlocked && isEnabled(defaults)
    }

    /// True when the device has Face ID, Touch ID, or a passcode to check against.
    static func canAuthenticate() -> Bool {
        var error: NSError?
        return LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
    }

    /// Face ID first, with the device passcode as the fallback. If the device has nothing to check
    /// against (no passcode), there is nothing to ask, so private tabs stay usable.
    @MainActor
    static func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else { return true }
        do {
            return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
        } catch {
            return false
        }
    }
}

// MARK: - Scheduled auto-clear

enum AutoClearSchedule: String, CaseIterable, Identifiable {
    case off = "Off"
    case onLaunch = "Every launch"
    case daily = "Daily"
    case weekly = "Weekly"

    var id: String { rawValue }

    var interval: TimeInterval? {
        switch self {
        case .off, .onLaunch: return nil
        case .daily: return 24 * 60 * 60
        case .weekly: return 7 * 24 * 60 * 60
        }
    }
}

/// Zalla Unlock: clear history and website data on a schedule. Checked whenever Zalla opens or comes back to the front.
enum AutoClear {
    static let scheduleKey = "autoClearSchedule"
    static let historyKey = "autoClearHistory"
    static let siteDataKey = "autoClearSiteData"
    static let lastRunKey = "autoClearLastRun"

    static func schedule(_ defaults: UserDefaults = .standard) -> AutoClearSchedule {
        AutoClearSchedule(rawValue: defaults.string(forKey: scheduleKey) ?? "") ?? .off
    }

    static func clearsHistory(_ defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: historyKey) as? Bool ?? true
    }

    static func clearsSiteData(_ defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: siteDataKey) as? Bool ?? true
    }

    static func lastRun(_ defaults: UserDefaults = .standard) -> Date? {
        let value = defaults.double(forKey: lastRunKey)
        return value > 0 ? Date(timeIntervalSince1970: value) : nil
    }

    static func recordRun(at date: Date = Date(), in defaults: UserDefaults = .standard) {
        defaults.set(date.timeIntervalSince1970, forKey: lastRunKey)
    }

    /// Whether a clear should happen now. Interval schedules wait for a first recorded time, which is
    /// set when the schedule is turned on, so turning it on never wipes anything immediately.
    static func isDue(schedule: AutoClearSchedule, lastRun: Date?, now: Date, ranThisLaunch: Bool) -> Bool {
        switch schedule {
        case .off:
            return false
        case .onLaunch:
            return !ranThisLaunch
        case .daily, .weekly:
            guard let lastRun, let interval = schedule.interval else { return false }
            return now.timeIntervalSince(lastRun) >= interval
        }
    }

    static func resetSettings(in defaults: UserDefaults = .standard) {
        for key in [scheduleKey, historyKey, siteDataKey, lastRunKey] {
            defaults.removeObject(forKey: key)
        }
    }
}

// MARK: - Tab sleeping

enum TabSleep {
    static let storageKey = "sleepUnusedTabs"
    /// A background tab that has not been opened for this long is put to sleep.
    static let idleSeconds: TimeInterval = 10 * 60

    static func isEnabled(_ defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: storageKey) as? Bool ?? true
    }
}

// MARK: - Tab groups

enum TabGroupColor: String, Codable, CaseIterable, Identifiable {
    case red, orange, yellow, green, blue, purple, gray

    var id: String { rawValue }

    var title: String { rawValue.capitalized }

    var color: Color {
        switch self {
        case .red: return Color(red: 0.89, green: 0.23, blue: 0.31)
        case .orange: return Color(red: 0.94, green: 0.42, blue: 0.18)
        case .yellow: return Color(red: 0.88, green: 0.64, blue: 0.10)
        case .green: return Color(red: 0.18, green: 0.66, blue: 0.40)
        case .blue: return Color(red: 0.18, green: 0.44, blue: 0.93)
        case .purple: return Color(red: 0.55, green: 0.24, blue: 0.86)
        case .gray: return Color(red: 0.50, green: 0.52, blue: 0.56)
        }
    }
}

struct TabGroup: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var color: TabGroupColor
}

enum TabGroupStore {
    static let storageKey = "tabGroups"
    static let maxGroups = 12
    static let maxNameLength = 24

    static func load(from defaults: UserDefaults = .standard) -> [TabGroup] {
        guard let data = defaults.data(forKey: storageKey),
              let groups = try? JSONDecoder().decode([TabGroup].self, from: data) else { return [] }
        return groups
    }

    static func save(_ groups: [TabGroup], to defaults: UserDefaults = .standard) {
        if groups.isEmpty {
            defaults.removeObject(forKey: storageKey)
        } else if let data = try? JSONEncoder().encode(groups) {
            defaults.set(data, forKey: storageKey)
        }
    }

    /// Trimmed and shortened group name, or nil when nothing usable was typed.
    static func cleanedName(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(maxNameLength))
    }
}

// MARK: - Listen to page

enum SpeechText {
    /// Reader text (title first) broken into pieces that speak smoothly and never exceed `limit` characters.
    static func chunks(title: String, paragraphs: [String], limit: Int = 3000, maxTotal: Int = 60_000) -> [String] {
        var pieces: [String] = []
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanTitle.isEmpty { pieces.append(cleanTitle + ".") }
        pieces.append(contentsOf: paragraphs.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })
        var result: [String] = []
        var current = ""
        var total = 0
        for piece in pieces {
            for part in split(piece, limit: limit) {
                if total + part.count > maxTotal { break }
                if !current.isEmpty, current.count + part.count + 1 > limit {
                    result.append(current)
                    current = ""
                }
                current += current.isEmpty ? part : "\n" + part
                total += part.count
            }
        }
        if !current.isEmpty { result.append(current) }
        return result
    }

    /// Breaks one long paragraph at spaces so no piece is longer than `limit`.
    private static func split(_ text: String, limit: Int) -> [String] {
        guard text.count > limit else { return [text] }
        var parts: [String] = []
        var current = ""
        for word in text.split(separator: " ", omittingEmptySubsequences: true) {
            if current.count + word.count + 1 > limit, !current.isEmpty {
                parts.append(current)
                current = ""
            }
            current += current.isEmpty ? String(word) : " " + word
        }
        if !current.isEmpty { parts.append(current) }
        return parts
    }
}
