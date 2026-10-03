import SwiftUI

/// SwiftUI side of the shared motion timings in `MotionSpec.swift`. Use `Motion.animation`, `withMotion`, or the
/// `.motion(_:value:)` modifier instead of picking numbers at the call site.
enum Motion {
    /// The animation for a kind, or nil when it should not animate (Reduce Motion).
    static func animation(_ kind: MotionKind, reduceMotion: Bool) -> Animation? {
        guard let spec = MotionSpec.spec(for: kind, reduceMotion: reduceMotion) else { return nil }
        switch spec.style {
        case .spring: return .spring(response: spec.time, dampingFraction: spec.damping)
        case .easeOut: return .easeOut(duration: spec.time)
        case .easeInOut: return .easeInOut(duration: spec.time)
        }
    }
}

/// `withAnimation` with a named motion kind. Does not animate when the kind is off for Reduce Motion.
func withMotion<Result>(_ kind: MotionKind, reduceMotion: Bool, _ body: () throws -> Result) rethrows -> Result {
    try withAnimation(Motion.animation(kind, reduceMotion: reduceMotion), body)
}

private struct MotionModifier<Value: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let kind: MotionKind
    let value: Value

    func body(content: Content) -> some View {
        content.animation(Motion.animation(kind, reduceMotion: reduceMotion), value: value)
    }
}

/// Fades a view in the first time it appears.
private struct FadeInOnAppear: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .onAppear { withMotion(.fade, reduceMotion: reduceMotion) { shown = true } }
    }
}

extension View {
    /// Animates changes caused by `value` with a named, Reduce Motion aware timing. Scope it to the smallest view
    /// that should move so unrelated layout does not animate.
    func motion<Value: Equatable>(_ kind: MotionKind, value: Value) -> some View {
        modifier(MotionModifier(kind: kind, value: value))
    }

    /// Fades the view in when it first appears.
    func fadesInOnAppear() -> some View {
        modifier(FadeInOnAppear())
    }
}
