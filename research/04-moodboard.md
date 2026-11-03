# 04 · Visual moodboard: gradients, texture and charts

Agent 04, 2 Nov 2026. The images are in `research/moodboard/` (31 JPGs, about 3 MB). I opened every one with the Read tool, and the descriptions below come from looking at them. Hex values marked "sampled" were read from the pixels with PIL.

## What I could and couldn't access

| Source | Result |
|---|---|
| **Pinterest** | The HTML search page and WebFetch both return an empty JS shell. The public JSON endpoint (`/resource/BaseSearchResource/get/`) did work without a login. I ran 9 searches (grainy gradient app ui, health app dashboard, dithered gradient poster, risograph gradient grain, wellness app ui warm, nothing os dot matrix ui, teenage engineering ui, gauge ring ui minimal, editorial data visualization) and got 224 pins. All 224 were downloaded, put on contact sheets and looked at, and 29 were kept. |
| Dribbble | HTTP 202 with an empty body, which is a bot challenge. Blocked. |
| Behance, Land-book | HTTP 403. Blocked. (Several of the Pinterest pins link back to Behance projects, so some Behance work is in the set anyway.) |
| Mobbin, Savee, Godly | The pages load, but they're client-rendered: I only got OG images and no gallery. Mobbin's catalogue needs a login. Not usable. |
| Awwwards, Stripe Press | Thumbnails came through. Awwwards was generic health marketing (none kept); 2 Stripe Press covers were kept. |
| TE, Nothing, Pentagram, Oura, Whoop | Product photos or OG images only. The TE and Nothing UI references came from Pinterest instead. |

## Reference list

Files are in `research/moodboard/`. "Pin img" means the `i.pinimg.com/736x/…` URL. Where a pin links to the original source, that link is given.

