# Wave 0 — mechanical restructure (2026-11-02)

Pure moves + stubs. No names, behaviour or visuals changed. `project.pbxproj` untouched (synchronized folder).

## Files and the types they contain (MRH1/)

### Moved out (new files)
- `Routes.swift` — `Route`, `ScoreKind` (from TodayView)
- `ExplainSheet.swift` — `SleepInfo`, `ExplainSheet` (from TodayCards)
- `SleepGraphics.swift` — `StageBar` (from TodayView), `Hypnogram` (from ScoreDetailView; its private `row(_:)` moved with it)
- `GuideMenu.swift` — `GuideView` (from PanelViews; private `guideRow` moved with it)
- `TodayWeek.swift` — `WeekStrip` (from WeekViews)
- `DataSourcesView.swift` — `DataSourcesView` (from ContentView)

### Stubs (new files)
- `LiveStore.swift` — `LiveRange`, `HRBucket`, `LiveStore` (@Observable @MainActor; §4 contract, empty/nil returns, `init()`)
- `LiveView.swift` — `LiveView` (placeholder Text)
- `MenuView.swift` — `MenuView` (placeholder Text)
- `JournalSheet.swift` — `JournalSheet` (placeholder Text)
- `OrbBackground.swift` — `OrbBackground { var status: Flag?; var evening: Bool }` (Color.clear)
- `Motion.swift` — `enum Motion {}`
- `DemoData.swift` — `enum Demo { static var isOn: Bool { false } }`
- `Typography.swift` — `enum Typo {}`

### Existing files (now contain)
- `TodayView.swift` — `TodayView`
- `TodayCards.swift` — `StressCard`, `HealthMonitorCard`, `SleepBalanceCard`
- `ScoreDetailView.swift` — `ScoreDetailView`
- `PanelViews.swift` — `PanelsView`, `PanelDetailView`
- `WeekViews.swift` — `WeeklyReportCard`, `BodyAgeCard`
- `ContentView.swift` — `ContentView`, `View` extension, private `ConnectView`, `#Preview`
- `MRH1App.swift`, `HealthStore.swift`, `Metrics.swift`, `Scores.swift`, `Insights.swift`, `History.swift`, `Notifier.swift`, `Theme.swift`, `Components.swift`, `MetricSheet.swift`, `TrendsView.swift` — unchanged

## Build
`xcodebuild … -sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO build` → **BUILD SUCCEEDED**, 0 errors, 0 source warnings (only the usual toolchain note "appintentsmetadataprocessor: Metadata extraction skipped, no AppIntents.framework dependency found").
