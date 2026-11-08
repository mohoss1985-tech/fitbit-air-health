# v1.1 · 03 · Coach UX/UI

Scope: where the coach lives, what each screen looks like, and how it moves and reads. Everything here uses DESIGN_SPEC tokens. Model choice and privacy wording belong to the privacy and model reports. The UI below works with either an on-device or a cloud model, and only the provenance line changes.

## Sources

- Apple HIG, Generative AI (updated 8 Jun 2026): https://developer.apple.com/design/human-interface-guidelines/generative-ai
- Google, Fitbit personal health coach public preview: https://blog.google/products/fitbit/personal-health-coach-public-preview/ and https://blog.google/products/fitbit/fitbit-ai-personal-health-coach-preview/
- Fitbit app areas and the "Ask Coach" button: https://helentech.jp/news-fitbit-personal-health-coach-preview/ ; iOS rollout: https://www.storyboard18.com/amp/digital/fitbit-expands-gemini-powered-ai-health-coach-to-ios-in-public-preview-89551.htm
- Oura Advisor: https://ouraring.com/blog/how-to-use-oura-advisor/ , https://ouraring.com/blog/oura-advisor , https://support.ouraring.com/hc/en-us/articles/39512345699219/ , https://www.businesswire.com/news/home/20250331565896/en/
- WHOOP Coach, Memory and roadmap: https://whoop.com/thelocker/introducing-whoop-coach-powered-by-openai , https://www.whoop.com/us/en/thelocker/my-memory-whoop/ , https://www.whoop.com/us/en/thelocker/2026-whats-next/ , https://the5krunner.com/2025/10/15/whoop-homescreen-gets-a-revamp
- WHOOP community reports (Coach cannot be turned off; send button pushed off screen by dictation; Daily Outlook ignores memory): https://www.community.whoop.com/t/turn-off-disable-whoop-coach/13911.md , https://www.community.whoop.com/t/whoop-ai-coach-send-arrow-disappears-with-longer-dictated-messages/16137.md , https://www.community.whoop.com/t/daily-outlook-coach-not-learning-from-my-preferences/15543
- Perplexity teardowns (answer first, then sources, then related questions; warning about citations on unverified claims): https://ai-design-patterns.pages.dev/teardowns/perplexity/citations , https://www.925studios.co/blog/perplexity-design-breakdown
- Follow-up chip patterns (2–4 chips; generic chips get ignored): https://ai-design-patterns.pages.dev/pattern/follow-up-chips , https://www.aiuxplayground.com/pattern/follow-up-chips
- NN/g diary study of LLM conversations, summarised by Simon Willison: https://www.simonwillison.net/2023/Nov/23/6-types-of-conversations-with-generative-ai
- Duolingo Max (an "Explain My Answer" button placed on the exercise; scenarios written by people): https://blog.duolingo.com/duolingo-max
- Foundation Models streaming snapshots in SwiftUI: https://nonstrict.eu/wwdcindex/wwdc2025/286/ , https://3nsofts-site.pages.dev/guides/foundation-models/streaming-generable-snapshots-swiftui
- Accessible streaming chat: https://azukiazusa.dev/en/blog/accessible-streaming-chat-ui , https://dev.to/wiscer/screen-reader-experience-analysis-on-claudeai-433a
- Bubble geometry in practice (Signal clamps the radius to half the shorter side; 12/8 pt text padding is common): https://cocalc.com/github/signalapp/Signal-iOS/blob/main/SignalUI/Appearance/BubbleConfiguration.swift , https://theswiftk.it.com/swiftui/chat-bubble

## Findings

**Entry points.** The market has settled on three layers.
1. **A persistent home for the coach.** Google added an always-available "Ask Coach" button plus coach content in every tab. Oura uses a + button on Today. WHOOP's Coach button was criticised as "poorly placed and easily overlooked" until a 2025 redesign moved it.
2. **Contextual entry on the data.** Oura has Readiness insight prompts. Duolingo puts "Explain My Answer" right where the confusion happens. Readers who just saw a number are the most motivated to ask about it.
3. **Proactive messages.** Google times them to waking, after a workout and before bed. WHOOP's 2026 roadmap adds check-ins "before a big day or after a run of poor sleep". Oura lets you choose how often and when.

