import SwiftUI

// MARK: - Trend copy (shared by Trends and the weekly report)

/// Plain-language reading of a week-vs-week trend. Deterministic templates, ≤14 words,
/// second person, no exclamation marks (DESIGN_SPEC §5).
enum TrendCopy {
    /// How a trend reads: changed in a good direction, a concerning one, a neutral change, or steady.
    enum Reading { case better, watch, changed, steady }

    static func reading(_ t: Insights.Trend) -> Reading {
        guard changed(t) else { return .steady }
        switch Insights.direction(t.id) {
        case .some(let higherIsBetter): return (t.recent > t.previous) == higherIsBetter ? .better : .watch
        case .none: return .changed
        }
    }

    /// A meaningful change: ≥3 % of the previous week's average (same rule as `Insights.trend`).
    /// Skin temperature is already a delta around 0, so it uses an absolute 0.25 °C step instead.
    static func changed(_ t: Insights.Trend) -> Bool {
        let diff = t.recent - t.previous
        if t.id == .skinTemp { return abs(diff) >= 0.25 }
        guard t.previous != 0 else { return diff != 0 }
        return abs(diff / t.previous) >= 0.03
    }

    /// Value with its unit, joined by a non-breaking space.
    static func value(_ id: MetricID, _ v: Double) -> String {
        let t = id.format(v)
        return id.info.unit.isEmpty ? t : t + "\u{00A0}" + id.info.unit
    }

    /// Absolute change with unit; skin temperature keeps its sign-free magnitude.
    static func delta(_ id: MetricID, _ v: Double) -> String {
        let t = id == .skinTemp ? abs(v).formatted(.number.precision(.fractionLength(1))) : id.format(abs(v))
        return id.info.unit.isEmpty ? t : t + "\u{00A0}" + id.info.unit
    }

    /// The takeaway sentence, e.g. "Resting heart rate averaged 3 bpm lower than the week before."
    static func sentence(_ t: Insights.Trend) -> String {
        let name = t.id.info.name
        let diff = t.recent - t.previous
        guard changed(t) else {
            return "\(name) held steady at about \(value(t.id, t.recent))."
        }
        let word: String
        switch t.id {
        case .sleepTotal, .deepSleep, .remSleep, .awake, .workoutMinutes: word = diff > 0 ? "longer" : "shorter"
        case .steps, .energy: word = diff > 0 ? "more" : "fewer"
        default: word = diff > 0 ? "higher" : "lower"
        }
        let fixedWord = (t.id == .energy && diff < 0) ? "less" : word
        return "\(name) averaged \(delta(t.id, diff)) \(fixedWord) than the week before."
    }

    /// One calm action, only when the change is a concern.
    static func action(_ t: Insights.Trend) -> String? {
        guard reading(t) == .watch else { return nil }
        switch t.id {
        case .restingHR, .sleepingHR: return "Easier days and earlier nights help it settle."
        case .hrv: return "Protect your sleep and keep sessions easy."
        case .breathing: return "Rest more if you feel run down."
        case .sleepTotal, .deepSleep, .remSleep: return "Aim for a steadier bedtime this week."
        case .awake: return "A cool, dark room helps."
        case .steps, .energy, .workoutMinutes: return "A short daily walk brings it back."
        case .spo2, .skinTemp: return nil
        }
    }

    /// Status tier for colour + word. Only a meaningful, directional change gets one.
    static func tier(_ t: Insights.Trend) -> StatusTier? {
        switch reading(t) {
        case .better: return .inRange
        case .watch: return .watch
        case .changed, .steady: return nil
        }
    }

    /// Short word that goes with the status colour, so colour is never alone.
    static func word(_ t: Insights.Trend) -> String {
        switch reading(t) {
        case .better: return "Better"
        case .watch: return "Watch"
        case .changed: return t.recent > t.previous ? "Up" : "Down"
        case .steady: return "Steady"
        }
    }

    /// Ranking for "changed first": relative size of the move.
    static func magnitude(_ t: Insights.Trend) -> Double {
        let diff = abs(t.recent - t.previous)
        if t.id == .skinTemp { return diff }
        return diff / max(abs(t.previous), 0.001)
    }
}

// MARK: - Weekly report

/// Last week in five lines, best change and the one to work on, and a plain-text export for a doctor.
/// Shown in Trends always and on Today on Mondays.
struct WeeklyReportCard: View {
    @Environment(HealthStore.self) private var health

