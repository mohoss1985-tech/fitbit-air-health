import Foundation
import HealthKit
import Observation

/// Reads Fitbit Air data that the Google Health app writes into Apple Health.
/// Read-only, on-device. This file makes no network calls.
@Observable
@MainActor
final class HealthStore {

    struct SourceRow: Identifiable {
        let id: String
        let name: String
        let latestValue: String
        let latestDate: Date?
        let samples7d: Int
        let sources: [String]
    }

    struct WorkoutItem: Identifiable {
        let id = UUID()
        let name: String
        let start: Date
        let minutes: Double
    }

    private let store = HKHealthStore()

    var hasAsked = UserDefaults.standard.bool(forKey: "mrh1.hasAskedHealth")
    var isLoading = false
    var errorMessage: String?
    var lastRefresh: Date?

    var states: [MetricID: MetricState] = [:]
    var lastSleep: SleepSession?
    var recovery: RecoveryResult?
    var strain: StrainResult?
    var sleepScore: Int?
    var todayHeartRate: [HRPoint] = []
    var todayWorkouts: [WorkoutItem] = []
    var stepsToday: Double?
    /// Active energy so far today, kcal (HealthKit de-duplicated). nil = no reading yet.
    var activeEnergyToday: Double?
    /// Newest heart-rate sample seen by the last refresh (freshness chip "Synced 23 min ago").
    var latestSampleDate: Date?
    var sourceRows: [SourceRow] = []
    var stressHours: [StressHour] = []
    var recentNights: [SleepSession] = []
    /// Last 14 days, oldest first (today last). Strain is filled for every day.
    var history: [DaySummary] = []
    var bodyAge: BodyAge?
    var weekly: WeeklyReport?
    var age: Int?

    var isAvailable: Bool { Demo.isOn || HKHealthStore.isHealthDataAvailable() }

    /// Days covered by `history`.
    static let historyDays = 14

    init() {
        BackgroundWatcher.shared.attach(self)
        if Demo.isOn { loadDemo() }
    }

    /// True while showing sample data (show the "Sample data" chip).
    var isDemo: Bool { Demo.isOn }

    /// Why a metric has no current value (`.notSent` for HRV / skin temp, never a zero).
    func missing(_ id: MetricID) -> MissingState? { state(id).missing }

    /// Greeting without a name (HealthKit has no name; v0.4 hard-coded one).
    func greeting(at date: Date = Demo.now) -> String {
        let h = Calendar.current.component(.hour, from: date)
        if h < 5 { return "Good evening" }
        if h < 12 { return "Good morning" }
        if h < 18 { return "Good afternoon" }
        return "Good evening"
    }

    /// Sync freshness for the chip: nil = never synced. Yellow after 3 h (DESIGN_SPEC §4).
    var syncAge: TimeInterval? { latestSampleDate.map { Demo.now.timeIntervalSince($0) } }
    var isSyncStale: Bool { (syncAge ?? .infinity) > 3 * 3600 }

    /// True when the latest night in Apple Health ended this morning.
    var isSleepFresh: Bool {
        guard let s = lastSleep else { return false }
        return Calendar.current.isDateInToday(s.end)
    }

