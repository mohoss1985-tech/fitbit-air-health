# Wave 1 · C · Data layer: public API

Files: `MRH1/HealthStore.swift`, `LiveStore.swift`, `BLEHeartRate.swift` (new), `DemoData.swift`, `Notifier.swift`,
`Journal.swift` (new), `Settings.swift` (new), and the logic files `Metrics.swift`, `Scores.swift`, `Insights.swift`, `History.swift`.
All v0.4 names still exist. Everything below was **added**; nothing was renamed.
Build (`build/C`): my files compile with 0 errors and 0 warnings. The errors left at the time of writing are in other agents' files: `Components.swift` uses `flag.tier`, but A's Theme defines `Flag.statusTier`; `ContentView.swift` has a non-exhaustive switch.

## Inject (agent D)
```swift
@State var health = HealthStore()      // in demo, init() loads sample data synchronously and attaches itself to BackgroundWatcher
@State var live = LiveStore()          // = LiveStore(mode: .automatic)
@State var journal = JournalStore()    // = JournalStore(demo: Demo.isOn); registers as JournalStore.current
// Live tab: .task { live.start(health: health) }, .onChange(of: health.lastRefresh) { live.attach(health: health) }
// scene background: live.stop()
```

## Metrics.swift
```swift
enum Flag { case normal, high, low, none          // cases unchanged
  var color: Color            // normal → recovery(good), high/low → warn(limit), none → text3. No blue.
  var word: String            // "In range" | "Watch" | "Watch" | "—"
  var directionWord: String   // "Within your usual range" | "Above your usual range" | "Below your usual range" | "No reading"
  var shortDirection: String  // "Usual" | "Above" | "Below" | "—"
}
// Flag.statusTier and Flag.chipColors live in A's Theme.swift (StatusTier: inRange/watch/outOfRange)
enum MissingState: Hashable { case notSent, waiting, noReading
  var text: String       // "Not sent by Google Health" | "Waiting for sync" | "No reading"
  var shortText: String  // "Not sent" | "Waiting for sync" | "No reading"
}
extension MetricID { var isNotSentByGoogle: Bool /* hrv, skinTemp */ ; var isNightly: Bool }
extension MetricState {
  var baselineDays: Int; static let fullBaselineDays = 14
  var earlyReadText: String?   // "Early read: 6 of 14 baseline days."
  var missing: MissingState?   // nil = current value; .waiting = nightly value older than today
  var displayText: String      // valueText, or missing.shortText (never "0")
  var chipFlag: Flag           // better-than-usual → .normal
  var statusWord: String       // from A's MetricState.statusTier: "In range"/"Watch"/"Out of range"/"—"
  var directionText: String    // "Above your usual range" … (use instead of colour-only legends)
}
```
`yourRangeText` without a baseline is now "Learning your range (needs 3+ nights)".

## Scores.swift / Insights.swift / History.swift
```swift
extension RecoveryResult {
  static let allInputs: [MetricID]   // [.hrv, .restingHR, .breathing, .sleepTotal]
  var signalsUsed: Int; var signalsTotal: Int; var missingInputs: [MetricID]
  var signalsText: String?           // "3 of 4 signals" when an input is missing
}
Insights.movingWord: String          // "Moving" (draw in graphite2)
Insights.heatMapLegend: String       // replaces "blue = below"
BodyAge.missingBirthDateText: String // replaces the "Apple Santé" copy (owner of WeekViews swaps it in)
Insights.history(states:nights:days:)  // unchanged; HealthStore now passes 14
```

## HealthStore (additions)
```swift
var activeEnergyToday: Double?        // kcal so far today
var latestSampleDate: Date?           // newest HR sample (freshness chip)
var history: [DaySummary]             // now 14 days, oldest first, strain filled on every day
static let historyDays = 14
var isDemo: Bool
var syncAge: TimeInterval?; var isSyncStale: Bool   // > 3 h → yellow chip
init()                                // attaches BackgroundWatcher; loads demo when Demo.isOn
func missing(_ id: MetricID) -> MissingState?
func greeting(at date: Date = Demo.now) -> String   // "Good morning" etc., no name (removes hard-coded "Mo.")
func loadDemo()                       // DemoData.swift
```
`refresh()` / `requestAccess()` call `loadDemo()` in demo. `refresh()` now uses **one** heart-rate query for 15 days instead of about 21. `sourceRows` show "Not sent by Google Health" for HRV, wrist and body temperature, and VO2 max, and "No reading" for others; they never show a zero. Sleep with no data shows "Waiting for sync". Each refresh hands `history` to `JournalStore.current`.