    var body: some View {
        if let r = health.weekly {
            Card(spacing: Space.l) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Weekly report").typo(.headline).foregroundStyle(Theme.ink)
                    Spacer(minLength: Space.s)
                    Text(Self.range(r)).typo(.caption).foregroundStyle(Theme.graphite)
                }
                .accessibilityElement(children: .combine)

                VStack(spacing: 0) {
                    row("Average recovery", r.avgRecovery.map { "\($0)" } ?? "—", unit: r.avgRecovery == nil ? "" : "%")
                    row("Average sleep", r.avgSleep.map { MetricID.sleepTotal.format($0) } ?? "—")
                    row("Sleep debt", MetricID.sleepTotal.format(r.sleepDebt),
                        note: r.sleepDebt > 120 ? "Watch" : nil)
                    row("Average steps", r.avgSteps.map { Int($0.rounded()).formatted() } ?? "—")
                    row("Workouts", Int(r.workoutMinutes.rounded()).formatted(), unit: "min",
                        note: "of 150", last: true)
                }

                if r.best != nil || r.worst != nil {
                    VStack(alignment: .leading, spacing: Space.m) {
                        if let b = r.best { highlight("Best change", TrendCopy.sentence(b), Theme.goodText) }
                        if let w = r.worst { highlight("To work on", TrendCopy.sentence(w), Theme.limitText) }
                    }
                }

                ShareLink(item: Self.summary(health),
                          subject: Text("MRH1 weekly report"),
                          message: Text("Wellness estimates, not medical advice."),
                          preview: SharePreview("MRH1 weekly report \(Self.range(r))")) {
                    Label("Share for a doctor", systemImage: "square.and.arrow.up")
                        .typo(.label)
                        .foregroundStyle(Theme.ink)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(Theme.paper, in: Capsule())
                }
                .buttonStyle(PressStyle())
                .accessibilityHint("Exports a plain-text summary of the last two weeks")
            }
        }
    }

    private func row(_ title: String, _ value: String, unit: String = "", note: String? = nil, last: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.s) {
            Text(title).typo(.body).foregroundStyle(Theme.graphite)
            Spacer(minLength: Space.s)
            if let note {
                Text(note).typo(.caption).foregroundStyle(note == "Watch" ? Theme.limitText : Theme.graphite)
            }
            ValueText(value: value, unit: unit, size: .headline)
        }
        .padding(.vertical, Space.m)
        .overlay(alignment: .bottom) {
            if !last { Rectangle().fill(Theme.hair).frame(height: 0.5) }
        }
        .accessibilityElement(children: .combine)
    }

    private func highlight(_ title: String, _ text: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text(title).typo(.label).foregroundStyle(color)
            Text(text).typo(.body).foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    static func range(_ r: WeeklyReport) -> String {
        let f = Date.FormatStyle.dateTime.day().month(.abbreviated)
        return "\(r.from.formatted(f)) – \(r.to.formatted(f))"
    }

    /// Plain-text export: the report, every metric's week-before vs last-7-days average, body age.
    static func summary(_ health: HealthStore) -> String {
        var lines: [String] = ["MRH1 weekly report"]
        if let r = health.weekly {
            lines.append(range(r))
            lines.append("")
            lines.append("Average recovery: " + (r.avgRecovery.map { "\($0) %" } ?? "no reading"))
            lines.append("Average sleep: " + (r.avgSleep.map { MetricID.sleepTotal.format($0) } ?? "no reading"))
            lines.append("Sleep debt (7 nights): " + MetricID.sleepTotal.format(r.sleepDebt))
            lines.append("Average steps: " + (r.avgSteps.map { Int($0.rounded()).formatted() } ?? "no reading"))
            lines.append("Workouts: \(Int(r.workoutMinutes.rounded())) min (target 150)")
        }
        lines.append("")
        lines.append("Week before → last 7 days (daily averages)")
        for id in MetricID.allCases {
            let s = health.state(id)
            if let t = Insights.trend(s) {
                lines.append("\(id.info.name): \(TrendCopy.value(id, t.previous)) → \(TrendCopy.value(id, t.recent))")
            } else {
                let missing = id.isNotSentByGoogle && !s.hasData ? "not sent by Google Health" : "not enough data"
                lines.append("\(id.info.name): \(missing)")
            }
        }
        if let b = health.bodyAge {
            lines.append("")
            lines.append("Body age estimate: \(b.estimate.formatted(.number.precision(.fractionLength(1)))) (age \(b.chronological))")
        }
        lines.append("")
        lines.append("Source: Fitbit Air via Google Health and Apple Health, computed on this iPhone by MRH1.")
        lines.append("Wellness estimates, not medical advice.")
        return lines.joined(separator: "\n")
    }
}

// MARK: - Body age

/// Fitness-age estimate: the number, one sentence, and each factor as a bar either side of your age.
struct BodyAgeCard: View {
    @Environment(HealthStore.self) private var health
    @State private var showInfo = false

