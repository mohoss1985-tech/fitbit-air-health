//  Shaders.metal — MRH1 v1.0 graphics layer ("Riso Paper" print look).
//
//  SwiftUI [[stitchable]] shaders for iOS 17 (`.colorEffect`, Shader-as-ShapeStyle).
//  Spec: DESIGN_SPEC §3 + research/04 "Gradient spec" / "Chart spec".
//    * orbs are hard-cored discs: solid inner 70 % of r, smoothstep edge 70 → 100 %
//    * the fading edge breaks into a halftone dot screen (3 pt pitch, 15°)
//    * all mixing in OKLab, static per-device-pixel grain, triangular dither before 8-bit
//
//  Functions (argument order must match the Swift call sites exactly):
//    mrhOrbs        — header orbs                         (OrbBackground.swift)
//    mrhGrain       — static print grain on any layer     (View.printGrain, ChartStyle.swift)
//    mrhGrainedArea — ShapeStyle: vertical grained fill   (GrainedAreaFill, ChartStyle.swift)
//    mrhChartLine   — crisp SDF line + grained fill       (GlowLine, ShaderViews.swift)
//
//  `position` is in SwiftUI points (y down); `scale` = displayScale so every edge ramp is
//  exactly one device pixel wide — crisp, never blurry.

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

namespace mrh {

// ---------------------------------------------------------------- colour (OKLab, Ottosson 2020)
inline float3 oklabToLinear(float3 c) {
    float l_ = c.x + 0.3963377774f * c.y + 0.2158037573f * c.z;
    float m_ = c.x - 0.1055613458f * c.y - 0.0638541728f * c.z;
    float s_ = c.x - 0.0894841775f * c.y - 1.2914855480f * c.z;
    float l = l_ * l_ * l_, m = m_ * m_ * m_, s = s_ * s_ * s_;
    return float3( 4.0767416621f * l - 3.3077115913f * m + 0.2309699292f * s,
                  -1.2684380046f * l + 2.6097574011f * m - 0.3413193965f * s,
                  -0.0041960863f * l - 0.7034186147f * m + 1.7076147010f * s);
}

inline float3 linearToOklab(float3 c) {
    float l = 0.4122214708f * c.x + 0.5363325363f * c.y + 0.0514459929f * c.z;
    float m = 0.2119034982f * c.x + 0.6806995451f * c.y + 0.1073969566f * c.z;
    float s = 0.0883024619f * c.x + 0.2817188376f * c.y + 0.6299787005f * c.z;
    l = sign(l) * pow(abs(l), 1.0f / 3.0f);
    m = sign(m) * pow(abs(m), 1.0f / 3.0f);
    s = sign(s) * pow(abs(s), 1.0f / 3.0f);
    return float3(0.2104542553f * l + 0.7936177850f * m - 0.0040720468f * s,
                  1.9779984951f * l - 2.4285922050f * m + 0.4505937099f * s,
                  0.0259040371f * l + 0.7827717662f * m - 0.8086757660f * s);
}

inline float3 srgbToLinear(float3 c) {
    float3 a = abs(c);
    float3 lo = a / 12.92f;
    float3 hi = pow((a + 0.055f) / 1.055f, float3(2.4f));
    return sign(c) * select(hi, lo, a <= 0.04045f);
}

inline float3 linearToSRGB(float3 c) {
    c = clamp(c, 0.0f, 1.0f);
    float3 lo = c * 12.92f;
    float3 hi = 1.055f * pow(c, float3(1.0f / 2.4f)) - 0.055f;
    return select(hi, lo, c <= 0.0031308f);
}

// SwiftUI renders into gamma-encoded sRGB (8-bit) by default.
inline float3 oklabToOutput(float3 lab) { return linearToSRGB(oklabToLinear(lab)); }
inline float3 inputToOklab(float3 rgb)  { return linearToOklab(srgbToLinear(rgb)); }

// ---------------------------------------------------------------- noise
// PCG hash (Jarzynski & Olano 2020): white noise without sin() precision artefacts.
inline uint pcg(uint v) {
    uint s = v * 747796405u + 2891336453u;
    uint w = ((s >> ((s >> 28u) + 4u)) ^ s) * 277803737u;
    return (w >> 22u) ^ w;
}

/// Uniform [0,1) per integer cell.
inline float hash01(int2 p, uint seed) {
    return float(pcg(uint(p.x) + pcg(uint(p.y) + pcg(seed)))) * (1.0f / 4294967296.0f);
}

/// Static film grain in [-1, 1], triangular-ish (sum of two hashes) so it reads as tooth,
/// not as salt-and-pepper. One value per device pixel.
inline float grain(float2 devicePx, uint seed) {
    int2 c = int2(floor(devicePx));
    return hash01(c, seed) + hash01(c, seed ^ 0x9E3779B9u) - 1.0f;
}

// Interleaved gradient noise (Jimenez 2014) for dither.
inline float ign(float2 p) {
    return fract(52.9829189f * fract(dot(p, float2(0.06711056f, 0.00583715f))));
}

/// ±0.5 LSB triangular dither per channel, added before the 8-bit write.
inline float3 dither3(float2 devicePx) {
    float a = ign(devicePx);
    float b = ign(devicePx + float2(17.0f, 59.0f));
    float c = ign(devicePx + float2(41.0f, 23.0f));
    float d = ign(devicePx + float2(7.0f, 113.0f));
    return (float3(a, b, c) + float3(d, a, b) - 1.0f) * (0.5f / 255.0f);
}

// ---------------------------------------------------------------- halftone
/// Dot-screen coverage (0…1) for a tone value, 3 pt pitch rotated 15°, 1-device-px AA edge.
inline float halftone(float2 pt, float tone, float pitch, float scale) {
    const float cs = 0.96592583f, sn = 0.25881905f;           // 15°
    float2 q = float2(cs * pt.x - sn * pt.y, sn * pt.x + cs * pt.y) / pitch;
    float2 f = fract(q) - 0.5f;
    float dist = length(f) * pitch;                           // points
    float radius = pitch * sqrt(clamp(tone, 0.0f, 1.0f) / M_PI_F);
    return clamp((radius - dist) * scale + 0.5f, 0.0f, 1.0f);
}

// ---------------------------------------------------------------- one orb
/// Alpha of an orb at `p` (width units). `pt` = position in points for the dot screen.
/// Solid core to 0.70 r, smoothstep to r; in the low-coverage fringe the smooth fade is
/// replaced by halftone dots that run slightly past the rim (the "printed" edge).
inline float orbAlpha(float2 p, float2 c, float r, float2 pt, float scale, float dots) {
    float d = length(p - c);
    float smoothCov = 1.0f - smoothstep(0.70f * r, r, d);
    float tone = 1.0f - smoothstep(0.70f * r, 1.12f * r, d);  // wider ramp for the dots
    float band = 1.0f - smoothstep(0.26f, 0.46f, smoothCov); // 1 in the fringe, 0 in the body
    float screen = halftone(pt, tone * 0.82f, 3.0f, scale);
    float fringe = max(smoothCov * 0.30f, screen);
    return mix(smoothCov, fringe, band * dots);
}

} // namespace mrh

