import Foundation

/// Demo / sample-data mode (research/07 §5).
///
/// On when the app is launched with `-demo`, or always in the Simulator unless `-realHealth` is passed.
/// `-demoNow HH:MM` pins the demo clock to today at that time (screenshots), and the clock then runs on
/// from there. `-demoNotSent` drops HRV and skin temperature to show the real "Not sent" states.
enum Demo {
    static let isOn: Bool = {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-demo") { return true }
        #if targetEnvironment(simulator)
        return !args.contains("-realHealth")
        #else
        return false
        #endif
    }()

    /// Drop HRV + skin temperature in demo, like the real Google Health pipeline.
    static let dropsNotSent: Bool = ProcessInfo.processInfo.arguments.contains("-demoNotSent")

    /// Pinned clock from `-demoNow HH:MM` (today), or nil.
    static func pinnedNow(_ args: [String] = ProcessInfo.processInfo.arguments) -> Date? {
        guard let i = args.firstIndex(of: "-demoNow"), i + 1 < args.count else { return nil }
        let parts = args[i + 1].split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return nil }
        return Calendar.current.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: Date())
    }

    private static let launchReal = Date()
    /// Demo clock at launch: the pinned time, or the real launch time.
    static let launchNow: Date = pinnedNow() ?? launchReal

    /// "Now" for demo content: pinned start + real time elapsed since launch. Equals `Date()` without `-demoNow`.
    static var now: Date { isOn ? launchNow.addingTimeInterval(Date().timeIntervalSince(launchReal)) : Date() }

    /// Header chip text while demo is on.
    static let chipText = "Sample data"
}

// MARK: - Deterministic port of web/demo/data.js

/// Same LCG, same call order, same overrides as `web/demo/data.js`, so iOS and web show the same person.
struct DemoDataset {
    var series: [MetricID: [DayValue]] = [:]
    var nights: [SleepSession] = []
    var hr: [HRPoint] = []
    /// (hour, level) where nil = moving.
    var stress: [(hour: Int, level: Double?)] = []
    let maxHR = 182.0
    let age = 38
    let zones: [Double] = [64, 38, 22, 14, 3]
    /// days ago → (recovery, sleep min, strain, steps)
    let history: [(d: Int, recovery: Int, sleep: Double, strain: Double, steps: Double)] = [
        (6, 71, 445, 11.2, 7930), (5, 84, 428, 13.6, 11400), (4, 66, 396, 8.1, 8770),
        (3, 74, 462, 12.4, 10340), (2, 41, 451, 6.3, 6120), (1, 69, 438, 14.8, 12850), (0, 78, 432, 9.4, 9420)
    ]
    let bodyAgeEstimate = 35.7
    let bodyAgeFactors: [(String, Double, String)] = [
        ("Resting heart rate", -0.5, "61 bpm (14-day average). Lower is younger; 60 or below is excellent."),
        ("Daily steps", -0.9, "9 230 a day. 8 000+ a day is linked to longer life."),
        ("Exercise", -0.4, "212 min of workouts in the last 7 days. 150+ is the target."),
        ("HRV", 0.3, "51 ms vs about 54 typical for your age."),
        ("Sleep duration", -0.5, "7 h 15 a night on average. 7 – 8.5 h is the sweet spot."),
        ("Sleep regularity", -0.3, "Bedtime varies ±31 min. Under ±45 min helps.")
    ]
    /// Minutes after midnight the web demo stops at (17:40).
    static let endMinute = 17 * 60 + 40

    let today: Date
    let workoutStartMinute = 12 * 60 + 10
    let workoutMinutes = 45.0

