import XCTest
@testable import Zalla

final class BarLayoutTests: XCTestCase {
    func testKeyAndDefault() {
        XCTAssertEqual(BarLayout.storageKey, "bottomBarLayout")
        XCTAssertEqual(BarLayout.defaultLayout, .safari)
    }

    func testMigrationSafeDefault() {
        XCTAssertEqual(BarLayout.stored(nil), .safari)
        XCTAssertEqual(BarLayout.stored(""), .safari)
        XCTAssertEqual(BarLayout.stored("something old"), .safari)
        XCTAssertEqual(BarLayout.stored(BarLayout.classic.rawValue), .classic)
        XCTAssertEqual(BarLayout.stored(BarLayout.safari.rawValue), .safari)
    }

    func testUnsetDefaultsReadAsSafari() {
        let defaults = UserDefaults(suiteName: "BarLayoutTests")!
        defaults.removePersistentDomain(forName: "BarLayoutTests")
        XCTAssertEqual(BarLayout.stored(defaults.string(forKey: BarLayout.storageKey)), .safari)
    }

    func testSafariBarOnlyAtTheBottomAndNeverForQuickAction() {
        XCTAssertTrue(BarLayout.usesSafariBar(layout: .safari, style: .classic, placement: .bottom))
        XCTAssertTrue(BarLayout.usesSafariBar(layout: .safari, style: .compact, placement: .bottom))
        XCTAssertFalse(BarLayout.usesSafariBar(layout: .safari, style: .quickAction, placement: .bottom))
        XCTAssertFalse(BarLayout.usesSafariBar(layout: .safari, style: .classic, placement: .top))
        XCTAssertFalse(BarLayout.usesSafariBar(layout: .classic, style: .compact, placement: .bottom))
    }

    func testEditorEditsTheListSafariStyleShows() {
        XCTAssertEqual(BarLayout.editTarget(layout: .safari, style: .classic, placement: .bottom), .compact)
        XCTAssertEqual(BarLayout.editTarget(layout: .classic, style: .classic, placement: .bottom), .classic)
        XCTAssertEqual(BarLayout.editTarget(layout: .safari, style: .quickAction, placement: .bottom), .quickActionBar)
        XCTAssertEqual(BarLayout.editTarget(layout: .safari, style: .classic, placement: .top), .classic)
    }

    func testDefaultButtonsMatchSafariOrder() {
        XCTAssertEqual(ToolbarLayout.defaultCompact, [.back, .forward, .address, .tabs, .menu])
        let layout = ToolbarLayout.default
        XCTAssertEqual(layout.compactLeading, [.back, .forward])
        XCTAssertEqual(layout.compactTrailing, [.tabs, .menu])
    }

    func testMetricsAreSlimAndEven() {
        XCTAssertEqual(SafariBarMetrics.height, 48)
        XCTAssertLessThan(SafariBarMetrics.collapsedHeight, SafariBarMetrics.height)
        XCTAssertLessThanOrEqual(SafariBarMetrics.buttonSize, SafariBarMetrics.height)
        XCTAssertEqual(SafariBarMetrics.sideInset(screenWidth: 393), 32)
        XCTAssertEqual(SafariBarMetrics.opacity(enabled: true), 1)
        XCTAssertLessThan(SafariBarMetrics.opacity(enabled: false), 0.5)
        XCTAssertGreaterThan(SafariBarMetrics.springDamping, 0.7)
        XCTAssertLessThan(SafariBarMetrics.springDamping, 1)
    }

    func testRowAndCopy() {
        XCTAssertTrue(SettingsRowID.coveredKeys.contains(BarLayout.storageKey))
        XCTAssertEqual(SettingsRowID.barLayout.group, .toolbarAndTabs)
        for text in [BarLayout.settingsFooter, BarLayout.safari.title, BarLayout.classic.title] {
            XCTAssertFalse(text.contains("\u{2014}"))
            XCTAssertFalse(text.contains("\u{2013}"))
        }
    }
}

/// Build 43: Back and Forward leave the Safari style bar when there is nowhere to go.
final class SafariBarVisibilityTests: XCTestCase {
    private let defaults: [ToolbarItemKind] = [.back, .forward, .address, .tabs, .menu]

    func testFreshTabShowsNeitherBackNorForward() {
        XCTAssertEqual(SafariBarMetrics.visibleItems(defaults, canGoBack: false, canGoForward: false), [.address, .tabs, .menu])
    }

