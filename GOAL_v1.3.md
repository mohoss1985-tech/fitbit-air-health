# MRH1 v1.3 · Today re-layout + Coach fixes — goal

**App:** MRH1 ("Test App Fitbit"), native SwiftUI iOS 17+ (owner runs iOS 27), dashboard for the Google Fitbit Air,
data only from Apple Health. Contract: `DESIGN_SPEC.md` (v1.0) + `DESIGN_SPEC_v1.1.md` (Coach). Code in `MRH1/`.

## Owner's ask (2026-11-08, after watching a screen recording of v1.2.1)
1. On Today, the M–S day-circle strip sits at the very top, above the main gauges. It should move **lower**.
   The **three gauges (Sleep · Recovery · Strain)** should be up front.
2. "Your week" (sleep balance, week strip / consistency) is buried: you have to dig to see it. Make it easier to reach.
3. **Body panels** card should be higher on Today.
4. Use the user-research method so the result is better, not just shuffled.

## Bugs seen in the recording (fold in)
- B1 Today headline "Strain 1,6 of your 10–14 target. Room for a session." while the Coach note under it says
  "Big jump vs your usual week: ease in." with chip "Plan an easy session" → contradiction (the cap fix of v1.2 missed
  the load-jump note).
- B2 Coach chip "Why is recovery low?" answered with a sleep reply ("Total sleep 7 h 10 is within your usual range").
- B3 "Why is recovery low?" offered when Recovery is 63 % (yellow, not low).
- B4 Coach sheet (CoachMark → "Ask about …") opens with a big empty gap above the first reply.
- B5 SpO2 reply lists "You tagged caffeine after 2 pm yesterday" as a possible cause of low blood oxygen (wrong link).

## Already done in the working copy (keep)
Tap the selected tab → pop to root, then scroll to top · swipe right from left edge in a Coach chat = back.

## Done means
- Builds with zero errors; every v1.0–v1.2.1 feature kept; Coach off = v1.0 behaviour.
- Today order changed per research + owner ask; screenshots of Today (top, middle, bottom) in light + dark.
- B1–B5 fixed and verified with a scripted check or screenshot.
