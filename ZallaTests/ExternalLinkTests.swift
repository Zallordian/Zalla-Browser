import WebKit
import XCTest
@testable import Zalla

/// Build 50: which links stay in the browser, which ask before opening an app, and which are dropped.
final class ExternalLinkTests: XCTestCase {
    private func url(_ string: String) -> URL {
        URL(string: string)!
    }

    private func tapped(
        _ string: String,
        activation: ExternalLinkActivation = .user,
        fresh: Bool = true,
        settled: Bool = true,
        promptAllowed: Bool = true
    ) -> ExternalLinkContext {
        ExternalLinkContext(
            url: url(string),
            activation: activation,
            gestureFresh: fresh,
            gestureSettled: settled,
            promptAllowed: promptAllowed
        )
    }

    private func prompt(for string: String, activation: ExternalLinkActivation = .user) -> ExternalLinkPrompt {
        let decision = ExternalLinks.decision(for: tapped(string, activation: activation))
        guard case .prompt(let prompt) = decision else {
            XCTFail("expected a prompt for \(string), got \(decision)")
            return ExternalLinkPrompt(url: url(string), title: "", confirmTitle: "")
        }
        return prompt
    }

    func testSchemeClassification() {
        XCTAssertEqual(ExternalLinks.kind(of: url("tel:1")), .phone)
        XCTAssertEqual(ExternalLinks.kind(of: url("TEL:1")), .phone)
        XCTAssertEqual(ExternalLinks.kind(of: url("telprompt:1")), .phone)
        XCTAssertEqual(ExternalLinks.kind(of: url("sms:1")), .messages)
        XCTAssertEqual(ExternalLinks.kind(of: url("mailto:a@b.c")), .mail)
        XCTAssertEqual(ExternalLinks.kind(of: url("facetime:1")), .faceTime)
        XCTAssertEqual(ExternalLinks.kind(of: url("facetime-audio:1")), .faceTime)
        XCTAssertEqual(ExternalLinks.kind(of: url("maps://q")), .maps)
        XCTAssertEqual(ExternalLinks.kind(of: url("itms-apps://apps.apple.com/app/id1")), .appStore)
        XCTAssertEqual(ExternalLinks.kind(of: url("https://apps.apple.com/app/id1")), .appStorePage)
        XCTAssertEqual(ExternalLinks.kind(of: url("https://www.youtube.com/watch?v=1")), .web)
        XCTAssertEqual(ExternalLinks.kind(of: url("https://maps.google.com/maps?q=1")), .web)
        XCTAssertEqual(ExternalLinks.kind(of: url("blob:https://example.com/abc")), .blob)
        XCTAssertEqual(ExternalLinks.kind(of: url("data:text/plain,hi")), .data)
        XCTAssertEqual(ExternalLinks.kind(of: url("javascript:void(0)")), .javaScript)
        XCTAssertEqual(ExternalLinks.kind(of: url("about:blank")), .document)
        XCTAssertEqual(ExternalLinks.kind(of: url("file:///tmp/a")), .blocked)
        XCTAssertEqual(ExternalLinks.kind(of: url("zalla://search")), .blocked)
        XCTAssertEqual(ExternalLinks.kind(of: url("spotify:track:1")), .app(name: "Spotify"))
        guard case .intent(let fallback) = ExternalLinks.kind(of: url(
            "intent://x/#Intent;S.browser_fallback_url=https%3A%2F%2Fexample.com%2Fgo;end"
        )) else { return XCTFail("intent should be its own kind") }
        XCTAssertEqual(fallback?.host, "example.com")
        XCTAssertEqual(fallback?.path, "/go")
    }

    func testATapInsideAFrameCanStillCall() {
        var context = tapped("tel:5550199", activation: .script)
        context.isMainFrame = false
        context.sourceIsMainFrame = false
        context.targetIsMainFrame = false
        guard case .prompt(let prompt) = ExternalLinks.decision(for: context) else {
            return XCTFail("a call link tapped inside a frame should ask")
        }
        XCTAssertEqual(prompt.confirmTitle, "Call")
    }

    // MARK: Phone, mail, maps, App Store

    func testGoogleStyleCallAsksToCall() {
        // Google fires tel: from a script in the moment after the tap, not as a plain link.
        let prompt = prompt(for: "tel:+1-555-0100", activation: .script)
        XCTAssertEqual(prompt.title, "Call +1-555-0100?")
        XCTAssertEqual(prompt.confirmTitle, "Call")
        XCTAssertEqual(prompt.url.scheme, "tel")
    }