## LiveStore (contract from research/07 §4, plus extras; implemented from the research/05 draft)
```swift
enum LiveRange: String, CaseIterable, Identifiable { live, h1, h24, d7, d30; var span; var bucket; var bucketSeconds; var isInMemory }
struct HRBucket: Identifiable, Hashable { start, min, avg, max }
struct RangeStats { range, from, to, min?, avg?, max?, points /*Live raw*/, buckets; var hasData; static func empty(_:now:) }
enum LiveSource: String { health, demo, bluetooth }   enum Freshness { live, recent, stale, old, none }
@Observable @MainActor final class LiveStore {
  enum Mode: Equatable { case health; case demo(seed: UInt64 = 7, reference: Date? = nil, batched: Bool = false)
                         var isDemo: Bool; static var automatic: Mode }
  struct TodaySoFar { strain: StrainResult?, stressHours: [StressHour], steps?, energy?, stepsLastHour?; var stressNow: StressHour? }
  struct LastNight { window: DateInterval?, breathing: Double?, spo2: Double? }   // nil = "No reading"
  init(mode: Mode = .automatic)
  // contract
  var latestSampleDate: Date?; var latestBPM: Double?; var recentHR: [HRPoint]   // last 60 min
  var stepsLastHour: Double?; var energyToday: Double?
  func buckets(_ r: LiveRange) -> [HRBucket]; func stats(_ r: LiveRange) -> (min: Double, avg: Double, max: Double)?
  func start(health: HealthStore); func stop()
  // extras
  private(set) var pulse: Int          // +1 on each new latest sample → OrbBackground(pulse:) / ripple
  private(set) var mode, isRunning, latest: HRPoint?, latestSource: LiveSource?, lastDelivery: Date?, now: Date
  private(set) var series: [HRPoint] /*26 h*/, blePoints, ranges: [LiveRange: RangeStats], today: TodaySoFar, lastNight: LastNight
  var selectedRange: LiveRange; var selected: RangeStats; func summary(_ r: LiveRange) -> RangeStats
  var freshness: Freshness; var stalenessText: String /* "Latest sample 4 min ago" */; var sourceText: String
  static func ago(_ d: Date, now: Date) -> String
  func start(); func attach(health: HealthStore); func attach(restingHR:age:lastSleep:); func refresh() async; func setMode(_:)
  // Bluetooth (opt-in)
  private(set) var ble: BLEHeartRate?
  func setBluetooth(enabled: Bool)     // writes AppSettings.bleEnabled and connects or disconnects
  var bluetoothStatusText: String      // "Off" / "Looking for your band…" / "Live from …"
  var isBluetoothConnected: Bool
  func connectBand(); func disconnectBand()
}
```
Health mode runs one `HKAnchoredObjectQueryDescriptor` for heart rate over the last 26 h, plus `HKObserverQuery` on steps, energy, breathing and SpO2. 7D and 30D come from `HKStatisticsCollectionQueryDescriptor`, debounced by 5 s. It never calls `HealthStore.refresh()`. Bluetooth starts only in health mode, and only when `AppSettings.bleEnabled` is set (checked on start and on each 15 s clock tick).
Demo mode uses the deterministic `DemoSignal` and adds a sample every **5 s**. Its "so far today" numbers (strain, stress, steps, energy) and its last-night breathing and SpO2 come from the demo HealthStore, so Live and Today show the same numbers.

## BLEHeartRate (new; the draft as-is)
```swift
@MainActor final class BLEHeartRate: NSObject, ObservableObject {
  enum Status: Equatable { off, unsupported, unauthorized, poweredOff, scanning, connecting(String), connected(String), notFound; var isConnected; var text }
  struct Reading: Equatable { date, bpm: Int, rrIntervals: [Double], contact: Bool?, energyKJ: Int? }
  @Published private(set) var status: Status; @Published private(set) var reading: Reading?
  var onReading: ((Reading) -> Void)?; var preferredNames: [String]
  func start(); func stop(); func forgetBand(); nonisolated static func parse(_ data: Data, at: Date = Date()) -> Reading?
}
```
`CBCentralManager` is created lazily, so the Bluetooth prompt appears only after the toggle is turned on. `NSBluetoothAlwaysUsageDescription` is already set in the build settings.