    init(now: Date = Demo.now) {
        let cal = Calendar.current
        today = cal.startOfDay(for: now)
        var seed: Int64 = 42
        func rnd() -> Double { seed = (seed * 16807) % 2147483647; return Double(seed - 1) / 2147483646 }
        func noise(_ sd: Double) -> Double { (rnd() + rnd() + rnd() - 1.5) * sd * 1.15 }

        let days: [Date] = (0...30).reversed().compactMap { cal.date(byAdding: .day, value: -$0, to: today) }
        func make(_ base: Double, _ sd: Double, _ overrides: [Int: Double]) -> [DayValue] {
            days.enumerated().map { i, d in
                let fromEnd = days.count - 1 - i
                return DayValue(date: d, value: overrides[fromEnd] ?? base + noise(sd))
            }
        }
        // Call order matters (shared RNG).
        series[.restingHR] = make(61, 1.6, [0: 60, 1: 62, 2: 64.5, 3: 61, 4: 60, 5: 59, 6: 61])
        series[.hrv] = make(50, 5, [0: 56, 1: 52, 2: 41, 3: 49, 4: 53, 5: 55, 6: 51])
        series[.breathing] = make(14.8, 0.35, [0: 15.9, 1: 14.9, 2: 15.1, 3: 14.6, 4: 14.7, 5: 14.8, 6: 14.5])
        series[.spo2] = make(96.4, 0.5, [0: 96.6, 3: 94.9])
        series[.skinTemp] = make(0, 0.18, [0: 0.2, 2: 0.4])
        series[.sleepingHR] = make(56, 1.6, [0: 55, 2: 59])
        series[.steps] = make(8900, 2100, [0: 9420, 1: 12850, 2: 6120, 3: 10340, 4: 8770, 5: 11400, 6: 7930])
        series[.energy] = make(690, 140, [0: 720, 1: 980, 2: 470, 3: 760])
        series[.workoutMinutes] = make(190, 30, [0: 212, 1: 205, 2: 180])

        // Sleep: [asleep, deep, rem, awake, bedH, bedM] for nights 13 … 0 days ago.
        let plan: [[Double]] = [
            [418, 68, 88, 34, 23, 40], [455, 80, 97, 28, 23, 5], [402, 61, 79, 41, 0, 25],
            [470, 84, 104, 26, 22, 55], [436, 72, 93, 30, 23, 30], [389, 58, 72, 46, 0, 50],
            [481, 86, 108, 22, 22, 45], [445, 77, 95, 29, 23, 20], [428, 70, 90, 33, 23, 50],
            [396, 55, 70, 52, 1, 5], [462, 81, 102, 27, 23, 0], [451, 79, 99, 31, 23, 15],
            [438, 74, 96, 35, 23, 25], [432, 82, 101, 31, 23, 35]
        ]
        for (i, p) in plan.enumerated() {
            let wakeDay = days[days.count - 1 - (plan.count - 1 - i)]
            nights.append(Self.makeNight(wakeDay: wakeDay, asleep: p[0], deep: p[1], rem: p[2], awake: p[3],
                                         bedH: Int(p[4]), bedM: Int(p[5])))
        }
        series[.sleepTotal] = zip(nights, plan).map { DayValue(date: cal.startOfDay(for: $0.end), value: $1[0]) }
        series[.deepSleep] = zip(nights, plan).map { DayValue(date: cal.startOfDay(for: $0.end), value: $1[1]) }
        series[.remSleep] = zip(nights, plan).map { DayValue(date: cal.startOfDay(for: $0.end), value: $1[2]) }
        series[.awake] = zip(nights, plan).map { DayValue(date: cal.startOfDay(for: $0.end), value: $1[3]) }

        // Today's heart rate every 2 min from 07:00 to 17:40.
        for m in stride(from: 7 * 60, through: Self.endMinute, by: 2) {
            let x = Double(m)
            var base = 66 + 6 * sin(x / 95)
            if m > 12 * 60 + 10 && m < 12 * 60 + 55 { base = 132 + 12 * sin(x / 4) }   // lunchtime run
            if m > 9 * 60 && m < 11 * 60 { base += 14 }                               // stressful meeting
            hr.append(HRPoint(date: today.addingTimeInterval(x * 60), bpm: base + noise(3)))
        }
        for h in 0...17 {
            if h < 7 { stress.append((h, 0.2 + rnd() * 0.3)); continue }
            if h == 12 { stress.append((h, nil)); continue }
            if h == 9 || h == 10 { stress.append((h, 2.2 + rnd() * 0.4)); continue }
            if h == 15 { stress.append((h, 1.3)); continue }
            stress.append((h, 0.4 + rnd() * 0.5))
        }
    }