**Control.** Apple says to clearly identify where AI is used, let people dismiss and retry, offer a non-AI fallback, and put thumbs-up/down feedback where it does not interrupt. WHOOP users complain that Coach cannot be turned off. **The coach must be optional, and the app must work fully without it.**

**Starting a conversation.** Apple recommends "curated suggestions that make it easy to get started" for open-ended prompts. Google's own examples are concrete and personal ("Why did I wake up feeling tired today?", "Create a 30-minute upper body workout I can do in my hotel room"). Pattern libraries find 2–4 chips work, and generic chips "quickly feel like filler". NN/g's diary study found follow-ups useful in most conversation types.

**Answer anatomy.**
- Perplexity puts the direct answer first, then sources, then related questions.
- Oura's replies include charts for Sleep, Readiness and Activity.
- A citation attached to an unverified claim makes a hallucination look more trustworthy. Cite data only when the number came from the app's own pipeline, never from the model's text.

**Waiting.** Apple: "instead of 'Processing…', say 'Summarizing key themes from your notes'". Foundation Models streams partial snapshots of a `@Generable` struct, so a structured card can fill in field by field. Give streamed items stable identity to avoid flicker.

**Memory and plans.**
- WHOOP Memory groups what it knows into 7 categories, and you can view, edit, delete or turn it off.
- Oura memories can be deleted in Settings, and history arrived later (Oura app 7.17.0, June 2026).
- Google plans are weekly and editable by chat ("My knee is bugging me, can you adjust my plan?").

**Accessibility.**
- Never put the streaming body in a live region. Announce a short status ("Coach is replying", then "Coach replied") once it is done.
- WHOOP's composer bug, where dictation pushed the send button off screen, shows the composer must cap its height.

**Measurements.** There is no official iMessage spec. Common practice:
- bubble padding 12 horizontal / 8 vertical
- radius clamped to half the shorter side
- user bubble max width about 75–80% of the column
- the assistant's text sits unboxed at full column width (ChatGPT and Claude iOS)
- HIG minimum hit target: 44×44 pt

## Proposed design

### Where it lives (IA)
Coach becomes the **5th tab**, after Trends. That gives five equal round icons, the selected one ink-filled, and still no animation when switching tabs. The icon is SF Symbol `bubble.left.and.text.bubble.right`. Do **not** use `sparkles`, the most recognisable AI-template tell. The tab label is "Coach". The three entry layers map like this:

| Layer | MRH1 surface |
|---|---|
| Home | Coach tab (thread, history, plans) |
| Contextual | "Ask about this" row at the bottom of every ScoreDetail and MetricSheet. It opens `CoachSheet` (`.large`), which uses the same thread view and the same history store |
| Proactive | `CoachNoteCard` on Today, plus an optional push notification (off by default) |

If the coach is turned off in Menu, the tab, the Today card and the Ask rows disappear, and v1.0 comes back exactly as it was.

### Screen 1: Coach tab, empty or start of day
```
 (≡)            Coach             (✎)     ← RoundIconButton 44: history · new chat
 ───────────────────────────────────────
  [small OrbBackground, 0.55 strength, header only]
  Morning. Recovery 72 %, sleep 7 h 12.   ← title 28, ink
  Here's what I can help with.            ← body 15, graphite
  ┌ card r28 ──────────────────────────┐
  │ Why did I wake up tired?         › │ ← StarterRow, headline 17
  │ Plan today around my recovery    › │   hair dividers 0.5
  │ Make me a 20-min workout         › │
  │ How was my sleep this week?      › │
  └────────────────────────────────────┘
  Uses your Apple Health data on this    ← caption 12, graphite + "How it works"
  iPhone. Wellness estimates, not        
  medical advice.                        
 ───────────────────────────────────────
 [ Ask about your sleep, training…  mic  ↑]  ← CoachComposer
 [ Today  Live  Body  Trends  Coach ]
```
Starters are generated from the data, never a fixed list: one about last night, one about today's target, one plan, and one trend. The greeting follows the same time-of-day logic as the Today verdict.