## JournalStore (Journal.swift)
```swift
struct JournalEntry: Codable, Identifiable, Hashable { var day: Date; var tags: Set<String> }
@Observable @MainActor final class JournalStore {
  static let defaultTags: [String]; static let discoveryThreshold = 5; private(set) static weak var current: JournalStore?
  struct DayScores: Codable, Hashable { var sleepScore: Int?; var recovery: Int? }
  private(set) var tags: [String]; private(set) var entries: [JournalEntry]; private(set) var scoreLog: [Date: DayScores]
  init(demo: Bool = Demo.isOn)
  func entries(for date: Date) -> Set<String>
  func isOn(_ tag: String, date: Date = Date()) -> Bool
  var taggedDays: Int; var progressText: String?    // "2 more tagged days to unlock discoveries"
  func toggle(tag: String, on date: Date = Date())              // flip
  func toggle(tag: String, on isOn: Bool, date: Date = Date())  // set
  func addTag(_ name: String); func removeTag(_ name: String)
  func attach(history: [DaySummary])                // HealthStore calls this on JournalStore.current
  var discoveries: [String]                         // after 5 or more tagged days; up to 3, e.g. "On late meal days, your sleep score averages 8 lower."
}
```
The journal is stored in `Application Support/journal.json` (entries, custom tags, and a score log so discoveries can look back more than 14 days). Demo mode seeds 9 tagged days in memory and never writes the file.

## Settings (Settings.swift)
```swift
enum AppSettings {                 // typealias Settings = AppSettings
  enum Key { static let morning = "mrh1.notif.morning"; static let drift = "mrh1.notif.drift"; static let bleEnabled = "mrh1.ble.enabled" }
  enum Default { static let morning = true; static let drift = true; static let bleEnabled = false }
  static var morningNotification: Bool { get set }; static var driftNotification: Bool { get set }; static var bleEnabled: Bool { get set }
}
// View: @AppStorage(AppSettings.Key.morning) var morning = AppSettings.Default.morning
// BLE toggle: .onChange(of: bleOn) { live.setBluetooth(enabled: bleOn) }
```

## Demo (DemoData.swift)
```swift
enum Demo {
  static let isOn: Bool            // "-demo", or Simulator unless "-realHealth"
  static let dropsNotSent: Bool    // "-demoNotSent": drops HRV and skin temp to show the "Not sent" states
  static func pinnedNow(_ args: [String] = …) -> Date?   // "-demoNow HH:MM"
  static let launchNow: Date; static var now: Date        // pinned start + elapsed time (use for time-of-day copy)
  static let chipText = "Sample data"
}
struct DemoDataset { init(now: Date = Demo.now); series, nights, hr, stress, history, bodyAge…; static func makeNight(…) }
```
This is a straight port of `web/demo/data.js`: the same LCG (seed 42), the same call order and the same overrides. The values go through `MetricState.make`, `Scores.recovery/sleepScore/strain` and `Insights.history/weeklyReport`. Stress, body age and the last 7 days of history come from data.js; today's recovery and strain use the pipeline values. Where my port differs from data.js:
1. Bedtimes after midnight are placed on the wake-up day. data.js puts them on the day before, which is a bug there.
2. Steps and energy so far today are scaled by how much of the 07:00 → 17:40 window has passed. Heart rate and workouts are clipped at `Demo.now`.
3. HRV and skin temperature stay in, following the audit. `-demoNotSent` shows the real pipeline, where they are missing.

## Notifier
- `Notifier.evaluate` does nothing in demo mode and follows `AppSettings.morningNotification` and `driftNotification`.
- `Notifier.driftTitle(_ count:) -> String` returns "2 signals are outside your usual range". Its body ends with "Your body may need more rest. Consider an easy day." It names no illness and never says "danger".
- `BackgroundWatcher.shared.attach(_ health: HealthStore)` binds the watcher to the shared store; `HealthStore.init` calls it.
- `.heartRate` is now observed, at most one refresh every 15 min. Wakes are debounced by 3 s. `start()` returns early in demo mode.

## Open items
- My files reference only A's `StatusTier` and `MetricState.statusTier`. Components.swift calls `flag.tier`, which needs a fix by A.
- Discovery wording such as "averages 8 lower" stays under 14 words, but it is a correlation, not a cause.
- BLE still needs a test on a real device with Share heart rate turned on.
