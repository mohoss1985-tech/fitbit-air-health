# Wave 1 · P · Web demo + landing (v1.1 Coach)

Only `web/` was changed. The demo is still plain static HTML and ES5, with no build step and no network calls beyond Google Fonts. It works from `file://` and from GitHub Pages.

## Files
- **`web/demo/coach.js` (new)**: the scripted coach. `window.MRHCoach(ctx)` is called by app.js with its helpers (stats, fmtV, tickRing, topbar…), so every number comes from `data.js` through the same maths as the other tabs.
- **`web/demo/app.js`**
  - 5th tab, CoachMarks, the Today note card, "Ask Coach about this" rows, and a Menu → Coach on/off switch.
  - New query parameters: `?tab=coach`, `&ask=<keys>` (seeds a finished chat, for screenshots), `&coach=off` and `&test` (exposes `window.__coach` for checks).
- **`web/demo/index.html`**: coach CSS (v1.0 tokens only, no new colours), `coach.js` script tag, hint text updated.
- **`web/demo/orbs.js`**: fixed an existing bug. Without WebGL, `destroy()` threw on undefined observers, which broke every tab switch. It is now guarded.
- **`web/index.html`**: new `#coach` section ("New in version 1.1") placed after "Three things". It covers on-device, free, private and what it does, with example questions, a "Try the Coach demo" button (→ `demo/?tab=coach`) and 2 screenshots. It also adds a nav link, and the coach's intended-purpose text in the legal box. Privacy copy mentions the coach. Everything else is unchanged.
- **`web/screenshots-v1/coach.png`, `coach-plan.png` (new)**: 780×1688, the same format as the other v1 shots.

## Demo behaviour
- **Coach tab**
  - Header: orbs at 55 % opacity, "Coach / On this iPhone", a "Demo · scripted sample answers" chip, a pencil button for a new chat, and the menu.
  - Greeting with today's numbers ("Afternoon. Recovery 78 %, strain 9.4 of 12–15."), then 4 starter rows (Recovery, Sleep, Strain, Plan) with a disclosure caption.
  - Thread, then the composer. The composer grows to 5 lines; Enter sends, Shift+Enter adds a new line.
  - Footer: "AI coach on this iPhone · can be wrong · wellness, not medical advice." plus "No AI runs in this browser."
- **Script**
  - 20 answers: recovery, plan, planShort, planIndoor, sleep, wind, week, rhr, breathing, train, strain, stress, caffeine, notsent, see, help, live, medical, fallback.
  - Every answer has a headline of 14 words or fewer, at most 3 sentences, data pills that open the metric sheet, and exactly 3 chips of 4 words or fewer. Every chip leads to another canned answer; this is checked automatically.
  - Typed text goes through a medical regex first, which returns the fixed "That's one for a doctor." notice (dangerBg, with the emergency line). Otherwise it is matched by keywords, and anything unmatched gets "In this demo I answer the suggested questions."
- **Thinking:** the bubble glyph with 3 ember dots pulsing in turn, plus status text such as "Reading your last 7 nights…". After 0.65–1.7 s the reply fades in by chunk (160 ms per sentence), cards enter at 0.96 scale over 220 ms, and chips follow with a 40 ms stagger. Earlier chips dim to graphite. A polite live region says "Coach is replying" and then "Coach replied".
- **PlanCard**: 4 plans (30-min walk, 15-min walk, 15-min indoor circuit, 15-min wind-down).
  - Checkboxes, a Start/Resume button, an "N of M done" count and "Stop if you feel pain or dizziness."
  - A newer plan of the same kind collapses the older one to "Replaced by the …".
- **Runner** (full-screen overlay): ember TickRing countdown with mm:ss, Back / Pause / Skip, a "Done" button for reps-only steps, and auto-check of finished steps. The end screen reads "Done. N of M steps done. Not saved to Apple Health." Esc closes it.
- **CoachMarks** (16 px bubble, graphite2, ember dot at 60 %, 44 px hit area). No buttons are nested: marks sit beside the card or row in a wrapper. Placement:
  - Today: rings, Strain target, Stress, Body panels, Health monitor, Last night, Sleep debt.
  - Live: chart caption and last-night rows.
  - Body: every result row.
  - Trends: every "Changed" card.
  - The Recovery, Strain and Sleep sheets and every metric sheet get an "Ask Coach about this" row.
  - A tap closes any sheet, switches to Coach and asks the matching question.
- **Today note card** (rule-based, not AI): red recovery → recovery day; else a vital outside its range → "Breathing ran 1.1 above your usual last night. Everything else is in range. Worth an early night."; else strain under target → session. The chips are the question and "Not today" (dismisses), plus a ✕.
- **Menu → Coach switch:** off removes the tab, the marks, the note and the Ask rows (v1.0 exactly).
- **Reduced motion:** dots are static at 1 / .6 / .3, card entry becomes opacity only, transitions are off and the runner has no fade. `?shot` turns off all animation and thinking delays.

## Testing
- `node --check` passes on all 5 demo JS files.
- Served with `python3 -m http.server` and driven in headless Edge over CDP (outside the sandbox, which blocks binding the browser), at 360 and 390 px. Checked:
  - no horizontal overflow on any tab or in the runner, at 320, 360 and 390 px, and on the landing page at 375 px
  - no JS errors
  - note → coach thread
  - free text → fallback and medical
  - pill → sheet
  - Body mark → "Why is RHR up?"
  - Ask row → coach
  - plan check / start / skip / pause / close
  - coach off → 4 tabs and 0 marks
  - new chat → starters
- Screenshots checked in light and dark.

## Open issues
1. The headless capture of the landing page at 375 px did not load the lazy coach images (a capture artefact). Look at it once in a real phone browser.
2. Not built: History, "What Coach knows", thumbs and copy/retry actions, and the mic. They are out of scope for a scripted demo.
3. Copy follows DESIGN_SPEC_v1.1 §5. "What can you help with?" (from research) became "What can you do?" to keep chips at 4 words or fewer. The help answer avoids the banned word "diagnose".
4. The gallery heading still says "Four tabs, one calm read." The Coach has its own section, so the 4-column gallery was left as it was.
5. The `&test` hook exposes `window.__coach`. It is harmless, but it can be removed before shipping.
