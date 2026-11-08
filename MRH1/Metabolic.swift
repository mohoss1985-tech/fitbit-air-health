import SwiftUI
import HealthKit

// v1.2 · Blood pressure from a home cuff + Metabolic health signals.
//
// The Fitbit Air has no blood-pressure sensor and Google's Premium "blood pressure / insulin resistance
// trends" never reach Apple Health. So MRH1 shows:
//   1. Real cuff readings (Withings, Omron, … anything that saves to Apple Health), never an estimate.
//   2. Lifestyle signals research links to insulin sensitivity, from data we already have.
//      Never an insulin or blood-sugar number. Wellness, not medical advice.

// MARK: - Blood pressure

struct BPReading: Identifiable, Hashable {
    let date: Date
    let systolic: Double
    let diastolic: Double
    let source: String
    var id: Date { date }

    var text: String { "\(Int(systolic.rounded()))/\(Int(diastolic.rounded()))" }
}

/// Home blood-pressure bands (American Heart Association adult categories), used as wellness context only.
enum BPBand {
    case normal, elevated, high, veryHigh

    init(systolic s: Double, diastolic d: Double) {
        if s >= 180 || d >= 120 { self = .veryHigh }
        else if s >= 130 || d >= 80 { self = .high }
        else if s >= 120 { self = .elevated }
        else { self = .normal }
    }

    var word: String {
        switch self {
        case .normal: return "Normal"
        case .elevated: return "Elevated"
        case .high: return "High"
        case .veryHigh: return "Very high"
        }
    }

    var color: Color {
        switch self {
        case .normal: return Theme.recovery
        case .elevated: return Theme.warn
        case .high, .veryHigh: return Theme.bad
        }
    }

    var advice: String {
        switch self {
        case .normal: return "Under 120/80, the range guidelines call normal."
        case .elevated: return "Top number 120–129. Movement, less salt and good sleep help."
        case .high: return "130/80 or more on average. Worth discussing with a doctor."
        case .veryHigh: return "180/120 or more. Measure again after 5 min of rest. If it stays this high or you feel unwell, get medical help now."
        }
    }
}

struct BPSummary {
    let latest: BPReading
    /// Average of the last 30 days (needs 1+ reading in that window).
    let avgSys: Double
    let avgDia: Double
    let count30: Int
    let readings: [BPReading]

    /// Band from the 30-day average (single readings swing a lot); a very high latest reading always wins.
    var band: BPBand {
        let latestBand = BPBand(systolic: latest.systolic, diastolic: latest.diastolic)
        if latestBand == .veryHigh { return .veryHigh }
        return BPBand(systolic: avgSys, diastolic: avgDia)
    }

    var avgText: String { "\(Int(avgSys.rounded()))/\(Int(avgDia.rounded()))" }

    init?(_ all: [BPReading], now: Date = Demo.now) {
        let sorted = all.sorted { $0.date < $1.date }
        guard let last = sorted.last else { return nil }
        let from = now.addingTimeInterval(-30 * 86_400)
        let recent = sorted.filter { $0.date >= from }
        let window = recent.isEmpty ? [last] : recent
        latest = last
        readings = sorted
        count30 = recent.count
        avgSys = window.map(\.systolic).reduce(0, +) / Double(window.count)
        avgDia = window.map(\.diastolic).reduce(0, +) / Double(window.count)
    }
}

extension HealthStore {
    /// Systolic + diastolic, so the cuff readings can be read (HealthKit can't authorise the correlation itself).
    static var bloodPressureReadTypes: Set<HKObjectType> {
        [HKQuantityType(.bloodPressureSystolic), HKQuantityType(.bloodPressureDiastolic)]
    }

