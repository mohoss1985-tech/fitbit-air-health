import SwiftUI

/// Motion tokens (DESIGN_SPEC §6, Emil Kowalski rules): few, short, interruptible.
enum Motion {
    /// Press feedback: scale 0.97, 160 ms ease-out.
    static let press: Animation = .easeOut(duration: 0.16)
    /// Element enter: cubic(0.23, 1, 0.32, 1), 220 ms, from scale 0.96 + opacity.
    static let enter: Animation = .timingCurve(0.23, 1, 0.32, 1, duration: 0.22)
    /// State morph: cubic(0.77, 0, 0.175, 1), 300 ms.
    static let morph: Animation = .timingCurve(0.77, 0, 0.175, 1, duration: 0.3)
    /// Range switch / data swap: crossfade only.
    static let crossfade: Animation = .easeInOut(duration: 0.2)
    /// Reduce Motion replacement: opacity-friendly short fade.
    static let reduced: Animation = .easeInOut(duration: 0.15)

    static let pressScale: CGFloat = 0.97
    static let enterScale: CGFloat = 0.96

    /// Picks the reduced animation when Reduce Motion is on.
    static func safe(_ anim: Animation, reduceMotion: Bool) -> Animation {
        reduceMotion ? reduced : anim
    }

    /// `withAnimation` that respects Reduce Motion (reads the system setting).
    @discardableResult
    static func animate<R>(_ anim: Animation, _ body: () throws -> R) rethrows -> R {
        try withAnimation(UIAccessibility.isReduceMotionEnabled ? reduced : anim, body)
    }
}

extension AnyTransition {
    /// Enter: scale 0.96 + opacity (opacity only under Reduce Motion via `motionSafe`).
    static var mrhEnter: AnyTransition {
        .scale(scale: Motion.enterScale).combined(with: .opacity)
    }
}

/// Buttons: scale 0.97 on press, 160 ms ease-out; opacity dip only under Reduce Motion.
struct PressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? Motion.pressScale : 1)
            .opacity(configuration.isPressed && reduceMotion ? 0.7 : 1)
            .animation(Motion.press, value: configuration.isPressed)
            .contentShape(Rectangle())
    }
}

extension ButtonStyle where Self == PressStyle {
    static var press: PressStyle { PressStyle() }
}

private struct MotionSafeModifier: ViewModifier {
    let anim: Animation
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.transaction { t in
            guard t.animation != nil, !t.disablesAnimations else { return }
            t.animation = reduceMotion ? Motion.reduced : anim
        }
    }
}

private struct MotionSafeValueModifier<V: Equatable>: ViewModifier {
    let anim: Animation
    let value: V
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? Motion.reduced : anim, value: value)
    }
}

extension View {
    /// Re-times any animated transaction in this subtree to `anim`, or to a short fade when
    /// Reduce Motion is on.
    func motionSafe(_ anim: Animation) -> some View {
        modifier(MotionSafeModifier(anim: anim))
    }

    /// `.animation(anim, value:)` that respects Reduce Motion.
    func motionSafe<V: Equatable>(_ anim: Animation, value: V) -> some View {
        modifier(MotionSafeValueModifier(anim: anim, value: value))
    }
}
