import Foundation

/// How Zalla treats a website that asks for your real location.
enum WebsiteLocationMode: String, CaseIterable, Identifiable {
    case ask
    case never

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ask: return "Ask"
        case .never: return "Never"
        }
    }

    var detail: String {
        switch self {
        case .ask: return WebsiteLocation.Copy.askDetail
        case .never: return WebsiteLocation.Copy.neverDetail
        }
    }
}

/// What to do with one location request.
enum WebsiteLocationVerdict: Equatable {
    case allow
    case deny
    case ask
}

/// A remembered answer for one site, for the list in Settings.
struct WebsiteLocationAnswer: Identifiable, Equatable {
    let host: String
    let allowed: Bool
    var id: String { host }
}

/// Website location: whether sites may ask for your real location. The default is Ask. Your location goes
/// only to a site you allow, through WebKit, and never to Zalla. Pure logic, so it can be tested without a device.
enum WebsiteLocation {
    static let modeKey = "websiteLocationMode"

    static func mode(_ defaults: UserDefaults = .standard) -> WebsiteLocationMode {
        WebsiteLocationMode(rawValue: defaults.string(forKey: modeKey) ?? "") ?? .ask
    }

    static func setMode(_ mode: WebsiteLocationMode, _ defaults: UserDefaults = .standard) {
        if mode == .ask {
            defaults.removeObject(forKey: modeKey)
        } else {
            defaults.set(mode.rawValue, forKey: modeKey)
        }
        NotificationCenter.default.post(name: .zallaScriptsChanged, object: nil)
    }

    /// Puts Website location back to Ask and forgets every per-site choice. Used by Reset the App.
    static func resetSettings(_ defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: modeKey)
        LocationSettings.clearSiteChoices(defaults)
    }

    /// Never blocks every request. Private tabs always ask and ignore remembered answers. Otherwise a
    /// remembered answer wins, and a site with no answer gets asked.
    static func verdict(mode: WebsiteLocationMode, isPrivate: Bool, remembered: Bool?) -> WebsiteLocationVerdict {
        if mode == .never { return .deny }
        if isPrivate { return .ask }
        guard let remembered else { return .ask }
        return remembered ? .allow : .deny
    }

    /// True when the page should be told "denied" without WebKit or iOS being asked at all.
    static func blocksInPage(host: String, isPrivate: Bool, _ defaults: UserDefaults = .standard) -> Bool {
        verdict(
            mode: mode(defaults),
            isPrivate: isPrivate,
            remembered: LocationSettings.answer(forHost: host, defaults)
        ) == .deny
    }

    enum Copy {
        static let allowTitle = "Allow"
        static let denyTitle = "Don't Allow"
        static let askDetail = "Sites have to ask, and nothing is shared unless you say yes."
        static let neverDetail = "Sites cannot ask for your real location. Zalla says no without a prompt."
        static let rememberedMessage = "Your location goes only to this site, never to Zalla. Zalla remembers your answer for this site. You can change it in Settings, Privacy, Location."
        static let privateMessage = "Your location goes only to this site, never to Zalla. Private tabs ask every time and remember nothing."
        static let settingsFooter = "Some sites ask where you are, for things like weather and nearby businesses. Ask lets you decide. Never blocks every request for your real location. Your location goes only to a site you allow, and never to Zalla. Private tabs ask every time and remember nothing."
        static let answersFooter = "Swipe to forget an answer. The site will ask again next time. Private tabs never save answers."

        static func title(site: String) -> String {
            "Allow \(site) to use your location?"
        }

        static func message(isPrivate: Bool) -> String {
            isPrivate ? privateMessage : rememberedMessage
        }
    }
}

extension LocationSettings {
    /// Remembered Allow or Don't Allow answers, by site. Kept on this device, never written for private tabs.
    static let answersKey = "locationSiteAnswers"

    /// The same lowercase host without a leading www that the other per-site settings use.
    static func siteKey(forHost host: String?) -> String? {
        guard var cleaned = HTTPSOnly.normalizedHost(host) else { return nil }
        if cleaned.hasPrefix("www."), cleaned.count > 4 {
            cleaned.removeFirst(4)
        }
        return cleaned
    }

    private static func storedAnswers(_ defaults: UserDefaults) -> [String: Bool] {
        defaults.dictionary(forKey: answersKey) as? [String: Bool] ?? [:]
    }

    static func answer(forHost host: String, _ defaults: UserDefaults = .standard) -> Bool? {
        storedAnswers(defaults)[host]
    }

    /// Saves an answer. Does nothing for a private tab, so private browsing leaves no trace.
    static func remember(_ allowed: Bool, host: String, isPrivate: Bool, _ defaults: UserDefaults = .standard) {
        guard !isPrivate else { return }
        var store = storedAnswers(defaults)
        store[host] = allowed
        defaults.set(store, forKey: answersKey)
        NotificationCenter.default.post(name: .zallaScriptsChanged, object: nil)
    }

    static func forget(host: String, _ defaults: UserDefaults = .standard) {
        var store = storedAnswers(defaults)
        guard store.removeValue(forKey: host) != nil else { return }
        if store.isEmpty {
            defaults.removeObject(forKey: answersKey)
        } else {
            defaults.set(store, forKey: answersKey)
        }
        NotificationCenter.default.post(name: .zallaScriptsChanged, object: nil)
    }

    static func answers(_ defaults: UserDefaults = .standard) -> [WebsiteLocationAnswer] {
        storedAnswers(defaults)
            .map { WebsiteLocationAnswer(host: $0.key, allowed: $0.value) }
            .sorted { $0.host < $1.host }
    }

    /// Forgets every remembered Allow or Don't Allow answer. Approximate sharing and the saved city stay.
    static func forgetAnswers(_ defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: answersKey)
        NotificationCenter.default.post(name: .zallaScriptsChanged, object: nil)
    }

    /// Forgets every per-site location choice (approximate sharing and remembered answers). The saved city stays.
    static func clearSiteChoices(_ defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: sitesKey)
        defaults.removeObject(forKey: answersKey)
        NotificationCenter.default.post(name: .zallaScriptsChanged, object: nil)
    }
}
