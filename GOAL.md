# GOAL — MRH1 v1.0 "sellable" release

Ship MRH1 v1.0: a native iOS dashboard for the Google Fitbit Air that covers everything
(scores, vitals, sleep, strain, stress, trends, **live** data) with a world-class, distinctive
design that could be sold to the public. It must NOT look vibe-coded / template-generated.

## Done means
1. The iOS app in `MRH1/` builds with zero errors for the iOS Simulator (Xcode 27.2,
   `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`, iOS 17.0 deployment target kept).
2. Every v0.4 feature and graph still exists (never remove features — owner rule).
3. New **Live** tab works: heart rate updating as samples land (HKAnchoredObjectQuery +
   HKObserverQuery), ranges Live · 1H · 24H · 7D · 30D with min/avg/max, strain/stress/steps/energy
   so far today, last night's breathing + SpO2, "latest sample N min ago" always visible.
4. Gradients and charts are crisp and have personality: Metal shaders via SwiftUI
   `.colorEffect` / `.layerEffect` (iOS 17 OK, no MeshGradient dependency), OKLab mixing, dithering,
   no muddy blur. The web demo (`web/demo/`) gets the equivalent in WebGL.
5. Design is grounded in research (`research/*.md`) on Linear, Whoop, Oura, Apple, Fitbit,
   Google Health and UI-craft sources (hierarchy, typography, spacing, motion, data-viz).
6. App runs in the simulator with demo data, screenshots of every screen saved in `screenshots/`.

## Facts and constraints (from PROJECT_NOTES.md — read it)
- Pipeline: Fitbit Air → Google Health → Apple Health → MRH1 (read-only HealthKit, on-device, NO networking).
- Not sent by Google Health: HRV, skin temp, VO2 max → show "Not sent", never zeros. Sync lags minutes–hours.
- Tabs: Today · Live · Body · Trends. Results guide = menu button top-left. Journal tags via + on Today.
- Mood board: warm paper, ink, ember = brand only, green/yellow/red = status only, no blue. See `design/moodboard/MOODBOARD.md` and `design/v1-direction/index.html`.
- Motion rules (Emil Kowalski) in PROJECT_NOTES.md.
- Keep logic in HealthStore, Metrics, Scores, Insights, History, Notifier. Project uses a
  file-system-synchronized group: new .swift files in `MRH1/` are picked up automatically —
  do NOT edit `MRH1.xcodeproj/project.pbxproj`.
- Wellness estimates, not medical advice — keep that line.
- Do not push to GitHub, do not touch `~/Documents/Claude Built Apps/MRH1_2026-11-01_2303/` (v0.4, installed).

## Layout of this folder
- `MRH1/` Swift sources (start: v0.4) · `web/` GitHub Pages site + `web/demo/` web replica
- `design/` v1 direction, moodboard, prototypes · `reference-captures/` frames of Google Health, Apple Health, MRH1
- `research/` agent reports (one markdown file per agent)
