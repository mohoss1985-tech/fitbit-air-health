# 01 — What makes best-in-class brands feel crafted (and what that means for MRH1)

Agent: brand-craft research · 2026-11-02 · Scope: Linear, Vercel/Geist, Stripe, Raycast, Things 3, Arc, Airbnb, Apple (Fitness/Health/Weather/HIG), Teenage Engineering, Nothing.

## Sources

Primary (read):
- Linear, "How we redesigned the Linear UI" — https://linear.app/now/how-we-redesigned-the-linear-ui
- Linear, "Behind the latest design refresh" (Mar 2026) — https://linear.app/now/behind-the-latest-design-refresh
- Linear changelog, new UI (2024) — https://linear.app/changelog/2024-03-20-new-linear-ui
- Vercel Geist Typography — https://vercel.com/geist/typography
- Vercel Geist Colors — https://vercel.com/geist/colors
- Vercel Web Interface Guidelines — https://vercel.com/design/guidelines
- Stripe, "Designing accessible color systems" — https://stripe.com/blog/accessible-color-systems
- Raycast, "A fresh look and feel" — https://www.raycast.com/blog/a-fresh-look-and-feel
- Apple HIG Typography — https://developer.apple.com/design/human-interface-guidelines/typography
- Apple HIG Charting data — https://developer.apple.com/design/human-interface-guidelines/charting-data
- Apple HIG Activity rings — https://developer.apple.com/design/human-interface-guidelines/activity-rings
- Rauno Freiberg, "Invisible details of interaction design" — https://rauno.me/craft/interaction-design
- Airbnb, "Working Type" / Cereal — https://airbnb.design/working-type , https://airbnb.design/cereal/introduction

Secondary (low confidence, flagged in the text where used): Nothing analysis at https://madegooddesigns.com/nothing-brand-guidelines/ and the Nothing OS 5 community post https://nothing.community/d/61774-nothing-os-evolution; Teenage Engineering study at https://blakecrosley.com/guides/design/teenage-engineering; Arc at https://en.wikipedia.org/wiki/Arc_(web_browser) and https://blakecrosley.com/blog/design-study-arc; Things 3 reviews at https://medium.com/@jordanborth/an-ode-to-cultured-code-and-things-3-292e20112624. The pages I found with Stripe and Airbnb hex values or font tokens were community reconstructions, so I did not use them.

## Patterns per brand (brief)

**Linear.** It rebuilt theme generation in LCH, so a theme is now **3 inputs (base, accent, contrast) instead of 98 variables**. Surface elevation (background → panel → dialog → modal) is derived from those inputs, not hand-picked. Headings use a Display cut (Inter Display) and body uses the Text cut. Text and neutral icons were made *darker in light mode and lighter in dark mode*, so contrast went up. Blue was pulled out of the neutrals. The 2026 refresh added two principles. "Don't compete for attention you haven't earned": navigation is dimmed "a few notches" so content leads. "Structure should be felt not seen": fewer separators, at lower contrast. It also used fewer and smaller icons, removed the coloured icon backgrounds, and moved the greys toward a warmer, less saturated hue, while noting that "too warm looked muddy".

**Vercel / Geist.** Type is a closed set of named roles: Heading 72–14, Label 20–12, Copy 24–13, Button 16/14/12. *Label* is for single lines and *Copy* for multi-line text. Mono variants exist only at small sizes (14/13/12). Numbers are explicit: "Use Label 13 with tabular numerals." Colour scales have 10 steps where **each step has one job**: 100–300 fills (rest/hover/active), 400–600 borders, 700–800 solid fills, **900 = secondary text, 1000 = primary text**. The Web Interface Guidelines add these rules: nested radii are concentric and a child is never larger than its parent; ±1 px optical nudges; hover/active states have *more* contrast than rest; shadows have ≥2 layers (ambient + direct) plus a semi-transparent border; design empty, sparse, dense and error states; no dead ends; spinners show after 150–300 ms and stay ≥300–500 ms; 44 px mobile hit targets; `…` and curly quotes; interruptible motion that honours reduced motion.