using namespace mrh;

// =====================================================================================
// mrhOrbs — header orbs over paper (light) or ink (dark).
// Swift (OrbBackground.swift):
//   Rectangle().colorEffect(ShaderLibrary.mrhOrbs(
//     .boundingRect, .float(time), .float(scale), .float(seed),
//     base, ember, peach, iris, status,            // OKLab .float3
//     .float4(emberA, peachA, irisA, statusA),     // opacities
//     .float(emberScale), .float(grainAmt), .float(dots)))
// =====================================================================================
[[ stitchable ]] half4 mrhOrbs(float2 position, half4 color, float4 bounds,
                                float time, float scale, float seed,
                                float3 base, float3 ember, float3 peach, float3 iris, float3 status,
                                float4 alphas, float emberScale, float grainAmt, float dots)
{
    float2 local = position - bounds.xy;
    float w = max(bounds.z, 1.0f);
    float h = max(bounds.w, 1.0f);
    float2 p = local / w;                                     // width units, y down
    const float TAU = 6.28318530718f;
    const float A = 0.05f;                                    // drift amplitude (w)

    // Lissajous drift, periods 41 / 53 / 67 s (never in sync). Positions move, scale never pulses.
    float2 cPeach  = float2(0.12f, -0.02f) + A * float2(sin(TAU * time / 53.0f + 0.7f), sin(TAU * time / 67.0f + 2.1f));
    float2 cEmber  = float2(0.96f, -0.06f) + A * float2(sin(TAU * time / 41.0f + 1.9f), sin(TAU * time / 53.0f + 0.3f));
    float2 cIris   = float2(0.52f, -0.10f) + A * float2(sin(TAU * time / 67.0f + 4.0f), sin(TAU * time / 41.0f + 5.2f));
    float2 cStatus = float2(0.60f,  0.40f) + A * float2(sin(TAU * time / 59.0f + 2.6f), sin(TAU * time / 47.0f + 1.1f));

    float2 pt = local;                                        // halftone grid in points (constant pitch)
    float3 lab = base;
    float cover = 0.0f;                                       // total ink coverage, drives grain

    float a;
    // Status first: peach/ember fringes print over it, so it joins the cluster without OKLab mud.
    a = orbAlpha(p, cStatus, 0.18f, pt, scale, dots) * alphas.w;
    lab = mix(lab, status, a); cover = cover + a * (1.0f - cover);
    a = orbAlpha(p, cPeach, 0.60f, pt, scale, dots) * alphas.y;
    lab = mix(lab, peach, a);  cover = cover + a * (1.0f - cover);
    a = orbAlpha(p, cEmber, 0.40f * emberScale, pt, scale, dots) * alphas.x;
    lab = mix(lab, ember, a);  cover = cover + a * (1.0f - cover);
    a = orbAlpha(p, cIris, 0.24f, pt, scale, dots) * alphas.z;
    lab = mix(lab, iris, a);   cover = cover + a * (1.0f - cover);

    // Header area: full strength to 0.74 of the fade length, eased to bare base (OKLab) by its end.
    float fadeEnd = min(w * 1.0f, h);
    float f = 1.0f - smoothstep(fadeEnd * 0.74f, fadeEnd, local.y);
    lab = mix(base, lab, f);
    cover *= f;

    // Static grain: ±grainAmt L scaled by coverage; bare paper keeps ±1 %.
    float2 devicePx = position * scale;
    float g = grain(devicePx, uint(seed));
    lab.x += g * mix(0.010f, grainAmt, cover);

    float3 rgb = oklabToOutput(lab) + dither3(devicePx);
    return half4(half3(clamp(rgb, 0.0f, 1.0f)), 1.0h);
}

