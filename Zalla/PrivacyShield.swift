import Foundation

extension Notification.Name {
    /// Posted when Privacy Shield, location, site CSS, or unlock settings that change page scripts are edited.
    static let zallaScriptsChanged = Notification.Name("zallaScriptsChanged")
    /// Posted when the proxy settings change.
    static let zallaProxyChanged = Notification.Name("zallaProxyChanged")
}

/// Privacy Shield: a set of on-device protections. It is not a VPN and does not hide your IP address
/// from the sites you visit (unless you set up your own proxy).
enum PrivacyShield {
    static let stripLinksKey = "shieldStripTrackingLinks"
    static let referrerKey = "shieldTrimReferrer"
    static let fingerprintKey = "shieldFingerprintProtection"
    static let encryptedDNSKey = "shieldEncryptedDNS"
    static let dnsProviderKey = "shieldDNSProvider"
    static let proxyEnabledKey = "shieldProxyEnabled"
    static let proxyTypeKey = "shieldProxyType"
    static let proxyHostKey = "shieldProxyHost"
    static let proxyPortKey = "shieldProxyPort"

    /// Link cleanup and referrer trimming are on by default because they rarely break pages.
    static func stripLinks(_ defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: stripLinksKey) as? Bool ?? true
    }

    static func trimReferrer(_ defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: referrerKey) as? Bool ?? true
    }

    /// Off by default: it can change how a few sites behave.
    static func fingerprintProtection(_ defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: fingerprintKey)
    }

    static func encryptedDNS(_ defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: encryptedDNSKey)
    }

    static func resetSettings(in defaults: UserDefaults = .standard) {
        for key in [stripLinksKey, referrerKey, fingerprintKey, encryptedDNSKey, dnsProviderKey,
                    proxyEnabledKey, proxyTypeKey, proxyHostKey, proxyPortKey] {
            defaults.removeObject(forKey: key)
        }
    }

    // MARK: Copy

    enum Copy {
        static let stripLinksTitle = "Clean tracking from links"
        static let stripLinksDetail = "Removes tracking tags such as utm_source, fbclid, and gclid from the addresses of pages you open."
        static let referrerTitle = "Trim referrer"
        static let referrerDetail = "Sites you go to next are told only your last site's name, not the exact page you were on. Pages that set their own referrer rule can override this."
        static let fingerprintTitle = "Fingerprinting protection"
        static let fingerprintDetail = "Adds small changes to canvas and audio results and reports a common processor count, so it is harder to tell your device apart. It does not make you anonymous and can affect some games and web apps."
        static let encryptedDNSTitle = "Encrypted DNS"
        static let encryptedDNSDetail = "Uses encrypted name lookups for what Zalla itself requests, such as image export and the speed test. iOS does not let an app change how web pages look up addresses. For that, add an encrypted DNS setting for your whole iPhone or use a DNS app."
        static let proxyTitle = "Use my own proxy"
        static let proxyDetail = "Sends web page traffic through a proxy server that you run or subscribe to. The proxy can see the sites you visit, and it looks up their addresses. Zalla does not provide a proxy, and proxies that ask for a username and password are not supported yet."
        static let footer = "Privacy Shield works on this device. It is not a VPN: it does not hide your IP address, and sites and your search engine still see the requests you make."
    }
}

/// Removes well-known tracking parameters from web addresses.
enum TrackingParameters {
    private static let exact: Set<String> = [
        "fbclid", "gclid", "gclsrc", "dclid", "gbraid", "wbraid", "msclkid", "yclid", "twclid", "ttclid",
        "igshid", "mc_eid", "mc_cid", "_hsenc", "_hsmi", "hsctatracking", "mkt_tok", "vero_id", "vero_conv",
        "oly_enc_id", "oly_anon_id", "s_cid", "rb_clickid", "_openstat", "ref_src"
    ]

    static func isTracking(_ name: String) -> Bool {
        let lower = name.lowercased()
        return lower.hasPrefix("utm_") || exact.contains(lower)
    }

    /// The address with tracking parameters removed, or nil when there is nothing to remove.
    static func cleaned(_ url: URL) -> URL? {
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https",
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let query = components.percentEncodedQuery, !query.isEmpty else { return nil }
        let pieces = query.split(separator: "&", omittingEmptySubsequences: true).map(String.init)
        let kept = pieces.filter { piece in
            let rawName = piece.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? piece
            let name = rawName.removingPercentEncoding ?? rawName
            return !isTracking(name)
        }
        guard kept.count != pieces.count else { return nil }
        components.percentEncodedQuery = kept.isEmpty ? nil : kept.joined(separator: "&")
        return components.url
    }
}

/// A user-supplied proxy. Only host and port are needed; nothing about it leaves the device.
struct ProxySettings: Equatable {
    enum Kind: String, CaseIterable, Identifiable {
        case http = "HTTP"
        case socks = "SOCKS5"
        var id: String { rawValue }
    }

    var kind: Kind
    var host: String
    var port: UInt16

    /// Trims and checks what the user typed. Returns nil when it cannot be a proxy address.
    static func validated(kind: Kind, host rawHost: String, port rawPort: String) -> ProxySettings? {
        let host = rawHost.trimmingCharacters(in: .whitespacesAndNewlines)
        let portText = rawPort.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !host.isEmpty, host.count <= 253,
              !host.contains("/"), !host.contains(":"),
              !host.contains(where: { $0.isWhitespace }),
              let port = UInt16(portText), port > 0 else { return nil }
        return ProxySettings(kind: kind, host: host, port: port)
    }

    static func stored(in defaults: UserDefaults = .standard) -> ProxySettings? {
        guard defaults.bool(forKey: PrivacyShield.proxyEnabledKey) else { return nil }
        let kind = Kind(rawValue: defaults.string(forKey: PrivacyShield.proxyTypeKey) ?? "") ?? .http
        return validated(
            kind: kind,
            host: defaults.string(forKey: PrivacyShield.proxyHostKey) ?? "",
            port: defaults.string(forKey: PrivacyShield.proxyPortKey) ?? ""
        )
    }
}

/// Providers for encrypted DNS (DNS over HTTPS) used for Zalla's own requests.
enum DNSProvider: String, CaseIterable, Identifiable {
    case cloudflare = "Cloudflare"
    case quad9 = "Quad9"

    var id: String { rawValue }

    var dohURL: URL {
        switch self {
        case .cloudflare: return URL(string: "https://cloudflare-dns.com/dns-query")!
        case .quad9: return URL(string: "https://dns.quad9.net/dns-query")!
        }
    }

    /// Fixed addresses so the encrypted resolver can be reached without a plain DNS lookup first.
    var serverAddresses: [String] {
        switch self {
        case .cloudflare: return ["1.1.1.1", "1.0.0.1"]
        case .quad9: return ["9.9.9.9", "149.112.112.112"]
        }
    }

    static func stored(in defaults: UserDefaults = .standard) -> DNSProvider {
        DNSProvider(rawValue: defaults.string(forKey: PrivacyShield.dnsProviderKey) ?? "") ?? .cloudflare
    }
}