### Screen 2: thread
```
                 ┌──────────────────────┐
                 │ Why am I tired today?│   ← UserBubble: ink fill, card text,
                 └──────────────────────┘     radius inner 16, max 78% width
  Coach                                    ← label 13 graphite (AI identity)
  You slept 6 h 05, about an hour under    ← body 15, ink, unboxed, full width
  your normal. Deep sleep was short too.
  ┌ CoachDataCard r16, paper on card ──┐
  │ Sleep        6 h 05   [Watch]      │   ← MetricRow-lite + BaselineRibbon
  │ ░░░░▓▓▓▓░░●░░                       │
  │ ▁▃▅▂▆▃▁  last 7 nights             │   ← Sparkline
  │ From your last 7 nights            │   ← SourceLine, caption, graphite, (i)
  └────────────────────────────────────┘
  Go to bed by 22:45 tonight to recover.   ← one action, ≤14 words
  [up] [down] [copy] [retry]               ← ReplyActions, graphite2 SF Symbols 17
  ( Plan tonight ) ( Easier day? ) ( Why deep sleep? )   ← SuggestionChips, max 3
```
- **UserBubble.** Padding is 12 horizontal (the `m` token) and 8 vertical (`s`). Radius is `Radius.inner` 16, with no tail, so it still reads as printed rather than iMessage. Max width is 78% of the column, which is about 276 pt on a 393 pt screen.
- **Coach replies have no bubble.** Each reply has up to 3 text blocks and up to 2 cards, and the gap between blocks is 12.
- **The gap between turns is 24.** Same speaker, consecutive: 8.
- **SuggestionChip.** Capsule with a 0.5 pt hair stroke, `card` fill and `label` 13 ink. It is 36 pt tall visually, with a 44 pt hit area via `contentShape`. Padding is 16 horizontal, the gap is 8, and the row scrolls horizontally with a 20 gutter. Tapping one sends its text as the user's turn. Chips from earlier turns fade to graphite2 and stay tappable. Max 3, and each one must refer to something in the reply.

### Screen 3: plan follow-up ("make me a 20-min workout")
```
  ┌ PlanCard r16 ──────────────────────┐
  │ 20-min bodyweight circuit          │ ← headline
  │ Fits your 14–17 strain target      │ ← caption graphite
  │ ─────────────────────────────────  │
  │ 1  Warm-up march          3:00     │ ← PlanStepRow, mono digits
  │ 2  Squats  ×12            0:45     │
  │ 3  Rest                   0:15     │
  │    … 3 rounds                      │
  │ 6  Cool-down walk         3:00     │
  │ ─────────────────────────────────  │
  │ [ Start ]   ( Shorter ) ( No jumps )│ ← ink capsule button + 2 chips
  └────────────────────────────────────┘
  Stop if you feel pain or dizziness.     ← caption, always under any plan
```
**Start** opens `PlanRunnerView` (fullScreenCover):
- a big `TickRing` counts down the current step, in ember
- step name in `title`, time left in `display` with `.numericText()`
- Pause / Skip use `RoundIconButton`
- a light haptic fires at each step change, a 3-2-1 countdown at 3 s, and the screen stays awake

At the end: "Done. 20 min logged here, not in Apple Health." Write access to HealthKit is a separate decision. **Save** puts the plan on the Coach tab under "Plans". Edits ("Shorter") produce a new version of the card. The old card collapses to a single line, "Replaced by a 15-min version", so the change is visible (Apple: acknowledge that corrections took effect).

### Screen 4: Today proactive card
Placed directly under the freshness chip row, above Strain target. At most one per day, one per time slot.
```
 ┌ CoachNoteCard r28 ─────────────────┐
 │ Coach                         ✕    │ ← label graphite, dismiss 44 hit
 │ Room for a session. 30 min easy    │ ← headline 17, ≤14 words
 │ cardio keeps you in target.        │
 │ ( Plan it ) ( Not today )          │ ← 2 chips
 └────────────────────────────────────┘
```
"Plan it" opens `CoachSheet` with the turn already sent. "Not today" dismisses the card and remembers that for the time slot. Data-wise, the card is computed from the existing `Insights` rules. It works with no model at all, which is Apple's non-AI fallback. Only the conversation needs the model.

