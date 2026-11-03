import Foundation
import SwiftUI

// MARK: - Sleep session

enum SleepStage: String, CaseIterable {
    case awake, rem, light, deep

    var label: String {
        switch self {
        case .awake: return "Awake"
        case .rem: return "REM (dreaming)"
        case .light: return "Light"
        case .deep: return "Deep"
        }
    }

    var color: Color {
        switch self {
        case .awake: return Theme.stageAwake
        case .rem: return Theme.stageREM
        case .light: return Theme.stageLight
        case .deep: return Theme.stageDeep
        }
    }
}

struct SleepSegment: Identifiable {
    let id = UUID()
    let stage: SleepStage
    let start: Date
    let end: Date
    var minutes: Double { end.timeIntervalSince(start) / 60 }
}

struct SleepSession {
    let start: Date
    let end: Date
    let segments: [SleepSegment]

    func minutes(_ stage: SleepStage) -> Double {
        segments.filter { $0.stage == stage }.reduce(0) { $0 + $1.minutes }
    }

    var asleepMinutes: Double { minutes(.light) + minutes(.deep) + minutes(.rem) }
    var inBedMinutes: Double { end.timeIntervalSince(start) / 60 }
    var efficiency: Double { inBedMinutes > 0 ? asleepMinutes / inBedMinutes : 0 }
    var hasStages: Bool { minutes(.deep) + minutes(.rem) > 0 }
}

// MARK: - Recovery

struct Contributor: Identifiable {
    let id: MetricID
    let label: String
    let z: Double          // + is better than usual, − is worse
    let valueText: String
}

struct RecoveryResult {
    let score: Int
    let contributors: [Contributor]
}

enum Scores {
    static let sleepNeedMinutes = 480.0

    /// Combines how each signal compares with your own baseline. 0 – 100 %.
    static func recovery(states: [MetricID: MetricState], lastSleep: SleepSession?) -> RecoveryResult? {
        var parts: [(Contributor, Double)] = []

        func z(_ id: MetricID, higherIsBetter: Bool) -> Double? {
            guard let s = states[id], let v = s.latest?.value, let b = s.baseline else { return nil }
            let raw = (v - b.mean) / b.sd
            return max(-3, min(3, higherIsBetter ? raw : -raw))
        }

        if let v = z(.hrv, higherIsBetter: true), let s = states[.hrv] {
            parts.append((Contributor(id: .hrv, label: "HRV (heart rate variability)", z: v, valueText: s.valueText + " ms"), 0.40))
        }
        if let v = z(.restingHR, higherIsBetter: false), let s = states[.restingHR] {
            parts.append((Contributor(id: .restingHR, label: "Resting heart rate", z: v, valueText: s.valueText + " bpm"), 0.25))
        }
        if let v = z(.breathing, higherIsBetter: false), let s = states[.breathing] {
            parts.append((Contributor(id: .breathing, label: "Breathing rate", z: v, valueText: s.valueText + " /min"), 0.15))
        }
        if let sleep = lastSleep, sleep.asleepMinutes > 0 {
            let ratio = sleep.asleepMinutes / sleepNeedMinutes
            let v = max(-3, min(3, (ratio - 0.9) / 0.1))
            parts.append((Contributor(id: .sleepTotal, label: "Sleep vs need (8 h)", z: v, valueText: MetricID.sleepTotal.format(sleep.asleepMinutes)), 0.20))
        }

        // Need at least one heart signal with a baseline.
        guard parts.contains(where: { $0.0.id == .hrv || $0.0.id == .restingHR }) else { return nil }

        let totalWeight = parts.reduce(0) { $0 + $1.1 }
        let avg = parts.reduce(0) { $0 + $1.0.z * $1.1 } / totalWeight
        let score = 100 / (1 + exp(-(1.2 * avg + 0.4)))
        return RecoveryResult(score: Int(score.rounded()), contributors: parts.map { $0.0 })
    }

    static func recoveryColor(_ score: Int) -> Color {
        score >= 67 ? Theme.recovery : (score >= 34 ? Theme.warn : Theme.bad)
    }

    static func verdict(_ recovery: RecoveryResult?) -> String {
        guard let r = recovery else { return "Calibrating: a few more nights with the Air." }
        if r.score >= 67 { return "You’re ready to push." }
        if r.score >= 34 { return "Take it steady today." }
        return "Your body is asking for rest."
    }

    static func strainTarget(_ recovery: RecoveryResult?) -> ClosedRange<Double> {
        guard let r = recovery else { return 8...12 }
        if r.score >= 67 { return 14...17 }
        if r.score >= 34 { return 10...14 }
        return 5...10
    }

    // MARK: Sleep score

    static func sleepScore(_ s: SleepSession?) -> Int? {
        guard let s, s.asleepMinutes > 60 else { return nil }
        let duration = min(s.asleepMinutes / sleepNeedMinutes, 1) * 50
        let restorative = s.hasStages ? min(((s.minutes(.deep) + s.minutes(.rem)) / s.asleepMinutes) / 0.40, 1) * 30 : 22
        let efficiency = min(s.efficiency / 0.90, 1) * 20
        return Int((duration + restorative + efficiency).rounded())
    }
}

// MARK: - Strain

struct HRPoint: Identifiable {
    let date: Date
    let bpm: Double
    var id: Date { date }
}

struct StrainResult {
    let value: Double          // 0 – 21
    let zoneMinutes: [Double]  // zones 1 – 5
    let maxHR: Double
}

extension Scores {
    /// All-day cardiovascular load (TRIMP), squashed to Whoop's 0 – 21 scale.
    static func strain(points: [HRPoint], restingHR: Double, maxHR: Double) -> StrainResult {
        var trimp = 0.0
        var zones = [Double](repeating: 0, count: 5)
        let reserve = max(maxHR - restingHR, 40)
        let sorted = points.sorted { $0.date < $1.date }
        for i in 0..<max(sorted.count - 1, 0) {
            let p = sorted[i]
            let minutes = min(sorted[i + 1].date.timeIntervalSince(p.date) / 60, 5)
            guard minutes > 0 else { continue }
            let r = (p.bpm - restingHR) / reserve
            if r > 0 { trimp += minutes * r * 0.64 * exp(1.92 * r) }
            let pct = p.bpm / maxHR
            if pct >= 0.5 {
                let zone = min(Int((pct - 0.5) / 0.1), 4)
                zones[zone] += minutes
            }
        }
        let value = 21 * (1 - exp(-trimp / 120))
        return StrainResult(value: value, zoneMinutes: zones, maxHR: maxHR)
    }
}

// MARK: - Recovery inputs ("3 of 4 signals")

extension RecoveryResult {
    /// The four inputs Recovery can use, in weight order.
    static let allInputs: [MetricID] = [.hrv, .restingHR, .breathing, .sleepTotal]

    var signalsUsed: Int { contributors.count }
    var signalsTotal: Int { Self.allInputs.count }

    /// Inputs that were missing for this score (e.g. HRV, which Google Health does not send).
    var missingInputs: [MetricID] {
        Self.allInputs.filter { id in !contributors.contains { $0.id == id } }
    }

    /// "3 of 4 signals" footnote when an input is missing, nil when all four were used.
    var signalsText: String? {
        signalsUsed < signalsTotal ? "\(signalsUsed) of \(signalsTotal) signals" : nil
    }
}
