import Foundation
import HealthKit
import Observation

// MARK: - Ranges

/// Live tab range picker: Live · 1H · 24H · 7D · 30D.
enum LiveRange: String, CaseIterable, Identifiable {
    case live = "Live", h1 = "1H", h24 = "24H", d7 = "7D", d30 = "30D"
    var id: String { rawValue }

    /// How far back the range looks from "now".
    var span: TimeInterval {
        switch self {
        case .live: return 30 * 60
        case .h1: return 3600
        case .h24: return 24 * 3600
        case .d7: return 7 * 86400
        case .d30: return 30 * 86400
        }
    }

    /// Bucket width for the chart. `nil` = raw samples (Live).
    var bucket: DateComponents? {
        switch self {
        case .live: return nil
        case .h1: return DateComponents(minute: 1)
        case .h24: return DateComponents(hour: 1)
        case .d7, .d30: return DateComponents(day: 1)
        }
    }

    var bucketSeconds: TimeInterval {
        switch self {
        case .live: return 0
        case .h1: return 60
        case .h24: return 3600
        case .d7, .d30: return 86400
        }
    }

    /// Ranges short enough to compute from the raw samples LiveStore keeps in memory (26 h).
    var isInMemory: Bool { self == .live || self == .h1 || self == .h24 }
}

struct HRBucket: Identifiable, Hashable {
    let start: Date
    let min: Double
    let avg: Double
    let max: Double
    var id: Date { start }
}

struct RangeStats {
    let range: LiveRange
    let from: Date
    let to: Date
    let min: Double?
    let avg: Double?
    let max: Double?
    /// Raw points for `.live`, empty otherwise.
    let points: [HRPoint]
    /// Min/avg/max per bucket for 1H…30D (draw as a range band + avg line).
    let buckets: [HRBucket]

    var hasData: Bool { avg != nil }

    static func empty(_ r: LiveRange, now: Date) -> RangeStats {
        RangeStats(range: r, from: now.addingTimeInterval(-r.span), to: now,
                   min: nil, avg: nil, max: nil, points: [], buckets: [])
    }
}

enum LiveSource: String { case health = "Apple Health", demo = "Demo", bluetooth = "Bluetooth" }

/// Drives the colour of the "latest sample" pill (status colours only, never brand).
enum Freshness {
    case live      // < 2 min
    case recent    // < 20 min
    case stale     // < 3 h  (normal for Google Health batch sync)
    case old       // older
    case none
}

// MARK: - LiveStore

/// Data layer for the Live tab. Owns its own long-running HealthKit queries so the big
/// `HealthStore.refresh()` never has to re-run when one heart-rate sample lands.
///
/// Health mode: one `HKAnchoredObjectQueryDescriptor` stream for heart rate (snapshot of the last
/// 26 h, then every add/delete), `HKObserverQuery` on steps / active energy / breathing / SpO2 to
/// refresh the "so far today" and "last night" numbers, and `HKStatisticsCollectionQueryDescriptor`
/// for the 7D / 30D buckets (re-run, debounced, after each delivery).
/// Demo mode: deterministic synthetic data, a new sample every few seconds (Simulator, screenshots).
///
/// Implements the Live contract in research/07-code-audit.md §4 (names kept identical) plus extras
/// the Live tab needs: today-so-far, last night, staleness text, demo mode, optional Bluetooth.
@Observable
@MainActor
final class LiveStore {

    enum Mode: Equatable {
        case health
        /// `reference` freezes the demo clock start for reproducible screenshots.
        case demo(seed: UInt64 = 7, reference: Date? = nil, batched: Bool = false)

        var isDemo: Bool { if case .demo = self { return true } else { return false } }

        /// Follows `Demo.isOn` (DemoData.swift: `-demo`, or Simulator without `-realHealth`).
        /// `-demoNow 17:40` pins the demo clock (today at 17:40) for screenshots.
        static var automatic: Mode {
            guard Demo.isOn else { return .health }
            return .demo(reference: demoNowArgument())
        }