### Screen 5: history and "What Coach knows"
- **History** (top-left ≡): a list grouped by Today, Yesterday, then by date. Each row shows the first question (headline) and the time (caption). Swipe to delete. "Delete all chats" sits at the bottom in dangerText.
- **What Coach knows:** goals, equipment, injuries, preferred times. Each item can be edited or deleted, and there is one toggle, "Remember things I tell you".
- Memory saves are confirmed inline in the thread: "Saved: you prefer mornings. Undo" (caption + text button).

### Thinking and streaming
- **Before the first token:** `CoachThinking`, a 12-tick mini `TickRing` (20 pt) whose ticks light up one after another, ember on hair, at 8 ms a tick and looping. Next to it, a specific status in caption graphite, such as "Reading your last 7 nights…" or "Comparing with your normal…". The status comes from the tool calls actually in progress.
- **Streaming:** text appends in place. Each new chunk fades in, opacity 0→1 over 160 ms easeOut. There is no typewriter cursor and no bouncing dots. Cards appear with `Motion.enter` (220 ms, 0.96 scale) once the snapshot has all their required fields. Numbers inside cards never stream digit by digit: they appear complete.
- **Scrolling:** auto-scroll only while the user is at the bottom. If they scroll up, a "Jump to latest" capsule appears.
- **Chips** appear only after the stream ends, with a single crossfade (no per-chip stagger).
- **Reduce Motion:** the ring becomes a static "…" and every transition becomes an opacity change.

### Composer
`CoachComposer` is a capsule with `card` fill and a 0.5 hair stroke. It is 44 pt minimum and grows to at most 5 lines, then scrolls inside. The send button stays pinned at the trailing edge (the WHOOP bug). The mic uses on-device speech-to-text into the field: it never auto-sends and never speaks back in v1.1. Send is an ink circle with `arrow.up`, and turns into a `stop.fill` while streaming. The placeholder rotates by context: "Ask about your sleep, training…".

### Guardrail states (copy)
- **Medical or symptom question:** a `CoachNoticeCard` with dangerBg tint. "That's one for a doctor. If it's sudden or severe, call your local emergency number." Chip: "What can you help with?"
- **Missing data:** "Google Health hasn't sent HRV, so I'm leaving it out."
- **Model unavailable:** "Coach needs Apple Intelligence turned on." Button: "Open Settings". Today cards keep working.
- **Out of scope:** "I stick to your sleep, recovery and training. Try:" followed by 2 chips.

### Voice examples (second person, calm, no exclamation, no emoji)
- "Recovery 58 %, lower than your normal. Keep today easy, a walk is plenty."
- "You hit your strain target 4 of the last 7 days."
- "Breathing rate was high last night, 1.8 above usual. Worth an early night."
- "Three nights under 6 h. Want a wind-down plan?"

### Accessibility
- Each turn is one VoiceOver element: "Coach: …" or "You: …". Cards are separate elements with the same summaries the v1.0 charts already have.
- The reply body is **not** a live region. Post `.announcement` "Coach is replying", then "Coach replied" once, at the end.
- Chips are buttons with the hint "Sends this as your reply". Starter rows work the same way.
- Full Dynamic Type: bubbles reflow, chips wrap onto 2 rows at AX sizes instead of scrolling, and the composer stays usable at AX5.
- Contrast: the user bubble's ink fill with card-colour text passes AAA in both themes. No ember text: "Coach" labels use graphite.
- PlanRunner announces each step change and supports a VoiceOver magic tap for Pause.

