# 07 · Code audit of v0.4 + v1 build plan

Agent 07, 2 Nov 2026. I read all 17 files in `MRH1/*.swift` (2,859 lines) and `design/v1-direction/index.html`, and checked `web/demo/data.js`.

## 1. Build result

- `xcodebuild -project MRH1.xcodeproj -scheme MRH1 -sdk iphonesimulator -configuration Debug -derivedDataPath build CODE_SIGNING_ALLOWED=NO build` → **BUILD SUCCEEDED, 0 errors, 0 Swift warnings.** The only warning is the usual AppIntents metadata one. Full log: `build/build-audit.log`. The app is at `build/Build/Products/Debug-iphonesimulator/MRH1.app`.
- **The sandbox blocks the build.** CoreSimulatorService says "Connection refused" and xcrun says "couldn't create cache file … Operation not permitted". Every `xcodebuild` / `simctl` call needs `dangerouslyDisableSandbox: true`.
- Scheme `MRH1`, one target. Project settings: `objectVersion 77`, `fileSystemSynchronizedGroups` (new files in `MRH1/` are picked up, including `.metal`), `IPHONEOS_DEPLOYMENT_TARGET = 17.0`, `SWIFT_VERSION = 5.0` (no strict concurrency, no default MainActor isolation), iPhone only, bundle `com.mrh.MRH1`. Entitlements: HealthKit + background-delivery.
- Simulators (iOS 27.2): **iPhone 18 Pro `16FB8DCB-0649-4B07-852E-5DF98C491C17` (Booted)**, 18 Pro Max, 17e, Air, 17, Duo.

## 2. Architecture map

| File | Purpose | Key types / API used by views |
|---|---|---|
| `MRH1App.swift` | `@main`. Creates `@State HealthStore`, starts `BackgroundWatcher`, **forces `.preferredColorScheme(.dark)`** | `.environment(health)` |
| `ContentView.swift` | 4-tab `TabView` (Today · Panels · Trends · Guide), `ConnectView` (first launch), `DataSourcesView`, `View.withRoutes()` router | `Route` → `ScoreDetailView`, `PanelsView`, `PanelDetailView`, `GuideView`, `DataSourcesView` |
| `HealthStore.swift` | `@Observable @MainActor final class`. All HealthKit reads, one big `refresh()` that computes everything | see §4. `store` and every query func are **private** |
| `Metrics.swift` | `Flag`, `Panel` (heart/lungs/sleep/activity), `MetricInfo`, `MetricID` (13 cases, all copy texts + `format`), `DayValue`, `Baseline`, `MetricState` (`.make`, `isConcern`, `color`, `band`, `valueText`, `yourRangeText`, `spark`) | logic + copy; **references `Theme.*` colours** |
| `Scores.swift` | `SleepStage/Segment/Session`, `Contributor`, `RecoveryResult`, `Scores.recovery/recoveryColor/verdict/strainTarget/sleepScore/strain`, `HRPoint`, `StrainResult` | pure functions |
| `Insights.swift` | `StressHour`, `Insights.stress/stressColor/stressWord/sleepDebt/bedtimeSpread/consistencyScore/direction/trend`, `Insights.Trend` | pure |
| `History.swift` | `DaySummary`, `AgeFactor`, `BodyAge`, `WeeklyReport`, `Insights.history/bodyAge/weeklyReport` | pure |
| `Notifier.swift` | `Notifier.requestPermission/evaluate(health)` (morning summary + drift alert, once a day each, `UserDefaults` keys `mrh1.morningSent`/`mrh1.driftSent`); `BackgroundWatcher` (HKObserverQuery on sleep, RHR, resp, HRV, hourly background delivery) | — |
| `Theme.swift` | Dark v0.3 palette (`background, card, cardRaised, inset, line, text2, text3, recovery, warn, low, bad, strain, sleep, heart, lungs, activity, stage*, band, bandEdge`, tracks), `Color(hex:)` | used by every file, logic files included |
| `Components.swift` | `RingView`, `FlagPill`, `RangeBar`, `Sparkline`, `Card`, `MetricRow` | shared |
| `TodayView.swift` | `TodayView`; **also defines `Route`, `ScoreKind`, `StageBar`** | — |
| `TodayCards.swift` | `StressCard`, `HealthMonitorCard` (+ drift banner), `SleepBalanceCard`, `SleepInfo`, **`ExplainSheet`** (shared) | — |
| `WeekViews.swift` | `WeekStrip` (Today), `WeeklyReportCard` (Today on Mondays + Trends), `BodyAgeCard` | — |
| `ScoreDetailView.swift` | Recovery / Strain / Sleep detail, `Hypnogram` | Swift Charts |
| `PanelViews.swift` | `PanelsView`, `PanelDetailView`, **`GuideView`** | — |
| `MetricSheet.swift` | Lab-result sheet with the interactive Week/Month chart | Swift Charts |
| `TrendsView.swift` | Weekly report, body age, 13 week-vs-week trend cards | — |