        static func demoNowArgument(_ args: [String] = ProcessInfo.processInfo.arguments) -> Date? {
            guard let i = args.firstIndex(of: "-demoNow"), i + 1 < args.count else { return nil }
            let parts = args[i + 1].split(separator: ":").compactMap { Int($0) }
            guard parts.count == 2 else { return nil }
            return Calendar.current.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: Date())
        }
    }

    struct TodaySoFar {
        var strain: StrainResult?
        var stressHours: [StressHour] = []
        var steps: Double?
        var energy: Double?          // kcal
        var stepsLastHour: Double?
        /// Latest hour with a stress level (nil while moving or no data).
        var stressNow: StressHour? { stressHours.last(where: { $0.level != nil }) }
    }

    struct LastNight {
        var window: DateInterval?
        var breathing: Double?       // breaths / min, nil = "Not sent"
        var spo2: Double?            // %, nil = "Not sent"
    }

    // Published state ------------------------------------------------------------------------

    private(set) var mode: Mode
    private(set) var isRunning = false
    private(set) var latest: HRPoint?
    private(set) var latestSource: LiveSource?
    /// When MRH1 last *received* new samples (sync time), as opposed to the sample's own time.
    private(set) var lastDelivery: Date?
    /// Raw HealthKit (or demo) heart rate, ascending, last 26 h.
    private(set) var series: [HRPoint] = []
    /// Bluetooth readings (≈1 Hz) for the last 30 min, only when BLE is connected.
    private(set) var blePoints: [HRPoint] = []
    private(set) var ranges: [LiveRange: RangeStats] = [:]
    var selectedRange: LiveRange = .live
    private(set) var today = TodaySoFar()
    private(set) var lastNight = LastNight()
    /// Ticks every 15 s (1 s in demo) so staleness text stays true without a TimelineView.
    private(set) var now = Date()

    // Contract names (07-code-audit §4) ------------------------------------------------------

    var latestSampleDate: Date? { latest?.date }
    var latestBPM: Double? { latest?.bpm }
    /// Last 60 min, raw (Bluetooth points when connected, else HealthKit / demo).
    var recentHR: [HRPoint] {
        let from = now.addingTimeInterval(-3600)
        return (blePoints.isEmpty ? series : blePoints).filter { $0.date >= from }
    }
    var stepsLastHour: Double? { today.stepsLastHour }
    var energyToday: Double? { today.energy }

    /// Chart buckets: Live / 1H 1-min, 24H hourly, 7D / 30D daily.
    func buckets(_ r: LiveRange) -> [HRBucket] {
        let s = summary(r)
        if r == .live, s.buckets.isEmpty { return Self.bucketize(s.points, width: 60) }
        return s.buckets
    }

    /// min / avg / max for the range, nil when there is no heart rate in it.
    func stats(_ r: LiveRange) -> (min: Double, avg: Double, max: Double)? {
        let s = summary(r)
        guard let lo = s.min, let av = s.avg, let hi = s.max else { return nil }
        return (lo, av, hi)
    }

    /// Optional BLE source. Created lazily so the Bluetooth prompt only appears on demand.
    private(set) var ble: BLEHeartRate?

    // Inputs reused from HealthStore (attach after its refresh) -------------------------------

    private var restingHR: Double = 60
    private var maxHR: Double = 185
    private var lastSleep: SleepSession?

    // Internals --------------------------------------------------------------------------------

    private let store = HKHealthStore()
    private let bpm = HKUnit.count().unitDivided(by: .minute())
    private var tasks: [Task<Void, Never>] = []
    private var observers: [HKObserverQuery] = []
    private var longRangeTask: Task<Void, Never>?
    private var cache: [LiveRange: RangeStats] = [:]   // 7D / 30D from HealthKit
    private var sampleDates: [UUID: Date] = [:]        // to honour HealthKit deletions
    private var demo: DemoSignal?
    private var demoClockStart = Date()
    private var demoReference = Date()
    private static let keepRaw: TimeInterval = 26 * 3600

    init(mode: Mode = .automatic) {
        self.mode = mode
    }

    // MARK: Public API

    func start() {
        guard !isRunning else { return }
        isRunning = true
        switch mode {
        case .health: startHealth()
        case let .demo(seed, reference, batched): startDemo(seed: seed, reference: reference, batched: batched)
        }
        startClock()
    }

    func stop() {
        tasks.forEach { $0.cancel() }
        tasks = []
        longRangeTask?.cancel()
        observers.forEach { store.stop($0) }
        observers = []
        isRunning = false
    }

    func setMode(_ m: Mode) {
        guard m != mode else { return }
        stop()
        series = []; blePoints = []; latest = nil; cache = [:]; ranges = [:]
        mode = m
        start()
    }

    /// Contract entry point: reuse HealthStore's resting HR, age and last night, then start.
    func start(health: HealthStore) {
        attach(health: health)
        start()
    }

    /// Call again after each `HealthStore.refresh()` (e.g. `.onChange(of: health.lastRefresh)`).
    func attach(health: HealthStore) {
        attach(restingHR: health.state(.restingHR).latest?.value, age: health.age, lastSleep: health.lastSleep)
    }

    /// Reuse what HealthStore already computed (resting HR, age-based max HR, last night).
    func attach(restingHR: Double?, age: Int?, lastSleep: SleepSession?) {
        if let r = restingHR { self.restingHR = r }
        if let a = age { maxHR = 208 - 0.7 * Double(a) }
        self.lastSleep = lastSleep
        guard isRunning, mode == .health else { return }
        tasks.append(Task { await refreshTotals(); await refreshLastNight() })
    }

    /// Pull-to-refresh / scene became active.
    func refresh() async {
        guard mode == .health else { return }
        await refreshTotals()
        await refreshLastNight()
        await refreshLongRanges()
    }

    /// Full summary (bounds, raw points for Live, buckets).
    func summary(_ r: LiveRange) -> RangeStats { ranges[r] ?? .empty(r, now: now) }
    var selected: RangeStats { summary(selectedRange) }

    // MARK: Bluetooth (optional)

    func connectBand() {
        let b = ble ?? BLEHeartRate()
        ble = b
        b.onReading = { [weak self] r in self?.ingestBLE(r) }
        b.start()
    }

    func disconnectBand() {
        ble?.stop()
        blePoints = []
        recomputeInMemory()
    }

    // MARK: Staleness

    var freshness: Freshness {
        guard let d = latest?.date else { return .none }
        let age = now.timeIntervalSince(d)
        if age < 120 { return .live }
        if age < 20 * 60 { return .recent }
        if age < 3 * 3600 { return .stale }
        return .old
    }

    /// Always visible on the Live tab: "Latest sample 4 min ago".
    var stalenessText: String {
        guard let d = latest?.date else {
            return mode == .health ? "No heart rate in Apple Health yet" : "Waiting for demo data"
        }
        return "Latest sample " + Self.ago(d, now: now)
    }

    /// Second line: where the number comes from and when it last synced.
    var sourceText: String {
        switch latestSource {
        case .bluetooth?: return "Live from your band over Bluetooth"
        case .demo?: return "Demo data · simulated samples"
        case .health?:
            let sync = lastDelivery.map { "synced " + Self.ago($0, now: now) } ?? "waiting for sync"
            return "Google Health → Apple Health · \(sync)"
        case nil: return ""
        }
    }

    static func ago(_ d: Date, now: Date) -> String {
        let s = max(0, now.timeIntervalSince(d))
        if s < 45 { return "just now" }
        let m = Int((s / 60).rounded())
        if m < 60 { return "\(m) min ago" }
        let h = m / 60
        if h < 24 { return m % 60 == 0 ? "\(h) h ago" : "\(h) h \(m % 60) min ago" }
        return d.formatted(.dateTime.weekday(.abbreviated).hour().minute())
    }

    // MARK: - Health mode

    private func startHealth() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        tasks.append(Task { await streamHeartRate() })
        tasks.append(Task {
            await loadRestingHRIfNeeded()
            await refreshTotals()
            await refreshLastNight()
            await refreshLongRanges()
        })
        // Steps / energy change the "so far today" row; breathing / SpO2 arrive after the night syncs.
        let watched: [HKQuantityTypeIdentifier] = [.stepCount, .activeEnergyBurned, .respiratoryRate, .oxygenSaturation]
        for id in watched {
            let q = HKObserverQuery(sampleType: HKQuantityType(id), predicate: nil) { [weak self] _, done, error in
                done()   // foreground-only observer; BackgroundWatcher handles background wakes
                guard error == nil else { return }
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if id == .stepCount || id == .activeEnergyBurned { await self.refreshTotals() }
                    else { await self.refreshLastNight() }
                }
            }
            store.execute(q)
            observers.append(q)
        }
    }

    /// Snapshot of the last 26 h, then every new / deleted heart-rate sample as Google Health writes them.
    private func streamHeartRate() async {
        let start = Date().addingTimeInterval(-Self.keepRaw)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: nil)
        let descriptor = HKAnchoredObjectQueryDescriptor(
            predicates: [.quantitySample(type: HKQuantityType(.heartRate), predicate: predicate)],
            anchor: nil   // could persist newAnchor; not needed since the snapshot is bounded to 26 h
        )
        do {
            for try await result in descriptor.results(for: store) {
                for s in result.addedSamples { sampleDates[s.uuid] = s.startDate }
                let added = result.addedSamples.map { HRPoint(date: $0.startDate, bpm: $0.quantity.doubleValue(for: bpm)) }
                let deleted = Set(result.deletedObjects.compactMap { sampleDates.removeValue(forKey: $0.uuid) })
                apply(added: added, deletedDates: deleted)
                if !added.isEmpty {
                    lastDelivery = Date()
                    await refreshTotals()            // strain / stress depend on today's HR
                    scheduleLongRangeRefresh()
                }
            }
        } catch {
            // Authorization missing or query cancelled; the tab shows the empty state.
        }
    }

    /// Merges new points into `series` (sorted, de-duplicated by timestamp, pruned to 26 h).
    private func apply(added: [HRPoint], deletedDates: Set<Date> = []) {
        guard !added.isEmpty || !deletedDates.isEmpty else { return }
        var byDate = Dictionary(series.map { ($0.date, $0) }, uniquingKeysWith: { a, _ in a })
        for d in deletedDates { byDate[d] = nil }
        for p in added { byDate[p.date] = p }
        let cutoff = (mode.isDemo ? now : Date()).addingTimeInterval(-Self.keepRaw)
        series = byDate.values.filter { $0.date >= cutoff }.sorted { $0.date < $1.date }
        // Bluetooth points are always newer, so a late HealthKit batch never overrides them.
        if let last = series.last, latestSource != .bluetooth || last.date > (latest?.date ?? .distantPast) {
            latest = last
            latestSource = mode.isDemo ? .demo : .health
        }
        recomputeInMemory()
    }

    private func scheduleLongRangeRefresh() {
        longRangeTask?.cancel()
        longRangeTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(5))     // batch deliveries arrive in bursts
            guard !Task.isCancelled else { return }
            await self?.refreshLongRanges()
        }
    }

    /// 7D and 30D: min / avg / max per bucket straight from HealthKit statistics.
    private func refreshLongRanges() async {
        for r in [LiveRange.d7, .d30] {
            if let s = await healthStats(r) { cache[r] = s }
        }
        recomputeInMemory()
    }

    private func healthStats(_ r: LiveRange) async -> RangeStats? {
        let end = Date()
        let start = end.addingTimeInterval(-r.span)
        let cal = Calendar.current
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let type = HKQuantityType(.heartRate)
        let collection = HKStatisticsCollectionQueryDescriptor(
            predicate: .quantitySample(type: type, predicate: predicate),
            options: [.discreteMin, .discreteAverage, .discreteMax],
            anchorDate: cal.startOfDay(for: end),
            intervalComponents: r.bucket ?? DateComponents(day: 1)
        )
        let whole = HKStatisticsQueryDescriptor(
            predicate: .quantitySample(type: type, predicate: predicate),
            options: [.discreteMin, .discreteAverage, .discreteMax]
        )
        guard let c = try? await collection.result(for: store) else { return nil }
        var buckets: [HRBucket] = []
        c.enumerateStatistics(from: start, to: end) { s, _ in
            guard let lo = s.minimumQuantity(), let av = s.averageQuantity(), let hi = s.maximumQuantity() else { return }
            buckets.append(HRBucket(start: s.startDate, min: lo.doubleValue(for: self.bpm),
                                    avg: av.doubleValue(for: self.bpm), max: hi.doubleValue(for: self.bpm)))
        }
        let all = try? await whole.result(for: store)
        return RangeStats(range: r, from: start, to: end,
                          min: all?.minimumQuantity()?.doubleValue(for: bpm),
                          avg: all?.averageQuantity()?.doubleValue(for: bpm),
                          max: all?.maximumQuantity()?.doubleValue(for: bpm),
                          points: [], buckets: buckets)
    }

    /// Steps + energy so far today (deduplicated by HealthKit), strain and stress from today's HR.
    private func refreshTotals() async {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let todayHR = series.filter { $0.date >= start }
        var t = TodaySoFar()
        if mode == .health {
            t.steps = await sumToday(.stepCount, unit: .count(), from: start)
            t.energy = await sumToday(.activeEnergyBurned, unit: .kilocalorie(), from: start)
            t.stepsLastHour = await sumToday(.stepCount, unit: .count(), from: Date().addingTimeInterval(-3600))
            let hourly = await hourlySteps(from: start)
            t.stressHours = Insights.stress(hr: todayHR, stepsByHour: hourly, restingHR: restingHR, maxHR: maxHR)
        } else if let demo {
            t.steps = demo.steps(at: now)
            t.energy = demo.energy(at: now)
            t.stepsLastHour = demo.steps(at: now) - demo.steps(at: max(start, now.addingTimeInterval(-3600)))
            t.stressHours = Insights.stress(hr: todayHR, stepsByHour: demo.hourlySteps(dayStart: start, now: now),
                                            restingHR: restingHR, maxHR: maxHR)
        }
        t.strain = todayHR.isEmpty ? nil : Scores.strain(points: todayHR, restingHR: restingHR, maxHR: maxHR)
        today = t
    }

    private func sumToday(_ id: HKQuantityTypeIdentifier, unit: HKUnit, from start: Date) async -> Double? {
        let d = HKStatisticsQueryDescriptor(
            predicate: .quantitySample(type: HKQuantityType(id),
                                       predicate: HKQuery.predicateForSamples(withStart: start, end: Date())),
            options: .cumulativeSum)
        return (try? await d.result(for: store))?.sumQuantity()?.doubleValue(for: unit)
    }

    private func hourlySteps(from start: Date) async -> [Date: Double] {
        let d = HKStatisticsCollectionQueryDescriptor(
            predicate: .quantitySample(type: HKQuantityType(.stepCount),
                                       predicate: HKQuery.predicateForSamples(withStart: start, end: Date())),
            options: .cumulativeSum, anchorDate: start, intervalComponents: DateComponents(hour: 1))
        guard let c = try? await d.result(for: store) else { return [:] }
        var out: [Date: Double] = [:]
        c.enumerateStatistics(from: start, to: Date()) { s, _ in
            if let q = s.sumQuantity() { out[s.startDate] = q.doubleValue(for: .count()) }
        }
        return out
    }

    /// Average breathing rate and SpO2 inside last night's sleep window.
    private func refreshLastNight() async {
        let window = lastSleep.map { DateInterval(start: $0.start, end: $0.end) } ?? Self.fallbackNight()
        var n = LastNight(window: window)
        n.breathing = await average(.respiratoryRate, unit: bpm, in: window)
        n.spo2 = await average(.oxygenSaturation, unit: .percent(), in: window).map { $0 * 100 }
        lastNight = n
    }

    private func average(_ id: HKQuantityTypeIdentifier, unit: HKUnit, in w: DateInterval) async -> Double? {
        let d = HKStatisticsQueryDescriptor(
            predicate: .quantitySample(type: HKQuantityType(id),
                                       predicate: HKQuery.predicateForSamples(withStart: w.start, end: w.end)),
            options: .discreteAverage)
        return (try? await d.result(for: store))?.averageQuantity()?.doubleValue(for: unit)
    }

    /// 20:00 yesterday → 11:00 today when HealthStore hasn't found a sleep session.
    static func fallbackNight(now: Date = Date()) -> DateInterval {
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        let s = cal.date(byAdding: .hour, value: -4, to: today) ?? today
        let e = cal.date(byAdding: .hour, value: 11, to: today) ?? now
        return DateInterval(start: s, end: max(s.addingTimeInterval(60), min(e, now)))
    }

    private func loadRestingHRIfNeeded() async {
        let d = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: HKQuantityType(.restingHeartRate))],
            sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)], limit: 1)
        if let s = try? await d.result(for: store).first { restingHR = s.quantity.doubleValue(for: bpm) }
    }

    // MARK: - In-memory ranges (Live, 1H, 24H) + cached 7D / 30D

    private func recomputeInMemory() {
        let t = mode.isDemo ? now : Date()
        var out = cache
        for r in LiveRange.allCases where r.isInMemory {
            let from = t.addingTimeInterval(-r.span)
            // Live prefers 1 Hz Bluetooth points when connected; everything else stays HealthKit-only
            // so Google Health's later copy of the same minutes is never double-counted.
            let source = (r == .live && !blePoints.isEmpty) ? blePoints : series
            let pts = source.filter { $0.date >= from && $0.date <= t }
            out[r] = Self.summarize(r, points: pts, from: from, to: t)
        }
        ranges = out
    }

    nonisolated static func summarize(_ r: LiveRange, points pts: [HRPoint], from: Date, to: Date) -> RangeStats {
        guard !pts.isEmpty else {
            return RangeStats(range: r, from: from, to: to, min: nil, avg: nil, max: nil, points: [], buckets: [])
        }
        let values = pts.map(\.bpm)
        let buckets = r.bucketSeconds > 0 ? bucketize(pts, width: r.bucketSeconds) : []
        // Note: avg is sample-weighted. Google Health samples are roughly evenly spaced, so this
        // matches HealthKit's discreteAverage used for 7D / 30D.
        return RangeStats(range: r, from: from, to: to, min: values.min(),
                          avg: values.reduce(0, +) / Double(values.count), max: values.max(),
                          points: r == .live ? pts : [], buckets: buckets)
    }

    /// Fixed-width buckets. Day buckets use local midnight, not UTC.
    nonisolated static func bucketize(_ pts: [HRPoint], width w: TimeInterval) -> [HRBucket] {
        let cal = Calendar.current
        let grouped = Dictionary(grouping: pts) { p -> Date in
            if w >= 86400 { return cal.startOfDay(for: p.date) }
            return Date(timeIntervalSince1970: floor(p.date.timeIntervalSince1970 / w) * w)
        }
        return grouped.keys.sorted().compactMap { k in
            let v = grouped[k]!.map(\.bpm)
            guard let lo = v.min(), let hi = v.max() else { return nil }
            return HRBucket(start: k, min: lo, avg: v.reduce(0, +) / Double(v.count), max: hi)
        }
    }

    // MARK: - Clock

    private func startClock() {
        let interval: Duration = mode.isDemo ? .seconds(1) : .seconds(15)
        tasks.append(Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: interval)
                guard let self else { return }
                self.now = self.clockNow()
                // Live / 1H windows slide even when nothing arrives.
                if self.mode == .health { self.recomputeInMemory() }
                // Day rolled over: restart the stream so its 26 h window moves on.
                if let first = self.series.first, self.now.timeIntervalSince(first.date) > Self.keepRaw + 3600,
                   self.mode == .health {
                    self.stop(); self.start(); return
                }
            }
        })
    }

    private func clockNow() -> Date {
        guard mode.isDemo else { return Date() }
        return demoReference.addingTimeInterval(Date().timeIntervalSince(demoClockStart))
    }

    // MARK: - Bluetooth merge

    private func ingestBLE(_ r: BLEHeartRate.Reading) {
        let p = HRPoint(date: r.date, bpm: Double(r.bpm))
        let cutoff = r.date.addingTimeInterval(-LiveRange.live.span)
        blePoints.append(p)
        if let i = blePoints.firstIndex(where: { $0.date >= cutoff }), i > 0 { blePoints.removeFirst(i) }
        latest = p
        latestSource = .bluetooth
        now = Date()
        recomputeInMemory()
    }

    // MARK: - Demo mode

    private func startDemo(seed: UInt64, reference: Date?, batched: Bool) {
        let signal = DemoSignal(seed: seed)
        demo = signal
        demoClockStart = Date()
        demoReference = reference ?? Date()
        restingHR = signal.restingHR
        maxHR = 185
        let t0 = clockNow()
        now = t0

        // Backfill 26 h at one point per minute (like Google Health), then 7D / 30D buckets.
        let from = t0.addingTimeInterval(-Self.keepRaw)
        series = stride(from: from.timeIntervalSince1970, through: t0.timeIntervalSince1970, by: 60).map {
            let d = Date(timeIntervalSince1970: $0)
            return HRPoint(date: d, bpm: signal.bpm(at: d))
        }
        latest = series.last
        latestSource = .demo
        lastDelivery = t0
        for r in [LiveRange.d7, .d30] {
            let start = t0.addingTimeInterval(-r.span)
            let pts = stride(from: start.timeIntervalSince1970, through: t0.timeIntervalSince1970, by: 300).map {
                HRPoint(date: Date(timeIntervalSince1970: $0), bpm: signal.bpm(at: Date(timeIntervalSince1970: $0)))
            }
            cache[r] = Self.summarize(r, points: pts, from: start, to: t0)
        }
        let night = Self.fallbackNight(now: t0)
        lastNight = LastNight(window: night, breathing: signal.breathing(night: night.start),
                              spo2: signal.spo2(night: night.start))
        recomputeInMemory()
        tasks.append(Task { await refreshTotals() })

        // New samples: every 3 s (streaming feel) or a batch of 5 min every 20 s (Google-Health feel).
        let tick: Duration = batched ? .seconds(20) : .seconds(3)
        tasks.append(Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: tick)
                guard let self, let demo = self.demo else { return }
                let t = self.clockNow()
                let lastDate = self.series.last?.date ?? t.addingTimeInterval(-60)
                let step: TimeInterval = batched ? 60 : 3
                let newPoints = stride(from: lastDate.timeIntervalSince1970 + step,
                                       through: (batched ? t.addingTimeInterval(-15 * 60) : t).timeIntervalSince1970,
                                       by: step).map {
                    HRPoint(date: Date(timeIntervalSince1970: $0), bpm: demo.bpm(at: Date(timeIntervalSince1970: $0)))
                }
                self.now = t
                guard !newPoints.isEmpty else { continue }
                self.lastDelivery = t
                self.apply(added: newPoints)
                await self.refreshTotals()
            }
        })
    }
}

