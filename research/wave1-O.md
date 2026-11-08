# Wave 1 · O · Coach integration

Build: `build/O`, **BUILD SUCCEEDED** (2026-11-07, against K/L/M/N files as they were then). No simulator runtime
was available on this machine, so nothing here has been checked on screen yet.

## What changed (only files owned by O)

- **MRH1App.swift**: one `@State CoachEngine()`, injected with `.environment(coach)`.
- **ContentView.swift**
  - Calls `coach.configure(health:journal:)` after the first `health.refresh()` (or straight away in Demo), and again on every `health.lastRefresh` change.
  - `MainTabs`: 5th tab `.coach` → `CoachTabRoot`. It is only in the `TabView` and the bar while `coach.enabled` is on. Turning it off moves you off the Coach tab and closes the coach sheet.
  - App-level `.sheet` presents `CoachSheet(metric: nav.coachMetric)` whenever `nav.showCoachSheet` is set (and only while the coach is on).
  - `TabBar` takes a `tabs` list. The Coach tab draws N's `CoachTabIcon(selected:)`, never an SF Symbol. Dynamic Type is capped at `.xxLarge`, with `minimumScaleFactor(0.7)` and a large-content viewer (long-press) so 5 items always fit.
  - `CoachIntroView` ("What Coach can see") is shown once, on the first open of the tab (`coach.onboarded`). It has the data list, "Processed on this iPhone", "Chats stay 30 days", the intended-purpose text, an "I am 18 or older" toggle that gates **Start Coach**, and **Not now** (back to Today).
  - Shared helpers:
    - `CoachMarkSlot(metric:name:)` wraps `CoachMark` in a 16 pt layout footprint, so the 44 pt hit area overhangs and layouts don't change. It is hidden while the coach is off.
    - `.coachAccessibilityAction {}` adds an "Ask Coach" VoiceOver action to merged elements.
    - `AskCoachRow(name:action:)`.
- **Routes.swift**
  - `CoachPrefs`:
    - keys `coach.enabled` (default true), `coach.proactive` (off/important/daily/every, default daily), `coach.style` (direct/supportive/numbers, default direct) and `coach.onboarded`
    - `Proactive` / `Style` enums with titles
    - static readers for non-view code (L can read `CoachPrefs.style`)
  - `openCoach(about:)` does nothing while the coach is off.
  - New `openCoachSheet(about:)`, which always opens the sheet, also with a nil metric.
  - Launch arguments: `-tab coach` works (ignored while the coach is off), plus `-open coach` (coach sheet) and `-coachSkipIntro` (marks the intro seen, for screenshots). The existing arguments are unchanged.
- **TodayView.swift**
  - `CoachNoteCard(note: CoachRules.evaluate(health, journal:).note)` is the first card under the header, so it sits under the freshness chips and above Strain target. It shows only when the coach is on and proactive notes ≠ Off.
  - "Important only" also needs a vital outside its usual range, or Recovery below 34.
  - There is one CoachMark at the top-right of the rings block.
- **TodayCards.swift**
  - `CardTitle` gains `coach: CoachTarget?`. The mark sits at the far right of the title row, after the trailing text and centred on the cap height.
  - Cards wrapped in a Button or NavigationLink get the VoiceOver action as well.
- **LiveView.swift**: CoachMark at the top-right of the heart-rate chart card.
- **PanelViews.swift**: CoachMark at the top-right of every `ResultRow`, with the VoiceOver action. There is no ⓘ in these rows.
- **TrendsView.swift**: CoachMark in the `TrendCard` title row, right of the trend chip, with the VoiceOver action on the button.
- **ScoreDetailView.swift**: `AskCoachRow` at the foot of Recovery, Strain and Sleep, above the disclaimer. It calls `nav.openCoachSheet(about:)`: `.sleepTotal` for Sleep, nil for Recovery and Strain.
- **MetricSheet.swift**: `AskCoachRow` above the disclaimer. It presents `CoachSheet(metric: state.id)` **stacked on the MetricSheet** with a local `@State`, because the app-level sheet can't present while another sheet is up. Closing it goes back to the metric.
- **MenuView.swift**
  - New **Coach** section, placed before Notifications. It has:
    - a Coach on/off toggle
    - Proactive notes and Style menu pickers, each with a one-line description
    - Delete coach history, with a confirm dialog → `coach.deleteAll()`
  - About now reads **Version 1.1** and "Everything, including the coach, runs on this iPhone. No internet code. …".
- Not touched: GuideMenu.swift, DataSourcesView.swift.

## CoachMark placements

| Screen | Where | metric |
|---|---|---|
| Today | Rings block, top-right | nil → Coach tab ("today's scores") |
| Today | Strain target card title | nil |
| Today | Stress today card title (right of trailing text; ⓘ stays next to the title) | nil |
| Today | Body panels strip title | nil |
| Today | Health monitor title | nil |
| Today | Last night card title | `.sleepTotal` |
| Today | Sleep debt & consistency card, top-right overlay | `.sleepTotal` |
| Live | Heart-rate chart card, top-right | nil ("your heart rate") |
| Body | Every ResultRow, top-right | `state.id` |
| Trends | Every TrendCard (What changed + steady), title row right | `t.id` |
| ScoreDetail ×3 | "Ask about this" row at foot | sleep → `.sleepTotal`, others nil (sheet) |
| MetricSheet | "Ask about this" row at foot | `state.id` (stacked sheet) |

There are no marks on the Journal card, the Drift banner, NotSent/NoSensor rows or the Menu.

## Open issues

1. **nil-metric marks go to the Coach tab, not a sheet.** That is the contract `openCoach(nil) → tab`, and `CoachMark` calls `openCoach`. Recovery, Strain and Stress have no `MetricID`, so those marks leave the current tab. Options: give `CoachMark` a sheet-always flag, or add score topics to `CoachSheet`. N/L to decide. The ScoreDetail rows already use the sheet (nil metric).
2. **Proactive "Daily" vs "Every moment"** are told apart only by the time slots and the 3-a-day cap, which `CoachRules` (K) should apply. O passes the setting through and filters only Off and Important only. K can read `CoachPrefs.proactive`.
3. **Style setting** is stored (`coach.style`). L's engine needs to read `CoachPrefs.style` to use it.
4. **Onboarding questions** (goal, active days, equipment, limits; §4.6) are not in O's intro screen. They belong with `CoachProfile` (L/N), and the intro hands over to `CoachView`.
5. **"What Coach knows"** menu row (§4.5) is not added: there is no memory view to link to yet. Add `NavigationLink` once N/L ship one.
6. **Visual QA pending.** There is no simulator runtime here, so please screenshot these with `-demo -tab coach`, `-demo -coachSkipIntro -tab coach` and `-demo -tab body`. Check mark alignment in the TrendCard and CardTitle rows (baseline guide +4/+5) and the Today rings overlay at AX sizes.
7. **Nested buttons.** CoachMarks inside Button/NavigationLink cards (Body rows, Trends, Last night, Body panels) rely on the inner button winning the tap, which is standard in a ScrollView. Confirm on device.
