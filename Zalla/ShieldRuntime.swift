import Foundation
import Network
import WebKit

/// Applies Privacy Shield settings to WebKit and to Zalla's own network requests.
@MainActor
enum ShieldRuntime {
    /// The proxy chosen in Settings, in the form WebKit wants. Empty when no proxy is set up.
    static func proxyConfigurations(defaults: UserDefaults = .standard) -> [ProxyConfiguration] {
        guard let proxy = ProxySettings.stored(in: defaults) else { return [] }
        let port = NWEndpoint.Port(rawValue: proxy.port) ?? NWEndpoint.Port(integerLiteral: 8080)
        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(proxy.host), port: port)
        switch proxy.kind {
        case .http:
            return [ProxyConfiguration(httpCONNECTProxy: endpoint)]
        case .socks:
            return [ProxyConfiguration(socksv5Proxy: endpoint)]
        }
    }

    /// Gives a new tab's website data store the proxy, if one is set up.
    static func applyProxy(toNewStore store: WKWebsiteDataStore) {
        let configurations = proxyConfigurations()
        if !configurations.isEmpty {
            store.proxyConfigurations = configurations
        }
    }

    private static var proxyWasSet = false

    /// Updates the shared store used by normal tabs, plus any private tab stores passed in.
    static func refreshProxy(privateStores: [WKWebsiteDataStore]) {
        let configurations = proxyConfigurations()
        guard !configurations.isEmpty || proxyWasSet else { return }
        proxyWasSet = !configurations.isEmpty
        WKWebsiteDataStore.default().proxyConfigurations = configurations
        for store in privateStores {
            store.proxyConfigurations = configurations
        }
    }

    /// Requires encrypted DNS for requests Zalla makes itself (image export, speed test).
    /// Turning it off takes effect the next time Zalla starts.
    /// WebKit runs page networking in its own processes, so this does not change how web pages look up addresses.
    static func applyEncryptedDNS(defaults: UserDefaults = .standard) {
        guard PrivacyShield.encryptedDNS(defaults) else { return }
        let provider = DNSProvider.stored(in: defaults)
        let addresses = provider.serverAddresses.map {
            NWEndpoint.hostPort(host: NWEndpoint.Host($0), port: NWEndpoint.Port(integerLiteral: 443))
        }
        NWParameters.PrivacyContext.default.requireEncryptedNameResolution(
            true,
            fallbackResolver: .https(provider.dohURL, serverAddresses: addresses)
        )
    }
}