    /// Cuff readings from the last 180 days, oldest first. Empty when there are none or access is off.
    nonisolated static func fetchBloodPressure(_ store: HKHealthStore) async -> [BPReading] {
        guard let type = HKCorrelationType.correlationType(forIdentifier: .bloodPressure) else { return [] }
        let from = Date().addingTimeInterval(-180 * 86_400)
        let pred = HKQuery.predicateForSamples(withStart: from, end: Date())
        let sys = HKQuantityType(.bloodPressureSystolic)
        let dia = HKQuantityType(.bloodPressureDiastolic)
        let mmHg = HKUnit.millimeterOfMercury()
        return await withCheckedContinuation { cont in
            let q = HKCorrelationQuery(type: type, predicate: pred, samplePredicates: nil) { _, results, _ in
                let out: [BPReading] = (results ?? []).compactMap { c in
                    guard let s = c.objects(for: sys).first as? HKQuantitySample,
                          let d = c.objects(for: dia).first as? HKQuantitySample else { return nil }
                    return BPReading(date: c.startDate,
                                     systolic: s.quantity.doubleValue(for: mmHg),
                                     diastolic: d.quantity.doubleValue(for: mmHg),
                                     source: c.sourceRevision.source.name)
                }
                cont.resume(returning: out.sorted { $0.date < $1.date })
            }
            store.execute(q)
        }
    }

    /// Sample cuff readings for demo mode: a slightly elevated week, about every other morning.
    static func demoBloodPressure(now: Date) -> [BPReading] {
        let values: [(Double, Double)] = [(118, 76), (124, 79), (121, 77), (126, 81), (119, 75), (123, 78),
                                          (122, 77), (127, 80), (120, 76), (124, 78), (121, 77), (125, 79)]
        let cal = Calendar.current
        return values.enumerated().compactMap { i, v in
            guard let day = cal.date(byAdding: .day, value: -(values.count - 1 - i) * 2, to: cal.startOfDay(for: now)) else { return nil }
            return BPReading(date: day.addingTimeInterval(7.5 * 3600), systolic: v.0, diastolic: v.1, source: "Home cuff (sample data)")
        }
    }
}

/// Heart panel row: real cuff readings when there are any, else how to get them.
struct BloodPressureRow: View {
    @Environment(HealthStore.self) private var health
    @State private var showInfo = false

    var body: some View {
        if let s = BPSummary(health.bloodPressure) {
            Button { showInfo = true } label: { filled(s) }
                .buttonStyle(PressStyle())
                .accessibilityHint("Opens what blood pressure means")
                .sheet(isPresented: $showInfo) { BloodPressureSheet(summary: s) }
        } else {
            empty
        }
    }

    private func filled(_ s: BPSummary) -> some View {
        let band = s.band
        return VStack(alignment: .leading, spacing: Space.m) {
            HStack(alignment: .top, spacing: Space.m) {
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text("Blood pressure").typo(.body).foregroundStyle(Theme.ink)
                    Text("30-day average \(s.avgText) · \(s.count30) \(s.count30 == 1 ? "reading" : "readings")")
                        .typo(.caption).monospacedDigit().foregroundStyle(Theme.graphite)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .trailing, spacing: Space.xs) {
                    ValueText(value: s.latest.text, unit: "mmHg", size: .headline)
                    BandChip(word: band.word, color: band.color)
                }
            }
            Text("Latest \(s.latest.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))) · \(s.latest.source). Measured by your cuff, not the Fitbit Air.")
                .typo(.caption).foregroundStyle(Theme.graphite)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, Space.l)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Blood pressure, latest \(s.latest.text) millimetres of mercury. 30-day average \(s.avgText). \(band.word).")
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            HStack(alignment: .firstTextBaseline, spacing: Space.m) {
                Text("Blood pressure").typo(.body).foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("No cuff readings").typo(.label).foregroundStyle(Theme.graphite)
            }
            Text("Fitbit Air has no blood-pressure sensor. Readings from a home cuff that saves to Apple Health (Withings, Omron…) appear here.")
                .typo(.caption).foregroundStyle(Theme.graphite)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, Space.l)
        .accessibilityElement(children: .combine)
    }
}

private struct BandChip: View {
    let word: String
    let color: Color
    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(word).typo(.label).foregroundStyle(Theme.ink)
        }
        .padding(.horizontal, Space.s)
        .padding(.vertical, 3)
        .background(Capsule().fill(color.opacity(0.14)))
    }
}