// MARK: - Deterministic demo signal

/// Heart rate as a pure function of (seed, time): the same timestamp always gives the same bpm,
/// so screenshots and previews are reproducible regardless of when the app started.
struct DemoSignal {
    let seed: UInt64
    let restingHR = 56.0

    /// Hash → [0, 1).
    private func noise(_ k: Int64, _ salt: UInt64 = 0) -> Double {
        var x = UInt64(bitPattern: k) &+ seed &* 0x9E37_79B9_7F4A_7C15 &+ salt
        x = (x ^ (x >> 30)) &* 0xBF58_476D_1CE4_E5B9
        x = (x ^ (x >> 27)) &* 0x94D0_49BB_1331_11EB
        x ^= x >> 31
        return Double(x >> 11) / Double(1 << 53)
    }

    /// Smooth value noise with a period of `p` seconds, in [-1, 1].
    private func smooth(_ t: TimeInterval, period p: Double, salt: UInt64) -> Double {
        let u = t / p
        let k = Int64(floor(u))
        let f = u - floor(u)
        let s = f * f * (3 - 2 * f)
        return (noise(k, salt) * (1 - s) + noise(k + 1, salt) * s) * 2 - 1
    }

    func bpm(at d: Date) -> Double {
        let cal = Calendar.current
        let c = cal.dateComponents([.hour, .minute, .weekday], from: d)
        let hour = Double(c.hour ?? 12) + Double(c.minute ?? 0) / 60
        let t = d.timeIntervalSince1970
        var v: Double
        if hour < 6.5 || hour >= 23.5 {
            v = restingHR - 2 + 3 * smooth(t, period: 1800, salt: 1)          // asleep
        } else {
            v = 72 + 6 * sin((hour - 9) / 14 * .pi)                           // daytime drift
            v += 8 * smooth(t, period: 900, salt: 2)                           // moving around
        }
        // Workouts: 07:15–07:55 every other day, 18:10–18:50 on weekdays.
        let day = Int64(floor(t / 86400))
        if day % 2 == 0, hour >= 7.25, hour < 7.92 { v += 70 * workoutShape((hour - 7.25) / 0.67) }
        if let w = c.weekday, (2...6).contains(w), hour >= 18.17, hour < 18.83 {
            v += 60 * workoutShape((hour - 18.17) / 0.66)
        }
        v += 1.6 * smooth(t, period: 20, salt: 3)                              // beat-level jitter
        return (v * 10).rounded() / 10
    }

