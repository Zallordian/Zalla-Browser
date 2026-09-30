import Foundation

/// The kinds of trouble a page load can run into, in words a person would use.
enum FriendlyErrorKind: String, Equatable {
    case offline
    case timeout
    case badCertificate
    case notFound
    case cannotConnect
    case other

    /// Sorts a failed load into one of the friendly kinds.
    static func classify(_ error: Error) -> FriendlyErrorKind {
        let ns = error as NSError
        guard ns.domain == NSURLErrorDomain else { return .other }
        switch ns.code {
        case NSURLErrorNotConnectedToInternet, NSURLErrorDataNotAllowed, NSURLErrorInternationalRoamingOff:
            return .offline
        case NSURLErrorTimedOut:
            return .timeout
        case NSURLErrorServerCertificateUntrusted, NSURLErrorServerCertificateHasBadDate,
             NSURLErrorServerCertificateHasUnknownRoot, NSURLErrorServerCertificateNotYetValid,
             NSURLErrorClientCertificateRejected, NSURLErrorSecureConnectionFailed:
            return .badCertificate
        case NSURLErrorCannotFindHost, NSURLErrorDNSLookupFailed:
            return .notFound
        case NSURLErrorCannotConnectToHost, NSURLErrorNetworkConnectionLost:
            return .cannotConnect
        default:
            return .other
        }
    }

    var title: String {
        switch self {
        case .offline: return "You're offline."
        case .timeout: return "That took too long."
        case .badCertificate: return "This site's ID doesn't check out."
        case .notFound: return "We couldn't find that site."
        case .cannotConnect: return "The site isn't picking up."
        case .other: return "That page didn't load."
        }
    }

    var message: String {
        switch self {
        case .offline:
            return "Zalla can't reach the internet. Check Wi-Fi or cellular, then try again. The web will still be there."
        case .timeout:
            return "The site took its time and then some. It might be busy, or your connection might be having a moment."
        case .badCertificate:
            return "Its security certificate is expired, mismatched, or not one we trust. Zalla won't load it, because anything you typed could end up somewhere it shouldn't."
        case .notFound:
            return "Nothing answers to that address. Check the spelling, or search for it instead."
        case .cannotConnect:
            return "Zalla found the site, but the connection dropped or was refused. Trying again in a minute often does it."
        case .other:
            return "Something got in the way. Trying again usually helps."
        }
    }

    var symbolName: String {
        switch self {
        case .offline: return "wifi.slash"
        case .timeout: return "hourglass"
        case .badCertificate: return "lock.trianglebadge.exclamationmark"
        case .notFound: return "questionmark.circle"
        case .cannotConnect: return "bolt.horizontal"
        case .other: return "exclamationmark.triangle"
        }
    }

    /// Certificate trouble has no "try again" on purpose.
    var offersRetry: Bool { self != .badCertificate }
}

/// A failed page load, ready to show.
struct FriendlyError: Equatable {
    let kind: FriendlyErrorKind
    let host: String?
    let failedURL: URL?

    init(error: Error, fallbackURL: URL?) {
        kind = FriendlyErrorKind.classify(error)
        let ns = error as NSError
        if let failing = ns.userInfo[NSURLErrorFailingURLErrorKey] as? URL {
            failedURL = failing
        } else if let failing = ns.userInfo[NSURLErrorFailingURLStringErrorKey] as? String {
            failedURL = URL(string: failing) ?? fallbackURL
        } else {
            failedURL = fallbackURL
        }
        host = failedURL?.host
    }
}