**Problems the build agents need to know about**
1. `BackgroundWatcher` refreshes a **new** `HealthStore()`, not the app's instance, so observer wake-ups never update the UI. Live needs observers bound to the shared store.
2. Logic colours are tied to Theme names: `Flag.color`, `MetricState.color`, `Scores.recoveryColor`, `Insights.stressColor`, `SleepStage.color`, `Panel.tint`. The new Theme must **keep these names as aliases**, or the logic files break.
3. Blue is used in many places: `Theme.low` #7DBBFF ("Low" flag), `Theme.strain` #4DA3FF, `activity`, `stageLight`, `stageREM`, the "Moving" stress bars, and the Guide/heat-map copy "blue = below". v1 bans blue, so these need new values and new copy.
4. Missing data shows "Not shared yet" (MetricRow) or "—". v1 wants **"Not sent"** for HRV, skin temperature and VO2.
5. The greeting has "Mo." hard-coded. The body-age copy says "Apple Santé" (French).
6. `history` covers only 7 days. The v1 Recovery detail shows "Last 14 days", so `Insights.history(days: 14)` is needed (14 extra HR queries for strain; strain for days 8–14 can be skipped).
7. `refresh()` is heavy: about 21 sequential HR queries plus the sources rows. Live must update incrementally and never call `refresh()` on every sample.
8. `RingView` re-animates on every appear. v1 wants the ring fill only on the first open of the day.

## 3. Complete v0.4 feature inventory → v1 home

| # | v0.4 feature (file) | v1 home |
|---|---|---|
| 1 | ConnectView: permission explainer + Connect button + error (ContentView) | Onboarding (expanded: data path + 14-day learning) |
| 2 | Tab bar Today/Panels/Trends/Guide | Today · Live · Body · Trends, with the Guide moved to the menu |
| 3 | Date + greeting + verdict header (TodayView) | Today header over the orbs |
| 4 | 3 animated rings (Recovery/Strain/Sleep), tap → detail | Today top, glass card + status chip + advice sentence |
| 5 | Stale-sync banner | Header line "Synced 07:42" (keep the full explanation as a tap/ⓘ) |
| 6 | Weekly report card on Mondays | Today (Mondays) + Trends |
| 7 | Strain target bar + advice text | Today, ember fill |
| 8 | Stress today: 24 hourly bars, current level, legend, "Moving", last-sync note, ⓘ ExplainSheet | Today (green/yellow/red; "Moving" in neutral ink, not blue) |
| 9 | Body panels strip (4 capsules, "N to watch") → Panels | Today, links to the Body tab (not in the design table, keep it) |
| 10 | Drift banner "N SIGNALS DRIFTING" | Today, above the health monitor |
| 11 | Health monitor heat map, 5 vitals × 7 nights, tap a name → MetricSheet | Today (grey "not sent" cells) |
| 12 | Last-night card: times, asleep, StageBar → Sleep detail | Today |
| 13 | Sleep debt + Consistency tiles, each with an ExplainSheet | Today · Your week |
| 14 | Swipeable week strip (7 day cards: recovery ring, sleep, strain, steps) | Today: day circles at the top + day cards |
| 15 | "Updated HH:MM" footer, pull to refresh | Today header/footer; pull to refresh on every tab |
| 16 | Toolbar → Data sources | Menu |
| 17 | Recovery detail: ring header, contributor z-bars → MetricSheet, calibrating checklist | ScoreDetail (+ new 14-day chart and "How it's computed") |
| 18 | Strain detail: header, HR-today line chart, 5 zone bars, workouts today | ScoreDetail |
| 19 | Sleep detail: header with efficiency, Hypnogram + legend, 4 MetricRows, not-synced state | ScoreDetail |
| 20 | Panels overview: summary + 4 panel cards | Body tab header / segmented panels |
| 21 | Panel detail: MetricRow ×n (value, unit, flag pill, RangeBar, 7-day sparkline, ⓘ) | Body tab |
| 22 | MetricSheet: value/pill, RangeBar, your range vs typical adult, what, if higher/lower, Week/Month chart (band area, coloured points, drag-select annotation, haptic), empty states, disclaimer | Sheet (ⓘ everywhere), drawer curve |
| 23 | ExplainSheet (stress, sleep debt, consistency, body age) | Sheet |
| 24 | Trends: intro, empty state, 13 trend cards (sentence, 14 bars, week before/last 7) → MetricSheet | Trends |
| 25 | Body age card (estimate, sentence, factors, ⓘ, no-DOB state) | Trends |
| 26 | Results guide (Scores, per-panel metrics, Colours) | **Menu** top-left (update the colour copy) |
| 27 | Data sources list (per type: latest, samples 7d, relative date, sources; footer; refresh) | Menu → screen |
| 28 | Notification: morning summary | Settings in the menu (toggle) |
| 29 | Notification: drift alert (2+ vitals) | Settings in the menu (toggle) |
| 30 | Notification permission at launch, HKObserver background delivery | App shell / data layer |
| 31 | Disclaimer "Wellness estimate…, not a medical test" | All sheets + menu |
| New | Live tab · journal tags (+ on Today) · settings toggles · orbs · "Not sent" HRV · Walking HR row in the Body mock (`walkingHeartRateAverage`, not read in v0.4: optional) · "Blood pressure: no sensor" on Live | — |