| # | File / source | What to take from it |
|---|---|---|
| 01 | `01-grain-orbs-diffuse-light…` pin img `12/cd/49/12cd49a0…` | Two **hard-edged discs** (#F96858 and #FFAC38, which the poster prints) with heavy mono grain. The orb has a shape before it fades out. This is the fix for "blurry". |
| 02 | `02-grain-orbs-red-orange-on-cream` pin `10/cd/20` | The same idea on cream. The orbs overlap and the overlap reads as a third colour, with no mud. Sampled #ED7564, #F2C274. |
| 03 | `03-orbital-trace…` instagram.com/p/DaLtiMKERC5 | An orb whose edge **breaks into a halftone dot screen**. Hairline arcs and a crosshair sit on top, with small mono coordinates. Paper #B9B2AC (sampled), violet #856AAC. |
| 04 | `04-the-coordinate…` psycvisual.com | Grain-textured warm grey paper, an ember flare, and line-screen hatching at the shadow edges. An "instrument on paper" feel. |
| 05 | `05-shift-poster…` Design_Archive01 | A single grainy ribbon on cream with lots of white space and three small colour dots as the legend. |
| 07 | `07-grain-violet-to-ink…` | A grainy violet-to-ink fade. A model for the evening/night variant. |
| 08 | `08-halftone-dot-arcs…` youcreativemedia | Concentric arcs drawn entirely in halftone dots, orange into lilac. A possible texture for rings. |
| 09–10 | `09-riso-stipple…`, `10-riso-ink-density…` | Real riso ink density steps and stipple. The reference for what "grain amount" should look like at 10–40 % coverage. |
| 11 | `11-grainy-gradients…` instagram.com/ellostudio.co | Ember #F4490B → peach #F2C2AF (sampled) with very fine grain. These are almost MRH1's own tokens, so it shows the palette works with grain. |
| 12 | `12-app-contexts…` akidataviz | Category orbs on a paper phone screen with mono labels. A data-driven use of orbs. |
| 14 | `14-hemoglobin-dot-matrix…` (Are.na) | **The best health-chart reference.** The range is a dot strip graded from pale to deep amber, with the current value as a dark dot in an "In range" pill. The trend is a dot-matrix column chart in which the dots fade with distance from the value. |
| 15 | `15-health-score-segmented-arc` Behance SKYFiN | A segmented, multi-colour arc around a big number on cream. |
| 17 | `17-wellness-78pct-ring…` pixelthebunny | A peach ring on blush paper with a serif headline ("Hello, sunshine"). |
| 18 | `18-daylight-calm-wellness-ui` graphicbull | A calm editorial wellness dashboard with a serif wordmark. |
| 19 | `19-dot-matrix-diagnostic…` newform.community | Dot-matrix charts on beige paper and on maroon, with mono labels and "BASELINE / DEVIATION" markers. Has real character. |
| 20–22 | `20-nothing-style-widget-grid`, `21-ndot…`, `22-dot-field…` | Nothing OS: the NDot type, widget grids, and a dot field fading from ember to black. |
| 23 | `23-knob-timer…` (Work Louder × Knob) | A capsule gauge whose orange→paper fill (#FB8126 → #F2C6A6, sampled) shrinks as time passes. A great strain/target gauge. |
| 24–25 | `24-te-op1…`, `25-te-ko2…` | Teenage Engineering: flat colour bars, a grey hardware shell, one orange accent, and tiny mono labels. |
| 26 | `26-tick-ring-gauge…` | **A tick ring**: about 60 radial ticks, with the filled ones in ember and the rest fading in grey. It has a lot more character than a solid stroke ring. |
| 27 | `27-industrial-widget-gauges…` | Light-grey cards with a burnt-orange (#AB5526, sampled) arc, dial and bar-tick gauges, and big grotesk numerals. |
| 28 | `28-editorial-area-chart…` quartr.com/insights/edge/the-dilemma-that-brought-down-kodak | **The model for line and fill.** On cream (#F3E9E0, sampled), a 2 pt line sits over an area fill that fades top to bottom and **carries visible grain**, with a hairline grid and one annotation pin. |
| 31 | `31-stripe-press-st-bob…` press.stripe.com (also 06, 13, 16, 29, 30, 32 in the folder) | A portrait rendered in ASCII/line halftone on flat orange. Texture made from type. |

## Three directions

### A. "Riso Paper" (editorial print) · refs 01–04, 09–11, 14, 28, 31

- **Palette:** paper #EDEBE7, card #FAF9F7, ink #151413, graphite #77726C, hair #DFDBD5, ember #F0582A, peach #F3A79E, iris #8B88F0. Status green/yellow/red stay reserved for results.
- **Type:** SF Pro for the UI. SF Mono for labels, timestamps and axes. **New York** (Apple's built-in serif, no licence needed) used only for the greeting and the one-sentence insight.
- **Gradient:** 2–3 orbs that keep a defined edge, mixed in OKLab, with mono film grain and a halftone fringe at the orb edges.
- **Charts:** an ink line over a grainy fill that fades out, hairline grid, dot-matrix range strips, tick rings.
- **Texture:** a printed feel. Fine grain everywhere a colour sits, and the paper stays almost clean.

### B. "Instrument" (TE / Nothing) · refs 19–27

- **Palette:** a cooler paper (#E6E4DF), ink, aluminium #B0B2AF, ember, plus signal orange #FB8126 for gauges.
- **Type:** SF Mono and a dot-matrix display face for big numerals. Grotesk labels.
- **Gradient:** almost none. Fields are drawn as ordered-dither dot fields (ref 22).
- **Charts:** dot-matrix everything, segmented bars and capsule gauges (ref 23).
- **Texture:** a flat surface plus a dot screen.
- **Trade-off:** the most distinctive of the three, but it reads as gadget and cold, and it drifts away from the soft orbs the owner chose.

### C. "Afterglow" (diffuse light) · refs 05–07, 11–13, 17–18

- **Palette:** peach #F3A79E, apricot #FFAC38, coral #F96858, lilac and cream.
- **Type:** a rounded sans with a serif display face.
- **Gradient:** large overlapping grainy blobs that fill the screen.
- **Charts:** soft rings and pastel bars.
- **Texture:** heavy grain.
- **Trade-off:** pretty, but it's the default Dribbble wellness look (ref 13). It's also the closest to what the owner just called "too blurry, no personality".

## Recommended: A, "Riso Paper", borrowing B's gauges

This direction keeps every existing token and the owner-approved orbs. It changes **how** they're rendered (shapes, grain, print textures) instead of changing the palette. From B it takes only the tick ring, the dot-matrix range strip and the capsule gauge, to give the data-viz its personality.

### Gradient spec (Metal `.colorEffect` / WebGL, same maths)

**Area.** The gradient covers the header band only. Full strength runs from 0 to 34 % of the screen height, and from 34 to 46 % it eases to bare paper with a smoothstep in OKLab. Nothing sits behind the cards.

**Shapes.** Positions and radii are in units of the screen width `w`. Orb centres can sit off-canvas.

| Orb | Colour | Centre (x, y) | Radius | Opacity |
|---|---|---|---|---|
| Ember | #F0582A | (0.86 w, 0.04 w) | 0.46 w | 1.0 |
| Peach | #F3A79E | (0.12 w, −0.02 w) | 0.60 w | 0.9 |
| Iris | #8B88F0 | (0.52 w, −0.10 w) | 0.24 w | 0.35 |

- **Edge (the anti-blur rule):** coverage = `1 − smoothstep(0.70 r, 1.0 r, d)`. The inner 70 % of the radius stays solid colour and only the outer 30 % fades. The current treatment is a full Gaussian, which is why it reads as fog.
- **Mixing:** overlaps composite in OKLab with premultiplied alpha. Never mix in sRGB.

**Grain.**
- **Kind:** monochrome luminance noise, one value per device pixel, from a hash or a 128² blue-noise texture.
- **Amount:** ±4 % OKLab L inside an orb, about ±10/255. The amount scales with orb coverage, so bare paper only gets ±1 %.
- **Motion:** none. The grain is static, and it reseeds only when the day changes. Animated grain looks like video noise.
- **Dither:** add ±0.5/255 triangular dither before 8-bit output to remove banding. On WebGL, use blue noise rather than Bayer.

**Halftone fringe.** This is what gives it character, after refs 03 and 08.
- **Where:** in the coverage band 0.12–0.40 of each orb, swap the smooth fade for a dot screen.
- **Grid:** 3.0 pt pitch (9 px @3x), rotated 15°.
- **Dots:** the dot radius is proportional to √coverage, in the orb's colour, with a 1 px anti-aliased edge.
- **Strength:** subtle. It should be visible at arm's length and read as print, not as a pattern.

**Motion.**
- **Drift:** each orb follows a Lissajous drift with amplitude 0.05 w. The periods are 41 s, 53 s and 67 s, chosen not to repeat in sync. Position moves; scale never pulses.
- **Day change:** crossfade the orb colours and positions over 600 ms with `cubic-bezier(0.23, 1, 0.32, 1)`.
- **Live tab:** when a new heart-rate sample lands, the ember orb radius goes +3 % and decays back over 500 ms with ease-out. That is the gradient's only reaction to data.
- **Reduce Motion:** static orbs, and the crossfade is cut to 150 ms opacity only.

**Evening / dark.**
- **Base:** ink #151413.
- **Orbs:** the same shapes at 0.55 opacity, with iris raised to 0.6.
- **Grain:** ±3 % L. The halftone fringe stays.
- **Model:** ref 07.

### Chart spec

**Line.**
- **Stroke:** 1.75 pt with round caps and joins. Ink #151413 for single-series charts; otherwise the metric's colour (ember for strain, iris for sleep). Curves use monotone cubic interpolation, never Catmull-Rom overshoot.
- **Missing data:** gaps stay gaps, with no interpolation across them. Fields Google Health doesn't send show "Not sent".

**Fill (ref 28).**
- **Gradient:** a vertical gradient under the line, from series colour at 24 % alpha down to 0 % at the baseline, mixed in OKLab.
- **Grain:** the same grain shader at ±3 % L, so the fill looks printed. This one detail is what most separates "editorial" from "template".

**Glow.**
- **Light mode:** none. Print doesn't glow.
- **Dark mode only:** a copy of the line with a 6 pt Gaussian blur at 22 % opacity.

**Current point.**
- **Dot:** 6 pt, ember, with a 2 pt card-coloured ring.
- **Live:** on each new sample, one ripple ring scales 1 → 2.4 while its opacity goes 0.35 → 0 over 1.1 s with ease-out. It does not loop.

**Grid and labels.**
- **Gridlines:** horizontal only, in hair #DFDBD5, 0.5 pt, dotted 1 on / 3 off.
- **Labels:** SF Mono 11 pt in graphite, tabular figures.
- **Annotations:** one at most per chart, as a 0.5 pt ink pin with a mono label.

**Range strips (ref 14).** These replace the plain range bars for vitals and the "your usual" bands.
- **Dots:** 4 pt dots on a 6.5 pt pitch. Out-of-range dots are hair-coloured. In-range dots step through the status colour at 30 → 100 % in OKLab.
- **Current value:** an ink dot with a pill label.

**Rings (ref 26).** Recovery, Strain and Sleep keep their rings, so no feature is lost.
- **Ticks:** the track becomes 48 radial ticks, 2 pt wide and 7 pt long, with round caps. Filled ticks are in the result colour and unfilled ticks are hair.
- **Fill animation:** ticks light up one after another, 8 ms apart, ease-out.
- **Number:** stays centred, in SF Pro Light.

**Bars (stress, steps).**
- **Shape:** 3 pt gap, 2 pt top radius, square base.
- **Colour:** status colours with the ±3 % grain. Future and empty slots are hair outlines, not grey fills.

**Strain target (ref 23).**
- **Shape:** a capsule gauge whose fill runs ember → peach in OKLab with grain.
- **Target zone:** drawn as two ink ticks, not a shaded band.
