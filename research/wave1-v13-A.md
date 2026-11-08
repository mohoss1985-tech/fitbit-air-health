# Wave 1 · v1.3 · Agent A: Today layout

Files: `MRH1/TodayView.swift` (rewritten body/header, order comment updated), `MRH1/TodayPinned.swift` (new:
`TodaySegment`, `TodaySwitchBar`, `CompactGaugeBar`, `TodayPinnedStack`, `todayRecoveryTier`),
`MRH1/TodayCards.swift` (HealthMonitorCard fold), `MRH1/TodayWeek.swift` (doc comment). `WeekViews.swift` unchanged.
Builds: `build/A` (generic iOS) and `build/A-sim` both **BUILD SUCCEEDED**.

## What was built (DESIGN_SPEC_v1.3 §4)
1. **Header** = menu · greeting + date · + → verdict → big rings (unchanged look) → status lines. The M–S day circles
   are gone from the header. Header bottom padding `Space.xl`. Orb mask fade is shorter (0.55→0.92), so the panels sit on paper.
   Then `PanelsStrip` → `Space.xl` → **Today | Week** `PillPicker` (44 pt: 36 pt buttons + 2×4 pt padding), opaque `Theme.paper`.
2. **Pinning without layout jumps.** I did not use `LazyVStack` pinned headers. The scroll content holds the real switch, and an
   opaque overlay at the top of the ScrollView holds the pinned copies (the "or equivalent" option in the spec).
   - The **compact gauge bar** (52 pt: three 36 pt TickRings in the same colours/tiers, value + unit + micro label) morphs in
     as the big rings' bottom edge passes under it. On iOS 18+ it follows scroll continuously (scale 0.92→1, offset −6→0,
     opacity); on iOS 17 it is a simple animated appear (`Motion.enter`). Reduce Motion gives opacity only. Each small ring is a
     `NavigationLink(Route.score(kind))`, the same route as the big ring.
   - The **switch** pins under the gauge bar when the in-content switch reaches that line. The pinned stack is 52 + 56 = **108 pt** (≤ 112).
   - The background is `Theme.paper`, extended under the status bar / Dynamic Island with `ignoresSafeArea(.top)`, so
     there's no clipping and no orb under the small rings. Content sits below the safe area. No gradient or divider.
   - Position tracking uses `onGeometryChange` (global frames vs. the safe-area top). `atTop` comes from
     `onScrollGeometryChange` on iOS 18+ and from the header frame on iOS 17. State is written only when values change
     (progress quantised to 1/50).
   - Switching segment while pinned scrolls (no animation) to an anchor that keeps the switch on its pinned line. A spacer
     makes each segment at least one screen tall, so a short Week segment can stay pinned.
3. **Today segment:** CoachNoteCard (if any) → StrainTargetCard → LastNightCard → StressCard → DriftBanner (only when 2 or more
   vitals drift) → HealthMonitorCard → [`Space.section`] JournalCard → footer.
   **HealthMonitorCard** folds to one row: "All vitals in your usual range" + chevron (green dot; "…waiting for sync" when there's no data).
   It auto-opens when any vital `isConcern`. Its state is in `@SceneStorage("today.monitor.open")`. When quiet it can be folded again with a chevron in the title row.
4. **Week segment:** DayCircles (select in place, no vertical scroll; WeekStrip centres the card; a 4 pt ink dot marks the
   selection; `.isSelected` trait) → WeeklyReportCard (Mondays) → SleepBalanceCard → WeekStrip → footer.
   `@SceneStorage("today.segment")` + `today.segmentDay`: a choice holds for the day it was made. Otherwise the default
   applies (Week on Mondays, Today on other days). The change is a crossfade only (`PillPicker` uses `Motion.crossfade`, `.transition(.opacity)`).
5. At `dynamicTypeSize >= .accessibility1` nothing pins: no overlay and no spacer.
6. A **second reselect at the top** switches to Today: TodayView watches `nav.scrollTopTick[.today]`; `.scrollsToTopOnReselect(.today)` is kept.
7. Launch hooks: `-tab` is untouched. New screenshot hooks: `-segment today|week`, `-todayScroll gauges|pinned|monitor`.

## Measurements (iPhone 18 Pro sim, default type, demo data, dark)
- Switch top edge ≈ 620 pt from the screen top (≤ 700 ✓). The rings sit in the top half ✓.
- Peek: ≈ 70 pt of the first card shows above the tab bar (≥ 44 ✓), in both segments.
- Pinned: gauge bar starts at the safe-area top, switch at +52, first card 12 pt below the switch ✓.

## Screenshots (`screenshots/v1.3/`)
`A-today-top.png`, `A-today-gauges.png` (gauge bar only), `A-today-pinned.png` (gauges + pinned switch),
`A-today-monitor.png`, `A-week-top.png`, `A-week-pinned.png`, `A-light-today-top.png`, `A-light-today-pinned.png`.

## Open issues
- The folded HealthMonitor row is not in a screenshot. Demo data has one vital in watch, so the card auto-opens (correct per spec).
- I did not add `.scrollEdgeEffectStyle(.automatic, for: .top)` (iOS 26). The pinned stack is our own opaque overlay, not
  a system bar, so it doesn't apply.
- The research §15 debug logging of scroll depth is not implemented.
- The verdict "Room for a session" vs. the Coach note cap (B1) belongs to agent B. TodayView still reads `CoachRules.todayCap`.
- The simulator is shared with the other agents: one capture run once hit the home screen (the app was killed externally). Retrying worked.
