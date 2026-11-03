import SwiftUI
import UIKit

/// MRH1 v1 "Riso Paper" palette (DESIGN_SPEC §2). Every colour adapts to light / dark.
/// No blue anywhere. Status colours (good / limit / danger) mean results only.
enum Theme {
    // MARK: Neutrals (warm, low chroma)
    static let paper     = Color(light: 0xEDEBE7, dark: 0x151413)
    static let card      = Color(light: 0xFAF9F7, dark: 0x1F1D1B)
    static let ink       = Color(light: 0x151413, dark: 0xF2EFEA)
    /// Secondary text. 5.4:1 on card (light), 7.5:1 (dark).
    static let graphite  = Color(light: 0x6B665F, dark: 0xB4AEA7)
    /// Non-text only: ticks, disabled, empty tracks.
    static let graphite2 = Color(light: 0xA8A39C, dark: 0x5E5953)
    static let hair      = Color(light: 0xDFDBD5, dark: 0x2E2B28)

    // MARK: Brand
    /// Fills only, never small text.
    static let ember    = Color(light: 0xF0582A, dark: 0xF0582A)
    /// Ember when it must be text (5.3:1 light).
    static let emberInk = Color(light: 0xB83F17, dark: 0xFF8A5C)
    static let peach    = Color(light: 0xF3A79E, dark: 0xE39A90)
    /// Sleep / night series only.
    static let iris     = Color(light: 0x8B88F0, dark: 0x9D9AF5)

    // MARK: Status (results only)
    static let good       = Color(light: 0x2F9D68, dark: 0x3DB27A)
    static let goodBg     = Color(light: 0xDDF0E4, dark: 0x2F9D68, darkAlpha: 0.18)
    static let goodText   = Color(light: 0x1F6E47, dark: 0x8FDAB3)
    static let limit      = Color(light: 0xE6B820, dark: 0xE6B820)
    static let limitBg    = Color(light: 0xFBF0C8, dark: 0xE6B820, darkAlpha: 0.18)
    static let limitText  = Color(light: 0x7A5D05, dark: 0xF2D374)
    static let danger     = Color(light: 0xD23A3A, dark: 0xE05252)
    static let dangerBg   = Color(light: 0xF8DCD8, dark: 0xD23A3A, darkAlpha: 0.18)
    static let dangerText = Color(light: 0xA92C2C, dark: 0xF2A39C)

    // MARK: Sleep stages
    static let stageDeep  = Color(light: 0x4B4880, dark: 0x6D69B8)
    static let stageCore  = Color(light: 0xC9B8A6, dark: 0x8C7E70)
    static let stageREM   = iris
    static let stageAwake = Color(light: 0xD23A3A, dark: 0xE05252, alpha: 0.6)

    // MARK: Helpers
    /// Personal-normal band in charts and ribbons (ink 10 %).
    static let bandFill = Color(light: 0x151413, dark: 0xF2EFEA, alpha: 0.10)
    /// Darker secondary text step between ink and graphite (not in the 9 tokens; alias support only).
    static let ink2 = Color(light: 0x3E3A36, dark: 0xB4AEA7)

    // MARK: v0.4 aliases (keep until every view migrates)
    static let background = paper
    static let cardRaised = card
    static let inset = paper
    static let line = hair
    static let text2 = ink2
    static let text3 = graphite

    static let recovery = good
    static let recoveryTrack = hair
    static let strain = ember
    static let strainTrack = hair
    static let sleep = iris
    static let sleepTrack = hair

    static let warn = limit
    static let low = limit
    static let bad = danger

    static let heart = ember
    static let lungs = graphite
    static let activity = ember

    static let stageLight = stageCore

    static let band = bandFill
    static let bandEdge = graphite2
}

// MARK: - Spacing / radius tokens

/// 4 · 8 · 12 · 16 · 20 · 24 · 32 · 48 only.
enum Space {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let gutter: CGFloat = 20
    static let xl: CGFloat = 24
    static let section: CGFloat = 32
    static let xxl: CGFloat = 48
    /// Aliases for readability.
    static let cardPadding: CGFloat = 20
    static let cardGap: CGFloat = 12
}

/// card 28 · inner 16 · chip 8 · capsule.
enum Radius {
    static let card: CGFloat = 28
    static let inner: CGFloat = 16
    static let chip: CGFloat = 8
    /// Chart bars: 2 pt top radius.
    static let bar: CGFloat = 2
}

// MARK: - Status tiers

/// The only three result words: In range · Watch · Out of range.
enum StatusTier: Hashable {
    case inRange, watch, outOfRange

    var word: String {
        switch self {
        case .inRange: return "In range"
        case .watch: return "Watch"
        case .outOfRange: return "Out of range"
        }
    }
    var fill: Color {
        switch self {
        case .inRange: return Theme.good
        case .watch: return Theme.limit
        case .outOfRange: return Theme.danger
        }
    }
    var chipColors: (bg: Color, text: Color) {
        switch self {
        case .inRange: return (Theme.goodBg, Theme.goodText)
        case .watch: return (Theme.limitBg, Theme.limitText)
        case .outOfRange: return (Theme.dangerBg, Theme.dangerText)
        }
    }
}

extension Flag {
    /// Chip background / text pair (both pass 4.5:1).
    var chipColors: (bg: Color, text: Color) {
        switch self {
        case .normal: return StatusTier.inRange.chipColors
        case .high, .low: return StatusTier.watch.chipColors
        case .none: return (Theme.hair, Theme.graphite)
        }
    }
    /// Default tier for a bare flag (no severity info): normal → In range, high/low → Watch.
    var statusTier: StatusTier? {
        switch self {
        case .normal: return .inRange
        case .high, .low: return .watch
        case .none: return nil
        }
    }
}

extension MetricState {
    /// How far the latest value sits outside the band, in SDs (0 inside).
    var bandDistance: Double {
        guard let v = latest?.value, let b = band else { return 0 }
        let sd = baseline?.sd ?? max((b.upperBound - b.lowerBound) / 2, 0.0001)
        if v > b.upperBound { return (v - b.upperBound) / sd }
        if v < b.lowerBound { return (b.lowerBound - v) / sd }
        return 0
    }
    /// Direction-aware tier: better-than-usual stays In range; concerns are Watch,
    /// or Out of range when more than one SD beyond the band edge.
    var statusTier: StatusTier? {
        guard hasData else { return nil }
        if flag == .normal || !isConcern { return .inRange }
        return bandDistance > 1 ? .outOfRange : .watch
    }
}

// MARK: - Colour helpers

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }

    /// Adaptive colour from two hex values.
    init(light: UInt32, dark: UInt32, alpha: CGFloat = 1, darkAlpha: CGFloat? = nil) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(hex: dark, alpha: darkAlpha ?? alpha)
                : UIColor(hex: light, alpha: alpha)
        })
    }

    /// Adaptive colour from two colours.
    init(light: Color, dark: Color) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: alpha)
    }
}
