import Foundation
import SwiftUI
import UIKit

/// Measured network performance using public Cloudflare speed endpoints.
/// No third-party speed-test trademarks or partner branding.
enum NetworkSpeedEndpoints {
    /// Lightweight trace endpoint for latency samples.
    static let latencyURL = URL(string: "https://speed.cloudflare.com/cdn-cgi/trace")!
    /// Download payload endpoint. `bytes` controls transfer size.
    static func downloadURL(bytes: Int) -> URL {
        URL(string: "https://speed.cloudflare.com/__down?bytes=\(bytes)")!
    }
    /// Upload echo endpoint used by Cloudflare's public measurement tooling.
    static let uploadURL = URL(string: "https://speed.cloudflare.com/__up")!
}

enum NetworkSpeedPhase: String, Equatable {
    case idle
    case ping
    case download
    case upload
    case finished
    case failed
}

struct NetworkSpeedResult: Equatable {
    var latencyMs: Double?
    var downloadMbps: Double?
    var uploadMbps: Double?
    var errorMessage: String?
    var finishedAt: Date?
}

@MainActor
final class NetworkSpeedTester: ObservableObject {
    @Published private(set) var phase: NetworkSpeedPhase = .idle
    @Published private(set) var result = NetworkSpeedResult()
    @Published private(set) var liveMbps: Double = 0
    @Published private(set) var needleProgress: Double = 0

    private var runTask: Task<Void, Never>?

    var isRunning: Bool {
        switch phase {
        case .ping, .download, .upload: return true
        default: return false
        }
    }

    func start() {
        guard !isRunning else { return }
        runTask?.cancel()
        result = NetworkSpeedResult()
        liveMbps = 0
        needleProgress = 0
        runTask = Task { await runSuite() }
    }

    func cancel() {
        runTask?.cancel()
        runTask = nil
        if isRunning {
            phase = .failed
            result.errorMessage = "Test cancelled."
        }
    }

    private func runSuite() async {
        do {
            phase = .ping
            let latency = try await measureLatency(samples: 4)
            try Task.checkCancellation()
            result.latencyMs = latency
            animateNeedle(toward: min(latency / 200, 0.25))

            phase = .download
            let download = try await measureDownload(bytes: 12_500_000)
            try Task.checkCancellation()
            result.downloadMbps = download
            liveMbps = download
            animateNeedle(toward: needleFraction(mbps: download))

            phase = .upload
            let upload = try await measureUpload(bytes: 4_000_000)
            try Task.checkCancellation()
            result.uploadMbps = upload
            liveMbps = upload
            animateNeedle(toward: needleFraction(mbps: max(download, upload)))

            phase = .finished
            result.finishedAt = Date()
            result.errorMessage = nil
        } catch is CancellationError {
            phase = .failed
            if result.errorMessage == nil {
                result.errorMessage = "Test cancelled."
            }
        } catch {
            phase = .failed
            result.errorMessage = friendlyError(error)
            liveMbps = 0
        }
    }

    private func measureLatency(samples: Int) async throws -> Double {
        var values: [Double] = []
        values.reserveCapacity(samples)
        for _ in 0..<samples {
            try Task.checkCancellation()
            let start = Date()
            var request = URLRequest(url: NetworkSpeedEndpoints.latencyURL, timeoutInterval: 12)
            request.httpMethod = "GET"
            request.cachePolicy = .reloadIgnoringLocalCacheData
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<400).contains(http.statusCode) else {
                throw URLError(.badServerResponse)
            }
            values.append(Date().timeIntervalSince(start) * 1000)
        }
        guard !values.isEmpty else { throw URLError(.cannotConnectToHost) }
        return values.reduce(0, +) / Double(values.count)
    }

    private func measureDownload(bytes: Int) async throws -> Double {
        let url = NetworkSpeedEndpoints.downloadURL(bytes: bytes)
        var request = URLRequest(url: url, timeoutInterval: 60)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let start = Date()
        let (data, response) = try await URLSession.shared.data(for: request)
        let elapsed = max(Date().timeIntervalSince(start), 0.001)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let bits = Double(data.count) * 8.0
        let mbps = bits / elapsed / 1_000_000
        liveMbps = mbps
        return mbps
    }

    private func measureUpload(bytes: Int) async throws -> Double {
        let payload = Data(count: bytes)
        var request = URLRequest(url: NetworkSpeedEndpoints.uploadURL, timeoutInterval: 60)
        request.httpMethod = "POST"
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.httpBody = payload
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let start = Date()
        let (_, response) = try await URLSession.shared.data(for: request)
        let elapsed = max(Date().timeIntervalSince(start), 0.001)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let bits = Double(bytes) * 8.0
        let mbps = bits / elapsed / 1_000_000
        liveMbps = mbps
        return mbps
    }

    private func needleFraction(mbps: Double) -> Double {
        // Log-ish mapping so typical home speeds fill the arc usefully.
        let clamped = max(0, min(mbps, 1000))
        return min(1, log10(clamped + 1) / log10(1001))
    }

    private func animateNeedle(toward value: Double) {
        withAnimation(.easeInOut(duration: 0.55)) {
            needleProgress = max(0, min(1, value))
        }
    }

    private func friendlyError(_ error: Error) -> String {
        let ns = error as NSError
        if ns.domain == NSURLErrorDomain {
            switch ns.code {
            case NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost:
                return "You appear to be offline. Check your connection and try again."
            case NSURLErrorTimedOut:
                return "The measurement timed out. Try again on a more stable connection."
            default:
                break
            }
        }
        return "Could not finish the measurement. \(error.localizedDescription)"
    }
}