// =====================================================================================
// mrhGrain — static print grain on an existing layer (bars, gauges, fills).
// Swift: .colorEffect(ShaderLibrary.mrhGrain(.float(amount), .float(scale), .float(seed)))
// amount = OKLab L amplitude (0.03 = ±3 %). Also modulates ink density ±(amount·5) so
// low-alpha fills look printed rather than airbrushed.
// =====================================================================================
[[ stitchable ]] half4 mrhGrain(float2 position, half4 color, float amount, float scale, float seed)
{
    float alpha = float(color.a);
    if (alpha < 0.002f) { return color; }
    float2 devicePx = position * scale;
    float g = grain(devicePx, uint(seed));
    float3 rgb = float3(color.rgb) / alpha;                   // un-premultiply
    float3 lab = inputToOklab(rgb);
    lab.x += g * amount;
    float3 outRGB = oklabToOutput(lab) + dither3(devicePx);
    float outA = alpha < 0.999f ? clamp(alpha * (1.0f + g * amount * 5.0f), 0.0f, 1.0f) : alpha;
    return half4(half3(clamp(outRGB, 0.0f, 1.0f) * outA), half(outA));
}

// =====================================================================================
// mrhGrainedArea — ShapeStyle shader: series colour `top`·alpha at the top of the shape's
// bounds fading to 0 at its bottom, with printed grain (ref 28).
// Swift: ShaderLibrary.mrhGrainedArea(.boundingRect, .color(c), .float(top), .float(amount),
//                                     .float(scale), .float(seed))
// =====================================================================================
[[ stitchable ]] half4 mrhGrainedArea(float2 position, float4 bounds, half4 color,
                                       float top, float amount, float scale, float seed)
{
    float v = clamp((position.y - bounds.y) / max(bounds.w, 1.0f), 0.0f, 1.0f);
    float ca = max(float(color.a), 1e-3f);
    float3 lab = inputToOklab(float3(color.rgb) / ca);
    float2 devicePx = position * scale;
    float g = grain(devicePx, uint(seed));
    lab.x += g * amount;
    float a = top * ca * pow(1.0f - v, 1.25f);
    a = clamp(a * (1.0f + g * 0.65f) + (ign(devicePx) - 0.5f) / 255.0f, 0.0f, 1.0f);
    float3 rgb = clamp(oklabToOutput(lab) + dither3(devicePx), 0.0f, 1.0f);
    return half4(half3(rgb * a), half(a));
}