    func testPhoneSchemesFromATapOrAScript() {
        for scheme in ["tel:5551234", "telprompt:5551234", "telprompt://+1-555-0100"] {
            for activation in [ExternalLinkActivation.user, .script] {
                let prompt = prompt(for: scheme, activation: activation)
                XCTAssertEqual(prompt.confirmTitle, "Call", scheme)
                XCTAssertTrue(prompt.title.hasPrefix("Call "), scheme)
            }
        }
    }

    func testNewWindowStillAsksInsteadOfOpeningABlankTab() {
        var context = tapped("tel:+15551212")
        context.hasTargetFrame = false
        guard case .prompt(let prompt) = ExternalLinks.decision(for: context) else {
            return XCTFail("a tel: link aimed at a new window should ask")
        }
        XCTAssertEqual(prompt.confirmTitle, "Call")
    }

    func testKnownAppsAskWithCancelAndOpen() {
        XCTAssertEqual(prompt(for: "sms:+15551212").title, "Open in Messages?")
        XCTAssertEqual(prompt(for: "mailto:ada@example.com").title, "Open in Mail?")
        XCTAssertEqual(prompt(for: "facetime:+15551212").title, "Open in FaceTime?")
        XCTAssertEqual(prompt(for: "facetime-audio:ada@example.com").title, "Open in FaceTime?")
        XCTAssertEqual(prompt(for: "maps://?q=coffee").title, "Open in Maps?")
        XCTAssertEqual(prompt(for: "itms-apps://apps.apple.com/app/id1").title, "Open in the App Store?")
        XCTAssertEqual(prompt(for: "itms://itunes.apple.com/app/id1").title, "Open in the App Store?")
        XCTAssertEqual(prompt(for: "itmss://apps.apple.com/app/id1").title, "Open in the App Store?")
        XCTAssertEqual(prompt(for: "itms-appss://apps.apple.com/app/id1").title, "Open in the App Store?")
        for string in ["sms:+15551212", "mailto:ada@example.com", "maps://?q=coffee", "itms-apps://apps.apple.com/app/id1"] {
            XCTAssertEqual(prompt(for: string).confirmTitle, "Open", string)
        }
    }

    func testAppStoreWebLinksAskOnlyAfterATap() {
        let pages = [
            "https://apps.apple.com/us/app/id123",
            "https://itunes.apple.com/app/id123",
            "https://geo.itunes.apple.com/app/id123",
            "https://apps.apple.com.cn/app/id123",
            "https://www.apps.apple.com/app/id123",
            "https://appsto.re/us/abc"
        ]
        for string in pages {
            guard case .prompt(let prompt) = ExternalLinks.decision(for: tapped(string)) else {
                return XCTFail("expected an App Store prompt for \(string)")
            }
            XCTAssertEqual(prompt.title, "Open in the App Store?", string)
            // No tap: show the page, the same as any other site.
            XCTAssertEqual(
                ExternalLinks.decision(for: tapped(string, activation: .script, fresh: false, settled: true)),
                .allow,
                string
            )
        }
    }

    func testUniversalLinksStayInTheBrowser() {
        let pages = [
            "https://www.youtube.com/watch?v=abc",
            "https://maps.google.com/maps?q=coffee",
            "https://maps.apple.com/?q=coffee",
            "https://music.apple.com/us/album/id1",
            "https://example.com/app"
        ]
        for string in pages {
            XCTAssertEqual(ExternalLinks.kind(of: url(string)), .web, string)
            XCTAssertEqual(ExternalLinks.decision(for: tapped(string)), .allow, string)
            XCTAssertEqual(ExternalLinks.decision(for: tapped(string, activation: .script)), .allow, string)
        }
    }

    func testCustomSchemesUseTheAppName() {
        XCTAssertEqual(prompt(for: "spotify:track:1").title, "Open in Spotify?")
        XCTAssertEqual(prompt(for: "youtube://watch?v=abc").title, "Open in YouTube?")
        XCTAssertEqual(prompt(for: "comgooglemaps://?q=coffee").title, "Open in Google Maps?")
        XCTAssertEqual(prompt(for: "myapp://open").title, "Open in Myapp?")
        XCTAssertEqual(prompt(for: "com.example.app://open").title, "Open in another app?")
        XCTAssertEqual(ExternalLinks.displayName(for: "otpauth"), "your authenticator")
    }