    func testOnlyBack() {
        XCTAssertEqual(SafariBarMetrics.visibleItems(defaults, canGoBack: true, canGoForward: false), [.back, .address, .tabs, .menu])
    }

    func testOnlyForward() {
        XCTAssertEqual(SafariBarMetrics.visibleItems(defaults, canGoBack: false, canGoForward: true), [.forward, .address, .tabs, .menu])
    }

    func testBoth() {
        XCTAssertEqual(SafariBarMetrics.visibleItems(defaults, canGoBack: true, canGoForward: true), defaults)
    }

    func testCustomButtonsAlwaysStayAndKeepOrder() {
        let custom: [ToolbarItemKind] = [.share, .back, .address, .forward, .burn, .menu]
        XCTAssertEqual(SafariBarMetrics.visibleItems(custom, canGoBack: false, canGoForward: false), [.share, .address, .burn, .menu])
    }

    func testSplitListsFromTheDefaultLayout() {
        let layout = ToolbarLayout.default
        XCTAssertEqual(SafariBarMetrics.visibleItems(layout.compactLeading, canGoBack: false, canGoForward: false), [])
        XCTAssertEqual(SafariBarMetrics.visibleItems(layout.compactTrailing, canGoBack: false, canGoForward: false), [.tabs, .menu])
    }

    func testHiddenScaleIsAShrinkNotAVanish() {
        XCTAssertGreaterThan(SafariBarMetrics.hiddenButtonScale, 0)
        XCTAssertLessThan(SafariBarMetrics.hiddenButtonScale, 1)
    }
}

final class LoadProgressTests: XCTestCase {
    func testSkipsTinySteps() {
        XCTAssertEqual(LoadProgress.published(current: 0.5, incoming: 0.51), 0.5)
        XCTAssertEqual(LoadProgress.published(current: 0.5, incoming: 0.55), 0.55)
    }

    func testStartAndFinishAlwaysLand() {
        XCTAssertEqual(LoadProgress.published(current: 0.99, incoming: 1.0), 1.0)
        XCTAssertEqual(LoadProgress.published(current: 0.7, incoming: 0), 0)
        XCTAssertEqual(LoadProgress.published(current: 0.7, incoming: 0.1), 0.1, "A new load starts over")
    }

    func testClamps() {
        XCTAssertEqual(LoadProgress.published(current: 0, incoming: 1.4), 1)
        XCTAssertEqual(LoadProgress.published(current: 0.3, incoming: -1), 0)
    }

    func testUpdatePublishesOnlyRealChanges() {
        let progress = LoadProgress()
        progress.update(0.3)
        XCTAssertEqual(progress.value, 0.3)
        progress.update(0.31)
        XCTAssertEqual(progress.value, 0.3)
        progress.update(1)
        XCTAssertEqual(progress.value, 1)
    }
}


/// Build 45: Safari's padding. The side inset never depends on how many buttons show.
final class SafariBarInsetTests: XCTestCase {
    func testSideInsetByScreenWidth() {
        XCTAssertEqual(SafariBarMetrics.sideInset(screenWidth: 393), 32)
        XCTAssertEqual(SafariBarMetrics.sideInset(screenWidth: 430), 32)
        XCTAssertEqual(SafariBarMetrics.sideInset(screenWidth: 375), 32)
        XCTAssertEqual(SafariBarMetrics.sideInset(screenWidth: 320), 27)
        XCTAssertEqual(SafariBarMetrics.sideInset(screenWidth: 200), 20, "Never under the floor")
        XCTAssertEqual(SafariBarMetrics.sideInset(screenWidth: 0), 32)
    }

    func testInsetIsTheSameForEveryButtonCount() {
        let lists: [[ToolbarItemKind]] = [
            [.back, .forward, .address, .tabs, .menu],
            [.address, .tabs, .menu],
            [.back, .address, .tabs, .menu],
            [.forward, .address, .menu],
            [.address, .menu],
            [.share, .back, .address, .burn, .downloads, .menu]
        ]
        for width in [320.0, 375.0, 393.0, 430.0] as [CGFloat] {
            let inset = SafariBarMetrics.sideInset(screenWidth: width)
            for list in lists {
                for back in [false, true] {
                    for forward in [false, true] {
                        let visible = SafariBarMetrics.visibleItems(list, canGoBack: back, canGoForward: forward)
                        let segments = SafariBarMetrics.segments(visible.filter { $0 != .address })
                        let pill = SafariBarMetrics.pillWidth(screenWidth: width, segments: segments)
                        let used = segments.reduce(CGFloat(0)) { $0 + SafariBarMetrics.width(of: $1) }
                            + CGFloat(segments.count) * SafariBarMetrics.spacing + pill
                        XCTAssertEqual(width - used, inset * 2, accuracy: 0.001, "\(list) back \(back) forward \(forward)")
                        XCTAssertEqual(SafariBarMetrics.sideInset(screenWidth: width), inset)
                    }
                }
            }
        }
    }

