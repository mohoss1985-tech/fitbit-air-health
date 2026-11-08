# MRH1 v1.1 · AI health coach — research goal

**App:** MRH1, home-screen name "Test App Fitbit". Native iOS (SwiftUI, iOS 17+ min, owner's phone runs iOS 27),
a dashboard for the Google Fitbit Air. Data comes only from Apple Health, written there by the Google Health app.
v1.0 is shipped (`MRH1/`, `DESIGN_SPEC.md` is the design contract, `research/` holds the v1.0 research).

**Owner's ask (2026-11-07):** "Improve it by integrating an AI health coach in the app, like the premium version of
the Google Health app (Gemini coach, included for a few months with the band). It gives recommendations, talks to you,
you ask it things, there are preset answers you can tap, and it interacts with you to give better health or sports
advice, exercises, whatever." → a **v1.1 with an integrated AI coach / health assistant**.

## Facts and constraints the research must respect

- **Data available to the coach** (from Apple Health via Google Health): heart rate samples, resting HR, sleep stages,
  breathing rate, SpO2, steps, active energy, workouts. **Not available:** HRV, skin temperature, VO2 max, blood pressure,
  real-time Bluetooth HR (tested 2026-11-05: band exposes 0x180D but stays silent). Plus MRH1's own scores: Recovery,
  Strain (0–21), Sleep score, strain target, stress hours, sleep debt, baselines ("your normal" from 30 days), journal tags.
- **Privacy promise in v1.0:** "Everything is computed on this iPhone. No internet code, sends nothing anywhere."
  A cloud LLM breaks this; an on-device model may not. Any trade-off must be explicit.
- **Wellness, not medical advice.** App Store guideline 1.4.1 (health), 5.1.3 (health data), and Apple's rules on
  HealthKit data with third-party AI must be respected. EU AI Act / medical-device lines must not be crossed.
- Sellable worldwide, must not look vibe-coded, keep every v1.0 feature. Design language: DESIGN_SPEC.md
  (warm paper/ink, ember accent, tick rings, green/yellow/red status, plain-language copy).
- Owner pays nothing recurring today (no paid dev account yet, sideloaded). Running cost per user matters for pricing.

## Done means (for the research wave)

Each agent writes `research/v11-<NN-topic>.md` with Sources · Findings · **Decisions for MRH1 v1.1**.
Then Claude merges them into a v1.1 plan for the owner to approve **before any code is written**.
