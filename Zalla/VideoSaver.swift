import Foundation

/// Video Saver (Zalla Unlock): saves a video that a page serves as a plain media file. It never touches protected
/// video (FairPlay, Widevine, PlayReady, or any stream that needs a key), never reads a platform's private player
/// data, and has no code for any one website. Streams that a page builds in memory (blob: sources) are not files and
/// are never captured. Foundation only, so the rules and the playlist reading can be tested without UIKit.
enum VideoSaver {
    static let storageKey = "videoSaverEnabled"
    static let defaultEnabled = true
    static let messageName = "zallaVideo"
    static let maxCandidates = 6

    static func isEnabled(in defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: storageKey) as? Bool ?? defaultEnabled
    }

    /// Saving needs Zalla Unlock and the setting on.
    static func isAvailable(unlocked: Bool, enabled: Bool) -> Bool { unlocked && enabled }

    // MARK: - Messages shown to the person

    static let protectedMessage = "This video is protected and can't be saved."
    static let noVideoMessage = "Zalla did not find a video on this page that it can save."
    static let streamMessage = "This video is a stream, not a single file. Saving streams is coming in a later build."
    static let liveMessage = "Live streams can't be saved."
    static let unreadableMessage = "Zalla could not read this stream, so it can't be saved."
    static let savingMessage = "Saving to Downloads."

    /// The footer under the Video Saver switch in Settings.
    static func settingsFooter(unlocked: Bool) -> String {
        let base = "Adds a Save video row to the Menu when a page offers a plain video file. Zalla never saves protected video, and has no special handling for any one website."
        return unlocked ? base : base + " Saving needs Zalla Unlock."
    }

    // MARK: - What a link is

    enum Kind: String, Equatable {
        /// A single media file: mp4, m4v, mov, or webm.
        case file
        /// An HLS playlist (m3u8). Detected, and checked for protection, but not downloaded yet.
        case hls
        /// Anything else: blob and data sources, other schemes, DASH manifests, and unknown types.
        case unsupported
    }

    static let fileExtensions: Set<String> = ["mp4", "m4v", "mov", "webm"]

    static func classify(_ url: URL) -> Kind {
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https",
              !(url.host ?? "").isEmpty else { return .unsupported }
        let ext = url.pathExtension.lowercased()
        if fileExtensions.contains(ext) { return .file }
        if ext == "m3u8" { return .hls }
        return .unsupported
    }

    struct Candidate: Equatable, Identifiable {
        let url: URL
        let kind: Kind
        var id: String { url.absoluteString }

        /// The last part of the address, or the host when there is none.
        var displayName: String {
            let last = url.lastPathComponent
            if !last.isEmpty, last != "/" { return last }
            return url.host ?? url.absoluteString
        }
    }

    /// Turns the addresses a page reported into the list to offer: only files and playlists, no repeats (a fragment
    /// does not make a different video), in the order the page gave them, up to `maxCandidates`.
    static func candidates(from rawURLs: [String]) -> [Candidate] {
        var seen = Set<String>()
        var result: [Candidate] = []
        for raw in rawURLs {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard var components = URLComponents(string: trimmed) else { continue }
            components.fragment = nil
            guard let url = components.url else { continue }
            let kind = classify(url)
            guard kind != .unsupported, seen.insert(url.absoluteString).inserted else { continue }
            result.append(Candidate(url: url, kind: kind))
            if result.count == maxCandidates { break }
        }
        return result
    }

    // MARK: - What the page script reports

    struct Report: Equatable {
        var candidates: [Candidate]
        /// The page's player uses encrypted media extensions (a key system), so its video is protected.
        var protectedMedia: Bool
    }

    /// Reads the message the page script posts. Anything that is not a dictionary is ignored.
    static func report(from body: Any) -> Report? {
        guard let dictionary = body as? [String: Any] else { return nil }
        let urls = (dictionary["sources"] as? [Any])?.compactMap { $0 as? String } ?? []
        return Report(
            candidates: candidates(from: urls),
            protectedMedia: dictionary["protected"] as? Bool ?? false
        )
    }

    enum Availability: Equatable {
        case none
        case ready
        case protected
    }

    static func availability(for report: Report) -> Availability {
        if !report.candidates.isEmpty { return .ready }
        return report.protectedMedia ? .protected : .none
    }

    // MARK: - HLS playlists

    struct HLSVariant: Equatable {
        var bandwidth: Int
        var resolution: String?
        var uri: String
    }

    struct HLSInfo: Equatable {
        var isMaster = false
        var variants: [HLSVariant] = []
        var segmentCount = 0
        var isLive = false
        /// Upper-cased METHOD of every EXT-X-KEY and EXT-X-SESSION-KEY tag.
        var keyMethods: [String] = []
        /// Lower-cased KEYFORMAT of those tags (identity when the tag has none).
        var keyFormats: [String] = []

        /// True when any key tag asks for decryption: a METHOD other than NONE, or a KEYFORMAT other than the
        /// plain identity one (FairPlay, PlayReady, Widevine, and the like).
        var isProtected: Bool {
            keyMethods.contains { $0 != "NONE" } || keyFormats.contains { $0 != "identity" }
        }

        var bestVariant: HLSVariant? { variants.max { $0.bandwidth < $1.bandwidth } }
    }

    /// Splits `KEY=value,KEY="quoted, value"` into a dictionary with upper-cased keys.
    static func attributes(_ list: String) -> [String: String] {
        var result: [String: String] = [:]
        var key = ""
        var value = ""
        var inKey = true
        var quoted = false
        func commit() {
            let name = key.trimmingCharacters(in: .whitespaces).uppercased()
            if !name.isEmpty { result[name] = value.trimmingCharacters(in: .whitespaces) }
            key = ""
            value = ""
            inKey = true
            quoted = false
        }
        for character in list {
            if inKey {
                if character == "=" { inKey = false } else { key.append(character) }
            } else if character == "\"" {
                quoted.toggle()
            } else if character == ",", !quoted {
                commit()
            } else {
                value.append(character)
            }
        }
        commit()
        return result
    }

    /// Reads an HLS playlist. Returns nil when the text is not a playlist.
    static func parseHLS(_ text: String) -> HLSInfo? {
        let pieces: [Substring] = text.split(whereSeparator: { $0 == "\n" || $0 == "\r" })
        let trimmed: [String] = pieces.map { $0.trimmingCharacters(in: .whitespaces) }
        let lines: [String] = trimmed.filter { !$0.isEmpty }
        guard lines.first == "#EXTM3U" else { return nil }
        var info = HLSInfo()
        var pendingVariant: [String: String]?
        var sawEnd = false
        for line in lines.dropFirst() {
            if line.hasPrefix("#EXT-X-STREAM-INF:") {
                info.isMaster = true
                pendingVariant = attributes(String(line.dropFirst("#EXT-X-STREAM-INF:".count)))
            } else if line.hasPrefix("#EXT-X-KEY:") || line.hasPrefix("#EXT-X-SESSION-KEY:") {
                let list = line.drop(while: { $0 != ":" }).dropFirst()
                let values = attributes(String(list))
                info.keyMethods.append((values["METHOD"] ?? "NONE").uppercased())
                info.keyFormats.append((values["KEYFORMAT"] ?? "identity").lowercased())
            } else if line.hasPrefix("#EXT-X-ENDLIST") {
                sawEnd = true
            } else if line.hasPrefix("#") {
                continue
            } else if let variant = pendingVariant {
                info.variants.append(HLSVariant(
                    bandwidth: Int(variant["BANDWIDTH"] ?? "") ?? 0,
                    resolution: variant["RESOLUTION"],
                    uri: line
                ))
                pendingVariant = nil
            } else if !info.isMaster {
                info.segmentCount += 1
            }
        }
        info.isLive = !info.isMaster && info.segmentCount > 0 && !sawEnd
        return info
    }

    /// What to tell the person when they ask to save a stream.
    static func message(forStream info: HLSInfo?) -> String {
        guard let info else { return unreadableMessage }
        if info.isProtected { return protectedMessage }
        if info.isLive { return liveMessage }
        return streamMessage
    }

    // MARK: - Page script

    /// Reports the files a page's video elements point at (and the files it already loaded, from the browser's own
    /// resource timing list), and whether a key system is in use. It reads only. It loads nothing, and a blob:
    /// source is never reported because it is not a file.
    static let script = #"""
    (function() {
      if (window.__zallaVideo) return;
      window.__zallaVideo = true;
      var last = '';
      var pending = null;
      function abs(value) {
        try { return new URL(value, document.baseURI).href; } catch (e) { return null; }
      }
      function collect() {
        var urls = [];
        var keyed = false;
        var videos = document.querySelectorAll('video');
        for (var i = 0; i < videos.length; i++) {
          var video = videos[i];
          if (video.mediaKeys) keyed = true;
          var values = [video.currentSrc, video.getAttribute('src')];
          var sources = video.querySelectorAll('source');
          for (var j = 0; j < sources.length; j++) values.push(sources[j].getAttribute('src'));
          for (var k = 0; k < values.length; k++) {
            var value = values[k];
            if (!value || value.indexOf('blob:') === 0 || value.indexOf('data:') === 0) continue;
            var full = abs(value);
            if (full) urls.push(full);
          }
        }
        try {
          var entries = performance.getEntriesByType('resource');
          for (var e = 0; e < entries.length; e++) {
            var name = entries[e].name;
            if (/\.(mp4|m4v|mov|webm|m3u8)([?#]|$)/i.test(name)) urls.push(name);
          }
        } catch (x) {}
        var unique = [];
        for (var u = 0; u < urls.length; u++) {
          if (unique.indexOf(urls[u]) < 0) unique.push(urls[u]);
        }
        return { sources: unique.slice(0, 12), protected: keyed };
      }
      function send() {
        var payload = collect();
        var key = JSON.stringify(payload);
        if (key === last) return;
        last = key;
        try { window.webkit.messageHandlers.zallaVideo.postMessage(payload); } catch (e) {}
      }
      function soon() {
        if (pending) return;
        pending = setTimeout(function() { pending = null; send(); }, 300);
      }
      send();
      document.addEventListener('DOMContentLoaded', soon);
      window.addEventListener('load', soon);
      document.addEventListener('loadedmetadata', soon, true);
      document.addEventListener('play', soon, true);
      try {
        var observer = new MutationObserver(soon);
        if (document.body) observer.observe(document.body, { childList: true, subtree: true });
      } catch (e) {}
      setInterval(function() { if (document.visibilityState === 'visible') send(); }, 3000);
    })();
    """#
}
