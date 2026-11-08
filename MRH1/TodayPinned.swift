import SwiftUI

// v1.3 Today pinned chrome (DESIGN_SPEC_v1.3 §2, §4): the compact gauge bar that takes over from the big
// rings once they scroll away, and the "Today | Week" switch bar. Both are drawn twice: once in the
// scroll content (the switch) and once in an opaque overlay at the top of the screen (the pinned copy),
// so pinning never changes layout or makes the content jump. Pinned stack = 52 + 56 = 108 pt (≤ 112).

/// Which half of Today is showing under the switch.
enum TodaySegment: String, CaseIterable, Hashable {
    case today, week
    var title: String { self == .today ? "Today" : "Week" }
}

/// Recovery tier, same cut-offs everywhere on Today (≥ 67 in range, ≥ 34 watch, else out of range).
func todayRecoveryTier(_ score: Int?) -> StatusTier? {
    guard let s = score else { return nil }
    return s >= 67 ? .inRange : (s >= 34 ? .watch : .outOfRange)
}

enum TodayPinned {
    /// Compact gauge row: 4 above, 44 row (36 pt rings), 4 below.
    static let compactHeight: CGFloat = 52
    /// Switch bar: `Space.xs` above, 44 pt switch, `Space.s` below.
    static let switchHeight: CGFloat = Space.xs + 44 + Space.s
}

// MARK: - Switch bar ("Today | Week", 44 pt, opaque paper)

struct TodaySwitchBar: View {
    @Binding var segment: TodaySegment

    var body: some View {
        // PillPicker buttons are 36 pt + 2 × 4 pt padding = a 44 pt control.
        PillPicker(selection: $segment, options: TodaySegment.allCases) { $0.title }
            .frame(minHeight: 44)
            .padding(.top, Space.xs)
            .padding(.bottom, Space.s)
            .padding(.horizontal, Space.gutter)
            .frame(maxWidth: .infinity)
            .background(Theme.paper)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Today or week")
    }
}

// MARK: - Compact gauge bar (Sleep · Recovery · Strain, 36 pt rings)

struct CompactGaugeBar: View {
    @Environment(HealthStore.self) private var health

    var body: some View {
        let rec = health.recovery?.score
        let tier = todayRecoveryTier(rec)
        HStack(spacing: Space.s) {
            gauge(.sleep, title: "Sleep",
                  value: health.sleepScore.map(String.init), unit: "",
                  progress: Double(health.sleepScore ?? 0) / 100, color: Theme.iris,
                  spoken: health.sleepScore.map { "\($0) out of 100" })
            gauge(.recovery, title: "Recovery",
                  value: rec.map(String.init), unit: rec == nil ? "" : "%",
                  progress: Double(rec ?? 0) / 100, color: tier?.fill ?? Theme.hair,
                  spoken: rec.map { "\($0) percent, \(tier?.word ?? "")" })
            gauge(.strain, title: "Strain",
                  value: health.strain.map { String(format: "%.1f", locale: .current, $0.value) }, unit: "",
                  progress: (health.strain?.value ?? 0) / 21, color: Theme.ember,
                  spoken: health.strain.map { String(format: "%.1f out of 21", locale: .current, $0.value) })
        }
        .padding(.horizontal, Space.gutter)
        .padding(.vertical, Space.xs)
        .frame(height: TodayPinned.compactHeight)
    }

    private func gauge(_ kind: ScoreKind, title: String, value: String?, unit: String, progress: Double,
                       color: Color, spoken: String?) -> some View {
        NavigationLink(value: Route.score(kind)) {
            HStack(spacing: Space.s) {
                TickRing(progress: progress, color: color, size: 36, ticks: 24, animateOnAppear: false) {
                    Color.clear
                }
                .frame(width: 36, height: 36)
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .firstTextBaseline, spacing: 1) {
                        Text(value ?? "—")
                            .typo(.headline)
                            .monospacedDigit()
                            .foregroundStyle(value == nil ? Theme.graphite : Theme.ink)
                            .contentTransition(.numericText())
                        if !unit.isEmpty { Text(unit).typo(.caption).foregroundStyle(Theme.ink2) }
                    }
                    Text(title).typo(.micro).foregroundStyle(Theme.ink2)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .center)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(spoken ?? "No reading")
        .accessibilityHint(kind == .recovery ? "Shows what drove it" : "Shows details")
    }
}

// MARK: - Pinned stack (overlay at the top of Today)

/// `progress` 0…1 morphs the gauge bar in (scale + opacity; opacity only under Reduce Motion).
/// `switchPinned` shows the switch copy right under it once the in-content switch reaches that line.
struct TodayPinnedStack: View {
    let progress: Double
    let switchPinned: Bool
    @Binding var segment: TodaySegment
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let p = max(0, min(progress, 1))
        VStack(spacing: 0) {
            CompactGaugeBar()
                .opacity(p)
                .scaleEffect(reduceMotion ? 1 : 0.92 + 0.08 * p, anchor: .top)
                .offset(y: reduceMotion ? 0 : -6 * (1 - p))
                .allowsHitTesting(p > 0.5)
                .accessibilityHidden(p < 0.5)
            if switchPinned {
                TodaySwitchBar(segment: $segment)
            }
        }
        .background(alignment: .top) {
            // Opaque paper from the very top of the screen (status bar / Dynamic Island) down, so cards
            // never show through behind the clock and the orb never sits under the small rings.
            Theme.paper
                .opacity(switchPinned ? 1 : p)
                .ignoresSafeArea(edges: .top)
        }
    }
}
