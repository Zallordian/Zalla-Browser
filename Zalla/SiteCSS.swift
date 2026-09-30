import Foundation

/// CSS the user wrote for one site (Zalla Unlock). Stored on this device, keyed by host.
enum SiteCSS {
    static let storageKey = "siteCSSByHost"
    static let maxLength = 20_000

    static func load(from defaults: UserDefaults = .standard) -> [String: String] {
        defaults.dictionary(forKey: storageKey) as? [String: String] ?? [:]
    }

    static func css(forHost host: String, in defaults: UserDefaults = .standard) -> String {
        load(from: defaults)[host] ?? ""
    }

    /// Saves the CSS for a host. Empty CSS removes the entry.
    static func set(_ css: String, forHost host: String, in defaults: UserDefaults = .standard) {
        var store = load(from: defaults)
        let trimmed = String(css.prefix(maxLength)).trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            store.removeValue(forKey: host)
        } else {
            store[host] = trimmed
        }
        if store.isEmpty {
            defaults.removeObject(forKey: storageKey)
        } else {
            defaults.set(store, forKey: storageKey)
        }
        NotificationCenter.default.post(name: .zallaScriptsChanged, object: nil)
    }

    static func clearAll(in defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: storageKey)
        NotificationCenter.default.post(name: .zallaScriptsChanged, object: nil)
    }

    static func hosts(in defaults: UserDefaults = .standard) -> [String] {
        load(from: defaults).keys.sorted()
    }
}

/// One user script Zalla wants on the page about to load.
struct PageScriptSpec: Equatable {
    var source: String
    var atDocumentStart: Bool
    var mainFrameOnly: Bool
}

extension PageScripts {
    /// The scripts to install for a page, from the current settings. Pure, so it can be tested.
    static func plan(
        for url: URL?,
        unlocked: Bool,
        defaults: UserDefaults = .standard
    ) -> [PageScriptSpec] {
        var specs: [PageScriptSpec] = []
        let isWeb = ["http", "https"].contains(url?.scheme?.lowercased() ?? "")
        guard isWeb else { return specs }
        if PrivacyShield.trimReferrer(defaults) {
            specs.append(PageScriptSpec(source: referrerTrim, atDocumentStart: true, mainFrameOnly: false))
        }
        if PrivacyShield.fingerprintProtection(defaults) {
            specs.append(PageScriptSpec(source: fingerprintProtection, atDocumentStart: true, mainFrameOnly: false))
        }
        if let host = ContentBlockingSettings.hostKey(for: url) {
            if let place = LocationSettings.coordinate(forHost: host, defaults) {
                specs.append(PageScriptSpec(
                    source: approximateLocation(latitude: place.latitude, longitude: place.longitude),
                    atDocumentStart: true,
                    mainFrameOnly: false
                ))
            }
            if unlocked {
                let css = SiteCSS.css(forHost: host, in: defaults)
                if !css.isEmpty {
                    specs.append(PageScriptSpec(source: siteCSS(css), atDocumentStart: true, mainFrameOnly: true))
                }
            }
        }
        return specs
    }
}