    /// 90-min cycles, deep early, REM late (same shape as data.js `makeNight`).
    /// Deviation: a bedtime after midnight (bedH < 12) is placed on the wake-up day, not the day before.
    static func makeNight(wakeDay: Date, asleep: Double, deep: Double, rem: Double, awake: Double,
                          bedH: Int, bedM: Int) -> SleepSession {
        let cal = Calendar.current
        let bedDay = bedH < 12 ? wakeDay : (cal.date(byAdding: .day, value: -1, to: wakeDay) ?? wakeDay)
        let start = cal.date(bySettingHour: bedH, minute: bedM, second: 0, of: bedDay) ?? bedDay
        let light = asleep - deep - rem
        var segs: [SleepSegment] = []
        var t = start
        let cycles = max(4, Int((asleep / 90).rounded()))
        let deepPer = [0.34, 0.28, 0.2, 0.1, 0.05, 0.03]
        let remPer = [0.08, 0.14, 0.18, 0.2, 0.2, 0.2]
        let sumD = deepPer.prefix(cycles).reduce(0, +)
        let sumR = remPer.prefix(cycles).reduce(0, +)
        func add(_ stage: SleepStage, _ min: Double) {
            guard min > 1 else { return }
            let end = t.addingTimeInterval(min * 60)
            segs.append(SleepSegment(stage: stage, start: t, end: end))
            t = end
        }
        for c in 0..<cycles {
            let d = deep * (c < deepPer.count ? deepPer[c] : 0.02) / sumD
            let r = rem * (c < remPer.count ? remPer[c] : 0.2) / sumR
            let l = light / Double(cycles)
            add(.light, l * 0.55)
            add(.deep, d)
            add(.light, l * 0.45)
            add(.rem, r)
            if c < cycles - 1 && awake > 0 { add(.awake, awake / Double(cycles - 1)) }
        }
        return SleepSession(start: start, end: t, segments: segs)
    }
}

// MARK: - HealthStore in demo mode

extension HealthStore {
    /// Fills every published value from `DemoDataset`, through the real pipeline
    /// (`MetricState.make`, `Scores.*`, `Insights.weeklyReport`). No HealthKit access.
    func loadDemo() {
        let now = Demo.now
        let d = DemoDataset(now: now)
        let cal = Calendar.current
        let today = d.today
        let minuteNow = Int(now.timeIntervalSince(today) / 60)
        // Share of the demo day (07:00 → 17:40) that has happened, for "so far today" totals.
        let dayShare = max(0, min(1, Double(minuteNow - 7 * 60) / Double(DemoDataset.endMinute - 7 * 60)))

        var new: [MetricID: MetricState] = [:]
        for id in MetricID.allCases {
            guard var s = d.series[id] else { continue }
            if Demo.dropsNotSent && id.isNotSentByGoogle { s = [] }
            if id == .steps || id == .energy { s = s.filter { $0.date < today } }
            new[id] = .make(id, series: s)
        }
        states = new

        let main = d.nights
        lastSleep = main.last(where: { $0.end <= now.addingTimeInterval(3600) && $0.end > now.addingTimeInterval(-30 * 3600) })
            ?? main.last
        sleepScore = Scores.sleepScore(lastSleep)
        recovery = Scores.recovery(states: new, lastSleep: lastSleep)
        recentNights = Array(main.suffix(14))

        let hrToday = d.hr.filter { $0.date <= now }
        todayHeartRate = hrToday
        latestSampleDate = hrToday.last?.date
        let rest = new[.restingHR]?.latest?.value ?? 60
        strain = hrToday.isEmpty ? nil : Scores.strain(points: hrToday, restingHR: rest, maxHR: d.maxHR)
        let workoutStart = today.addingTimeInterval(Double(d.workoutStartMinute) * 60)
        todayWorkouts = workoutStart <= now ? [WorkoutItem(name: "Run", start: workoutStart, minutes: d.workoutMinutes)] : []
        stepsToday = d.series[.steps]?.last.map { ($0.value * dayShare).rounded() }
        activeEnergyToday = d.series[.energy]?.last.map { ($0.value * dayShare).rounded() }

        stressHours = d.stress.compactMap { s -> StressHour? in
            guard let start = cal.date(byAdding: .hour, value: s.hour, to: today), start <= now else { return nil }
            let end = start.addingTimeInterval(3600)
            let pts = hrToday.filter { $0.date >= start && $0.date < end }.map(\.bpm)
            let avg = pts.isEmpty ? rest - 4 : pts.reduce(0, +) / Double(pts.count)
            return StressHour(start: start, level: s.level, avgBPM: avg)
        }

        // 14-day history: pipeline for every day, data.js values for the last 7, today = live scores.
        var days = Insights.history(states: new, nights: main, days: 14)
        for i in days.indices {
            let ago = cal.dateComponents([.day], from: days[i].date, to: today).day ?? 0
            guard let h = d.history.first(where: { $0.d == ago }) else { continue }
            let isToday = ago == 0
            days[i] = DaySummary(date: days[i].date,
                                 recovery: isToday ? (recovery?.score ?? h.recovery) : h.recovery,
                                 sleepMinutes: h.sleep,
                                 sleepScore: days[i].sleepScore,
                                 steps: isToday ? stepsToday : h.steps,
                                 strain: isToday ? (strain?.value ?? h.strain) : h.strain)
        }
        history = days
        age = d.age
        bodyAge = BodyAge(chronological: d.age, estimate: d.bodyAgeEstimate,
                          factors: d.bodyAgeFactors.map { AgeFactor(label: $0.0, years: $0.1, detail: $0.2) })
        weekly = Insights.weeklyReport(history: days, states: new, nights: main)

        bloodPressure = Self.demoBloodPressure(now: now)
        sourceRows = demoSourceRows(now: now)
        hasAsked = true
        errorMessage = nil
        isLoading = false
        lastRefresh = now
        JournalStore.current?.attach(history: days)
    }

