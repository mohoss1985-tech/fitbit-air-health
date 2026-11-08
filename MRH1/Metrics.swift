import Foundation
import SwiftUI

// MARK: - Flags

enum Flag {
    case normal, high, low, none

    /// Status colour. No blue: a low reading uses the same "watch" yellow as a high one.
    var color: Color {
        switch self {
        case .normal: return Theme.recovery
        case .high, .low: return Theme.warn
        case .none: return Theme.text3
        }
    }

    /// Display word for a bare flag (no direction or severity): In range · Watch · Out of range tiers.
    /// For a metric, prefer `MetricState.statusWord`, which is direction-aware and knows severity.
    var word: String {
        switch self {
        case .normal: return "In range"
        case .high, .low: return "Watch"
        case .none: return "—"
        }
    }

    /// Direction in plain words (replaces the v0.4 "blue = below" colour code).
    var directionWord: String {
        switch self {
        case .normal: return "Within your usual range"
        case .high: return "Above your usual range"
        case .low: return "Below your usual range"
        case .none: return "No reading"
        }
    }

    /// Short arrow-free direction label for chips and legends: "Above" / "Below" / "Usual".
    var shortDirection: String {
        switch self {
        case .normal: return "Usual"
        case .high: return "Above"
        case .low: return "Below"
        case .none: return "—"
        }
    }
}

// MARK: - Missing data

/// The three explicit missing states (DESIGN_SPEC §5). Never show a zero or a blank tile.
enum MissingState: Hashable {
    /// Google Health never writes this type to Apple Health (HRV, skin temperature, VO2 max).
    case notSent
    /// The type normally arrives but the latest value has not synced yet.
    case waiting
    /// Nothing recorded (e.g. band not worn).
    case noReading

    var text: String {
        switch self {
        case .notSent: return "Not sent by Google Health"
        case .waiting: return "Waiting for sync"
        case .noReading: return "No reading"
        }
    }

    /// Short form for tight rows.
    var shortText: String {
        switch self {
        case .notSent: return "Not sent"
        case .waiting: return "Waiting for sync"
        case .noReading: return "No reading"
        }
    }
}

// MARK: - Panels

enum Panel: String, CaseIterable, Identifiable {
    case heart, lungs, sleep, activity

    var id: String { rawValue }

    var title: String {
        switch self {
        case .heart: return "Heart"
        case .lungs: return "Lungs, oxygen & temp"
        case .sleep: return "Sleep"
        case .activity: return "Activity & load"
        }
    }

    var short: String {
        switch self {
        case .heart: return "Heart"
        case .lungs: return "Lungs"
        case .sleep: return "Sleep"
        case .activity: return "Activity"
        }
    }

    var tint: Color {
        switch self {
        case .heart: return Theme.heart
        case .lungs: return Theme.lungs
        case .sleep: return Theme.sleep
        case .activity: return Theme.activity
        }
    }

    var metrics: [MetricID] {
        MetricID.allCases.filter { $0.info.panel == self }
    }
}

// MARK: - Metric definitions

struct MetricInfo {
    let name: String
    let sub: String
    let unit: String
    let typicalText: String
    let typical: ClosedRange<Double>?
    let floorSD: Double
    let what: String
    let ifHigh: String
    let ifLow: String
    let panel: Panel
}

enum MetricID: String, CaseIterable, Identifiable {
    case restingHR, hrv, sleepingHR
    case breathing, spo2, skinTemp
    case sleepTotal, deepSleep, remSleep, awake
    case steps, energy, workoutMinutes

    var id: String { rawValue }

