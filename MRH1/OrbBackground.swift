import SwiftUI

/// Printed grain/halftone orbs for the Today and Live headers (DESIGN_SPEC §3).
///
///     OrbBackground(tier: recoveryTier, evening: isEvening)            // Today
///     OrbBackground(status: flag, evening: isEvening, pulse: live.pulse) // Live
///         .frame(height: 420).ignoresSafeArea(edges: .top)
///
/// * 3 orbs (ember, peach, iris) with a solid 70 % core and a halftone-dot fringe, mixed in
///   OKLab over paper; static grain; dither. A 4th small orb carries the status tint.
/// * The orbs dissolve into the page background over the bottom of the view (or by 1× width,
///   whichever comes first), so the view can be any height — nothing sits behind cards.
/// * `evening`: dusk palette (iris up, ember down). Dark appearance: ink base, orbs trimmed
///   (ember 0.48, peach 0.34, iris 0.22) so light text keeps >= 4.5:1.
/// * `pulse`: each increment bumps the ember radius +3 %, decaying over 500 ms (Live).
/// * 30 fps cap; paused off-screen, in background and under Reduce Motion (frozen frame).
struct OrbBackground: View {
    var status: Flag?
    /// Preferred over `status` when set: carries the red "Out of range" level.
    var tier: StatusTier?
    var evening: Bool
    var pulse: Int = 0

    init(status: Flag?, evening: Bool, pulse: Int = 0) {
        self.status = status
        self.tier = nil
        self.evening = evening
        self.pulse = pulse
    }

    /// Today passes Recovery's tier: inRange → green, watch → yellow, outOfRange → red, nil → none.
    init(tier: StatusTier?, evening: Bool, pulse: Int = 0) {
        self.status = nil
        self.tier = tier
        self.evening = evening
        self.pulse = pulse
    }

    private var tint: StatusTint { tier.map(StatusTint.init(tier:)) ?? StatusTint(status) }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.displayScale) private var displayScale
    @Environment(\.colorScheme) private var colorScheme

    @State private var statusFrom: StatusTint = .none
    @State private var morphStart = Date.distantPast
    @State private var pulseAt = Date.distantPast
    @State private var onScreen = true
    @State private var appeared = false

    private static let epoch = Date()
    private static let frozenTime: Double = 9      // a balanced composition for Reduce Motion
    private static let morph: TimeInterval = 1.2
    private static let pulseDecay: TimeInterval = 0.5

    private var paused: Bool {
        reduceMotion || !onScreen || !appeared || scenePhase == .background
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: paused)) { context in
            let now = context.date
            Rectangle()
                .colorEffect(shader(at: now))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear { appeared = true }
        .onDisappear { appeared = false }
        .onGeometryChange(for: Bool.self) { proxy in
            let f = proxy.frame(in: .global)
            return f.maxY > 0 && f.height > 0
        } action: { visible in
            onScreen = visible
        }
        .onChange(of: tint) { old, new in
            statusFrom = reduceMotion ? new : old
            morphStart = reduceMotion ? .distantPast : Date()
        }
        .onChange(of: pulse) { _, _ in
            if !reduceMotion { pulseAt = Date() }
        }
    }

    // MARK: shader inputs

    private func shader(at now: Date) -> Shader {
        let night = colorScheme == .dark
        let time = reduceMotion
            ? Self.frozenTime
            : Self.frozenTime + now.timeIntervalSince(Self.epoch).truncatingRemainder(dividingBy: 10_000)

        // Pulse: +3 % ember radius, ease-out decay over 500 ms.
        let pk = min(max(now.timeIntervalSince(pulseAt) / Self.pulseDecay, 0), 1)
        let bump = 0.03 * pow(1 - pk, 2)

        // Status orb: OKLab morph over 1.2 s, cubic(0.77,0,0.175,1)-like.
        let target = tint
        let mk = min(max(now.timeIntervalSince(morphStart) / Self.morph, 0), 1)
        let e = Float(mk < 0.5 ? 4 * mk * mk * mk : 1 - pow(-2 * mk + 2, 3) / 2)
        let fromLab = statusFrom == .none ? target.lab : statusFrom.lab
        let toLab = target == .none ? statusFrom.lab : target.lab
        let statusLab = OKLab.mix(fromLab, toLab, e)
        let statusA = statusFrom.alpha + (target.alpha - statusFrom.alpha) * e

        // Dark: spec says 0.55 / iris 0.6, trimmed so light ink text keeps >= 4.5:1 over every orb.
        var emberA: Float = night ? 0.48 : 1.0
        var peachA: Float = night ? 0.34 : 0.9
        var irisA: Float = night ? 0.22 : 0.35
        if evening && !night { emberA = 0.85; peachA = 0.8; irisA = 0.6 }

        let day = Calendar.current.ordinality(of: .day, in: .era, for: now) ?? 1   // grain reseeds daily
        return ShaderLibrary.mrhOrbs(
            .boundingRect,
            .float(Float(time)),
            .float(Float(displayScale)),
            .float(Float(day % 9973)),
            (night ? GfxTokens.base : GfxTokens.paper).arg,
            GfxTokens.ember.arg, GfxTokens.peach.arg, GfxTokens.iris.arg,
            statusLab.arg,
            .float4(emberA, peachA, irisA, statusA * (night ? 0.8 : 1)),
            .float(Float(1 + bump)),
            .float(night ? 0.03 : 0.04),
            .float(1)
        )
    }
}

/// Status tint for the 4th orb (green / yellow / red = status only).
private enum StatusTint: Equatable {
    case none, good, limit, danger

    init(tier: StatusTier) {
        switch tier {
        case .inRange: self = .good
        case .watch: self = .limit
        case .outOfRange: self = .danger
        }
    }

    init(_ flag: Flag?) {
        guard let flag else { self = .none; return }
        if flag == .normal { self = .good }
        else if flag == .high || flag == .low { self = .limit }
        else { self = .none }
    }

    var lab: OKLab {
        switch self {
        case .none, .good: return GfxTokens.good
        case .limit: return GfxTokens.limit
        case .danger: return GfxTokens.danger
        }
    }

    var alpha: Float { self == .none ? 0 : 0.5 }
}