    private func demoSourceRows(now: Date) -> [SourceRow] {
        let src = ["Google Health (sample data)"]
        func row(_ id: String, _ name: String, _ metric: MetricID?, _ unit: String, value: String? = nil) -> SourceRow {
            let s = metric.map { state($0) }
            let notSent = metric?.isNotSentByGoogle == true && s?.hasData != true
            let text = value ?? (s?.hasData == true ? s!.valueText + (unit.isEmpty ? "" : " " + unit)
                                 : (notSent ? MissingState.notSent.text : MissingState.noReading.text))
            return SourceRow(id: id, name: name, latestValue: text,
                             latestDate: notSent ? nil : (s?.latest?.date ?? now),
                             samples7d: notSent ? 0 : 7, sources: notSent ? [] : src)
        }
        var rows: [SourceRow] = [
            SourceRow(id: "HKQuantityTypeIdentifierHeartRate", name: "Heart rate",
                      latestValue: todayHeartRate.last.map { String(format: "%.0f bpm", locale: .current, $0.bpm) } ?? MissingState.noReading.text,
                      latestDate: todayHeartRate.last?.date, samples7d: 2_400, sources: src),
            row("HKQuantityTypeIdentifierRestingHeartRate", "Resting heart rate", .restingHR, "bpm"),
            row("HKQuantityTypeIdentifierHeartRateVariabilitySDNN", "HRV", .hrv, "ms"),
            row("HKQuantityTypeIdentifierRespiratoryRate", "Breathing rate", .breathing, "/min"),
            row("HKQuantityTypeIdentifierOxygenSaturation", "Blood oxygen (SpO2)", .spo2, "%"),
            row("HKQuantityTypeIdentifierAppleSleepingWristTemperature", "Sleeping wrist temp", .skinTemp, "°C"),
            SourceRow(id: "HKQuantityTypeIdentifierVO2Max", name: "VO2 max", latestValue: MissingState.notSent.text,
                      latestDate: nil, samples7d: 0, sources: []),
            row("HKQuantityTypeIdentifierStepCount", "Steps", nil, "",
                value: stepsToday.map { MetricID.steps.format($0) + " steps" }),
            row("HKQuantityTypeIdentifierActiveEnergyBurned", "Active energy", nil, "",
                value: activeEnergyToday.map { MetricID.energy.format($0) + " kcal" })
        ]
        let s = lastSleep
        rows.append(SourceRow(id: "sleep", name: "Last night’s sleep",
                              latestValue: s.map { MetricID.sleepTotal.format($0.asleepMinutes) } ?? MissingState.waiting.text,
                              latestDate: s?.end, samples7d: s?.segments.count ?? 0,
                              sources: s == nil ? [] : ["with stages"]))
        return rows
    }
}