    func testPillTakesTheFreedSpace() {
        let both = SafariBarMetrics.segments([.back, .forward, .tabs, .menu])
        let none = SafariBarMetrics.segments([.tabs, .menu])
        let grow = SafariBarMetrics.pillWidth(screenWidth: 393, segments: none) - SafariBarMetrics.pillWidth(screenWidth: 393, segments: both)
        XCTAssertEqual(grow, SafariBarMetrics.navCapsuleWidth + SafariBarMetrics.spacing)
        // 393 - 64 inset - 92 capsule - 48 tabs - 48 more - 24 gaps
        XCTAssertEqual(SafariBarMetrics.pillWidth(screenWidth: 393, segments: both), 117)
    }

    func testSafariSizesAndBottomGap() {
        XCTAssertEqual(SafariBarMetrics.buttonSize, 48)
        XCTAssertEqual(SafariBarMetrics.height, 48)
        XCTAssertEqual(SafariBarMetrics.spacing, 8)
        XCTAssertEqual(SafariBarMetrics.navCapsuleWidth, 92)
        XCTAssertEqual(SafariBarMetrics.bottomInset(collapsed: false, homeIndicatorInset: 34), 19)
        XCTAssertEqual(SafariBarMetrics.bottomInset(collapsed: false, homeIndicatorInset: 0), 19)
        XCTAssertEqual(SafariBarMetrics.bottomInset(collapsed: true, homeIndicatorInset: 34), 34 + ScrollChrome.pillLift)
    }
}

/// Build 45: Back and Forward share one capsule.
final class NavCapsuleTests: XCTestCase {
    func testStates() {
        XCTAssertEqual(SafariBarMetrics.navCapsule(canGoBack: true, canGoForward: true), .both)
        XCTAssertEqual(SafariBarMetrics.navCapsule(canGoBack: true, canGoForward: false), .backOnly)
        XCTAssertEqual(SafariBarMetrics.navCapsule(canGoBack: false, canGoForward: true), .forwardOnly)
        XCTAssertEqual(SafariBarMetrics.navCapsule(canGoBack: false, canGoForward: false), .hidden)
        XCTAssertEqual(NavCapsuleState.both.width, 92)
        XCTAssertEqual(NavCapsuleState.backOnly.width, 48)
        XCTAssertEqual(NavCapsuleState.forwardOnly.width, 48)
        XCTAssertEqual(NavCapsuleState.hidden.width, 0)
    }

    func testSegmentsMergeNeighbors() {
        XCTAssertEqual(SafariBarMetrics.segments([.back, .forward]), [.nav([.back, .forward])])
        XCTAssertEqual(SafariBarMetrics.segments([.back]), [.nav([.back])])
        XCTAssertEqual(SafariBarMetrics.segments([.forward]), [.nav([.forward])])
        XCTAssertEqual(SafariBarMetrics.segments([]), [])
        XCTAssertEqual(SafariBarMetrics.segments([.tabs, .menu]), [.single(.tabs), .single(.menu)])
    }

    func testCapsuleWidthMatchesState() {
        for back in [false, true] {
            for forward in [false, true] {
                let visible = SafariBarMetrics.visibleItems([.back, .forward], canGoBack: back, canGoForward: forward)
                let width = SafariBarMetrics.segments(visible).reduce(CGFloat(0)) { $0 + SafariBarMetrics.width(of: $1) }
                XCTAssertEqual(width, SafariBarMetrics.navCapsule(canGoBack: back, canGoForward: forward).width)
            }
        }
    }

    func testOneCapsulePerListAndStableIDs() {
        let split = SafariBarMetrics.segments([.back, .share, .forward])
        XCTAssertEqual(split, [.nav([.back]), .single(.share), .single(.forward)])
        XCTAssertEqual(Set(split.map(\.id)).count, split.count)
        XCTAssertEqual(SafariBarSegment.nav([.back]).id, SafariBarSegment.nav([.back, .forward]).id)
        XCTAssertEqual(SafariBarSegment.nav([.forward]).id, SafariBarSegment.nav([.back, .forward]).id)
    }
}