// =====================================================================================
// mrhChartLine — crisp SDF polyline + grained area fill + optional (dark-only) glow.
// Swift (GlowLine): Rectangle().colorEffect(ShaderLibrary.mrhChartLine(
//   .boundingRect, .floatArray(ys), .float(lineWidth), lineLab, .float(fillAlpha),
//   .float(glow), .float(grainAmt), .float(scale)))
// ys: 0 (bottom) … 1 (top), evenly spaced in x; negative = gap (gaps stay gaps).
// Only ±8 neighbouring segments are tested per pixel → O(1) in series length.
// =====================================================================================
[[ stitchable ]] half4 mrhChartLine(float2 position, half4 color, float4 bounds,
                                     device const float *ys, int count,
                                     float lineWidth, float3 lineLab, float fillAlpha,
                                     float glow, float grainAmt, float scale)
{
    if (count < 2) { return half4(0.0h); }
    float2 p = position - bounds.xy;
    float w = max(bounds.z, 1.0f);
    float h = max(bounds.w, 1.0f);
    float dx = w / float(count - 1);
    float fi = p.x / dx;
    int i0 = clamp(int(floor(fi)), 0, count - 2);
    float glowR = 6.0f;
    int k = min(int(ceil((glowR + lineWidth) / dx)) + 1, 8);

    float d = 1e6f;
    int jEnd = min(i0 + k, count - 2);
    for (int j = max(i0 - k, 0); j <= jEnd; ++j) {
        float ya = ys[j], yb = ys[j + 1];
        if (ya < 0.0f || yb < 0.0f) { continue; }
        float2 a = float2(float(j) * dx, (1.0f - ya) * h);
        float2 b = float2(float(j + 1) * dx, (1.0f - yb) * h);
        float2 pa = p - a, ba = b - a;
        float t = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-6f), 0.0f, 1.0f);
        d = min(d, length(pa - ba * t));
    }
    // A lone point between two gaps still shows as a dot.
    {
        float yi = ys[i0], yn = ys[i0 + 1];
        if (yi >= 0.0f && (i0 == 0 || ys[i0 - 1] < 0.0f) && yn < 0.0f) {
            d = min(d, length(p - float2(float(i0) * dx, (1.0f - yi) * h)));
        }
    }

    float2 devicePx = position * scale;
    float g = grain(devicePx, 11u);
    float3 rgb = oklabToOutput(lineLab);
    float4 outc = float4(0.0f);

    // Grained fill: 24 % at the top of the plot → 0 at the baseline, only under the line.
    float ya = ys[i0], yb = ys[i0 + 1];
    if (fillAlpha > 0.0f && ya >= 0.0f && yb >= 0.0f) {
        float t = clamp(fi - float(i0), 0.0f, 1.0f);
        float yLine = (1.0f - mix(ya, yb, t)) * h;
        float under = clamp((p.y - yLine) * scale + 0.5f, 0.0f, 1.0f);
        float a = fillAlpha * pow(clamp(1.0f - p.y / h, 0.0f, 1.0f), 1.15f) * under;
        a = clamp(a * (1.0f + g * 0.65f) + (ign(devicePx) - 0.5f) / 255.0f, 0.0f, 1.0f);
        float3 fl = lineLab; fl.x += g * grainAmt;
        float3 frgb = oklabToOutput(fl);
        outc = float4(frgb * a, a);
    }

    // Dark mode only: soft glow (6 pt, 22 %).
    if (glow > 0.0f && d < glowR + lineWidth) {
        float x = max(d - lineWidth * 0.5f, 0.0f) / (glowR * 0.5f);
        float ga = glow * exp(-x * x);
        outc = float4(rgb * ga, ga) + outc * (1.0f - ga);
    }

    // Core line: exact 1-device-pixel anti-aliased edge.
    float la = clamp((lineWidth * 0.5f - d) * scale + 0.5f, 0.0f, 1.0f);
    outc = float4(rgb * la, la) + outc * (1.0f - la);

    outc = clamp(outc, 0.0f, 1.0f);
    outc.rgb = min(outc.rgb, float3(outc.a));
    return half4(outc);
}
