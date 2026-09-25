import Foundation

/// What a site asked to use. Mirrors WKMediaCaptureType without depending on WebKit.
enum MediaCaptureKind: String, CaseIterable {
    case camera
    case microphone
    case cameraAndMicrophone

    var noun: String {
        switch self {
        case .camera: return "your camera"
        case .microphone: return "your microphone"
        case .cameraAndMicrophone: return "your camera and microphone"
        }
    }
}

/// Copy and origin formatting for the per-site camera and microphone prompt.
enum MediaCapturePrompt {
    static let allowTitle = "Allow"
    static let denyTitle = "Don't Allow"

    /// Readable site name: host, plus the port when it is not the default for the scheme.
    static func siteLabel(scheme: String, host: String, port: Int) -> String {
        let cleanHost = host.isEmpty ? "This site" : host
        let isDefaultPort = port == 0
            || (scheme.lowercased() == "https" && port == 443)
            || (scheme.lowercased() == "http" && port == 80)
        return isDefaultPort ? cleanHost : "\(cleanHost):\(port)"
    }

    static func title(site: String, kind: MediaCaptureKind) -> String {
        "Allow \(site) to use \(kind.noun)?"
    }

    static let message = "Zalla remembers your choice for this site until you close the app."
}

/// Session-only memory of per-site choices. Never written to disk; private tabs keep their own entries.
struct MediaPermissionMemory {
    struct Key: Hashable {
        var site: String
        var kind: MediaCaptureKind
        var isPrivate: Bool
    }

    private var decisions: [Key: Bool] = [:]

    func decision(site: String, kind: MediaCaptureKind, isPrivate: Bool) -> Bool? {
        if let exact = decisions[Key(site: site, kind: kind, isPrivate: isPrivate)] {
            return exact
        }
        // A site allowed both camera and microphone may use either one alone.
        if kind != .cameraAndMicrophone,
           decisions[Key(site: site, kind: .cameraAndMicrophone, isPrivate: isPrivate)] == true {
            return true
        }
        return nil
    }

    mutating func remember(_ allowed: Bool, site: String, kind: MediaCaptureKind, isPrivate: Bool) {
        decisions[Key(site: site, kind: kind, isPrivate: isPrivate)] = allowed
    }

    mutating func removeAll() {
        decisions.removeAll()
    }

    var isEmpty: Bool { decisions.isEmpty }
}

/// App-wide holder for the session memory, shared by every tab.
@MainActor
enum MediaPermissionSession {
    static var memory = MediaPermissionMemory()
}