Settings in v0.4: none in the UI. Only `mrh1.hasAskedHealth` exists.

## 4. Data model surface for the new views (read-only bindings)

`@Environment(HealthStore.self) var health`
- Status: `hasAsked, isLoading, errorMessage, lastRefresh: Date?, isAvailable, isSleepFresh, sleepDayText`
- Scores: `recovery: RecoveryResult?` (`score`, `contributors[Contributor(id,label,z,valueText)]`), `strain: StrainResult?` (`value 0–21`, `zoneMinutes[5]`, `maxHR`), `sleepScore: Int?`
- Metrics: `state(_ MetricID) -> MetricState`, `states`. `MetricState`: `series[DayValue]`, `latest`, `baseline(mean,sd,low,high)`, `flag`, `hasData`, `isConcern`, `color`, `valueText`, `band`, `yourRangeText`, `spark`. `MetricID.info` (name, sub, unit, typicalText, what, ifHigh, ifLow, panel), `.format(v)`. `Panel.allCases`, `.metrics`, `.title/.short/.tint`
- Day data: `todayHeartRate[HRPoint(date,bpm)]` (≈900 pts), `todayWorkouts[WorkoutItem(name,start,minutes)]`, `stepsToday`, `stressHours[StressHour(start, level?, avgBPM)]`
- Sleep: `lastSleep: SleepSession?` (`start,end,segments,minutes(stage),asleepMinutes,efficiency,hasStages`), `recentNights` (14)
- Week: `history[DaySummary(date,recovery,sleepMinutes,sleepScore,steps,strain)]` (7), `weekly: WeeklyReport?`, `bodyAge: BodyAge?`, `age`
- Sources: `sourceRows[SourceRow(name,latestValue,latestDate,samples7d,sources)]`
- Helpers: `Scores.verdict/recoveryColor/strainTarget`, `Insights.stressWord/stressColor/sleepDebt/bedtimeSpread/consistencyScore/trend/direction`
- Actions: `await health.requestAccess()`, `await health.refresh()`