    var body: some View {
        Card(spacing: Space.l) {
            HStack(alignment: .center) {
                Text("Body age").typo(.headline).foregroundStyle(Theme.ink)
                Spacer(minLength: Space.s)
                Button { showInfo = true } label: {
                    Image(systemName: "info.circle")
                        .font(Typo.body)
                        .foregroundStyle(Theme.graphite)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressStyle())
                .padding(.vertical, -Space.m)
                .padding(.trailing, -Space.m)
                .accessibilityLabel("What is body age?")
            }

            if let b = health.bodyAge {
                let diff = b.estimate - Double(b.chronological)
                VStack(alignment: .leading, spacing: Space.xs) {
                    HStack(alignment: .firstTextBaseline, spacing: Space.s) {
                        ValueText(value: b.estimate.formatted(.number.precision(.fractionLength(1))),
                                  unit: "years", size: .metric)
                        Text("vs \(b.chronological) by the calendar")
                            .typo(.caption).foregroundStyle(Theme.graphite)
                    }
                    Text(Self.sentence(diff)).typo(.body).foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)

                let scale = max(b.factors.map { abs($0.years) }.max() ?? 1, 1)
                VStack(spacing: 0) {
                    ForEach(Array(b.factors.enumerated()), id: \.element.id) { i, f in
                        factorRow(f, scale: scale, last: i == b.factors.count - 1)
                    }
                }
                Text("Left of the line takes years off. Right of it adds them.")
                    .typo(.caption).foregroundStyle(Theme.graphite)
            } else {
                Text(health.age == nil ? BodyAge.missingBirthDateText
                     : "Needs at least two signals, such as resting heart rate and steps. Check back in a few days.")
                    .typo(.body).foregroundStyle(Theme.graphite)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .sheet(isPresented: $showInfo) {
            ExplainSheet(title: "Body age", sub: "A rough “fitness age” from your habits and vitals",
                         what: "Research links resting heart rate, HRV, daily steps, sleep length and regularity, and exercise to how fast people age. MRH1 starts from your real age and adds or removes years for each one, compared with typical values. It is a motivating estimate, not a medical or biological test. VO2 max would make it more accurate, but Google Health does not send it yet.",
                         rows: [("Minus years", "That habit or vital is better than typical for your age."),
                                ("Plus years", "Room to improve: these are the levers to work on."),
                                ("Changes", "Expect it to move slowly over weeks, not days.")])
        }
    }

    static func sentence(_ diff: Double) -> String {
        let y = abs(diff).formatted(.number.precision(.fractionLength(1)))
        if diff <= -0.5 { return "Your habits look \(y) years younger than your age." }
        if diff >= 0.5 { return "Your habits look \(y) years older than your age." }
        return "Your habits match your age."
    }

    /// Label + signed years, a diverging bar around a centre hairline, and the detail line.
    private func factorRow(_ f: AgeFactor, scale: Double, last: Bool) -> some View {
        let younger = f.years <= 0
        let years = (f.years < 0 ? "−" : "+") + abs(f.years).formatted(.number.precision(.fractionLength(1)))
        return VStack(alignment: .leading, spacing: Space.s) {
            HStack(alignment: .firstTextBaseline) {
                Text(f.label).typo(.label).foregroundStyle(Theme.ink)
                Spacer(minLength: Space.s)
                Text(years + "\u{00A0}y").typo(.label).monospacedDigit()
                    .foregroundStyle(younger ? Theme.goodText : Theme.limitText)
            }
            GeometryReader { geo in
                let half = geo.size.width / 2
                let w = max(CGFloat(abs(f.years) / scale) * half, 2)
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.paper).frame(height: 6)
                    UnevenRoundedRectangle(cornerRadii: .init(topLeading: younger ? 3 : 0, bottomLeading: younger ? 3 : 0,
                                                              bottomTrailing: younger ? 0 : 3, topTrailing: younger ? 0 : 3))
                        .fill(younger ? Theme.good : Theme.limit)
                        .frame(width: w, height: 6)
                        .offset(x: younger ? half - w : half)
                    Rectangle().fill(Theme.ink).frame(width: 1, height: 12).offset(x: half - 0.5)
                }
                .frame(height: 12)
            }
            .frame(height: 12)
            .accessibilityHidden(true)
            Text(f.detail).typo(.caption).foregroundStyle(Theme.graphite)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, Space.m)
        .overlay(alignment: .bottom) {
            if !last { Rectangle().fill(Theme.hair).frame(height: 0.5) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(f.label), \(years) years, \(younger ? "younger" : "older"). \(f.detail)")
    }
}