### Component list
| Component | Notes |
|---|---|
| `CoachTabView` | Starter state + thread + toolbar |
| `CoachSheet` | Same thread, opened from context or Today |
| `CoachThreadView` | ScrollViewReader, stable ids per turn and block |
| `UserBubble` | Ink fill, r16, 78% max width |
| `CoachReply` | Unboxed text blocks + embedded cards + `ReplyActions` |
| `CoachDataCard` | MetricRow-lite, `BaselineRibbon`, `Sparkline`, `SourceLine` |
| `SourceLine` | "From your last 7 nights" + (i) popover listing the exact samples and dates |
| `SuggestionChip` / `ChipRow` | Max 3; wraps at AX sizes |
| `StarterRow` | Rows in a card on the empty state |
| `PlanCard` / `PlanStepRow` / `PlanRunnerView` | Workout and wind-down plans |
| `CoachNoteCard` | Today, rule-based |
| `CoachNoticeCard` | Guardrail and error states |
| `CoachThinking` | 12-tick ring + specific status text |
| `CoachComposer` | Text, mic, send/stop |
| `ReplyActions` | thumbs up, thumbs down, copy, retry as SF Symbols (`hand.thumbsup`…); feedback stays on device |
| `CoachHistoryView` / `CoachMemoryView` | Lists, swipe delete |

## Decisions for MRH1 v1.1

1. **Coach is the 5th tab** ("Coach", icon `bubble.left.and.text.bubble.right`), after Trends. No `sparkles` icon anywhere.
2. **Three entry layers:** the tab; an "Ask about this" row at the foot of every ScoreDetail and MetricSheet that opens `CoachSheet` seeded with that metric; and one `CoachNoteCard` on Today under the freshness chips.
3. **A Menu toggle turns the coach off entirely**, giving v1.0 behaviour. Push check-ins are opt-in, max 1 a day, with time slots matching the verdict (morning, afternoon, evening).
4. **The Today card is computed by `Insights` rules**, not the model, so it works offline, on unsupported devices, and when the model fails.
5. **Coach replies are unboxed body text.** User turns are ink `UserBubble`s with radius 16, 12/8 padding, 78% max width and no tail. Gap between turns 24, within a turn 12.
6. **Suggestion chips:** capsule, 36 pt visual with a 44 pt hit area, `label` type, hair stroke, max 3 after a reply, all specific to that reply. They appear only after streaming ends.
7. **Empty state:** 4 data-generated `StarterRow`s in one card, under a greeting sentence with today's numbers. No mascot, no avatar, no name beyond "Coach".
8. **Every number in a reply comes from MRH1's pipeline** and is rendered in a `CoachDataCard` with a `SourceLine` ("From your last 7 nights"). The model never prints a number that is not in its tool results. No citation on free-text claims.
9. **Workout and wind-down requests return a `PlanCard`** with Start, Save and 2 edit chips, plus `PlanRunnerView`, which uses a ember TickRing countdown and haptics. Every plan carries the line "Stop if you feel pain or dizziness."
10. **Thinking state:** a 12-tick mini TickRing plus specific status text taken from real tool calls. Streamed text fades in by chunk (160 ms), cards enter with `Motion.enter`, and numbers never stream. Reduce Motion means opacity only.
11. **Composer:** grows to max 5 lines with the send/stop button pinned; on-device dictation that never auto-sends; no spoken replies in v1.1.
12. **Control:** thumbs up/down, copy and retry under every reply; edits replace a card and leave a one-line "Replaced by…" stub; memory saves show an inline Undo; "What Coach knows" lets you view, edit and delete each item; history can be deleted one chat at a time or all at once.
13. **Disclosure:** a persistent caption on the empty state and in CoachSheet, "Uses your Apple Health data on this iPhone. Wellness estimates, not medical advice.", linking to "How Coach works". The first sentence changes if a cloud model is chosen, and must then name what is sent.
14. **Guardrail cards with fixed copy** for medical, missing-data, model-unavailable and out-of-scope cases. Symptoms always route to "That's one for a doctor…".
15. **Accessibility:** one element per turn, no live region on streaming text, a single "Coach replied" announcement, chips wrap at AX sizes, and the runner speaks each step.
16. **Copy follows §5:** ≤14 words for the insight sentence, one action per reply, no exclamation marks, no emoji, sentence case, and "Watch / Out of range" wording only.
