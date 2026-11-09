> Historical notes from v0.4 (Nov 2026). Folder names and versions below are out of date; the README is current.

# MRH1 · "Fitbit Air on Steroids"

Personal iOS app that replaces the Google Health app for the **Google Fitbit Air** band.
Whoop-style scores computed from what Google Health writes to Apple Health, with every metric
explained like a blood-test result (green good · yellow limit · red danger).

## Folder map

| Path | What |
|---|---|
| `fitbit-air-on-steroids/` | **The git repo** (github.com/mohoss1985-tech/fitbit-air-on-steroids, branch `main`). Source of truth. |
| `fitbit-air-on-steroids/ios/` | Xcode project v0.4 (SwiftUI, Swift Charts, HealthKit). `DEVELOPMENT_TEAM` is empty on purpose. |
| `fitbit-air-on-steroids/docs/` | GitHub Pages: landing page, `demo/` web replica on synthetic data (`app.js`, `data.js`), `screenshots/`. |
| `design/v1-direction/index.html` | **Approved-in-progress v1.0 direction** (open in a browser): Today, Live, Body, Recovery mocks, palette, orb shader, motion spec, roadmap. Screenshots next to it. |
| `design/moodboard/` | Mood board spec + tokens. Put the 4 reference images here. |
| `design/body-light-prototype/` | Earlier WebGL "body light" prototype (palette later called cheap). |
| `design/design-canvas/` | v0.3 storyboard design canvas (`*.dc.html`). |
| `reference-captures/` | Frames from screen recordings of Google Health, Apple Health and MRH1 v0.2–v0.3.1. |
| `history/` | Zips of every shipped version (v0.2 → v0.4) and the first repo snapshot. |

## Data pipeline and facts

Fitbit Air → Google Health app → Apple Health → MRH1 (read-only HealthKit, on-device, no networking).

- Arrives in Apple Health: heart rate, resting HR, breathing rate, SpO2, sleep stages, workouts, steps, active energy.
- **Not sent** by Google Health: HRV, skin temperature, VO2 max. Show "Not sent", never zeros.
- Sync is batched and lags (minutes to hours). Fitbit Air has **no blood-pressure sensor**.
- Baselines: own last 30 days, mean ± max(SD, floor); needs ~14 days before flags are meaningful.
- Direction-aware flags: `Insights.direction(id)`; better-than-usual stays green (`Metric.isConcern`).

Scores (`Scores.swift`): Recovery = logistic of weighted z-scores (HRV .40, RHR .25, breathing .15, sleep .20; reweighted when HRV missing). Strain = TRIMP mapped to 0–21. Sleep = duration 50 + restorative 30 + efficiency 20. Stress = HR above resting while still, hourly 0–3. Also sleep debt, bedtime consistency, body age, weekly report.

Background: `HKObserverQuery` + background delivery (entitlement accepted on a free team). Local notifications: morning summary, 2+ vitals drift alert.

## Build and install

- Xcode on the owner's Mac: `~/Documents/Claude Built Apps/MRH1_2026-11-01_2303/` (team B9RRMBU363 set there; don't overwrite its `project.pbxproj`, copy Swift files only).
- Free Apple ID → install expires after 7 days (renew with ▶). No paid Developer account yet, so no TestFlight / Diawi.
- Bundle `com.mrh.MRH1`, iOS 17 target today. Proposal: raise to iOS 18 for native `MeshGradient`.
- Owner rule: apps Claude builds live in `~/Documents/Claude Built Apps/<APP>_<timestamp>/`.

## Where we are (2 Nov 2026)

v0.4 is installed and working. The owner asked for UX + UI research and a state-of-the-art redesign.
`design/v1-direction/index.html` is the current proposal, revised after feedback:

1. **Keep every v0.4 feature and graph** (rings, strain target, 24 h stress chart, health-monitor heat map, week card, panels with range bars + 7-day lines, score details, weekly report, body age, trends, explanation sheets, notifications). A "where it lives" table is in the page.
2. **Mood board look everywhere** (see `design/moodboard/MOODBOARD.md`). Ember = brand only; green/yellow/red = status only; no blue.
3. **Tabs:** Today · **Live (new)** · Body · Trends. Results guide = menu button top-left (owner wants it as a menu, not a page). Journal tags via + on Today.
4. **Live tab:** heart-rate chart that updates as samples land (HKObserverQuery / anchored query), ranges Live · 1H · 24H · 7D · 30D with min/avg/max; strain, stress, steps, energy so far today; last night's breathing and SpO2; "latest sample N min ago" always visible. Investigate whether Fitbit Air broadcasts BLE Heart Rate Service for true real-time.
5. **Gradient:** peach/ember orbs at the top of Today only, status adds one orb (green/yellow/rose, dusk at night), mixed in OKLab, dithered, ~40 s drift, 1.2 s morph on state change, frozen with Reduce Motion. iOS: `MeshGradient` + small Metal dither shader.
6. **Motion (Emil Kowalski rules):** press scale 0.97 / 160 ms ease-out; enter cubic-bezier(0.23,1,0.32,1) 220 ms from scale 0.96; morph cubic-bezier(0.77,0,0.175,1) 300 ms; sheets cubic-bezier(0.32,0.72,0,1) 500 ms in / 200 ms out; drag spring(duration 0.5, bounce 0.2); no animation on tab switches; `.contentTransition(.numericText())` for numbers; Reduce Motion → opacity only.

**Open decisions for the owner:** approve direction · raise min to iOS 18 · paid Apple Developer account (TestFlight) yes/no.

## Next steps

1. Get the owner's answers to the 3 decisions.
2. Rebuild the SwiftUI views to the v1 direction (Theme tokens first, then Today, Live, Body, Trends, score details, sheets), keeping all existing logic in `HealthStore`, `Metrics`, `Scores`, `Insights`, `History`, `Notifier`.
3. Add Live tab data layer (HKAnchoredObjectQuery for HR, hourly buckets for 24H, daily for 7D/30D).
4. Update `docs/demo` web replica, screenshots and README; push to `main`.
5. A reminder to reinstall the free build fires 8 Nov 18:00 Paris.

## Conventions

- Repo is independent from the owner's `AI-skills` repo (that one only links to this project).
- Commits authored as Claude; never put the owner's personal team ID in the public repo.
- MRH1 gives wellness estimates, not medical advice; keep that line in the app and README.