**Stripe.** Colour is built in CIELAB so that **contrast is predictable from level numbers**: any two colours at least 5 levels apart pass 4.5:1 for small text, and at least 4 levels apart pass 3:1 for icons and large text. Badges shift background and text one level together instead of being tuned case by case. Colour is a system with rules, not a set of picks.

**Raycast.** One icon family: outline, slightly heavier stroke, and **one rule for stroke width and corner radius across the whole set**. The key control (search) gets a larger size. Even debug builds get their own icons.

**Things 3** (reviews only, low confidence). Two Apple Design Awards. Generous white space, custom type, motion "tuned for years", and colour used almost only for meaning (yellow star = Today, blue = scheduled). Most of the screen is black text on white.

**Arc** (secondary). The user picks a colour or gradient at onboarding, framed "like a movie opening". Motion is physical (Split View's "toddler pushing two blocks" bounce). The lesson is that personality lives in **one or two signature moments**, not across every surface.

**Airbnb.** It commissioned its own typeface, Cereal, because the fonts it reviewed worked "for brand and print but not UI, or vice versa". One voice from marketing to product. (Karri Saarinen, later Linear's co-founder, ran that team.)

**Apple (Fitness, Health, Weather).** The HIG gives the iOS scale at Large: Large Title 34/41, Title1 28/34, Title2 22/28, Title3 20/25, Headline 17/22 semibold, Body 17/22, Callout 16/21, Subhead 15/20, Footnote 13/18, Caption1 12/16, Caption2 11/13. The minimum is 11 pt. *"In general, avoid light font weights"* (Ultralight/Thin/Light). Use `.monospacedDigit()` wherever digits must align. Tracking tightens as size grows, and the system applies it automatically. Activity rings are **never recoloured or used as decoration**, and the UI "adapts to the rings, not the reverse". Chart guidance covers four points. Put a *descriptive headline* above the chart (Weather: "Chance of light rain in the next hour"). Keep charts simple and reveal detail progressively. Use the **same chart style for the small trend card and its expanded view** (Health Trends). Keep colours consistent for the same dataset.

**Teenage Engineering** (secondary). Black, white and **one orange**. Monospaced or bitmap type everywhere, used as a stance. Spec-sheet grids with thin rules and no shadows.

**Nothing** (secondary). Monochrome plus red. Red is an *interrupt*: "if nothing is urgent, no red on the screen". The Ndot dot-matrix face was later restricted to places where it "defines character rather than compromises readability" (OS 5 post).

## Cross-brand principles

1. **Restraint is the brand.** Each brand has one accent, used rarely and with meaning: TE orange, Nothing red, Linear's single accent input. The accent loses power every time it appears without a reason.
2. **Colour is generated, not picked.** Linear (LCH), Stripe (Lab) and Geist (role-numbered steps) all derive every shade from rules. That is why their neutrals look like one family.
3. **Every token has exactly one job.** Geist's step 900 is *always* secondary text. No "almost-graphite" variants.
4. **A closed, small type scale.** Roughly 8 named roles. Display cut above about 20 pt, Text cut below. Size *and* weight carry hierarchy, never colour alone. No light weights for UI text.
5. **Numbers are a first-class typographic object.** Tabular digits wherever values update or stack. Mono only at label sizes. Units smaller and in secondary colour, baseline-aligned to the number.
6. **Structure is felt, not seen.** Fewer borders and dividers, at lower contrast. Spacing and alignment do the grouping.
7. **Chrome recedes, content leads.** Navigation and icons are dimmed and smaller, and the data is the brightest thing on screen.
8. **Geometry obeys rules.** Concentric radii (inner = outer − padding). One icon stroke. ±1 pt optical correction for round glyphs and play/arrow shapes.
9. **Charts say what they mean.** A one-line headline sentence above, the same style at every size, one emphasised series with the rest muted.
10. **Personality in a few signature moments** (Arc's onboarding, Apple's ring intro). Everything else stays quiet.
11. **Every state is designed.** Empty, sparse, dense, error and loading, with delays tuned so nothing flickers.

## Vibe-coded tells to avoid

- Gradient or glow on every card. Purple-to-blue "AI" gradients. Coloured drop shadows.
- **Cards around everything**, every card with the same weight, padding and radius, and a border plus shadow plus fill all at once.
- Too many colours, with a different hue per metric chosen for variety rather than meaning. Status colours used as decoration.
- **Emoji as icons.** Mixed icon families, or SF Symbols in mixed weights. A coloured rounded-square badge behind every icon (Linear removed exactly this).
- Everything centred. Hero numbers floating with no baseline grid.
- Uniform weight (all semibold) or uniform grey. Secondary text that fails contrast because it "looks soft".
- **Too many font sizes** (11, 11.5, 12, 12.5, 13, 13.5…). Arbitrary letter-spacing per element.
- Inconsistent radii (20 / 22 / 26 / 9 / 2), with inner radii larger than the gap allows.
- Proportional digits that jitter while live values update. "0" shown for missing data.
- Springy bounce on every tap, animations that can't be interrupted, skeleton shimmer forever.
- Default chart gridlines and legends, no headline. Generic copy with exclamation marks.

**Audit note on our own v1 direction.** `design/v1-direction/index.html` currently uses **11 font sizes** (11, 11.5, 12, 12.5, 13, 13.5, 14, 14.5, 15, 17, 22+) and **six radii** (2, 9, 20, 22, 26, 99). Contrast computed against the moodboard tokens:
- `graphite #77726C` is 4.53:1 on card but only **4.0:1 on paper**, so it fails small text on paper.
- `ember #F0582A` is **3.25:1 on card**, so it is not usable as small text in light mode.
- `good #2F9D68` is **3.25:1**, so it works as a fill or dot, not as text (the chip-text tokens exist for that).
- `hair #DFDBD5` is 1.16:1 on paper, so it is effectively invisible there.

## Decisions for MRH1

1. **Type scale: closed set of 9 roles, SF Pro (Geist in web demo), no other sizes allowed.**

   | Token | Size/Leading | Weight | Tracking | Use |
   |---|---|---|---|---|
   | `display` | 56/56 | semibold | −0.04em | the one hero score per screen (rounded, tabular) |
   | `title` | 28/34 | semibold | −0.02em | screen titles |
   | `metric` | 34/38 | semibold | −0.03em | card numbers (tabular) |
   | `headline` | 17/22 | semibold | −0.01em | card titles |
   | `body` | 15/20 | regular | 0 | sentences, insights |
   | `label` | 13/16 | medium | 0 | row labels, chips, segmented control |
   | `caption` | 12/16 | regular | 0 | units, timestamps, axis labels (tabular) |
   | `overline` | 11/13 | semibold | +0.06em, uppercase | section eyebrows only, max one per card |
   | `mono` | 12/16 | medium (SF Mono) | 0 | "latest sample 4 min ago", raw values in Live |

   Map these onto Dynamic Type text styles (`.relativeTo:`) so they still scale. Never use Light, Thin or Ultralight.
2. **Numbers.** All numerals get `.monospacedDigit()`. Hero and metric numbers use `.fontDesign(.rounded)` to echo the round UI, and nothing else is rounded. Units are set in `caption` and `graphite`, with a 2 pt gap, baseline-aligned (e.g. **72** bpm). Missing values show `—` plus the "Not sent" caption, never 0. Live values animate with `.contentTransition(.numericText())`.
3. **Spacing: 4 pt base. Allowed values are 4 · 8 · 12 · 16 · 20 · 24 · 32 · 48.** Screen gutter 20. Card padding 20. Gap between cards 12. Section gap (between groups) 32. Spacing inside a row 8. Nothing else.
4. **Radii: three values plus the pill, nested concentrically.** `r.card` 28 (moodboard 26–30), `r.inner` 16 (= 28 − 12, for a tile inside a card with 12 inset), `r.chip` 8, `r.pill` = capsule (buttons, segmented, day circles). Retire 20, 22, 9 and 2. Chart bars use a 3 pt top radius only.
5. **Secondary text fix.** Darken `graphite` to **#6B665F**, giving 5.4:1 on card and 4.8:1 on paper. Add `graphite2 #A8A39C` for *non-text* only: axis ticks, disabled states, empty-track fills. In dark mode `ink2 #B4AEA7` is fine (7.5:1) and `ink3 #8A847D` is limited to non-essential captions or 13 pt+.
6. **Ember as a rare signal (TE/Nothing rule).** At most **one ember element per screen region**: the today marker, the strain ring, or the focused value. Never use it for small text in light mode. Where text has to be ember, use `ember-ink #B83F17` (5.3:1). Ember never appears on a chip, a border or an icon background.
7. **Status colours mean results only.** Green, yellow and red appear only next to a score judgement, as a 6 pt dot or a chip using the chip-bg/chip-text pairs. Never on charts as decoration and never as card tints. Iris is reserved for sleep and night series. A chart shows one emphasised series in ink, ember or iris, with the comparison series in `graphite2`.
8. **Structure felt, not seen.** Cards use fill only (`card` on `paper`): no border, no shadow in light mode. If depth is needed (the frosted icon buttons), use a 2-layer shadow (`0 1 2 / 4%` + `0 8 24 / 6%` of ink) plus a 0.5 pt `hair` stroke. Dividers inside cards are 0.5 pt (hairline) `hair`, inset by 20, and only between list rows. Use whitespace to group things instead of cards. Not every section needs a card.
9. **Chrome recedes.** The tab bar and top icon buttons use `graphite` icons. Only the selected tab is ink-filled. All SF Symbols share one weight, `.medium` at 17 pt in buttons and `.regular` inline. No coloured icon backgrounds. No emoji anywhere, including the journal tags (use text chips).
10. **Left-aligned, baseline-gridded.** Card titles, numbers and captions share one left edge at the 20 pt padding. Centre only the hero score and the ring contents. Round glyphs (rings, play, chevrons) get a ±1 pt optical nudge.
11. **Charts carry a headline.** Every chart card opens with a one-line descriptive sentence in `body`, for example "Resting HR 3 bpm below your 30-day average". One gridline style (0.5 pt `hair`, max 3 horizontal lines), no legends (label lines directly), and the same style in the small card and the expanded view.
12. **Colour generation.** Define neutrals in OKLCH from one warm hue (≈ h 60–70, chroma ≤ 0.012) with role steps in Geist style: paper → card → hair → graphite2 → graphite → ink. Derive dark/night by mirroring the lightness steps, not by hand-picking. Keep chroma low so the warmth doesn't turn muddy (Linear's warning).
13. **Motion: few and interruptible.** Taps get a 120 ms ease-out press at scale 0.97. Navigation and sheets use the system spring with no extra bounce. Live updates use numeric content transitions. High-frequency actions (range switch Live · 1H · 24H · 7D · 30D) cross-fade the data with no layout motion. Respect Reduce Motion (the orbs freeze). Loading indicators appear only after 200 ms and stay at least 400 ms.
14. **Signature moments (only two).** (a) The header orbs, OKLab-mixed and dithered, appearing **only at the top of Today and Live**. (b) The Live heart-rate trace drawing in as samples land, with a small ember pulse on the newest point. Every other surface stays calm paper and ink.
15. **Every state designed.** Empty ("No samples since 07:12 — Google Health usually syncs within an hour"), Not sent (HRV, skin temp, VO2 max), stale (>2 h shows a graphite clock glyph and the timestamp), and error. Each state names a next step. Copy uses the `…` character, curly quotes and sentence case, with no exclamation marks.