    func testUnsafePhoneTextIsNotShown() {
        XCTAssertEqual(prompt(for: "tel:").title, "Call this number?")
        XCTAssertEqual(prompt(for: "tel:Please%20call%20your%20bank").title, "Call this number?")
        XCTAssertEqual(prompt(for: "tel:555%0AYour%20bank").title, "Call this number?")
        let encoded = "tel:+1%20(555)%20010-0999"
        XCTAssertEqual(prompt(for: encoded).title, "Call +1 (555) 010-0999?")
    }

    func testCopyHasNoDashes() {
        let samples = [
            "tel:+1-555-0100", "sms:+1555", "mailto:a@b.c", "facetime:a@b.c", "facetime-audio:+1555",
            "maps://?q=1", "itms-apps://apps.apple.com/app/id1", "spotify:track:1",
            "com.example.app://x", "myapp://x", "https://apps.apple.com/app/id1"
        ]
        for string in samples {
            let prompt = prompt(for: string)
            XCTAssertFalse(prompt.title.contains("\u{2014}") || prompt.title.contains("\u{2013}"), prompt.title)
            XCTAssertFalse(prompt.confirmTitle.contains("\u{2014}"), prompt.confirmTitle)
            XCTAssertTrue(prompt.title.hasSuffix("?"))
            XCTAssertTrue(prompt.confirmTitle == "Call" || prompt.confirmTitle == "Open")
        }
        XCTAssertFalse(ExternalLinks.gestureScript.contains("\u{2014}"))
        XCTAssertFalse("Couldn't open that app.".contains("\u{2014}"))
    }

    // MARK: Gesture required

    func testAPageAloneCannotOpenAnApp() {
        XCTAssertEqual(
            ExternalLinks.decision(for: tapped("tel:5551234", activation: .script, fresh: false, settled: true)),
            .cancel
        )
        XCTAssertEqual(
            ExternalLinks.decision(for: tapped("spotify:track:1", activation: .script, fresh: false, settled: true)),
            .cancel
        )
        XCTAssertEqual(
            ExternalLinks.decision(for: tapped("maps://?q=1", activation: .history, fresh: true, settled: true)),
            .cancel
        )
    }

    func testSyntheticClickWaitsThenDrops() {
        // A script can make a link look tapped. Without a real tap note, the first look waits and the second drops it.
        XCTAssertEqual(
            ExternalLinks.decision(for: tapped("tel:5551234", fresh: false, settled: false)),
            .wait
        )
        XCTAssertEqual(
            ExternalLinks.decision(for: tapped("tel:5551234", fresh: false, settled: true)),
            .cancel
        )
    }

    func testScriptRightAfterATapCanLeave() {
        XCTAssertEqual(
            ExternalLinks.decision(for: tapped("mailto:a@b.c", activation: .script, fresh: true)).confirmTitle,
            "Open"
        )
    }

    func testRepeatedPromptsAreBlocked() {
        var context = tapped("tel:5551234")
        context.promptAllowed = false
        XCTAssertEqual(ExternalLinks.decision(for: context), .cancel)
        // Still waiting on the tap note, but a prompt is already up, so do not wait.
        context.gestureFresh = false
        context.gestureSettled = false
        XCTAssertEqual(ExternalLinks.decision(for: context), .cancel)
    }

