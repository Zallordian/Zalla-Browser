# Video Saver

Video Saver (Zalla Unlock, Settings, Premium switch "Video Saver", on by default) lets you save a video that a page serves as a plain media file. It adds a Save video row to the Menu when a page offers one.

## What it supports (Build 29)
- Direct media files: `.mp4`, `.m4v`, `.mov`, `.webm` over `http` or `https`.
- Detection of HLS playlists (`.m3u8`). The playlist is read once, only when the person taps Check stream, and only to explain why it can not be saved yet. Saving streams is not built.
- Saved files use the existing download manager (`BrowserStore.beginDownload`, `DownloadsStore`), so they land in Settings, Tools, Downloads, with Open and Share (Photos, Files, AirDrop). Private tabs mark their downloads private, as before.

## What it intentionally does not do
- No DRM circumvention. A page whose player uses encrypted media extensions (`video.mediaKeys` is set) is reported as protected and shows "This video is protected and can't be saved." Playlists with any `EXT-X-KEY` or `EXT-X-SESSION-KEY` that has a METHOD other than NONE, or a KEYFORMAT other than identity (FairPlay, PlayReady, Widevine), are protected too. That includes plain AES-128 encrypted streams. Zalla does not fetch keys.
- No website specific code. There is no host list and no extraction for any one platform, YouTube included. This is deliberate: it keeps Zalla inside App Store Review Guideline 5.2.3 (no saving of media from services without authorization) and those sites' terms.
- Blob sources (`blob:`) are never captured. Players that build the video in memory (media source extensions) are not files, so they never show up.
- No network calls except the download the person asked for, and the one playlist read described above. The page script reads the page only (video elements, `currentSrc`, source tags, and the browser's resource timing list for files the page already loaded). It loads nothing and never calls fetch.
- Requests are made through the web view, so cookies and sessions are the person's own. No headers are forged. A file that the site refuses to serve to a direct request simply fails.

## Architecture
- `Zalla/VideoSaver.swift` (Foundation only, tested in `VideoSaverTests.swift`): URL classification, candidate list rules (dedupe, cap of 6), message parsing, HLS playlist parsing and protection detection, the page script, the user facing messages, and the Settings switch key `videoSaverEnabled`.
- `BrowserTab` (`BrowserStore.swift`): registers the `zallaVideo` message handler, injects the script on http and https pages while the switch is on, keeps `videoCandidates` and `videoProtected` (cleared on each new page commit), and `saveVideo(_:)` starts the download through `WKWebView.startDownload(using:)`, handing it to the normal download manager.
- `Zalla/VideoSaverViews.swift`: the Menu row (`VideoSaverMenuRow`, lock and Unlock sheet when locked) and the page list (`VideoSaverView`) with per row status read from the downloads list.
- Gating: `VideoSaver.isAvailable(unlocked:enabled:)`. Detection runs while the switch is on so a locked person sees the row with a lock. Saving needs Zalla Unlock.

## Roadmap
1. HLS to MP4 for clear (non-encrypted), finished (VOD) streams: pick the best variant from a master playlist, download the segments with `URLSession`, and mux to MP4 with AVFoundation (`AVAssetExportSession` on a local playlist, or `AVMutableComposition`). Progress by segment count. Still no encrypted streams.
2. A clear-only DASH path, only if there is a real need. Encrypted or live manifests stay out.
3. Real byte progress in the download manager (it shows a spinner today) and a small pill on the page.
4. Save to Photos directly from the download row.