    var info: MetricInfo {
        switch self {
        case .restingHR:
            return MetricInfo(
                name: "Resting heart rate", sub: "RHR · beats per minute at rest", unit: "bpm",
                typicalText: "60 – 100 bpm (fit people often lower)", typical: 45...85, floorSD: 2,
                what: "Your lowest steady heart rate, measured while you sleep. Fit people often sit lower, which is normal for them.",
                ifHigh: "5+ bpm above your usual: stress, alcohol, heat, dehydration or a coming illness.",
                ifLow: "Usually a sign of good fitness. See a doctor only if it comes with dizziness or fainting.",
                panel: .heart)
        case .hrv:
            return MetricInfo(
                name: "Heart rate variability", sub: "HRV · variation between heartbeats, in ms", unit: "ms",
                typicalText: "Very personal (20 – 100 ms)", typical: nil, floorSD: 4,
                what: "The tiny differences in time between heartbeats. Higher means your nervous system is relaxed and recovered. Only compare it with yourself.",
                ifHigh: "Well rested and recovered.",
                ifLow: "Stress, short sleep, alcohol, illness or overtraining.",
                panel: .heart)
        case .sleepingHR:
            return MetricInfo(
                name: "Heart rate during sleep", sub: "Average while asleep last night", unit: "bpm",
                typicalText: "50 – 75 bpm", typical: 45...78, floorSD: 2,
                what: "Your average heart rate across the night. It should sit close to your resting heart rate.",
                ifHigh: "Late meal, alcohol, a warm room or illness.",
                ifLow: "Deep, calm sleep.",
                panel: .heart)
        case .breathing:
            return MetricInfo(
                name: "Breathing rate", sub: "Breaths per minute while asleep", unit: "/min",
                typicalText: "12 – 20 /min", typical: 12...20, floorSD: 0.6,
                what: "How many breaths you take per minute during sleep. It barely changes from night to night, so a jump is meaningful.",
                ifHigh: "+1 or more above your usual can appear a day or two before you feel ill. Also alcohol or heat.",
                ifLow: "Rarely a concern on its own.",
                panel: .lungs)
        case .spo2:
            return MetricInfo(
                name: "Blood oxygen", sub: "SpO2 · oxygen saturation in your blood", unit: "%",
                typicalText: "95 – 100 %", typical: 95...100, floorSD: 0.8,
                what: "The share of your red blood cells carrying oxygen, estimated with red and infrared light through the skin.",
                ifHigh: "Nothing to worry about.",
                ifLow: "Repeated nights under 93 % can mean breathing pauses in sleep or altitude. Under 90 %: see a doctor.",
                panel: .lungs)
        case .skinTemp:
            return MetricInfo(
                name: "Skin temperature", sub: "Change vs your usual night, in °C", unit: "°C",
                typicalText: "within ±0.5 °C of your usual", typical: -0.5...0.5, floorSD: 0.25,
                what: "Not your body temperature: the difference between last night and your normal night, measured at the wrist.",
                ifHigh: "Over +1 °C: fever, illness, alcohol, a warm room or the cycle phase after ovulation.",
                ifLow: "Usually a cold room or less bedding.",
                panel: .lungs)
        case .sleepTotal:
            return MetricInfo(
                name: "Total sleep", sub: "Time actually asleep", unit: "",
                typicalText: "7 – 9 h", typical: 420...540, floorSD: 30,
                what: "Time asleep, not counting awake moments in bed.",
                ifHigh: "Fine after hard days or short nights. Often over 9 – 10 h with tiredness is worth checking.",
                ifLow: "Under 7 h builds sleep debt and lowers tomorrow’s recovery.",
                panel: .sleep)
        case .deepSleep:
            return MetricInfo(
                name: "Deep sleep", sub: "Slow-wave sleep · body repair", unit: "",
                typicalText: "10 – 20 % of the night (≈ 45 – 110 min)", typical: 45...110, floorSD: 10,
                what: "The deepest stage, when your body repairs muscle and your immune system works hardest. Mostly in the first half of the night.",
                ifHigh: "Your body caught up after a hard day or short nights.",
                ifLow: "Alcohol, late caffeine or a late meal often cut it.",
                panel: .sleep)
        case .remSleep:
            return MetricInfo(
                name: "REM sleep", sub: "Rapid eye movement · the dreaming stage", unit: "",
                typicalText: "20 – 25 % of the night (≈ 75 – 130 min)", typical: 75...135, floorSD: 12,
                what: "The dreaming stage, important for memory and mood. Longer in the second half of the night.",
                ifHigh: "Common after a sleep debt (rebound).",
                ifLow: "Alcohol and short nights cut REM first.",
                panel: .sleep)
        case .awake:
            return MetricInfo(
                name: "Awake during the night", sub: "Wake-ups after falling asleep", unit: "",
                typicalText: "under 30 – 60 min", typical: 0...60, floorSD: 8,
                what: "Total time awake between falling asleep and getting up. Short wake-ups are normal; you rarely remember them.",
                ifHigh: "Noise, light, heat, alcohol, stress or needing the toilet.",
                ifLow: "Unbroken sleep.",
                panel: .sleep)
        case .steps:
            return MetricInfo(
                name: "Steps", sub: "Yesterday, full day", unit: "steps",
                typicalText: "7 000 – 10 000 a day", typical: 7000...14000, floorSD: 1500,
                what: "Daily steps, from the Fitbit Air and your iPhone combined (Apple Health removes double counting).",
                ifHigh: "Great for long-term health.",
                ifLow: "Under 5 000 a day for weeks is linked to poorer health.",
                panel: .activity)
        case .energy:
            return MetricInfo(
                name: "Active energy", sub: "Calories burned by moving, yesterday", unit: "kcal",
                typicalText: "Depends on body size and activity", typical: nil, floorSD: 120,
                what: "Calories burned by movement and exercise, on top of what your body burns at rest.",
                ifHigh: "A very active day.",
                ifLow: "A quiet day.",
                panel: .activity)
        case .workoutMinutes:
            return MetricInfo(
                name: "Workout time", sub: "Recorded workouts, last 7 days", unit: "min",
                typicalText: "150+ min a week of moderate effort", typical: 150...600, floorSD: 30,
                what: "Total time of your workouts in the last 7 days. Walks count as steps, and auto-detected sessions count only when your heart rate shows real effort.",
                ifHigh: "A big training week: watch your recovery.",
                ifLow: "An easy week. Aim for 150+ minutes a week.",
                panel: .activity)
        }
    }