    func testGestureClockConsumesTheTapAndThenRequiresAClick() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let clock = ExternalGestureClock()
        XCTAssertFalse(clock.isFresh(at: start))
        clock.note(.touch, at: start)
        XCTAssertTrue(clock.isFresh(at: start.addingTimeInterval(1)))
        XCTAssertFalse(clock.isFresh(at: start.addingTimeInterval(1.6)))
        XCTAssertTrue(clock.allowsPrompt(at: start))
        clock.didShow(at: start.addingTimeInterval(0.2))
        XCTAssertFalse(clock.allowsPrompt(at: start.addingTimeInterval(0.3)))
        XCTAssertFalse(clock.isFresh(at: start.addingTimeInterval(0.3)))
        clock.note(.click, at: start.addingTimeInterval(0.4))
        XCTAssertTrue(clock.isFresh(at: start.addingTimeInterval(0.4)))
        clock.didDismiss(at: start.addingTimeInterval(0.5))
        XCTAssertFalse(clock.allowsPrompt(at: start.addingTimeInterval(0.6)))
        XCTAssertTrue(clock.allowsPrompt(at: start.addingTimeInterval(1.6)))
        // A scroll is a finger going down. After the first answer that is not enough.
        clock.note(.touch, at: start.addingTimeInterval(2))
        XCTAssertFalse(clock.isFresh(at: start.addingTimeInterval(2)))
        clock.note(.click, at: start.addingTimeInterval(2.2))
        XCTAssertTrue(clock.isFresh(at: start.addingTimeInterval(2.2)))
    }

    func testATouchDoesNotEraseAClick() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let clock = ExternalGestureClock()
        clock.note(.click, at: start)
        clock.note(.touch, at: start.addingTimeInterval(0.2))
        clock.didDismiss(at: start.addingTimeInterval(0.3))
        XCTAssertTrue(clock.isFresh(at: start.addingTimeInterval(0.3)))
    }

    func testGestureMessageAndScript() {
        XCTAssertEqual(ExternalLinks.gestureKind(from: "click"), .click)
        XCTAssertEqual(ExternalLinks.gestureKind(from: "touch"), .touch)
        XCTAssertNil(ExternalLinks.gestureKind(from: "nope"))
        XCTAssertNil(ExternalLinks.gestureKind(from: 1))
        XCTAssertTrue(ExternalLinks.gestureScript.contains("isTrusted"))
        XCTAssertTrue(ExternalLinks.gestureScript.contains("messageHandlers.\(ExternalLinks.gestureMessageName)"))
        XCTAssertTrue(ExternalLinks.gestureScript.contains("pointerdown"))
        XCTAssertTrue(ExternalLinks.gestureScript.contains("click"))
    }

    func testNavigationTypes() {
        XCTAssertEqual(ExternalLinks.activation(for: .linkActivated), .user)
        XCTAssertEqual(ExternalLinks.activation(for: .formSubmitted), .user)
        XCTAssertEqual(ExternalLinks.activation(for: .other), .script)
        XCTAssertEqual(ExternalLinks.activation(for: .backForward), .history)
        XCTAssertEqual(ExternalLinks.activation(for: .reload), .history)
        XCTAssertEqual(ExternalLinks.activation(for: .formResubmitted), .history)
    }

    // MARK: Android intent links

    func testIntentFallsBackToItsWebPage() {
        let raw = "intent://scan/#Intent;scheme=zxing;package=com.google.zxing.client.android;S.browser_fallback_url=https%3A%2F%2Fexample.com%2Fscan;end"
        guard case .load(let fallback) = ExternalLinks.decision(for: tapped(raw)) else {
            return XCTFail("expected the fallback page")
        }
        XCTAssertEqual(fallback.scheme, "https")
        XCTAssertEqual(fallback.host, "example.com")
        XCTAssertEqual(fallback.path, "/scan")
    }

    func testIntentKeepsTheFallbackQuery() {
        let raw = "intent://maps.google.com/maps#Intent;scheme=https;package=com.google.android.apps.maps;S.browser_fallback_url=https%3A%2F%2Fmaps.google.com%2Fmaps%3Fq%3Dcoffee;end"
        guard case .load(let fallback) = ExternalLinks.decision(for: tapped(raw, activation: .script)) else {
            return XCTFail("expected the fallback page")
        }
        XCTAssertEqual(fallback.host, "maps.google.com")
        XCTAssertEqual(fallback.query, "q=coffee")
    }

    func testIntentWithoutASafeFallbackIsDropped() {
        let samples = [
            "intent://scan/#Intent;scheme=zxing;package=com.example;end",
            "intent://scan/#Intent;scheme=zxing;S.browser_fallback_url=javascript:alert(1);end",
            "intent://scan/#Intent;scheme=zxing;S.browser_fallback_url=spotify:track:1;end",
            "intent://scan/#Intent;scheme=zxing;S.browser_fallback_url=file:///etc/passwd;end"
        ]
        for string in samples {
            XCTAssertEqual(
                ExternalLinks.decision(for: tapped(string, fresh: true, settled: true)),
                .cancel,
                string
            )
        }
    }

    func testIntentWithoutATapDoesNotNavigate() {
        let raw = "intent://scan/#Intent;S.browser_fallback_url=https%3A%2F%2Fexample.com%2Fa;end"
        XCTAssertEqual(
            ExternalLinks.decision(for: tapped(raw, activation: .script, fresh: false, settled: false)),
            .wait
        )
        XCTAssertEqual(
            ExternalLinks.decision(for: tapped(raw, activation: .script, fresh: false, settled: true)),
            .cancel
        )
    }

    // MARK: In-page links

    func testSamePageAnchorsAreNotANewLoad() {
        XCTAssertTrue(ExternalLinks.isSameDocument(
            from: url("https://example.com/guide"),
            to: url("https://example.com/guide#setup"),
            method: "GET",
            hasTargetFrame: true
        ))
        XCTAssertTrue(ExternalLinks.isSameDocument(
            from: url("https://Example.com"),
            to: url("https://example.com/#top"),
            method: "GET",
            hasTargetFrame: true
        ))
        XCTAssertTrue(ExternalLinks.isSameDocument(
            from: url("https://example.com:443/a"),
            to: url("https://example.com/a#b"),
            method: "GET",
            hasTargetFrame: true
        ))
        var context = ExternalLinkContext(
            url: url("https://example.com/guide?utm_source=x#setup"),
            currentURL: url("https://example.com/guide?utm_source=x"),
            activation: .user,
            gestureFresh: true,
            gestureSettled: true
        )
        XCTAssertEqual(ExternalLinks.decision(for: context), .allow)
        context.hasTargetFrame = false
        XCTAssertEqual(ExternalLinks.decision(for: context), .allow)
        XCTAssertFalse(ExternalLinks.isSameDocument(
            from: context.currentURL, to: context.url, method: "GET", hasTargetFrame: false
        ))
    }

    func testADifferentPageIsNotTheSameDocument() {
        XCTAssertFalse(ExternalLinks.isSameDocument(
            from: url("https://example.com/a"),
            to: url("https://example.com/b"),
            method: "GET",
            hasTargetFrame: true
        ))
        XCTAssertFalse(ExternalLinks.isSameDocument(
            from: url("https://example.com/a?x=1"),
            to: url("https://example.com/a?x=2"),
            method: "GET",
            hasTargetFrame: true
        ))
        XCTAssertFalse(ExternalLinks.isSameDocument(
            from: url("https://example.com/a"),
            to: url("https://example.com/a"),
            method: "POST",
            hasTargetFrame: true
        ))
    }

    func testDownloadLinksDownloadAndFramesCanUseBlob() {
        var download = tapped("https://example.com/report.pdf")
        download.wantsDownload = true
        XCTAssertEqual(ExternalLinks.decision(for: download), .download)

        var blob = tapped("blob:https://example.com/1234")
        XCTAssertEqual(ExternalLinks.decision(for: blob), .download)
        blob.isMainFrame = false
        XCTAssertEqual(ExternalLinks.decision(for: blob), .allow)
        blob.wantsDownload = true
        XCTAssertEqual(ExternalLinks.decision(for: blob), .download)
    }

    func testJavaScriptLinksRunOnlyForTheFrameThatWasTapped() {
        var link = tapped("javascript:void(0)")
        XCTAssertEqual(ExternalLinks.decision(for: link), .allow)
        link.hasTargetFrame = false
        XCTAssertEqual(ExternalLinks.decision(for: link), .cancel)
        link.hasTargetFrame = true
        link.sourceIsMainFrame = false
        link.targetIsMainFrame = true
        XCTAssertEqual(ExternalLinks.decision(for: link), .cancel)
        link.targetIsMainFrame = false
        XCTAssertEqual(ExternalLinks.decision(for: link), .allow)
        XCTAssertEqual(
            ExternalLinks.decision(for: tapped("javascript:void(0)", activation: .script, fresh: false, settled: true)),
            .cancel
        )
    }

    func testBlockedSchemesNeverLeave() {
        XCTAssertEqual(ExternalLinks.decision(for: tapped("file:///etc/passwd")), .cancel)
        XCTAssertEqual(ExternalLinks.decision(for: tapped("zalla://search")), .cancel)
        XCTAssertEqual(ExternalLinks.kind(of: url("about:blank")), .document)
        XCTAssertEqual(ExternalLinks.decision(for: tapped("about:blank")), .allow)
    }
}

private extension ExternalLinkDecision {
    var confirmTitle: String? {
        if case .prompt(let prompt) = self { return prompt.confirmTitle }
        return nil
    }
}