    private func workoutShape(_ x: Double) -> Double {
        let ramp = min(1, x / 0.15) * min(1, (1 - x) / 0.2)
        return max(0, ramp) * (0.85 + 0.15 * sin(x * 18))
    }

    /// Cumulative steps since midnight (deterministic, monotone).
    func steps(at d: Date) -> Double {
        let start = Calendar.current.startOfDay(for: d)
        let hours = d.timeIntervalSince(start) / 3600
        var total = 0.0
        var h = 0.0
        while h < hours {
            let slice = min(0.25, hours - h)
            total += stepRate(hour: h, day: start) * slice
            h += 0.25
        }
        return total.rounded()
    }

    private func stepRate(hour: Double, day: Date) -> Double {
        if hour < 7 || hour > 22.5 { return 0 }
        let k = Int64(day.timeIntervalSince1970 / 900 + hour * 4)
        return 250 + 900 * noise(k, 4) + ((7.25..<7.92).contains(hour) ? 5000 : 0)
    }

    func hourlySteps(dayStart: Date, now: Date) -> [Date: Double] {
        var out: [Date: Double] = [:]
        var h = dayStart
        while h < now {
            let next = h.addingTimeInterval(3600)
            out[h] = steps(at: min(next, now)) - steps(at: h)
            h = next
        }
        return out
    }

    func energy(at d: Date) -> Double { (steps(at: d) * 0.045).rounded() }

    func breathing(night: Date) -> Double {
        ((14.4 + 0.8 * noise(Int64(night.timeIntervalSince1970 / 86400), 5)) * 10).rounded() / 10
    }

    func spo2(night: Date) -> Double {
        ((95.8 + 1.6 * noise(Int64(night.timeIntervalSince1970 / 86400), 6)) * 10).rounded() / 10
    }
}
