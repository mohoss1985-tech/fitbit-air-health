import SwiftUI
import UIKit

/// The 9 type roles (DESIGN_SPEC §2). No Light/Thin weights anywhere. Every role scales with
/// Dynamic Type relative to a system text style; all numerals are tabular.
enum Typo {
    /// 56 semibold rounded, the one hero number per screen.
    static var display: Font  { make(56, .semibold, rounded: true, relativeTo: .largeTitle) }
    /// 28/34 semibold, screen titles.
    static var title: Font    { make(28, .semibold, relativeTo: .title1) }
    /// 34 semibold rounded, card numbers.
    static var metric: Font   { make(34, .semibold, rounded: true, relativeTo: .largeTitle) }
    /// 17 semibold, card titles.
    static var headline: Font { make(17, .semibold, relativeTo: .headline) }
    /// 15 regular, sentences.
    static var body: Font     { make(15, .regular, relativeTo: .subheadline) }
    /// 13 medium, row labels, chips, segmented controls.
    static var label: Font    { make(13, .medium, relativeTo: .footnote) }
    /// 12 regular, units, timestamps, axis labels.
    static var caption: Font  { make(12, .regular, relativeTo: .caption1) }
    /// 11 medium, the minimum size anywhere.
    static var micro: Font    { make(11, .medium, relativeTo: .caption2) }
    /// 12 medium SF Mono. Live "latest sample N min ago" ticker and raw timestamps only.
    static var mono: Font     { make(12, .medium, mono: true, relativeTo: .caption1) }

    /// Tracking per role, in points (em × size).
    enum Role { case display, title, metric, headline, body, label, caption, micro, mono }

    static func font(_ r: Role) -> Font {
        switch r {
        case .display: return display
        case .title: return title
        case .metric: return metric
        case .headline: return headline
        case .body: return body
        case .label: return label
        case .caption: return caption
        case .micro: return micro
        case .mono: return mono
        }
    }

    static func tracking(_ r: Role) -> CGFloat {
        switch r {
        case .display: return -0.04 * 56
        case .title: return -0.02 * 28
        case .metric: return -0.03 * 34
        case .headline: return -0.01 * 17
        default: return 0
        }
    }

    private static func make(_ size: CGFloat, _ weight: UIFont.Weight, rounded: Bool = false, mono: Bool = false,
                             relativeTo style: UIFont.TextStyle) -> Font {
        var ui: UIFont = mono
            ? .monospacedSystemFont(ofSize: size, weight: weight)
            : .systemFont(ofSize: size, weight: weight)
        if rounded, let d = ui.fontDescriptor.withDesign(.rounded) {
            ui = UIFont(descriptor: d, size: size)
        }
        let scaled = UIFontMetrics(forTextStyle: style).scaledFont(for: ui)
        let f = Font(scaled)
        return mono ? f : f.monospacedDigit()
    }
}

extension View {
    /// Applies a type role: font + tracking.
    func typo(_ role: Typo.Role) -> some View {
        font(Typo.font(role)).tracking(Typo.tracking(role))
    }

    /// Unit next to a number: caption, graphite.
    func unitStyle() -> some View {
        font(Typo.caption).foregroundStyle(Theme.graphite)
    }
}

/// Number + unit, baseline aligned with a 2 pt gap. "—" for missing values.
struct ValueText: View {
    enum Size { case display, metric, headline }

    let value: String
    var unit: String = ""
    var size: Size = .metric
    var color: Color = Theme.ink

    init(value: String, unit: String = "", size: Size = .metric, color: Color = Theme.ink) {
        self.value = value
        self.unit = unit
        self.size = size
        self.color = color
    }

    private var role: Typo.Role {
        switch size {
        case .display: return .display
        case .metric: return .metric
        case .headline: return .headline
        }
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text(value)
                .typo(role)
                .foregroundStyle(value == "—" ? Theme.graphite : color)
                .contentTransition(.numericText())
            if !unit.isEmpty && value != "—" {
                Text(unit).unitStyle()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(value == "—" ? "No value" : "\(value) \(unit)")
    }
}
