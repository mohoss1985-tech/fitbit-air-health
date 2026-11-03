# 05 · Live tab: technical approach

Agent: Live-tech research · 2 Nov 2026 · Drafts: `research/live-draft/LiveStore.swift`, `research/live-draft/BLEHeartRate.swift`
(both typecheck cleanly with all of `MRH1/*.swift` for `arm64-apple-ios17.0-simulator`, Swift 5 mode, with the draft replacing the Wave-0 stub `MRH1/LiveStore.swift`).

## 1. Findings (with sources)

**HKAnchoredObjectQuery is the right core.** Apple: an anchored query "grabs a snapshot of the data currently stored… It can also perform a long-running query that responds to updates (like an HKObserverQuery). Often, it's more efficient to set up and run a single anchored object query than to run separate sample and observer queries." The Swift-concurrency form `HKAnchoredObjectQueryDescriptor.results(for:)` (iOS 15.4+, fine for iOS 17) returns an `AsyncSequence`. Its first element is the snapshot. Each later element carries `addedSamples`, `deletedObjects` and `newAnchor`.
[developer.apple.com/documentation/healthkit/hkanchoredobjectquery](https://developer.apple.com/documentation/healthkit/hkanchoredobjectquery) · [results(for:)](https://developer.apple.com/documentation/healthkit/hkanchoredobjectquerydescriptor/results(for:))

**Background delivery is throttled. Treat it as a wake-up, not a stream.** Apple's `enableBackgroundDelivery(for:frequency:)` says "The system wakes your app… at most once per time period defined by the specified frequency. Some sample types have a maximum frequency of hourly… on iOS, step-count samples have an hourly maximum." The completion handler must be called. After 3 misses, HealthKit backs off and stops. Background delivery needs the `com.apple.developer.healthkit.background-delivery` entitlement (already in `MRH1.entitlements`). It isn't supported in the Simulator. Third-party SDK docs add that iOS may delay delivery further for battery reasons or while the phone is locked, because HealthKit data is protected while the device is locked.
[Apple: enableBackgroundDelivery](https://developer.apple.com/documentation/healthkit/hkhealthstore/enablebackgrounddelivery(for:frequency:withcompletion:)) · [Spike SDK: background delivery](https://docs.spikeapi.com/sdk-docs/flutter/background-delivery.md)

**Upstream latency sets the limit, not HealthKit.** Google Health 5.05 for iOS (Aug 2026) added direct export to Apple Health, including heart rate. HRV is not included. No source documents an export interval: outlets only describe "periodic" sync. Fitbit community threads describe HR syncing in batches, with roughly 10–15 min between pushes even inside Fitbit's own pipeline. The project already observed lags of "minutes to hours". **Design consequence:** "Live" over HealthKit means "as soon as Google Health writes", typically 5–60 min old. The UI must always show the sample's age, and it should separate *sample time* from *sync time*.
[MacRumors 3 Aug 2026](https://macrumors.com/2026/08/03/fitbit-apple-health-syncing) · [Droid-Life](https://www.droid-life.com/2026/08/03/google-health-adds-full-apple-health-sync/) · [Fitbit community: BPM sync delay](https://community.fitbit.com/t5/Blaze/FitBit-App-BPM-Sync-Delay/td-p/1599083)

**HealthKit also coalesces samples.** Apple's `heartRate` documentation says "Sample data may be condensed and/or coalesced by HealthKit". A sample can be an `HKQuantitySample` whose `count > 1`. The draft uses `startDate` plus the sample's average quantity. If Google Health writes series samples, expand them with `HKQuantitySeriesSampleQueryDescriptor` (open question, check on device).
[blakecrosley.com: five-second HR](https://blakecrosley.com/blog/five-second-heart-rate-healthkit)

**Range buckets.** `HKStatisticsCollectionQueryDescriptor` with `[.discreteMin, .discreteAverage, .discreteMax]` gives min, avg and max per interval in one query, and `HKStatisticsQueryDescriptor` gives the totals for the whole range. HealthStore already uses this API, so the pattern is proven in the codebase.

**Fitbit Air does broadcast HR over Bluetooth.** Google's support page lists Fitbit Air, Edge, Charge 6 and Pixel Watch 2+ as "compatible with fitness equipment or apps that use the Bluetooth Heart Rate Profile" (GATT service 0x180D, characteristic 0x2A37). On the Air it is turned on in **Google Health → Connections → Fitbit Air → Share heart rate**, with an "Always visible" toggle. It costs battery. Charge 6 connects to one receiver at a time. Caveats: Charge 6 forum users report a non-standard handshake that some receivers (Garmin, some Wahoo, Technogym, Life Fitness) can't complete. One ESPHome user saw 0x180D advertised but couldn't receive data. A May 2026 Reddit thread shows confusion about whether the Air supports it at all. **No one has documented a CoreBluetooth app reading it.** It must be tested on the owner's band before it is promised in the UI.
[Google Health Help 14236705](https://support.google.com/googlehealth/answer/14236705?hl=en) · [Android Central: first things to do with the Air](https://androidcentral.com/wearables/fitbit/first-things-you-should-do-with-google-fitbit-air) · [Fitbit community: Charge 6 HR broadcasting incompatibility](https://community.fitbit.com/t5/Charge-6/Charge-6-HR-broadcasting-incompatibility-I-ll-evaluate-workarounds-please/td-p/5577725) · [Home Assistant ESPHome thread](https://community.home-assistant.io/t/esphome-as-fitbit-exercise-equipment/786160) · [DC Rainmaker on Charge 6](https://dcrainmaker.com/2023/09/fitbit-announces-different.html)

**CoreBluetooth details.** `CBCentralManager` needs `NSBluetoothAlwaysUsageDescription`, otherwise the app crashes on first use. Creating the manager triggers the permission prompt, so it should be created lazily. The Simulator reports `.unsupported`. `retrieveConnectedPeripherals(withServices:)` finds a band that iOS is already connected to. Background reading would need `UIBackgroundModes = bluetooth-central`, which v1 doesn't need because the Live tab is a foreground feature.

**Free Apple ID (Personal Team) capabilities.** From Apple's *Supported capabilities (iOS)* table, rightmost "Apple Developer" column: App Groups ✓, Background Modes ✓, HealthKit ✓, Push Notifications ✗, Time Sensitive Notifications ✗, Siri ✗.
[developer.apple.com/help/account/reference/supported-capabilities-ios](https://developer.apple.com/help/account/reference/supported-capabilities-ios)

What this means for each feature:
- **Live Activity:** feasible with **local** ActivityKit updates (`Activity.request(…, pushType: nil)`, then `activity.update`). It needs no special entitlement, only `NSSupportsLiveActivities = YES` and a **Widget Extension target**. Push-updated Live Activities need APNs, which a free team can't use. Each update is limited to 4 KB, and the app must be running to update the activity, so it only makes sense while BLE streaming or the Live tab is open.
- **WidgetKit:** a home or lock-screen widget is feasible: an extension target plus an App Group to share a small snapshot. Each extension is one more App ID, and the 7-day expiry applies to every target.

Both need a new target in `project.pbxproj`, which this sprint's rules forbid. **Recommendation:** defer them to v1.1.
[ActivityKit](https://developer.apple.com/documentation/activitykit) · [Displaying live data with Live Activities](https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities)

**Usage strings.** These are already present as `INFOPLIST_KEY_*` build settings: `NSHealthShareUsageDescription` and `NSHealthUpdateUsageDescription`. These are needed for BLE: `INFOPLIST_KEY_NSBluetoothAlwaysUsageDescription` = *"MRH1 can read your Fitbit Air's live heart rate over Bluetooth when you turn on Share heart rate. Nothing leaves the iPhone."* The project has no Info.plist file. The key can only be added in the target's build settings, which means a `project.pbxproj` change. **Without it, `BLEHeartRate.start()` would crash.** The orchestrator or owner has to decide: either allow that one-line build-setting change, or keep BLE behind a disabled toggle until v1.1.

## 2. Recommended architecture

```
                 ┌───────────── HealthStore (existing, heavy refresh, Today/Body/Trends)
                 │  restingHR, age, lastSleep ──attach(health:)──┐
Apple Health ────┤                                               ▼
 (Google Health  │   HKAnchoredObjectQueryDescriptor(HR, last 26 h) ──► LiveStore (@Observable @MainActor)
  writes batches)│   HKObserverQuery(steps, energy, resp, SpO2)    ──►   series[26 h raw] → Live/1H/24H in memory
                 │   HKStatisticsCollectionQuery (7D, 30D, debounced 5 s) ─► cache
                 └── BackgroundWatcher (existing; add .heartRate .hourly, shared instance)
Fitbit Air ──BLE 0x180D/0x2A37 (opt-in)──► BLEHeartRate ──onReading──► LiveStore.blePoints (Live range only)
Simulator / -demo ──► DemoSignal (pure f(seed, t)) ──3 s ticks──► LiveStore
```

1. **One long-running anchored query** for HR, scoped to the last 26 h. It feeds `series`, which is sorted, de-duplicated by timestamp, honours deletions and is pruned to 26 h. Live, 1H and 24H are computed in memory from `series`, so they need no query per tap.
2. **7D and 30D** come from `HKStatisticsCollectionQueryDescriptor` (daily min/avg/max) plus one `HKStatisticsQueryDescriptor` for the range totals. They are re-run 5 s after the last delivery, because batches arrive in bursts.
3. **Today so far:** steps, energy and steps in the last hour come from `HKStatisticsQueryDescriptor .cumulativeSum` (HealthKit removes iPhone/band double counting). Strain and stress reuse `Scores.strain` and `Insights.stress` on today's points, so the numbers match the Today tab. They are refreshed on each HR delivery and on step/energy observer fires.
4. **Last night:** average breathing and SpO2 in the `lastSleep` window, taken from HealthStore. If no window is known, it falls back to 20:00 → 11:00. `nil` means "Not sent", never 0.
5. **Never call `HealthStore.refresh()` per sample** (code audit §1.7). LiveStore owns its own `HKHealthStore`. Code audit §1.1, the BackgroundWatcher bug where it uses a fresh `HealthStore()`, stays with the Data agent. Adding `.heartRate` there at `.hourly` is enough, because the foreground stream does the real work.
6. **Staleness.** `stalenessText` gives "Latest sample 4 min ago". `sourceText` gives "Google Health → Apple Health · synced 2 min ago". `freshness` (live <2 min / recent <20 min / stale <3 h / old) drives a status-colour dot. `now` ticks every 15 s (1 s in demo). The Live view may still use `TimelineView(.periodic(1 s))` as planned by the Live agent.
7. **BLE stays opt-in and best-effort.** Its points only replace the **Live** range and `latest`. 1H and later stay HealthKit-only, so Google Health's later copy of the same minutes is never double-counted.
8. **Demo mode is deterministic.** `bpm = f(seed, timestamp)` combines a circadian curve, sleep at ~54, smooth value noise, workouts at 07:15 every other day and 18:10 on weekdays, and beat jitter. The same timestamp always gives the same value, which makes screenshots reproducible. `-demoNow 17:40` pins the clock. It backfills 26 h at 1/min and 30 d at 1/5 min, then ticks every 3 s. `.demo(batched: true)` instead delivers 5-minute batches every 20 s, 15 min late, to test the stale UI. Steps, energy, breathing and SpO2 are deterministic too.

## 3. API sketch (as implemented in the draft)

It keeps the exact contract from `07-code-audit.md` §4 and adds extras. Note: the brief asked for `ObservableObject`, but the contract and `HealthStore` both use `@Observable`. The draft follows the codebase, inject it with `.environment(live)`.

```swift
enum LiveRange: String, CaseIterable, Identifiable { case live = "Live", h1 = "1H", h24 = "24H", d7 = "7D", d30 = "30D" }
struct HRBucket: Identifiable, Hashable { let start: Date; let min, avg, max: Double }
struct RangeStats { range, from, to, min?, avg?, max?, points /*Live raw*/, buckets }
enum LiveSource { case health, demo, bluetooth }   enum Freshness { case live, recent, stale, old, none }

@Observable @MainActor final class LiveStore {
  enum Mode { case health; case demo(seed: UInt64 = 7, reference: Date? = nil, batched: Bool = false)
              static var automatic: Mode }               // follows Demo.isOn, -demoNow HH:mm
  init(mode: Mode = .automatic)
  // contract
  var latestSampleDate: Date? ; var latestBPM: Double? ; var recentHR: [HRPoint]   // last 60 min
  var stepsLastHour: Double? ; var energyToday: Double?
  func buckets(_ r: LiveRange) -> [HRBucket]                 // 1-min · 1-min · hourly · daily · daily
  func stats(_ r: LiveRange) -> (min: Double, avg: Double, max: Double)?
  func start(health: HealthStore); func stop()
  // extras
  private(set) var latest: HRPoint?, latestSource: LiveSource?, lastDelivery: Date?, now: Date
  private(set) var series: [HRPoint]  /*26 h*/ , blePoints: [HRPoint], ranges: [LiveRange: RangeStats]
  var selectedRange: LiveRange ; var selected: RangeStats ; func summary(_:) -> RangeStats
  private(set) var today: TodaySoFar   // strain: StrainResult?, stressHours, stressNow, steps, energy, stepsLastHour
  private(set) var lastNight: LastNight // window, breathing?, spo2?  (nil = "Not sent")
  var stalenessText: String ; var sourceText: String ; var freshness: Freshness
  func attach(health:) ; func refresh() async ; func setMode(_:)
  private(set) var ble: BLEHeartRate? ; func connectBand() ; func disconnectBand()
}

@MainActor final class BLEHeartRate: NSObject, ObservableObject {   // CoreBluetooth delegate on .main
  enum Status { off, unsupported, unauthorized, poweredOff, scanning, connecting(String), connected(String), notFound; var text }
  struct Reading { date, bpm: Int, rrIntervals: [Double] /*s*/, contact: Bool?, energyKJ: Int? }
  var onReading: ((Reading) -> Void)? ; var preferredNames = ["Fitbit","Air","Charge","Pixel"]
  func start() /*lazy CBCentralManager → remembered → already-connected → scan 30 s*/ ; func stop() ; func forgetBand()
  nonisolated static func parse(_ data: Data, at: Date) -> Reading?   // SIG 0x2A37 flags: u16, contact, energy, RR/1024
}
```

## 4. Integration steps for the Data agent

1. Replace the stub `MRH1/LiveStore.swift` with the draft. Add `BLEHeartRate.swift` only if the Bluetooth usage string is approved (see §1). Otherwise remove `ble`, `connectBand` and `ingestBLE`, about 25 lines.
2. In `MRH1App`: `@State var live = LiveStore()`, then `.environment(live)`. On the Live tab: `.task { live.start(health: health) }` and `.onChange(of: health.lastRefresh) { live.attach(health: health) }`. Call `live.stop()` when the scene goes to background, since queries only matter in the foreground.
3. In `BackgroundWatcher`: add `HKQuantityType(.heartRate)` at `.hourly`.

## 5. Assumptions and open items

- The draft assumes Google Health writes discrete HR samples. It should be checked on device (`sample.count`).
- It assumes `HealthStore.age` and `state(.restingHR)` stay internal, as they are in v0.4.
- Persisting `newAnchor` isn't needed, because the snapshot is bounded to 26 h.
- The day-rollover restart in `startClock` is a safety net. A cleaner trigger is `.NSCalendarDayChanged`.
- BLE needs a device test with the owner's Air and Share heart rate turned on. If it doesn't connect, ship v1 without it. The HealthKit path already meets "Done means #3".
- The Live tab footer keeps the line: wellness estimates, not medical advice.
