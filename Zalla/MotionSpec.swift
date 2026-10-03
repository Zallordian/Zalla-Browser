import Foundation

/// The kinds of everyday motion in Zalla. Each one has one timing, in one place, so the app moves the same way
/// everywhere and the feel can be tuned here. Foundation only, so the rules can be tested without SwiftUI.
enum MotionKind: CaseIterable {
    /// A bar or a control group changing shape or position: the address bar expanding, buttons sliding away.
    case bar
    /// A page of content swapping inside a sheet, such as the Settings categories.
    case sheet
    /// A card or a row moving: the tab grid, a card springing back after a swipe.
    case card
    /// A selection indicator moving between choices.
    case indicator
    /// A small lively change: a selected swatch, a symbol swap, a bubble appearing.
    case pop
    /// A plain cross fade.
    case fade
    /// A progress value easing toward its next value.
    case progress
    /// A freshly committed web page easing in.
    case page
}

/// One timing: a spring (response and damping) or an ease (duration).
struct MotionSpec: Equatable {
    enum Style: Equatable {
        case spring
        case easeOut
        case easeInOut
    }

    let style: Style
    /// The spring response, or the duration of an ease, in seconds.
    let time: Double
    /// The spring damping fraction. 1 for the eases.
    let damping: Double

    /// The timing for a kind, or nil when nothing should animate. With Reduce Motion on, only the plain fade is
    /// left, shortened. Every other kind returns nil so the change simply happens.
    static func spec(for kind: MotionKind, reduceMotion: Bool) -> MotionSpec? {
        if reduceMotion {
            return kind == .fade ? MotionSpec(style: .easeOut, time: 0.12, damping: 1) : nil
        }
        switch kind {
        case .bar: return MotionSpec(style: .spring, time: 0.35, damping: 0.85)
        case .sheet: return MotionSpec(style: .spring, time: 0.42, damping: 0.9)
        case .card: return MotionSpec(style: .spring, time: 0.38, damping: 0.82)
        case .indicator: return MotionSpec(style: .spring, time: 0.32, damping: 0.8)
        case .pop: return MotionSpec(style: .spring, time: 0.3, damping: 0.62)
        case .fade: return MotionSpec(style: .easeOut, time: 0.18, damping: 1)
        case .progress: return MotionSpec(style: .easeOut, time: 0.25, damping: 1)
        case .page: return MotionSpec(style: .easeOut, time: 0.2, damping: 1)
        }
    }

    /// The opacity a page starts at when it commits, before it eases to fully visible.
    static let pageStartAlpha = 0.9
}

/// Swiping a tab card away in the tab grid.
enum CardSwipe {
    /// Sideways or upward travel that closes a card.
    static let closeDistance = 80.0
    /// A flick whose predicted end passes this closes the card even when the finger moved less.
    static let flingDistance = 200.0
    /// Travel before the card starts to follow the finger.
    static let startDistance = 24.0

    /// How far the card moves for a drag. Left follows the finger. Right only gives a little, like a rubber band.
    static func followOffset(translation: Double) -> Double {
        translation <= 0 ? translation : translation * 0.2
    }

    /// 0 at rest to 1 at the close distance, for fading the card as it goes.
    static func progress(translation: Double) -> Double {
        min(max(-translation / closeDistance, 0), 1)
    }

    /// Whether a finished drag closes the card: far enough left or up, or a quick flick to the left.
    static func shouldClose(translationX: Double, translationY: Double, predictedX: Double) -> Bool {
        if translationX < -closeDistance || translationY < -closeDistance { return true }
        return predictedX < -flingDistance && translationX < -startDistance
    }
}
