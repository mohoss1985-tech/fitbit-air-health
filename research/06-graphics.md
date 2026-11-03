# 06 · Graphics layer: orbs, rings, charts (Metal + WebGL2)

Agent report, 2 Nov 2026. Draft code: `research/graphics-draft/` (`Shaders.metal`, `ShaderViews.swift`, `orbs-webgl.js`).

## 1. What was wrong before

The v1-direction shader (`design/v1-direction/index.html`, "WebGL orbs") already mixes in OKLab and dithers. It still looks blurry because of **how each orb is shaped**: every orb is `exp(-d²/r)`, and the orbs are blended with normalised weights `(bg·wb + Σ cᵢ·wᵢ) / (wb + Σ wᵢ)`. A Gaussian has no edge, and normalised weights pull every pixel towards the average of all the colours. The result is one smooth fog with no shapes, no light and no depth, which is the "no personality" the owner sees. The body-light prototype has the same problem and adds RGB mixing.

**Fix in one sentence:** treat orbs as *objects*, not weights. Each orb is a signed-distance disc with a defined rim, lit from one side, composited in order (painter's algorithm) in OKLab over paper. Grain and dither run at true device resolution.

## 2. Decisions

| # | Decision | Why |
|---|---|---|
| D1 | **Pure Metal `.colorEffect` stitchable shaders, no `MeshGradient`** | GOAL §4. iOS 17 has `ShaderLibrary` and `.colorEffect/.layerEffect/.distortionEffect`. `colorEffect` is enough here because the orbs are generated, not sampled, and it is the cheapest of the three (no layer read). |
| D2 | **All colours enter the shader as OKLab `float3`**, converted on the CPU (`OKLab` struct). | `Shader.Argument.color` arrives as premultiplied `half4` "in the target colour space", which makes it hard to know what you are mixing. Passing OKLab floats is exact and the same on iOS and web. |
| D3 | **SDF orbs with asymmetric edges**: soft inside (30 % of r), tight outside (6 % of r) | You see a clear silhouette but no hard cartoon line. The rim wobbles through 3rd + 5th angular harmonics (seam-free, ±3.5 %), so shapes look liquid, never like perfect circles. |
| D4 | **Lit body + rim band** (L +0.055 toward the top-left, L +0.03 and chroma ×1.14 on the rim) | This gives the orbs volume and a "glass bead" edge. Most of the personality comes from here. |
| D5 | **Composite order** paper → peach → warm glow → status → ember | Ember (brand) sits on top, small, top-right. Status is the largest and centre-right, and breathes ±1.5 % on an 8 s cycle. |
| D6 | **Fade to exact paper in OKLab**, over 38 %→95 % of the header height | The bottom of the header matches the `paper` background exactly, with no grey seam and no visible rectangle edge. |
| D7 | **Static luma grain**, 1.5-device-px clusters, OKLab L ±0.010 (light) / ±0.016 (night), weaker where the gradient has faded out | Grain that changes every frame at 30 fps looks like video noise. Static grain looks like paper tooth, which fits the warm-paper board. |
| D8 | **Triangular-PDF dither, ±1 LSB, after the final sRGB encode**, using interleaved gradient noise rotated each frame | Wronski's comparison shows triangular noise removes banding without visible noise. Zed's GPUI uses the same ±1/255 fix for dark gradients. It must run in the shader *before* the 8-bit write: dithering an 8-bit buffer later does nothing. |
| D9 | **Every edge gets a 1 device-pixel AA ramp** (`clamp(0.5 − d·scale)`) with `scale = displayScale` passed in | This is what "crisp" means: SDF edges are exactly one physical pixel wide on 2× and 3× screens. Lines can be true hairlines (`lineWidth = 1/scale`). |
| D10 | **Battery:** `TimelineView(.animation(minimumInterval: 1/30, paused:))`, paused when Reduce Motion is on, the header has scrolled off (`onGeometryChange`, back-deployed to iOS 16), the view is gone, or `scenePhase != .active` | The orbs drift on 40–70 s cycles, so 30 fps is plenty. One draw pass, 4 orbs, about 1.5 M px at 3×, which is well inside budget. |
| D11 | **Reduce Motion:** time frozen at a fixed good composition (t = 8), state changes snap (no 1.2 s morph), the live dot shows a static halo | Matches the PROJECT_NOTES motion rule ("Reduce Motion → opacity only / frozen"). |
| D12 | **Charts: Swift Charts stays the base** (axes, selection, VoiceOver) with a hairline grid and `.interpolationMethod(.monotone)` (no overshoot, unlike catmullRom). The **glow + area fill come from a shader underlay** placed exactly in `plotFrame` (`.mrhGlowUnderlay`) | We keep every v0.4 chart and its accessibility, and only the pixels get better. For sparklines and the Live chart, `GlowLine` can be used alone. |
| D13 | **Web: raw WebGL2, no OGL/three** | One full-screen triangle and one program. OGL would add a dependency for about 40 lines of setup. WebGL2 gives `uint` hashes and `#version 300 es`. If WebGL2 is missing, we fall back to CSS gradients. |
| D14 | **Web DPR:** `ResizeObserver` with `box:'device-pixel-content-box'` (exact physical pixels), falling back to `round(css·devicePixelRatio)` on Safari. Full DPR (not capped at 2) up to 2.4 M px | Fractional backing sizes resample and blur the grain. Safari does not support `devicePixelContentBoxSize`, hence the fallback. |

## 3. Visual spec

### Ambient orbs (Today header only)

Units are fractions of view width, y measured from the top. Frequencies are in rad/s.

| Orb | Colour (light) | Centre | r | Opacity |
|---|---|---|---|---|
| Peach | `#F3A79E` | (0.14 ± 0.06, 0.22 ± 0.05), ω 0.13 / 0.10 | 0.44 | 0.85 |
| Warm glow | good `#F6C9B8` · limit `#F6CFAE` · danger `#F4B9B0` | (0.42 ± 0.10, 0.04 ± 0.03), ω 0.09 / 0.16 | 0.28 | 0.75 |
| **Status** | good `#9AD3B2` · limit `#F2D46A` · danger `#E77A86` · neutral `#E9D9C8` | (0.60 ± 0.12, 0.44 ± 0.04), ω 0.11 / 0.14 | 0.38, breath ±1.5 % / 8 s | 0.92 |
| Ember | `#F0582A` | (0.90 ± 0.05, 0.10 ± 0.04), ω 0.15 / 0.12 | 0.30 | 0.90 |

The night palette (dusk, from v1-direction state 4) is paper `#141318`, peach `#6E4A63`, glow `#3A2E48`, status `#5B53A8`, ember `#B8442A`, with lighting 0.035 and grain 0.016.

A state change morphs all five colours in OKLab over 1.2 s, eased to approximate `cubic-bezier(0.77,0,0.175,1)`. The time uniform wraps every 10 000 s, which gives one invisible jump about every 2.8 h.

### Rings (`mrhRingGlow` / `GlowRing`)

- Exact SDF ring with round caps. 0° is at 12 o'clock, clockwise. 1-px AA.
- An OKLab gradient runs along the arc from `start` to `end` (for example good `#2F9D68` → `#4CC789`). "Tube" lighting adds up to L +0.03 at the stroke centreline, so it looks like a stroke with volume, not a flat SVG line.
- The glow is concentrated at the **head** (`exp(-dist/2.5·lw)`), the live end of the score, at 0.6 strength. It sits on the outside of the stroke only.
- Above 85 % progress, the head cap draws on top with a small forward shadow, in the style of Apple's Activity rings. This hides the seam when the ring is full.
- The track is `hair` (`#DFDBD5` / night `#33313B`). Output is premultiplied, so it composites on cards.
- `progress` is `Animatable`, so it animates with the enter curve `timingCurve(0.23,1,0.32,1)`.

### Charts

- **Line:** 1.5 pt with round caps and joins. Pass 0 to get a 1-device-px hairline. Ember for HR/strain, iris for sleep, status colours only on result bands.
- **Glow:** a Gaussian of radius max(5·lw, 7 pt) at 0.35·glow alpha. Off for dense comparison charts, 0.5 for the Live HR line.
- **Area fill:** a *local* ramp from the line down to the baseline, `fill·v^1.8`, starting at 0.20, slightly lighter than the line (L +0.04). The alpha is dithered, because low-alpha ramps band worst.
- **Gaps:** `nil` values break the line and the fill ("Not sent" and sync holes stay honest).
- **Grid:** y hairlines only (`1/displayScale`), no x grid. 11 pt monospaced-digit labels in graphite `#77726C`. Dividers use `Hairline`, which is pixel-snapped through `PixelSnap.snap`.
- **Live point:** `LivePulse`, a 7 pt dot with a 1.5 pt paper ring and a soft shadow. Every 2 s a ring expands to 3.6× with an ease-out cubic and fades. It is static under Reduce Motion. It lives in a separate tiny view, so the chart shader never re-renders for the animation.
- **Cost:** the line shader tests only ±8 neighbouring segments per pixel (O(1) in series length). The series is bucket-averaged to ≤ 240 points. The shader re-renders only when the data changes, since there is no TimelineView around it.

## 4. Integration notes for the build agents

1. Copy `Shaders.metal` and `ShaderViews.swift` into `MRH1/`. The synchronized group picks them up, and `ShaderLibrary.default` finds the `[[stitchable]]` functions by name. **Argument order must match exactly**; each call site has a comment listing it.
2. **Blocker:** this Mac's Xcode 27.2 has **no Metal Toolchain installed** (`xcrun metal` → "missing Metal Toolchain; use: xcodebuild -downloadComponent MetalToolchain"). Any `.metal` file in `MRH1/` will fail the build until someone runs `xcodebuild -downloadComponent MetalToolchain` (it is a system download, so the owner or orchestrator must approve it). I could not compile `Shaders.metal` here. I reviewed it by hand against MSL 3 and the SwiftUI shader signatures. `ShaderViews.swift` **typechecks cleanly** with `swiftc -typecheck -target arm64-apple-ios17.0-simulator`.
3. SwiftUI renders into 8-bit, gamma-encoded sRGB by default, so the shaders gamma-encode their output. If a parent ever uses `.drawingGroup(colorMode: .linear)`, set `MRH_OUTPUT_LINEAR 1`.
4. Use `AmbientOrbs(state:)` as the Today header background with `.frame(height: ~420).ignoresSafeArea(edges: .top)`. Put frosted 42 pt icon buttons and the week strip on top. Map `Scores` recovery to the state like this: ≥ 67 → good, ≥ 34 → limit, < 34 → danger, evening → night, no data → neutral.
5. Web: load `orbs-webgl.js` as a plain script and call `MRHOrbs.mount(canvas, {state})` / `.setState()`. The canvas must be CSS-sized (`width:100%;height:100%`). The script sets the backing size itself. It pauses with IntersectionObserver and `visibilitychange`, respects `prefers-reduced-motion` live, handles context loss, caps at 30 fps, and falls back to CSS gradients.
6. The GLSL is a line-for-line port of `mrhOrbField`; keep them in sync.

## 5. Reference notes

Stripe moves a noise-deformed mesh (`minigl`), so its gradient reads as shapes, not blur. Linear and Vercel use few colours, fine grain and one accent glow: restraint plus grain looks expensive. Apple Weather and Activity use perceptual mixing and lit ring tubes with a head-cap shadow, which is the model for `mrhRingGlow`.

## Sources

- SwiftUI shader APIs (iOS 17, `[[stitchable]]`, TimelineView driving time, one pass per modifier): [Hacking with Swift: layer effects](https://hackingwithswift.com/quick-start/swiftui/how-to-add-metal-shaders-to-swiftui-views-using-layer-effects), [cnblogs: Metal shaders in SwiftUI](https://cnblogs.com/jerrywossion/p/18090457), [Cindori: SwiftUI shaders](https://cindori.com/developer/swiftui-shaders-wave)
- `Shader.Argument` (`floatArray` → `device const float*, int`, `color` → premultiplied half4, `boundingRect`): [Apple: Shader.Argument](https://developer.apple.com/documentation/swiftui/shader/argument.md), [Apple: boundingRect](https://developer.apple.com/documentation/swiftui/shader/argument/boundingrect.md), [Metal Shader Effect details (ta_ka_tsu)](https://docswell.com/s/ta_ka_tsu/KMXGD9-2025-01-25-DetailOfMetalShaderEffect)
- OKLab: [Ottosson: A perceptual color space for image processing](https://bottosson.github.io/posts/oklab/), [Wikipedia: Oklab](https://en.wikipedia.org/wiki/Oklab_color_space), [Smashing interview with Ottosson](https://smashingmagazine.com/2024/10/interview-bjorn-ottosson-creator-oklab-color-space/)
- Dithering: [Bart Wronski: Dithering part three](https://bartwronski.com/2016/10/30/dithering-part-three-real-world-2d-quantization-dithering/), [Zed GPUI gradient dither commit](https://git.secluded.site/zed/commit/a46858ac21ec43b1af94d8b2b9a5a8fde4ac4f01), [Anisoptera: fixing banding with dithering](https://www.anisopteragames.com/how-to-fix-color-banding-with-dithering/)
- SDF arcs and segments: [Inigo Quilez: 2D distance functions](https://iquilezles.org/articles/distfunctions2d)
- Stripe gradient: [Bramus: How to create the Stripe website gradient](https://www.bram.us/2021/10/13/how-to-create-the-stripe-website-gradient-effect)
- Web DPR: [web.dev: Pixel-perfect rendering with devicePixelContentBox](https://web.dev/articles/device-pixel-content-box), [MDN: devicePixelContentBoxSize](https://developer.mozilla.org/en-US/docs/Web/API/ResizeObserverEntry/devicePixelContentBoxSize)
