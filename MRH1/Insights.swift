import Foundation
import SwiftUI

// MARK: - Stress (0 – 3), hour by hour

struct StressHour: Identifiable {
    let start: Date
    let level: Double?     // nil = you were moving (excluded)
    let avgBPM: Double
    var id: Date { start }
}

enum Insights {

    /// Heart rate above your resting level while you were NOT moving = stress.
    static func stress(hr: [HRPoint], stepsByHour: [Date: Double], restingHR: Double, maxHR: Double) -> [StressHour] {
        let cal = Calendar.current
        let reserve = max(maxHR - restingHR, 40)
        var buckets: [Date: [Double]] = [:]
        for p in hr {
            guard let hour = cal.dateInterval(of: .hour, for: p.date)?.start else { continue }
            buckets[hour, default: []].append(p.bpm)
        }
        return buckets.keys.sorted().map { hour -> StressHour in
            let values = buckets[hour] ?? []
            let avg = values.reduce(0, +) / Double(max(values.count, 1))
            let steps = stepsByHour[hour] ?? 0
            if steps > 600 { return StressHour(start: hour, level: nil, avgBPM: avg) }
            let level = max(0, min(3, (avg - restingHR - 5) / (reserve * 0.3) * 3))
            return StressHour(start: hour, level: level, avgBPM: avg)
        }
    }

    static func stressColor(_ v: Double) -> Color {
        v >= 2 ? Theme.bad : (v >= 1 ? Theme.warn : Theme.recovery)
    }

    static func stressWord(_ v: Double) -> String {
        v >= 2 ? "High" : (v >= 1 ? "Medium" : "Calm")
    }

    /// Label for hours excluded because you were moving (drawn in neutral graphite, never blue).
    static let movingWord = "Moving"

    /// Legend for the health-monitor heat map: direction in words, no colour-only coding.
    static let heatMapLegend =
        "Each square is one night. Green is your usual range, yellow is outside it, grey is no reading."

    // MARK: Sleep debt & consistency

    /// Minutes short of an 8 h need, summed over the last 7 nights.
    static func sleepDebt(_ nights: [SleepSession]) -> Double {
        nights.suffix(7).reduce(0) { $0 + max(0, Scores.sleepNeedMinutes - $1.asleepMinutes) }
    }

    /// Spread of your bedtimes (± minutes). Smaller = more regular.
    static func bedtimeSpread(_ nights: [SleepSession]) -> Double? {
        let last = nights.suffix(14)
        guard last.count >= 3 else { return nil }
        let cal = Calendar.current
        let mins: [Double] = last.map {
            let c = cal.dateComponents([.hour, .minute], from: $0.start)
            return Double(((c.hour ?? 0) * 60 + (c.minute ?? 0) - 18 * 60 + 1440) % 1440)
        }
        let mean = mins.reduce(0, +) / Double(mins.count)
        return (mins.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(mins.count)).squareRoot()
    }

    static func consistencyScore(_ spread: Double) -> Int {
        Int(max(0, min(100, 100 - spread * 0.8)).rounded())
    }

    // MARK: Trends, week vs week

    struct Trend: Identifiable {
        let id: MetricID
        let recent: Double
        let previous: Double
        let sentence: String
        let good: Bool?          // nil = neutral
        let recentValues: [Double]
        let previousValues: [Double]
    }

    /// true = higher is better, false = lower is better, nil = neutral.
    static func direction(_ id: MetricID) -> Bool? {
        switch id {
        case .hrv, .steps, .energy, .workoutMinutes, .sleepTotal, .deepSleep, .remSleep: return true
        case .restingHR, .sleepingHR, .breathing, .awake: return false
        case .spo2, .skinTemp: return nil
        }
    }

    static func trend(_ s: MetricState) -> Trend? {
        let values = s.series.map(\.value)
        guard values.count >= 6 else { return nil }
        let recent = Array(values.suffix(7))
        let previous = Array(values.dropLast(recent.count).suffix(7))
        guard previous.count >= 3 else { return nil }
        let r = recent.reduce(0, +) / Double(recent.count)
        let p = previous.reduce(0, +) / Double(previous.count)
        let diff = r - p
        let name = s.id.info.name
        let fmt: (Double) -> String = { v in
            let t = s.id.format(abs(v))
            return s.id.info.unit.isEmpty ? t : t + " " + s.id.info.unit
        }
        let pct = p != 0 ? abs(diff / p) * 100 : 0
        var sentence: String
        if pct < 3 {
            sentence = "\(name) is steady: about \(fmt(r)) on average, same as the week before."
        } else {
            let word = diff > 0 ? "up" : "down"
            sentence = "\(name) is \(word) \(fmt(diff)) (\(Int(pct.rounded()))%) vs the week before: \(fmt(r)) on average."
        }
        var good: Bool? = nil
        if pct >= 3, let d = direction(s.id) { good = (diff > 0) == d }
        return Trend(id: s.id, recent: r, previous: p, sentence: sentence, good: good,
                     recentValues: recent, previousValues: previous)
    }
}