    /// Types Google Health does not write into Apple Health (show "Not sent", never zero).
    var isNotSentByGoogle: Bool { self == .hrv || self == .skinTemp }

    /// Nightly metrics should have a value dated today once last night has synced.
    var isNightly: Bool {
        switch self {
        case .restingHR, .hrv, .sleepingHR, .breathing, .spo2, .skinTemp,
             .sleepTotal, .deepSleep, .remSleep, .awake: return true
        case .steps, .energy, .workoutMinutes: return false
        }
    }

    func format(_ v: Double) -> String {
        switch self {
        case .sleepTotal, .deepSleep, .remSleep, .awake:
            let m = Int(v.rounded())
            return m >= 60 ? "\(m / 60) h \(String(format: "%02d", locale: .current, m % 60))" : "\(m) min"
        case .steps, .energy:
            return Int(v.rounded()).formatted(.number.grouping(.automatic))
        case .breathing:
            return String(format: "%.1f", locale: .current, v)
        case .spo2:
            return String(format: "%.1f", locale: .current, v)
        case .skinTemp:
            return (v >= 0 ? "+" : "−") + String(format: "%.1f", locale: .current, abs(v))
        default:
            return String(format: "%.0f", locale: .current, v)
        }
    }
}

// MARK: - Values and baselines

struct DayValue: Identifiable, Hashable {
    let date: Date
    let value: Double
    var id: Date { date }
}

struct Baseline {
    let mean: Double
    let sd: Double
    var low: Double { mean - sd }
    var high: Double { mean + sd }
}

struct MetricState: Identifiable {
    let id: MetricID
    let series: [DayValue]
    let latest: DayValue?
    let baseline: Baseline?
    let flag: Flag

    var hasData: Bool { latest != nil }

