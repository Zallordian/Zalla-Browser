import Foundation

/// Page zoom steps and per-site memory. Levels are stored by host so each site keeps its own zoom.
enum PageZoom {
    static let storageKey = "pageZoomByHost"
    static let defaultLevel = 1.0
    static let levels: [Double] = [0.5, 0.75, 0.85, 1.0, 1.15, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0]

    static var minimum: Double { levels.first ?? 0.5 }
    static var maximum: Double { levels.last ?? 3.0 }

    static func clamped(_ level: Double) -> Double {
        min(max(level, minimum), maximum)
    }

    static func next(after level: Double) -> Double {
        levels.first(where: { $0 > level + 0.001 }) ?? maximum
    }

    static func previous(before level: Double) -> Double {
        levels.last(where: { $0 < level - 0.001 }) ?? minimum
    }

    static func isDefault(_ level: Double) -> Bool {
        abs(level - defaultLevel) < 0.001
    }

    static func percentText(_ level: Double) -> String {
        "\(Int((level * 100).rounded()))%"
    }

    /// Lowercased host used as the storage key, or nil for pages without a host.
    static func hostKey(for url: URL?) -> String? {
        guard let host = url?.host?.lowercased(), !host.isEmpty else { return nil }
        return host
    }

    static func level(for host: String, in store: [String: Double]) -> Double {
        clamped(store[host] ?? defaultLevel)
    }

    /// Returns the store with `level` saved for `host`. The default level removes the entry.
    static func updated(_ store: [String: Double], host: String, level: Double) -> [String: Double] {
        var copy = store
        if isDefault(level) {
            copy.removeValue(forKey: host)
        } else {
            copy[host] = clamped(level)
        }
        return copy
    }

    static func load(from defaults: UserDefaults = .standard) -> [String: Double] {
        defaults.dictionary(forKey: storageKey) as? [String: Double] ?? [:]
    }

    static func save(_ store: [String: Double], to defaults: UserDefaults = .standard) {
        if store.isEmpty {
            defaults.removeObject(forKey: storageKey)
        } else {
            defaults.set(store, forKey: storageKey)
        }
    }
}