struct NetworkSpeedView: View {
    @StateObject private var tester = NetworkSpeedTester()
    @AppStorage("themeID") private var themeID = ZallaThemeID.zallaRed.rawValue
    @AppStorage("useCustomAccent") private var useCustomAccent = false
    @AppStorage("customAccentHex") private var customAccentHex = "E33B4F"

    private var theme: ZallaTheme {
        ZallaTheme.resolved(themeID: themeID, useCustom: useCustomAccent, customHex: customAccentHex)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                speedometer
                metrics
                controls
                Text("Zalla measures latency, download, and upload against public Cloudflare endpoints. Results stay on this device.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(24)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Network Speed")
        .navigationBarTitleDisplayMode(.inline)
        .tint(theme.primary)
        .onDisappear { tester.cancel() }
    }

    private var speedometer: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.08), lineWidth: 18)
                .frame(width: 220, height: 220)
            Circle()
                .trim(from: 0.12, to: 0.12 + 0.76 * tester.needleProgress)
                .stroke(
                    AngularGradient(
                        colors: [theme.deep, theme.primary, theme.bright],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 18, lineCap: .round)
                )
                .rotationEffect(.degrees(90))
                .frame(width: 220, height: 220)
            VStack(spacing: 4) {
                Text(primaryReadout)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(theme.primary)
                Text(phaseLabel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(phaseLabel), \(primaryReadout)")
    }

    private var primaryReadout: String {
        switch tester.phase {
        case .ping:
            if let ms = tester.result.latencyMs {
                return String(format: "%.0f ms", ms)
            }
            return "…"
        case .download, .upload:
            return String(format: "%.1f Mbps", tester.liveMbps)
        case .finished:
            if let down = tester.result.downloadMbps {
                return String(format: "%.1f Mbps", down)
            }
            return "Done"
        case .failed:
            return "-"
        case .idle:
            return "Ready"
        }
    }

    private var phaseLabel: String {
        switch tester.phase {
        case .idle: return "Tap Start to measure"
        case .ping: return "Measuring latency"
        case .download: return "Measuring download"
        case .upload: return "Measuring upload"
        case .finished: return "Finished"
        case .failed: return "Could not finish"
        }
    }

    private var metrics: some View {
        HStack(spacing: 12) {
            metricCard(title: "Ping", value: formatMs(tester.result.latencyMs))
            metricCard(title: "Download", value: formatMbps(tester.result.downloadMbps))
            metricCard(title: "Upload", value: formatMbps(tester.result.uploadMbps))
        }
    }

    private func metricCard(title: String, value: String) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var controls: some View {
        VStack(spacing: 12) {
            Button {
                tester.start()
            } label: {
                Text(tester.phase == .finished || tester.phase == .failed ? "Retest" : "Start")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .disabled(tester.isRunning)

            if tester.isRunning {
                Button("Cancel", role: .cancel) { tester.cancel() }
            }

            if let message = tester.result.errorMessage, tester.phase == .failed {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private func formatMs(_ value: Double?) -> String {
        guard let value else { return "-" }
        return String(format: "%.0f ms", value)
    }

    private func formatMbps(_ value: Double?) -> String {
        guard let value else { return "-" }
        return String(format: "%.1f", value)
    }
}
