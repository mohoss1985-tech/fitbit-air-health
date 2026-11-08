# MRH1

**Recovery, strain and sleep scores for your Fitbit Air, explained like a lab result. On-device. No subscription.**

[**▶ Live demo**](https://mohoss1985-tech.github.io/mrh2/demo/) · [Project page](https://mohoss1985-tech.github.io/mrh2/)

Works with Fitbit Air via Google Health and Apple Health. Not affiliated with Google, Fitbit or Apple.

## New in v1.2 · Blood pressure and metabolic signals

<p align="center">
  <img src="screenshots/v1.2/dark-body-bp.png" width="200" alt="Body with blood pressure">
  <img src="screenshots/v1.2/dark-body-metabolic.png" width="200" alt="Metabolic health signals">
  <img src="screenshots/v1.2/dark-coach.png" width="200" alt="Coach composer above the tab bar">
</p>

- **Blood pressure from your own cuff:** any home cuff that saves to Apple Health (Withings, Omron…). Latest reading,
  30-day average and a normal / elevated / high label from the adult guideline ranges. The Fitbit Air has no
  blood-pressure sensor and MRH1 never estimates one.
- **Metabolic health signals:** five habits research links to insulin sensitivity (steps, exercise, sleep length,
  bedtime regularity, resting heart rate trend), each on track or room to improve. Not a blood-sugar or insulin number.
- **One easy-day rule everywhere:** after two hard days, the headline, Strain target, Live tab and Coach all say "easy".
- **Fixes:** content no longer hides under the floating tab bar (iOS 27), a back arrow in the Coach tab, faster Apple
  Health refresh.

## New in v1.1 · Coach

A free AI coach that runs **entirely on your iPhone** (Apple's on-device model, no internet code). Ask about your
own numbers, tap one of 3 suggested follow-ups, get a workout from a reviewed library with a step timer. A small
speech-bubble mark on every card opens the coach about that metric.

<p align="center">
  <img src="screenshots/v1.1/dark-coach.png" width="200" alt="Coach tab">
  <img src="screenshots/v1.1/light-today.png" width="200" alt="Today with coach note">
  <img src="screenshots/v1.1/dark-body.png" width="200" alt="Body with coach marks">
</p>

- **On-device, free:** Apple Foundation Models with 9 read-only tools over your data; a rule-based coach takes over on iPhones without Apple Intelligence.
- **Grounded:** 22 evidence-based rules set today's intensity cap; the AI explains them. It may only quote numbers the app gives it.
- **Safe:** emergency, crisis and medical questions get fixed replies written in code, never generated. 18+, wellness only, chat kept on the phone for 30 days.
- **Turn it off** in Menu → Coach to get the exact v1.0 app back.

## v1.0

<p align="center">
  <img src="screenshots/v1/light-today.png" width="200" alt="Today">
  <img src="screenshots/v1/light-live.png" width="200" alt="Live">
  <img src="screenshots/v1/light-body.png" width="200" alt="Body">
  <img src="screenshots/v1/light-trends.png" width="200" alt="Trends">
</p>

> Screenshots and the web demo use **synthetic sample data**, not real health readings.

## What it does

- **Today:** Recovery, Sleep and Strain tick rings, a time-of-day verdict, strain target, 24-hour stress, health-monitor heat map, last night, sleep debt, your week, journal discoveries.
- **Live:** latest heart rate with a "latest sample N min ago" ticker, Live · 1H · 24H · 7D · 30D chart with min / avg / max, strain, stress, steps and energy so far today, last night's breathing and SpO2. Optional Bluetooth heart rate (beta, off by default).
- **Body:** every metric as a lab result: value, your personal normal, a dot-matrix range strip and a 7-day line. Metrics Google Health doesn't send (HRV, skin temperature, VO2 max) say so, never zero.
- **Trends:** what changed this week versus last, in one sentence per metric. Weekly report with a share export, body age.
- **Score details:** every input to a score, its weight, and how it's computed.

## How it works

```
Fitbit Air ──► Google Health ──► Apple Health ──► MRH1 (on this iPhone)
```

- Native iOS 17+ (Coach AI on iOS 26+ with Apple Intelligence), SwiftUI, Swift Charts, HealthKit (read-only), Metal shaders for the header and chart texture.
- No networking code, no analytics, no third-party packages, including the coach. Baselines come from your own last 30 days.
- Google Health writes to Apple Health in batches, so "Live" is as fresh as the latest sync, and the app always shows how old it is.

## Build

1. Open `MRH1.xcodeproj` in Xcode (26 or later; the Metal Toolchain component must be installed: `xcodebuild -downloadComponent MetalToolchain`).
2. Select the MRH1 target → Signing & Capabilities → choose your team.
3. Run on an iPhone. In the Simulator the app runs on deterministic sample data (`-demo`); pass `-realHealth` to read HealthKit instead.

Screenshot launch arguments: `-tab today|live|body|trends`, `-open recovery|strain|sleep|menu|journal`, `-uiLight` / `-uiDark`, `-demoNow 17:40`.

## Repository

| Path | What |
|---|---|
| `MRH1/` | App source |
| `docs/` | GitHub Pages: landing page and browser demo (WebGL2), synthetic data |
| `DESIGN_SPEC.md` | Design system: tokens, type, charts, motion, copy rules |
| `DESIGN_SPEC_v1.1.md`, `GOAL_v1.1.md` | Coach spec and goal |
| `MRH1/Coach/` | Coach: rules, workout library, on-device engine, tools, safety, UI |
| `research/` | Research behind the design (brands, competitors, UI craft, live data, graphics, market) |
| `screenshots/v1/`, `screenshots/v1.1/` | Simulator screenshots, light and dark |

---

MRH1 gives wellness estimates, not medical advice. © 2026. All rights reserved.