**New Live contract.** The Data agent implements it and the Live agent codes against it from day one. Stored properties can't live in an extension, so this is a separate class injected with `.environment(live)`:
```swift
enum LiveRange: String, CaseIterable, Identifiable { case live = "Live", h1 = "1H", h24 = "24H", d7 = "7D", d30 = "30D"; var id: String { rawValue } }
struct HRBucket: Identifiable { let start: Date; let min: Double; let avg: Double; let max: Double; var id: Date { start } }
@Observable @MainActor final class LiveStore {
  var latestSampleDate: Date?          // "latest sample N min ago" (use TimelineView for the ticker)
  var latestBPM: Double?
  var recentHR: [HRPoint]              // last 60 min, raw, appended by HKAnchoredObjectQuery
  func buckets(_ r: LiveRange) -> [HRBucket]   // live/1H raw→1-min, 24H hourly, 7D/30D daily
  func stats(_ r: LiveRange) -> (min: Double, avg: Double, max: Double)?
  var stepsLastHour: Double?; var energyToday: Double?
  // strain/stress/steps today + last night breathing/SpO2 come from HealthStore (strain, stressHours.last, stepsToday, state(.breathing/.spo2))
  func start(health: HealthStore); func stop()   // HKObserverQuery(heartRate, steps, energy) + anchored query; no full refresh()
}
```
The Data agent must make `HealthStore.store` and `heartRate(from:to:)` non-private (or let LiveStore own its own `HKHealthStore`), add `.heartRate` to `BackgroundWatcher`, and point the observer at the shared instance. It also adds `activeEnergyToday` (currently filtered out of `.energy`) and history for 14 days.

## 5. Demo mode

**No demo or sample-data mode exists.** `grep demo|simulator|ProcessInfo` finds nothing. On the Simulator, HealthKit is available but empty, so every screen shows empty states.

Plan:
1. `DemoData.swift` (new, Data agent) contains `enum Demo { static var isOn: Bool }`. It is true when `ProcessInfo.processInfo.arguments.contains("-demo")`, or when `#if targetEnvironment(simulator)` and the args don't contain `-realHealth`. Launch with `xcrun simctl launch booted com.mrh.MRH1 -demo`.
2. Port `web/demo/data.js` exactly: an LCG `seed = 42; seed = seed*16807 % 2147483647; rnd = (seed-1)/2147483646`, `noise(sd) = (rnd()+rnd()+rnd()-1.5)*sd*1.15`. Keep the same call order (`series()` for restingHR, hrv, breathing, spo2, skinTemp, sleepingHR, steps, energy, workoutMinutes, each over 31 days with the same overrides), then the 14-night `plan` → `makeNight` cycles (deep early, REM late) → `[SleepSession]`, today's HR every 2 min from 07:00 (lunchtime run 12:10–12:55, meeting bump 9–11h), the stress array, `history` (7 days), `bodyAge`, `workoutsToday`, `zones`, age 38 / maxHR 182. Use a `Double`/`Int64` LCG so it doesn't overflow.
3. `extension HealthStore { func loadDemo() }` in the same file. It sets only internal vars, so private access isn't a problem. Run raw series through **`MetricState.make`**, then `Scores.recovery/sleepScore/strain` and `Insights.weeklyReport`, so the flags, bands and contributors are real outputs of the pipeline. `stressHours`, `history` and `bodyAge` come straight from data.js. `sourceRows` are synthetic, with the source "Fitbit (demo)". Clip today's HR at `min(now, 17:40)`, or pin the clock for screenshots with `-demoNow 17:40`.
4. Hooks (Data agent, 3 lines): at the top of `refresh()`, `if Demo.isOn { loadDemo(); hasAsked = true; lastRefresh = Date(); return }`. In `requestAccess()` and `BackgroundWatcher.start()`, return early. `Notifier.evaluate` is skipped in demo.
5. `LiveStore` in demo: seed 30 days of daily HR buckets (min ≈ resting − 3, avg ≈ 72 ± noise, max from strain) and 24 h of hourly buckets. Run a `Timer` that appends one HR point (72 ± 4) every 5 s, so the chart visibly moves and "latest sample 3 s ago" is real.
6. Screenshot hooks (App shell agent): `-tab today|live|body|trends`, `-open recovery|strain|sleep|menu|journal`, plus `-uiLight` / `-uiDark`. This lets `screenshots/` be captured with `simctl io booted screenshot`, without UI automation.
7. Show a small "Sample data" chip in the header while demo is on, so it's honest.

## 6. File ownership split

