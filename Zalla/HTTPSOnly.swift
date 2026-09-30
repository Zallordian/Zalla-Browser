import Foundation

/// HTTPS-Only Mode: which main-frame http addresses get upgraded, which failures fall back to the
/// in-app notice, and the notice copy. Pure logic so it can be tested without WebKit.
enum HTTPSOnly {
    static let storageKey = "httpsOnlyMode"

    /// On unless you turned it off. People who never touched the switch get it too.
    static var isEnabled: Bool {
        enabled(in: .standard)
    }

    static func enabled(in defaults: UserDefaults) -> Bool {
        defaults.object(forKey: storageKey) as? Bool ?? true
    }

    static let noticeTitle = "This site doesn't use encryption."
    static let noticeMessage = "Anything you type here could be read by others on the network. Probably fine for reading recipes. Less fine for passwords."
    static let goBackTitle = "Take me back"
    static let continueTitle = "Continue anyway"

    /// The https version of `url`, or nil when it should load as is: not http, a local or private
    /// network address, or a host you chose to open over http this session.
    static func upgradedURL(for url: URL, exceptions: HTTPSOnlyExceptions = HTTPSOnlyExceptions()) -> URL? {
        guard url.scheme?.lowercased() == "http",
              let host = normalizedHost(url.host),
              !isLocalOrPrivate(host),
              !exceptions.contains(host),
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }
        components.scheme = "https"
        if components.port == 80 {
            components.port = nil
        }
        return components.url
    }

    /// Lowercased host without IPv6 brackets or a trailing dot. Nil when empty.
    static func normalizedHost(_ host: String?) -> String? {
        guard var cleaned = host?.lowercased() else { return nil }
        if cleaned.hasPrefix("[") && cleaned.hasSuffix("]") {
            cleaned = String(cleaned.dropFirst().dropLast())
        }
        if cleaned.hasSuffix(".") {
            cleaned.removeLast()
        }
        return cleaned.isEmpty ? nil : cleaned
    }

    /// Localhost, .local names, single-label intranet names, and loopback, private, or link-local IPs.
    /// These rarely have certificates, so they always load as typed.
    static func isLocalOrPrivate(_ host: String) -> Bool {
        if host == "localhost" || host.hasSuffix(".localhost") || host.hasSuffix(".local") {
            return true
        }
        if let octets = ipv4Octets(host) {
            switch (octets[0], octets[1]) {
            case (0, _), (10, _), (127, _):
                return true
            case (169, 254), (192, 168):
                return true
            case (100, 64...127):
                // Carrier-grade NAT range, which Tailscale and similar tools use.
                return true
            case (172, 16...31):
                return true
            default:
                return false
            }
        }
        if host.contains(":") {
            if host == "::1" || host == "::" { return true }
            if let mapped = mappedIPv4(host) { return isLocalOrPrivate(mapped) }
            let first = host.split(separator: ":", omittingEmptySubsequences: false).first ?? ""
            guard let group = UInt16(first, radix: 16) else { return false }
            // Unique local fc00::/7 and link-local fe80::/10.
            return (group & 0xFE00) == 0xFC00 || (group & 0xFFC0) == 0xFE80
        }
        return !host.contains(".")
    }

    /// The IPv4 address inside an IPv4-mapped IPv6 host such as ::ffff:10.0.0.1 or ::ffff:a00:1, else nil.
    private static func mappedIPv4(_ host: String) -> String? {
        let prefix = "::ffff:"
        guard host.hasPrefix(prefix) else { return nil }
        let rest = String(host.dropFirst(prefix.count))
        if rest.contains(".") { return rest }
        let groups = rest.split(separator: ":", omittingEmptySubsequences: false)
        guard groups.count == 2,
              let high = UInt16(groups[0], radix: 16),
              let low = UInt16(groups[1], radix: 16) else { return nil }
        return "\(high >> 8).\(high & 0xFF).\(low >> 8).\(low & 0xFF)"
    }

    private static func ipv4Octets(_ host: String) -> [Int]? {
        let parts = host.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4 else { return nil }
        var octets: [Int] = []
        for part in parts {
            guard !part.isEmpty, part.count <= 3,
                  part.allSatisfy({ $0.isASCII && $0.isNumber }),
                  let value = Int(part), value <= 255 else {
                return nil
            }
            octets.append(value)
        }
        return octets
    }

    /// Failures that mean the site has no working https version: TLS and certificate errors,
    /// or the secure port not answering.
    static let upgradeFailureCodes: Set<Int> = [
        NSURLErrorSecureConnectionFailed,
        NSURLErrorServerCertificateHasBadDate,
        NSURLErrorServerCertificateUntrusted,
        NSURLErrorServerCertificateHasUnknownRoot,
        NSURLErrorServerCertificateNotYetValid,
        NSURLErrorClientCertificateRejected,
        NSURLErrorClientCertificateRequired,
        NSURLErrorCannotConnectToHost,
        NSURLErrorTimedOut,
        NSURLErrorNetworkConnectionLost,
        NSURLErrorBadServerResponse
    ]

    static func isUpgradeFailure(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain && upgradeFailureCodes.contains(nsError.code)
    }

    /// A load that was cancelled or replaced by another one, not a real failure.
    static func isInterruption(_ error: Error) -> Bool {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled { return true }
        // WebKit reports "Frame load interrupted" when a policy decision replaces a load.
        return nsError.domain == "WebKitErrorDomain" && nsError.code == 102
    }
}

/// Hosts you chose to open over http. Session only, never written to disk.
struct HTTPSOnlyExceptions {
    private var hosts: Set<String> = []

    func contains(_ host: String) -> Bool {
        guard let key = HTTPSOnly.normalizedHost(host) else { return false }
        return hosts.contains(key)
    }

    mutating func allow(_ host: String) {
        guard let key = HTTPSOnly.normalizedHost(host) else { return }
        hosts.insert(key)
    }

    mutating func removeAll() {
        hosts.removeAll()
    }

    var isEmpty: Bool { hosts.isEmpty }
}

/// App-wide holder for the session exceptions, shared by every tab.
@MainActor
enum HTTPSOnlySession {
    static var exceptions = HTTPSOnlyExceptions()
}

/// The http address HTTPS-Only Mode could not open securely, shown in the in-app notice.
struct HTTPSFallback: Equatable {
    let url: URL

    var host: String { url.host ?? url.absoluteString }
}
