import Foundation

/// Build 51: Zalla does not keep running after you leave it. App Review guideline 2.5.4 rejected a
/// background audio declaration because nothing keeps playing. Listen to page is speech while the app is open.
enum BackgroundModePolicy {
    /// Every mode in the shipped Info.plist is disallowed. Zalla declares none.
    static func disallowed(in declared: [String]?) -> [String] {
        declared ?? []
    }

    /// True when the XcodeGen project still asks for a background mode. That key is what becomes UIBackgroundModes.
    static func projectDeclaresABackgroundMode(_ yaml: String) -> Bool {
        yaml.contains("UIBackgroundModes:")
    }
}