**Wave 0 (one agent, sequential, about 15 min, must build green before Wave 1).** This agent moves shared types out of feature files so nobody edits another agent's file. Names stay the same and nothing is rewritten.
- `Route` + `ScoreKind` (TodayView) → `Routes.swift`
- `ExplainSheet` + `SleepInfo` (TodayCards) → `ExplainSheet.swift`
- `StageBar` (TodayView) + `Hypnogram` (ScoreDetailView) → `SleepGraphics.swift`
- `GuideView` (PanelViews) → `GuideMenu.swift`
- `WeekStrip` (WeekViews) → `TodayWeek.swift`
- `DataSourcesView` (ContentView) → `DataSourcesView.swift`
- Add stub files with the agreed signatures: `LiveStore.swift` (contract above, empty bodies), `LiveView.swift` (`struct LiveView: View`), `MenuView.swift`, `JournalSheet.swift`, `OrbBackground.swift` (`struct OrbBackground: View { var status: Flag?; var evening: Bool }`), `Motion.swift`.

**Wave 1, parallel.** Each agent edits only its own files. All other files are read-only for it.

| Agent | Owns (creates / rewrites) | Notes |
|---|---|---|
| A · Theme + Components | `Theme.swift`, `Components.swift`, `Motion.swift`, new `Typography.swift` | Light paper + dark tokens from the design (`paper, ink, ink2, ink3, hair, card, ember, good/limit/danger + -bg/-t`). **Keep old names as aliases** (`recovery→good`, `warn→limit`, `bad→danger`, `low→` non-blue such as `ink2`/limit, `strain→ember`, stage colours without blue). Adds `PressStyle` (0.97/160 ms), motion tokens, `PillPicker` (black pill), `RoundIconButton`, `StatusChip`, `GlassCard`, `NotSentLabel`. Publish the API list in `research/` for the others. |
| B · Graphics | `OrbBackground.swift`, `Shaders.metal`, `OKLab.swift`; web: new `web/demo/orbs.js` only | iOS 17: `.colorEffect`/`.layerEffect`, no MeshGradient. 40 s drift, 1.2 s morph, Reduce Motion freezes. |
| C · Data layer | `HealthStore.swift`, `LiveStore.swift`, `DemoData.swift`, `Notifier.swift`, new `Journal.swift` (model + JSON in UserDefaults/App Support), new `Settings.swift` (`@AppStorage` keys `mrh1.notif.morning`, `mrh1.notif.drift`) | Sole editor of `Metrics/Scores/Insights/History.swift` (e.g. "Not sent" support, 14-day history, `activeEnergyToday`). Fixes the BackgroundWatcher shared-instance bug. |
| D · App shell | `MRH1App.swift`, `ContentView.swift` (4 tabs, onboarding, launch-arg routing), `Routes.swift`, `MenuView.swift`, `GuideMenu.swift`, `DataSourcesView.swift` | Remove the forced dark mode. Inject `LiveStore`. The menu holds the Results guide, notification toggles, data sources and the disclaimer. |
| E · Today | `TodayView.swift`, `TodayCards.swift`, `TodayWeek.swift`, `JournalSheet.swift` | Order from the mock: rings → advice → strain target → stress → health monitor → week/debt/consistency → journal; plus panels strip, last night, Monday report (reuses `WeeklyReportCard`, read-only). |
| F · Live | `LiveView.swift`, new `LiveChart.swift` | Codes against the `LiveStore` contract; `TimelineView(.periodic(1s))` for "N min ago". |
| G · Body | `PanelViews.swift` (PanelsView → Body tab with segmented panels + PanelDetailView) | Uses `MetricRow` from A. |
| H · Trends + Week | `TrendsView.swift`, `WeekViews.swift` (WeeklyReportCard, BodyAgeCard) | Leaves a slot for "tags vs recovery" (v1.1). |
| I · ScoreDetail + Sheets | `ScoreDetailView.swift`, `MetricSheet.swift`, `ExplainSheet.swift`, `SleepGraphics.swift` | Recovery 14-day chart, drivers as bars either side of your normal, "How it's computed". |
| J · Web demo (optional) | `web/demo/app.js`, `index.html`, `data.js`, `web/index.html` | Imports B's `orbs.js`. |

Rules: never edit `project.pbxproj`. Never rename a public type another file uses without asking its owner. A needs to land its token names first, or publish them, because everyone else consumes them. A's aliases keep the old code compiling in the meantime. After merge, one integrator runs the build with `dangerouslyDisableSandbox` and then takes screenshots in demo mode.
