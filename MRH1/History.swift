import Foundation
import SwiftUI

/// One day of scores, for the swipeable week on Today and the weekly report.
struct DaySummary: Identifiable {
    let date: Date
    let recovery: Int?
    let sleepMinutes: Double?
    let sleepScore: Int?
    let steps: Double?
    var strain: Double?
    var id: Date { date }
}

// MARK: - Body age

struct AgeFactor: Identifiable {
    let id = UUID()
    let label: String
    let years: Double
    let detail: String
}

struct BodyAge {
    let chronological: Int
    let estimate: Double
    let factors: [AgeFactor]
}

// MARK: - Weekly report

struct WeeklyReport {
    let from: Date
    let to: Date
    let avgRecovery: Int?
    let avgSleep: Double?
    let sleepDebt: Double
    let avgSteps: Double?
    let workoutMinutes: Double
    let best: Insights.Trend?
    let worst: Insights.Trend?
}

extension Insights {

    private static func avg(_ xs: [Double]) -> Double? {
        xs.isEmpty ? nil : xs.reduce(0, +) / Double(xs.count)
    }

    /// Recovery / sleep / steps for each of the last `days` days, using only data known on that day.
    static func history(states: [MetricID: MetricState], nights: [SleepSession], days: Int = 7) -> [DaySummary] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (0..<days).reversed().compactMap { offset -> DaySummary? in
            guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { return nil }
            var asOf: [MetricID: MetricState] = [:]
            for (id, s) in states {
                let upTo = s.series.filter { $0.date <= day }
                // Only use a value if it belongs to this exact day.
                if let last = upTo.last, cal.isDate(last.date, inSameDayAs: day) {
                    asOf[id] = .make(id, series: upTo)
                }
            }
            let night = nights.last(where: { cal.isDate($0.end, inSameDayAs: day) })
            let steps = states[.steps]?.series.first(where: { cal.isDate($0.date, inSameDayAs: day) })?.value
            return DaySummary(date: day,
                              recovery: Scores.recovery(states: asOf, lastSleep: night)?.score,
                              sleepMinutes: night?.asleepMinutes,
                              sleepScore: Scores.sleepScore(night),
                              steps: steps,
                              strain: nil)
        }
    }

    /// A rough "fitness age" from habits and vitals. Not a medical measure.
    static func bodyAge(age: Int?, states: [MetricID: MetricState], nights: [SleepSession]) -> BodyAge? {
        guard let age else { return nil }
        var f: [AgeFactor] = []
        func clamp(_ v: Double, _ lo: Double, _ hi: Double) -> Double { max(lo, min(hi, v)) }

        if let rhr = avg(states[.restingHR]?.series.suffix(14).map(\.value) ?? []) {
            f.append(AgeFactor(label: "Resting heart rate", years: clamp((rhr - 62) * 0.25, -4, 4),
                               detail: String(format: "%.0f bpm (14-day average). Lower is younger; 60 or below is excellent.", locale: .current, rhr)))
        }
        if let hrv = avg(states[.hrv]?.series.suffix(14).map(\.value) ?? []) {
            let expected = max(25, 65 - 0.6 * Double(age - 20))
            f.append(AgeFactor(label: "HRV", years: clamp((expected - hrv) / 5 * 0.5, -3, 3),
                               detail: String(format: "%.0f ms vs about %.0f typical for your age.", locale: .current, hrv, expected)))
        }
        if let steps = avg(states[.steps]?.series.suffix(14).map(\.value) ?? []) {
            f.append(AgeFactor(label: "Daily steps", years: clamp((8000 - steps) / 1000 * 0.4, -3, 3),
                               detail: String(format: "%.0f a day. 8 000+ a day is linked to longer life.", locale: .current, steps)))
        }
        let sleeps = nights.suffix(14).map(\.asleepMinutes)
        if let s = avg(sleeps) {
            let years: Double = (s >= 420 && s <= 510) ? -0.5 : clamp(abs(s - 465) / 60 * 0.8, 0, 3)
            f.append(AgeFactor(label: "Sleep duration", years: years,
                               detail: "\(MetricID.sleepTotal.format(s)) a night on average. 7 – 8.5 h is the sweet spot."))
        }
        if let spread = bedtimeSpread(nights) {
            f.append(AgeFactor(label: "Sleep regularity", years: clamp((spread - 45) / 30 * 0.5, -1, 2),
                               detail: "Bedtime varies ±\(Int(spread.rounded())) min. Under ±45 min helps."))
        }
        if let w = states[.workoutMinutes]?.latest?.value {
            f.append(AgeFactor(label: "Exercise", years: clamp((150 - w) / 150 * 1.5, -2, 2),
                               detail: "\(Int(w.rounded())) min of workouts in the last 7 days. 150+ is the target."))
        }
        guard f.count >= 2 else { return nil }
        let total = clamp(f.reduce(0) { $0 + $1.years }, -10, 10)
        return BodyAge(chronological: age, estimate: Double(age) + total,
                       factors: f.sorted { abs($0.years) > abs($1.years) })
    }

    static func weeklyReport(history: [DaySummary], states: [MetricID: MetricState], nights: [SleepSession]) -> WeeklyReport? {
        let week = history.suffix(7)
        guard let from = week.first?.date, let to = week.last?.date else { return nil }
        let trends = MetricID.allCases.compactMap { trend(states[$0] ?? MetricState(id: $0, series: [], latest: nil, baseline: nil, flag: .none)) }
        let ranked = trends.filter { $0.good != nil }.sorted { abs($0.recent - $0.previous) / max(abs($0.previous), 0.001) > abs($1.recent - $1.previous) / max(abs($1.previous), 0.001) }
        return WeeklyReport(
            from: from, to: to,
            avgRecovery: avg(week.compactMap { $0.recovery.map(Double.init) }).map { Int($0.rounded()) },
            avgSleep: avg(week.compactMap(\.sleepMinutes)),
            sleepDebt: sleepDebt(nights),
            avgSteps: avg(week.compactMap(\.steps)),
            workoutMinutes: states[.workoutMinutes]?.latest?.value ?? 0,
            best: ranked.first(where: { $0.good == true }),
            worst: ranked.first(where: { $0.good == false }))
    }
}

extension BodyAge {
    /// Shown when Apple Health has no date of birth (English copy; replaces the v0.4 "Apple Santé" text).
    static let missingBirthDateText =
        "Add your date of birth in Apple Health (profile, Health Details) so MRH1 can compare with your age."
}
