# DESIGN_SPEC v1.3 · Today re-layout + Coach fixes (addendum)

`DESIGN_SPEC.md` (v1.0) and `DESIGN_SPEC_v1.1.md` (Coach) still rule tokens, type, motion, copy and every other screen.
This file only changes Today and fixes Coach bugs B1–B5 (`GOAL_v1.3.md`). Sources: `research/v13-01…03`.

## 0 · Identity in one line
Today answers "how am I and what should I do" on the first screen; the week is one tap away, never a long scroll.

## 1 · Conflicts resolved (owner decisions 2026-11-08 marked ★)
| Topic | Reports said | Decision |
|---|---|---|
| Week access | 01: "Your week" section in one long scroll · 02: pinned Today/Week switch | ★ **Pinned "Today \| Week" switch** |
| Day circles | 01 + 02: leave the top | Move into the **Week** segment as its day selector; no scroll jump on tap |
| Date | 02: date in the title row | Header keeps "Good afternoon" + date line (unchanged); the M–S strip is removed from it |
| Edit Today (hide/reorder) | 01: add | ★ **Not in v1.3** |
| Health monitor | 02: fold when quiet | ★ **Yes**: one line when all vitals are in range, auto-opens on drift |
| Coach note chips | 03: only open Coach | ★ **They open Coach and send the question** |
| Liquid Glass tab bar (02 #13) | system tab bar | N/A: MRH1 uses its own floating TabBar (kept) |
| Monday default (02 #3) | default to Week on Mondays | Yes, only while the weekly report is new (Monday) |

## 2 · Tokens
No new tokens or colours. Switch = existing `PillPicker` at 44 pt min height. Pinned bar ≤ 56 pt: `Space.xs` above,
`Space.s` below, opaque `Theme.paper`. Header bottom padding `Space.section` → `Space.xl`. Panels → switch `Space.xl`;
switch → first card `Space.m`; card gap `Space.cardGap`; before journal + footer `Space.section`.

## 4 · Information architecture — Today (top → bottom)
**Fold 1 (no scroll):** header (menu · greeting + date · +) → verdict → rings (Sleep · Recovery · Strain) → freshness
chips / status lines → **PanelsStrip** (body panels) → **Today | Week switch** (pinned when scrolled).
Acceptance: switch top edge ≤ 700 pt on iPhone 17/18 Pro at default type; rings fully in the top half.

**Today segment (≤ 5 cards, then journal):** CoachNoteCard (if any) → StrainTargetCard → LastNightCard → StressCard →
HealthMonitorCard (DriftBanner shown inside/just above it when drifting) → [Space.section] JournalCard → footer.

**Week segment:** DayCircles (selects a day in place) → WeeklyReportCard (Mondays) → SleepBalanceCard → WeekStrip →
footer.

- ★ **Gauges are the main character and stay.** When Today is scrolled so the big rings leave the screen, a
  **compact gauge bar** pins at the top: three small rings (Sleep 90 · Recovery 63 % · Strain 1,6, ~36 pt each, values
  + labels), with the Today | Week switch pinned right under it. It morphs in as the big rings scroll out (scale +
  opacity tied to scroll offset, `onScrollGeometryChange` on iOS 18+, simple appear on iOS 17; Reduce Motion: opacity).
  Tapping a small ring opens its score detail, same as the big ring. Pinned stack total ≤ 112 pt.
- Segment state `@SceneStorage("today.segment")`, default Today (Week on Mondays). Crossfade only (`Motion.crossfade`).
- Tab reselect: pop → scroll to top (keeps segment) → a second reselect at top switches to Today.
- At `dynamicTypeSize >= .accessibility1` the switch does not pin.
- Peek: ≥ 44 pt of the first card visible under the switch above the tab bar.
- Health monitor folded row: "All vitals in your usual range" + chevron; expanded state in `@SceneStorage`.

## 5 · Copy / Coach rules (bug fixes)
- **B1** A Coach note that advises easing off carries a cap: load-jump note → `.easy`, steady-climb note → `.moderate`.
  Headline, Strain card and note always read the same cap (`CoachRules.todayCap`). Debug assert: note text "ease"/"easy"
  never under cap `.any`.
- **B2** A topic named in the question wins over the chat's metric: `CoachRules.focus(for: String, context: MetricID?) -> Focus`.
- **B3** Recovery chip follows the tier: red "Why is recovery low?" · yellow "What affects my recovery?" ·
  green "What helped recovery?" (`CoachRules.recoveryChip(_ score: Int?) -> String`). Also rewrites model chips.
- **B4** Coach chat with few messages starts at the top (iOS 18+: `.defaultScrollAnchor(.top, for: .alignment)` +
  `.bottom` initial offset; iOS 17: `.top` + scroll-down on appear). No empty gap above the first reply.
- **B5** Journal tags quoted only when relevant to the metric (`CoachRules.relevantTags(for: MetricID?) -> Set<String>`):
  caffeine/screen/late meal → sleep, RHR, sleep HR; alcohol → sleep, RHR, sleep HR, SpO2, breathing; hard workout →
  RHR, recovery, strain; stress/travel/unwell → RHR, recovery, sleep. Never caffeine → SpO2.

## 8 · Shared API (names FIXED)
```swift
// CoachRules.swift (owner B)
enum Focus { case recovery, sleep, strain, metric(MetricID), plan, week, general }
static func focus(for text: String, context: MetricID?) -> Focus
static func recoveryChip(_ score: Int?) -> String
static func relevantTags(for metric: MetricID?) -> Set<String>
// Routes.swift (owner C): AppNav gains
var coachPrompt: String?            // question to send when the Coach opens
func openCoach(about: MetricID?, asking: String?)
// TodayView.swift (owner A)
enum TodaySegment: String { case today, week }
```

## 9 · Build rules
Owners: **A** Today (TodayView, TodayCards, TodayWeek, WeekViews) · **B** CoachRules, CoachLibrary ·
**C** CoachEngine, CoachConversation, CoachViews, CoachSupport, CoachTools, Routes, new CoachRulesChecks.swift.
B lands §8 names compiling first. Each builds into `build/<LETTER>`. Never remove features. Coach off = v1.0.