    /// "Sun 1 Nov" for the morning the latest synced night ended.
    var sleepDayText: String {
        lastSleep?.end.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)) ?? ""
    }

    private let quantityIDs: [HKQuantityTypeIdentifier] = [
        .heartRate, .restingHeartRate, .heartRateVariabilitySDNN, .respiratoryRate,
        .oxygenSaturation, .appleSleepingWristTemperature, .bodyTemperature, .vo2Max,
        .stepCount, .activeEnergyBurned, .distanceWalkingRunning
    ]

    private var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = Set(quantityIDs.map { HKQuantityType($0) })
        types.insert(HKCategoryType(.sleepAnalysis))
        types.insert(HKObjectType.workoutType())
        if let dob = HKObjectType.characteristicType(forIdentifier: .dateOfBirth) { types.insert(dob) }
        return types
    }

    func state(_ id: MetricID) -> MetricState {
        states[id] ?? MetricState(id: id, series: [], latest: nil, baseline: nil, flag: .none)
    }

    // MARK: - Permission

    func requestAccess() async {
        if Demo.isOn { loadDemo(); return }
        guard isAvailable else {
            errorMessage = "Apple Health isn't available on this device."
            return
        }
        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
            hasAsked = true
            UserDefaults.standard.set(true, forKey: "mrh1.hasAskedHealth")
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Refresh

    func refresh() async {
        if Demo.isOn { loadDemo(); return }
        guard isAvailable else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        // Asks only for data types added since the last version; silent otherwise.
        try? await store.requestAuthorization(toShare: [], read: readTypes)

        let bpm = HKUnit.count().unitDivided(by: .minute())
        async let rhr = dailySeries(.restingHeartRate, unit: bpm, sum: false)
        async let hrv = dailySeries(.heartRateVariabilitySDNN, unit: .secondUnit(with: .milli), sum: false)
        async let resp = dailySeries(.respiratoryRate, unit: bpm, sum: false)
        async let spo2 = dailySeries(.oxygenSaturation, unit: .percent(), sum: false, scale: 100)
        async let wrist = dailySeries(.appleSleepingWristTemperature, unit: .degreeCelsius(), sum: false)
        async let body = dailySeries(.bodyTemperature, unit: .degreeCelsius(), sum: false)
        async let steps = dailySeries(.stepCount, unit: .count(), sum: true)
        async let energy = dailySeries(.activeEnergyBurned, unit: .kilocalorie(), sum: true)
        async let nights = sleepSessions(days: 31)
        async let workouts = workoutsList(days: 31)

        let today = Calendar.current.startOfDay(for: Date())
        let stepsAll = await steps
        let energyAll = await energy
        let sessions = await nights
        let workoutAll = await workouts
        let wristAll = await wrist
        let bodyAll = await body

        var new: [MetricID: MetricState] = [:]
        new[.restingHR] = .make(.restingHR, series: await rhr)
        new[.hrv] = .make(.hrv, series: await hrv)
        new[.breathing] = .make(.breathing, series: await resp)
        new[.spo2] = .make(.spo2, series: await spo2)
        new[.skinTemp] = .make(.skinTemp, series: wristAll.isEmpty ? bodyAll : wristAll)
        // Cumulative metrics: compare full days only (today is still in progress).
        new[.steps] = .make(.steps, series: stepsAll.filter { $0.date < today })
        new[.energy] = .make(.energy, series: energyAll.filter { $0.date < today })
        stepsToday = stepsAll.first(where: { $0.date >= today })?.value
        activeEnergyToday = energyAll.first(where: { $0.date >= today })?.value

        // Sleep: one value per night, dated by wake-up day.
        let main = sessions.filter { $0.asleepMinutes >= 180 }
        func nightly(_ f: (SleepSession) -> Double) -> [DayValue] {
            main.map { DayValue(date: Calendar.current.startOfDay(for: $0.end), value: f($0)) }
        }
        new[.sleepTotal] = .make(.sleepTotal, series: nightly { $0.asleepMinutes })
        let staged = main.filter(\.hasStages)
        new[.deepSleep] = .make(.deepSleep, series: staged.map { DayValue(date: Calendar.current.startOfDay(for: $0.end), value: $0.minutes(.deep)) })
        new[.remSleep] = .make(.remSleep, series: staged.map { DayValue(date: Calendar.current.startOfDay(for: $0.end), value: $0.minutes(.rem)) })
        new[.awake] = .make(.awake, series: nightly { $0.minutes(.awake) })

        // Workouts: rolling 7-day total, per day.
        var weekly: [DayValue] = []
        for offset in stride(from: 30, through: 0, by: -1) {
            guard let day = Calendar.current.date(byAdding: .day, value: -offset, to: today),
                  let from = Calendar.current.date(byAdding: .day, value: -6, to: day),
                  let to = Calendar.current.date(byAdding: .day, value: 1, to: day) else { continue }
            let total = workoutAll.filter { $0.start >= from && $0.start < to }.reduce(0) { $0 + $1.minutes }
            weekly.append(DayValue(date: day, value: total))
        }
        new[.workoutMinutes] = .make(.workoutMinutes, series: workoutAll.isEmpty ? [] : weekly)
        todayWorkouts = workoutAll.filter { $0.start >= today }

        // Last night = the most recent main sleep that ended in the last 30 hours.
        let recent = main.last(where: { $0.end > Date().addingTimeInterval(-30 * 3600) })
        lastSleep = recent

        // One heart-rate fetch for the whole history window (was ~21 sequential queries in v0.4).
        let hrFrom = Calendar.current.date(byAdding: .day, value: -(Self.historyDays + 1), to: today) ?? today
        let hrAll = await heartRate(from: hrFrom, to: Date())
        func hrSlice(_ from: Date, _ to: Date) -> [HRPoint] { hrAll.filter { $0.date >= from && $0.date < to } }
        latestSampleDate = hrAll.last?.date

        // Heart rate during sleep, from the raw heart-rate samples of that session.
        if let s = recent {
            let hr = hrSlice(s.start, s.end)
            if !hr.isEmpty {
                let avg = hr.reduce(0) { $0 + $1.bpm } / Double(hr.count)
                var series: [DayValue] = []
                // Earlier nights: average heart rate for each session (cheap enough for 30 nights).
                for night in main.suffix(14) where night.end != s.end {
                    let pts = hrSlice(night.start, night.end)
                    if !pts.isEmpty {
                        series.append(DayValue(date: Calendar.current.startOfDay(for: night.end),
                                               value: pts.reduce(0) { $0 + $1.bpm } / Double(pts.count)))
                    }
                }
                series.append(DayValue(date: Calendar.current.startOfDay(for: s.end), value: avg))
                new[.sleepingHR] = .make(.sleepingHR, series: series)
            }
        }

        states = new
        sleepScore = Scores.sleepScore(recent)
        recovery = Scores.recovery(states: new, lastSleep: recent)

        let hrToday = hrSlice(today, Date().addingTimeInterval(1))
        // Keep the chart light: about one point per minute.
        let step = max(hrToday.count / 900, 1)
        todayHeartRate = stride(from: 0, to: hrToday.count, by: step).map { hrToday[$0] }
        let rest = new[.restingHR]?.latest?.value ?? 60
        strain = hrToday.isEmpty ? nil : Scores.strain(points: hrToday, restingHR: rest, maxHR: maxHeartRate())
        let stepsHourly = await hourlySteps(from: today)
        stressHours = Insights.stress(hr: hrToday, stepsByHour: stepsHourly, restingHR: rest, maxHR: maxHeartRate())
        recentNights = Array(main.suffix(14))

        // Week history, with each day's strain from that day's heart rate.
        var days = Insights.history(states: new, nights: Array(main), days: Self.historyDays)
        let maxHR = maxHeartRate()
        for i in days.indices {
            guard let end = Calendar.current.date(byAdding: .day, value: 1, to: days[i].date) else { continue }
            let pts = Calendar.current.isDateInToday(days[i].date) ? hrToday : hrSlice(days[i].date, end)
            if !pts.isEmpty {
                days[i].strain = Scores.strain(points: pts, restingHR: rest, maxHR: maxHR).value
            }
        }
        history = days
        age = ageYears()
        bodyAge = Insights.bodyAge(age: age, states: new, nights: Array(main))
        self.weekly = Insights.weeklyReport(history: days, states: new, nights: Array(main))

        sourceRows = await buildSourceRows()
        lastRefresh = Date()
        JournalStore.current?.attach(history: days)
        Notifier.evaluate(self)
    }

    // MARK: - Queries

    private func dailySeries(_ id: HKQuantityTypeIdentifier, unit: HKUnit, sum: Bool, days: Int = 31, scale: Double = 1) async -> [DayValue] {
        let cal = Calendar.current
        let end = Date()
        let anchor = cal.startOfDay(for: end)
        guard let start = cal.date(byAdding: .day, value: -days, to: anchor) else { return [] }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let descriptor = HKStatisticsCollectionQueryDescriptor(
            predicate: .quantitySample(type: HKQuantityType(id), predicate: predicate),
            options: sum ? .cumulativeSum : .discreteAverage,
            anchorDate: anchor,
            intervalComponents: DateComponents(day: 1)
        )
        guard let collection = try? await descriptor.result(for: store) else { return [] }
        var out: [DayValue] = []
        collection.enumerateStatistics(from: start, to: end) { stats, _ in
            let q = sum ? stats.sumQuantity() : stats.averageQuantity()
            if let q {
                out.append(DayValue(date: stats.startDate, value: q.doubleValue(for: unit) * scale))
            }
        }
        return out
    }

    private func hourlySteps(from start: Date) async -> [Date: Double] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())
        let descriptor = HKStatisticsCollectionQueryDescriptor(
            predicate: .quantitySample(type: HKQuantityType(.stepCount), predicate: predicate),
            options: .cumulativeSum,
            anchorDate: start,
            intervalComponents: DateComponents(hour: 1)
        )
        guard let collection = try? await descriptor.result(for: store) else { return [:] }
        var out: [Date: Double] = [:]
        collection.enumerateStatistics(from: start, to: Date()) { stats, _ in
            if let q = stats.sumQuantity() { out[stats.startDate] = q.doubleValue(for: .count()) }
        }
        return out
    }

    private func heartRate(from: Date, to: Date) async -> [HRPoint] {
        let predicate = HKQuery.predicateForSamples(withStart: from, end: to)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: HKQuantityType(.heartRate), predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .forward)],
            limit: nil
        )
        let unit = HKUnit.count().unitDivided(by: .minute())
        guard let samples = try? await descriptor.result(for: store) else { return [] }
        return samples.map { HRPoint(date: $0.startDate, bpm: $0.quantity.doubleValue(for: unit)) }
    }

    /// Groups sleep-stage samples into whole nights (gaps under 90 min stay in the same night).
    private func sleepSessions(days: Int) async -> [SleepSession] {
        guard let start = Calendar.current.date(byAdding: .day, value: -days, to: Date()) else { return [] }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: HKCategoryType(.sleepAnalysis), predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .forward)],
            limit: nil
        )
        guard let all = try? await descriptor.result(for: store) else { return [] }

        // Keep one source only, so two apps never double-count the same night.
        let staged = all.filter { $0.value != HKCategoryValueSleepAnalysis.inBed.rawValue }
        var bySource: [String: Double] = [:]
        for s in staged {
            bySource[s.sourceRevision.source.bundleIdentifier, default: 0] += s.endDate.timeIntervalSince(s.startDate)
        }
        guard let best = bySource.max(by: { $0.value < $1.value })?.key else { return [] }
        let samples = staged.filter { $0.sourceRevision.source.bundleIdentifier == best }

        var sessions: [SleepSession] = []
        var current: [SleepSegment] = []
        var currentEnd: Date?

        func close() {
            guard let first = current.first, let end = currentEnd else { return }
            sessions.append(SleepSession(start: first.start, end: end, segments: current))
            current = []
            currentEnd = nil
        }

        for s in samples {
            guard let value = HKCategoryValueSleepAnalysis(rawValue: s.value) else { continue }
            let stage: SleepStage
            switch value {
            case .awake: stage = .awake
            case .asleepREM: stage = .rem
            case .asleepDeep: stage = .deep
            default: stage = .light   // asleepCore and asleepUnspecified
            }
            if let end = currentEnd, s.startDate.timeIntervalSince(end) > 90 * 60 { close() }
            current.append(SleepSegment(stage: stage, start: s.startDate, end: s.endDate))
            currentEnd = max(currentEnd ?? s.endDate, s.endDate)
        }
        close()
        return sessions
    }

    private func workoutsList(days: Int) async -> [WorkoutItem] {
        guard let start = Calendar.current.date(byAdding: .day, value: -days, to: Date()) else { return [] }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.workout(predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .forward)],
            limit: nil
        )
        guard let workouts = try? await descriptor.result(for: store) else { return [] }
        // Google Health and other apps can each write the same session, and auto-detected walks
        // can overlap a logged run. Merge overlapping time so a minute is only counted once.
        var items: [WorkoutItem] = []
        var lastEnd: Date? = nil
        for w in workouts {
            let start = max(w.startDate, lastEnd ?? .distantPast)
            guard w.endDate > start else { continue }
            items.append(WorkoutItem(name: w.workoutActivityType.displayName, start: w.startDate,
                                     minutes: w.endDate.timeIntervalSince(start) / 60))
            lastEnd = max(lastEnd ?? w.endDate, w.endDate)
        }
        return items
    }

    private func ageYears() -> Int? {
        guard let dob = try? store.dateOfBirthComponents(), let date = Calendar.current.date(from: dob) else { return nil }
        let years = Calendar.current.dateComponents([.year], from: date, to: Date()).year ?? 0
        return (years > 10 && years < 100) ? years : nil
    }

    private func maxHeartRate() -> Double {
        if let a = ageYears() { return 208 - 0.7 * Double(a) }
        return 185
    }

    // MARK: - Data sources screen (from v0.1)

    private func buildSourceRows() async -> [SourceRow] {
        let now = Date()
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
        let specs: [(HKQuantityTypeIdentifier, String, HKUnit, String, Double, Int)] = [
            (.heartRate, "Heart rate", HKUnit.count().unitDivided(by: .minute()), "bpm", 1, 0),
            (.restingHeartRate, "Resting heart rate", HKUnit.count().unitDivided(by: .minute()), "bpm", 1, 0),
            (.heartRateVariabilitySDNN, "HRV", .secondUnit(with: .milli), "ms", 1, 0),
            (.respiratoryRate, "Breathing rate", HKUnit.count().unitDivided(by: .minute()), "/min", 1, 1),
            (.oxygenSaturation, "Blood oxygen (SpO2)", .percent(), "%", 100, 0),
            (.appleSleepingWristTemperature, "Sleeping wrist temp", .degreeCelsius(), "°C", 1, 2),
            (.bodyTemperature, "Body temperature", .degreeCelsius(), "°C", 1, 2),
            (.vo2Max, "VO2 max", HKUnit(from: "ml/kg*min"), "ml/kg/min", 1, 1),
            (.stepCount, "Steps", .count(), "steps", 1, 0),
            (.activeEnergyBurned, "Active energy", .kilocalorie(), "kcal", 1, 0)
        ]
        var rows: [SourceRow] = []
        for (id, name, unit, suffix, mult, decimals) in specs {
            let predicate = HKQuery.predicateForSamples(withStart: weekAgo, end: now)
            let descriptor = HKSampleQueryDescriptor(
                predicates: [.quantitySample(type: HKQuantityType(id), predicate: predicate)],
                sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)],
                limit: nil
            )
            let samples = (try? await descriptor.result(for: store)) ?? []
            let latest = samples.first
            let notSent: Set<HKQuantityTypeIdentifier> = [.heartRateVariabilitySDNN, .appleSleepingWristTemperature, .bodyTemperature, .vo2Max]
            let missingText = notSent.contains(id) ? MissingState.notSent.text : MissingState.noReading.text
            let value = latest.map { String(format: "%.\(decimals)f", locale: .current, $0.quantity.doubleValue(for: unit) * mult) + " " + suffix } ?? missingText
            rows.append(SourceRow(id: id.rawValue, name: name, latestValue: value, latestDate: latest?.endDate,
                                  samples7d: samples.count,
                                  sources: Array(Set(samples.map { $0.sourceRevision.source.name })).sorted()))
        }
        let s = lastSleep
        rows.append(SourceRow(id: "sleep", name: "Last night’s sleep",
                              latestValue: s.map { MetricID.sleepTotal.format($0.asleepMinutes) } ?? MissingState.waiting.text,
                              latestDate: s?.end, samples7d: s?.segments.count ?? 0,
                              sources: s == nil ? [] : [s!.hasStages ? "with stages" : "no stages"]))
        return rows
    }
}

extension HKWorkoutActivityType {
    var displayName: String {
        switch self {
        case .running: return "Run"
        case .walking: return "Walk"
        case .cycling: return "Ride"
        case .rowing: return "Row"
        case .elliptical: return "Elliptical"
        case .traditionalStrengthTraining, .functionalStrengthTraining: return "Strength"
        case .swimming: return "Swim"
        case .hiking: return "Hike"
        case .yoga: return "Yoga"
        case .highIntensityIntervalTraining: return "HIIT"
        default: return "Workout"
        }
    }
}