    /// Outside your range in the direction that matters (e.g. high resting HR, low HRV).
    /// A high step count or long sleep is outside the range but good news, not a concern.
    var isConcern: Bool {
        guard hasData, flag == .high || flag == .low else { return false }
        guard let higherIsBetter = Insights.direction(id) else { return true }
        return (flag == .high) != higherIsBetter
    }

    /// Days of history behind the baseline (the latest value is not counted).
    var baselineDays: Int { max(series.count - 1, 0) }

    /// Days needed before flags are meaningful (PROJECT_NOTES: ~14).
    static let fullBaselineDays = 14

    /// "Early read: 6 of 14 baseline days." while the baseline is still young, else nil.
    var earlyReadText: String? {
        guard hasData, baselineDays < Self.fullBaselineDays else { return nil }
        return "Early read: \(baselineDays) of \(Self.fullBaselineDays) baseline days."
    }

    /// Why there is no value, or nil when there is one that is current.
    /// `.waiting` = a nightly value exists but is older than today.
    var missing: MissingState? {
        if !hasData { return id.isNotSentByGoogle ? .notSent : .noReading }
        if id.isNightly, let d = latest?.date, !Calendar.current.isDateInToday(d),
           !(Calendar.current.isDateInYesterday(d) && id == .restingHR) {
            return .waiting
        }
        return nil
    }

    /// Value text, or the short missing-state text instead of a zero/blank.
    var displayText: String { hasData ? valueText : (missing?.shortText ?? "—") }

    /// Flag for a status chip: better-than-usual is shown as `.normal` (stays green).
    var chipFlag: Flag {
        guard hasData else { return .none }
        return isConcern ? flag : (flag == .none ? .none : .normal)
    }

    /// Direction-aware status word: "In range", "Watch" or "Out of range" ("—" without data).
    var statusWord: String { statusTier?.word ?? "—" }

    /// Plain direction sentence for legends/accessibility, e.g. "Above your usual range".
    var directionText: String { hasData ? flag.directionWord : (missing?.text ?? "No reading") }

    /// Green when in range or better than usual, yellow when it is a concern (never blue).
    var color: Color {
        if !hasData { return Theme.text3 }
        if flag == .normal || !isConcern { return Theme.recovery }
        return flag.color
    }

    var valueText: String { latest.map { id.format($0.value) } ?? "—" }

    /// Range used for the dashed band: personal baseline if known, else the typical adult range.
    var band: ClosedRange<Double>? {
        if let b = baseline { return b.low...b.high }
        return id.info.typical
    }

    var yourRangeText: String {
        guard let b = baseline else { return "Learning your range (needs 3+ nights)" }
        if id == .skinTemp { return "±" + String(format: "%.1f", locale: .current, b.sd) + " °C" }
        return id.format(b.low) + " – " + id.format(b.high) + (id.info.unit.isEmpty ? "" : " " + id.info.unit)
    }

    var spark: [Double] { series.suffix(7).map(\.value) }

    static func make(_ id: MetricID, series raw: [DayValue]) -> MetricState {
        var series = raw.sorted { $0.date < $1.date }
        // Skin temperature: show the change versus your own average.
        if id == .skinTemp, series.count >= 2 {
            let hist = series.dropLast().map(\.value)
            let mean = hist.reduce(0, +) / Double(hist.count)
            series = series.map { DayValue(date: $0.date, value: $0.value - mean) }
        }
        let latest = series.last
        let history = series.dropLast().map(\.value)
        var baseline: Baseline?
        if history.count >= 3 {
            let mean = history.reduce(0, +) / Double(history.count)
            let variance = history.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(history.count)
            baseline = Baseline(mean: mean, sd: max(variance.squareRoot(), id.info.floorSD))
        }
        var flag = Flag.none
        if let v = latest?.value {
            if let range = baseline.map({ $0.low...$0.high }) ?? id.info.typical {
                flag = v > range.upperBound ? .high : (v < range.lowerBound ? .low : .normal)
            } else {
                flag = .normal
            }
        }
        return MetricState(id: id, series: series, latest: latest, baseline: baseline, flag: flag)
    }
}