private struct BloodPressureSheet: View {
    let summary: BPSummary
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.section) {
                    VStack(alignment: .leading, spacing: Space.s) {
                        Text(summary.band.word).typo(.title).foregroundStyle(Theme.ink)
                        Text(summary.band.advice).typo(.body).foregroundStyle(Theme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Card {
                        VStack(alignment: .leading, spacing: Space.s) {
                            Text("Last readings").typo(.headline).foregroundStyle(Theme.ink)
                            ForEach(summary.readings.suffix(10).reversed()) { r in
                                HStack {
                                    Text(r.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute()))
                                        .typo(.caption).foregroundStyle(Theme.graphite)
                                    Spacer()
                                    Text(r.text + " mmHg").typo(.body).monospacedDigit().foregroundStyle(Theme.ink)
                                    Circle().fill(BPBand(systolic: r.systolic, diastolic: r.diastolic).color).frame(width: 6, height: 6)
                                }
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: Space.s) {
                        Text("How to read it").typo(.headline).foregroundStyle(Theme.ink)
                        Text("Top number (systolic): pressure while your heart beats. Bottom (diastolic): between beats. Guidelines: under 120/80 normal · 120–129 elevated · 130/80 or more high. One reading swings a lot; the 30-day average matters more.")
                            .typo(.body).foregroundStyle(Theme.ink).fixedSize(horizontal: false, vertical: true)
                        Text("Tip: sit 5 minutes, feet flat, arm at heart level, same time each day.")
                            .typo(.body).foregroundStyle(Theme.graphite).fixedSize(horizontal: false, vertical: true)
                        Text("From your own cuff via Apple Health. Wellness information, not medical advice.")
                            .typo(.caption).foregroundStyle(Theme.graphite)
                    }
                }
                .padding(.horizontal, Space.gutter)
                .padding(.vertical, Space.l)
            }
            .background(Theme.paper)
            .navigationTitle("Blood pressure")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Metabolic health signals

struct MetabolicSignal: Identifiable {
    let id: String
    let name: String
    let value: String
    let target: String
    let onTrack: Bool?          // nil = not enough data
    let why: String
}

enum Metabolic {
    /// Five habits research links to insulin sensitivity. Lifestyle signals only; never a glucose or insulin estimate.
    @MainActor static func signals(_ h: HealthStore) -> [MetabolicSignal] {
        var out: [MetabolicSignal] = []

        // 1. Daily steps, last 7 full days.
        let steps = h.state(.steps).series.suffix(7).map(\.value)
        if steps.count >= 3 {
            let avg = steps.reduce(0, +) / Double(steps.count)
            out.append(MetabolicSignal(id: "steps", name: "Daily steps", value: MetricID.steps.format(avg) + " a day",
                                       target: "7 000+", onTrack: avg >= 7000,
                                       why: "Walking after meals helps your muscles use sugar."))
        } else {
            out.append(MetabolicSignal(id: "steps", name: "Daily steps", value: "Not enough days", target: "7 000+", onTrack: nil,
                                       why: "Walking after meals helps your muscles use sugar."))
        }

        // 2. Exercise minutes, last 7 days (logged workouts; walks count as steps).
        if let w = h.state(.workoutMinutes).latest?.value {
            out.append(MetabolicSignal(id: "exercise", name: "Exercise", value: "\(Int(w.rounded())) min this week",
                                       target: "150+ min", onTrack: w >= 150,
                                       why: "Regular exercise is the strongest habit for insulin sensitivity."))
        } else {
            out.append(MetabolicSignal(id: "exercise", name: "Exercise", value: "No workouts logged", target: "150+ min", onTrack: nil,
                                       why: "Regular exercise is the strongest habit for insulin sensitivity."))
        }

        // 3. Sleep length, last 7 nights.
        let nights = h.recentNights.suffix(7)
        if nights.count >= 3 {
            let avg = nights.map(\.asleepMinutes).reduce(0, +) / Double(nights.count)
            out.append(MetabolicSignal(id: "sleep", name: "Sleep length", value: MetricID.sleepTotal.format(avg) + " a night",
                                       target: "7 h+", onTrack: avg >= 420,
                                       why: "Short nights make the body handle sugar less well the next day."))
        } else {
            out.append(MetabolicSignal(id: "sleep", name: "Sleep length", value: "Not enough nights", target: "7 h+", onTrack: nil,
                                       why: "Short nights make the body handle sugar less well the next day."))
        }

        // 4. Bedtime regularity.
        if let spread = Insights.bedtimeSpread(h.recentNights) {
            out.append(MetabolicSignal(id: "regularity", name: "Bedtime regularity", value: "±\(Int(spread.rounded())) min",
                                       target: "±45 min or less", onTrack: spread <= 45,
                                       why: "A steady body clock keeps your metabolism in rhythm."))
        } else {
            out.append(MetabolicSignal(id: "regularity", name: "Bedtime regularity", value: "Not enough nights",
                                       target: "±45 min or less", onTrack: nil,
                                       why: "A steady body clock keeps your metabolism in rhythm."))
        }

        // 5. Resting heart rate trend: last 7 days vs the 30-day normal.
        let rhr = h.state(.restingHR)
        let recent = rhr.series.suffix(7).map(\.value)
        if let b = rhr.baseline, recent.count >= 3 {
            let avg = recent.reduce(0, +) / Double(recent.count)
            let diff = avg - b.mean
            let word = abs(diff) < 1 ? "steady" : (diff > 0 ? "+\(Int(diff.rounded())) bpm" : "−\(Int((-diff).rounded())) bpm")
            out.append(MetabolicSignal(id: "rhr", name: "Resting heart rate trend", value: "\(Int(avg.rounded())) bpm · \(word)",
                                       target: "Steady or falling", onTrack: diff < 2,
                                       why: "A resting heart rate that creeps up often follows less fitness or sleep."))
        } else {
            out.append(MetabolicSignal(id: "rhr", name: "Resting heart rate trend", value: "Learning your normal",
                                       target: "Steady or falling", onTrack: nil,
                                       why: "A resting heart rate that creeps up often follows less fitness or sleep."))
        }
        return out
    }
}

/// Body tab card: 5 habits linked to insulin sensitivity, each green (on track) or yellow (room to improve).
struct MetabolicCard: View {
    @Environment(HealthStore.self) private var health
    @State private var expanded: String?

    var body: some View {
        let signals = Metabolic.signals(health)
        let known = signals.filter { $0.onTrack != nil }
        let good = known.filter { $0.onTrack == true }.count
        Card {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Metabolic health signals").typo(.headline).foregroundStyle(Theme.ink)
                    Spacer(minLength: Space.s)
                    Text(known.isEmpty ? "Learning" : "\(good) of \(known.count) on track")
                        .typo(.label).monospacedDigit().foregroundStyle(Theme.graphite)
                }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)
                Text("Habits research links to insulin sensitivity. Not a blood-sugar or insulin measurement.")
                    .typo(.caption).foregroundStyle(Theme.graphite)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, Space.xs)
                    .padding(.bottom, Space.s)

                ForEach(signals) { s in
                    Rectangle().fill(Theme.hair).frame(height: 0.5)
                    row(s)
                }
            }
        }
    }

    private func row(_ s: MetabolicSignal) -> some View {
        let open = expanded == s.id
        let color: Color = s.onTrack == nil ? Theme.graphite2 : (s.onTrack! ? Theme.recovery : Theme.warn)
        return Button {
            withAnimation(Motion.enter) { expanded = open ? nil : s.id }
        } label: {
            VStack(alignment: .leading, spacing: Space.xs) {
                HStack(alignment: .firstTextBaseline, spacing: Space.s) {
                    Circle().fill(color).frame(width: 7, height: 7)
                    Text(s.name).typo(.body).foregroundStyle(Theme.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(s.value).typo(.label).monospacedDigit().foregroundStyle(Theme.ink)
                }
                Text("Goal \(s.target)" + (open ? " · \(s.why)" : ""))
                    .typo(.caption).foregroundStyle(Theme.graphite)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 15)
            }
            .padding(.vertical, Space.m)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(s.name), \(s.value). Goal \(s.target). \(s.onTrack == nil ? "Not enough data" : (s.onTrack! ? "On track" : "Room to improve")). \(s.why)")
    }
}
