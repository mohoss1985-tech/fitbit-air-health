//  Shaders.metal — MRH1 v1.0 graphics layer (draft)
//
//  SwiftUI stitchable shaders for iOS 17+ (`.colorEffect`). No MeshGradient dependency.
//  All colour inputs are OKLab float3 computed on the CPU (see OKLab in ShaderViews.swift);
//  all mixing happens in OKLab; conversion to gamma-encoded sRGB happens once, at the end,
//  followed by a triangular-PDF dither of +-1 LSB (8-bit target) to kill banding.
//
//  Functions (argument order must match ShaderViews.swift exactly):
//    mrhOrbField   — Today header: paper + 4 SDF orbs (peach, glow, status, ember)
//    mrhRingGlow   — score ring/arc: crisp SDF arc, OKLab gradient along arc, lit tube, glowing head
//    mrhChartLine  — chart line: crisp SDF polyline (hairline-capable), local area fill, soft glow
//
//  Coordinates: `position` is in SwiftUI points, y down. `scale` = displayScale (2 or 3) and is
//  used to make every edge exactly ~1 device pixel wide (crisp, not blurry).

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// SwiftUI's default render target is 8-bit, gamma-encoded sRGB. If a host view ever wraps the
// effect in `.drawingGroup(colorMode: .linear)` set this to 1.
#define MRH_OUTPUT_LINEAR 0

namespace mrh {

constant float TAU = 6.28318530718f;

// ---------------------------------------------------------------- colour
inline float3 oklabToLinear(float3 c) {
    float l_ = c.x + 0.3963377774f * c.y + 0.2158037573f * c.z;
    float m_ = c.x - 0.1055613458f * c.y - 0.0638541728f * c.z;
    float s_ = c.x - 0.0894841775f * c.y - 1.2914855480f * c.z;
    float l = l_ * l_ * l_;
    float m = m_ * m_ * m_;
    float s = s_ * s_ * s_;
    return float3( 4.0767416621f * l - 3.3077115913f * m + 0.2309699292f * s,
                  -1.2684380046f * l + 2.6097574011f * m - 0.3413193965f * s,
                  -0.0041960863f * l - 0.7034186147f * m + 1.7076147010f * s);
}

inline float3 linearToSRGB(float3 c) {
    c = clamp(c, 0.0f, 1.0f);
    float3 lo = c * 12.92f;
    float3 hi = 1.055f * pow(c, float3(1.0f / 2.4f)) - 0.055f;
    return select(hi, lo, c <= 0.0031308f);
}

inline float3 oklabToOutput(float3 lab) {
#if MRH_OUTPUT_LINEAR
    return clamp(oklabToLinear(lab), 0.0f, 1.0f);
#else
    return linearToSRGB(oklabToLinear(lab));
#endif
}

// ---------------------------------------------------------------- noise
// PCG hash (Jarzynski & Olano 2020): good white noise, no sin() precision artefacts.
inline uint pcg(uint v) {
    uint s = v * 747796405u + 2891336453u;
    uint w = ((s >> ((s >> 28u) + 4u)) ^ s) * 277803737u;
    return (w >> 22u) ^ w;
}

inline float hash01(uint2 p, uint seed) {
    return float(pcg(p.x + pcg(p.y + pcg(seed)))) * (1.0f / 4294967295.0f);
}

// Interleaved gradient noise (Jimenez 2014): cheap, blue-ish spectrum, ideal for dither.
inline float ign(float2 p) {
    return fract(52.9829189f * fract(dot(p, float2(0.06711056f, 0.00583715f))));
}

// Uniform [0,1) -> triangular PDF in [-1,1] (Gjøl / Wronski remap).
inline float triPDF(float n) {
    float v = n * 2.0f - 1.0f;
    return sign(v) * (1.0f - sqrt(1.0f - abs(v)));
}

// +-1 LSB triangular dither per channel, decorrelated, temporally rotated by `frame`.
inline float3 dither3(float2 devicePx, float frame) {
    float2 o = float2(5.588238f, 5.588238f) * fmod(frame, 64.0f);
    return float3(triPDF(ign(devicePx + o)),
                  triPDF(ign(devicePx + o + float2(17.0f, 59.0f))),
                  triPDF(ign(devicePx + o + float2(41.0f, 23.0f)))) * (1.0f / 255.0f);
}

// ---------------------------------------------------------------- SDF helpers
inline float sdSegment(float2 p, float2 a, float2 b) {
    float2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-6f), 0.0f, 1.0f);
    return length(pa - ba * h);
}

// Coverage of a signed distance (points) with a ~1 device-pixel ramp.
inline float aaCoverage(float d, float scale) {
    return clamp(0.5f - d * scale, 0.0f, 1.0f);
}

inline void overPremul(thread float4 &dst, float3 rgb, float a) {
    dst.rgb = rgb * a + dst.rgb * (1.0f - a);
    dst.a   = a + dst.a * (1.0f - a);
}

// ---------------------------------------------------------------- orbs
// One orb: a disc whose rim wobbles slowly (low-order angular harmonics, seam-free),
// with a defined edge (`softIn` inside, `softOut` outside), inner light from the top-left
// and a thin rim band. This is what gives the orbs shape instead of the old Gaussian fog.
struct Orb {
    float coverage;
    float rim;
    float light;
};

inline Orb orb(float2 p, float2 c, float r, float t, float seed) {
    float2 d2 = p - c;
    float d = length(d2);
    float th = (d > 1e-5f) ? atan2(d2.y, d2.x) : 0.0f;
    float wobble = 0.035f * sin(3.0f * th + t * 0.21f + seed)
                 + 0.020f * sin(5.0f * th - t * 0.17f + seed * 1.7f);
    float re = r * (1.0f + wobble);
    float softIn  = r * 0.30f;   // wide, luminous falloff inside
    float softOut = r * 0.06f;   // tight outside -> the edge reads
    Orb o;
    o.coverage = 1.0f - smoothstep(re - softIn, re + softOut, d);
    float x = (d - (re - softIn * 0.35f)) / (r * 0.10f);
    o.rim = exp(-x * x);
    float2 lightPos = c + float2(-0.35f, -0.45f) * r;
    o.light = clamp(1.0f - length(p - lightPos) / (r * 1.2f), 0.0f, 1.0f);
    return o;
}

inline float3 shadeOrb(float3 lab, Orb o, float lightAmt) {
    float3 s = lab;
    s.x += lightAmt * o.light * o.light;          // lit body
    s.x += 0.030f * o.rim;                         // crisp luminous rim
    s.yz *= 1.0f + 0.14f * o.rim;                  // rim slightly more chromatic
    return s;
}

} // namespace mrh

using namespace mrh;

// =====================================================================================
// mrhOrbField — the Today header background.
// Swift: Rectangle().colorEffect(ShaderLibrary.mrhOrbField(
//   .boundingRect, .float(time), paper, peach, glow, status, ember,   // OKLab .float3
//   .float(grain), .float(fadeStart), .float(fadeEnd), .float(scale), .float(frame), .float(night)))
// time: seconds (frozen under Reduce Motion). fadeStart/fadeEnd: 0..1 of view height where
// the orbs dissolve into paper. grain: OKLab L amplitude (0.010 light, 0.016 night).
// =====================================================================================
[[ stitchable ]] half4 mrhOrbField(float2 position, half4 color, float4 bounds,
                                    float time,
                                    float3 paper, float3 peach, float3 glow, float3 status, float3 ember,
                                    float grain, float fadeStart, float fadeEnd,
                                    float scale, float frame, float night)
{
    float2 local = position - bounds.xy;
    float w = max(bounds.z, 1.0f);
    float h = max(bounds.w, 1.0f);
    float2 p = local / w;                 // width units, y down
    float vy = local.y / h;               // 0..1 of height
    float t = time;

    // Orb layout (width units). Frequencies 0.09–0.16 rad/s -> 40–70 s drift cycles.
    float breath = 1.0f + 0.015f * sin(t * 0.785f);   // status orb breathes on an 8 s cycle
    float2 cPeach  = float2(0.14f + 0.06f * cos(t * 0.13f),        0.22f + 0.05f * sin(t * 0.10f + 1.0f));
    float2 cGlow   = float2(0.42f + 0.10f * sin(t * 0.09f + 3.0f), 0.04f + 0.03f * cos(t * 0.16f));
    float2 cStatus = float2(0.60f + 0.12f * cos(t * 0.11f + 2.0f), 0.44f + 0.04f * sin(t * 0.14f));
    float2 cEmber  = float2(0.90f + 0.05f * sin(t * 0.15f),        0.10f + 0.04f * cos(t * 0.12f));

    float lightAmt = mix(0.055f, 0.035f, night);
    float3 lab = paper;

    Orb o;
    o = orb(p, cPeach, 0.44f, t, 0.0f);
    lab = mix(lab, shadeOrb(peach, o, lightAmt), o.coverage * 0.85f);
    o = orb(p, cGlow, 0.28f, t, 1.3f);
    lab = mix(lab, shadeOrb(glow, o, lightAmt), o.coverage * 0.75f);
    o = orb(p, cStatus, 0.38f * breath, t, 2.1f);
    lab = mix(lab, shadeOrb(status, o, lightAmt), o.coverage * 0.92f);
    o = orb(p, cEmber, 0.30f, t, 4.7f);
    lab = mix(lab, shadeOrb(ember, o, lightAmt), o.coverage * 0.90f);

    // Dissolve into paper before the cards (OKLab, so no grey seam).
    float f = 1.0f - smoothstep(fadeStart, fadeEnd, vy);
    f = f * f * (3.0f - 2.0f * f);
    lab = mix(paper, lab, f);

    // Static, luma-only grain at ~1.5 device-pixel clusters: reads as paper tooth, not video noise.
    float2 devicePx = position * scale;
    uint2 cell = uint2(floor(devicePx / 1.5f));
    float g = hash01(cell, 7u) - 0.5f;
    lab.x += g * grain * (0.35f + 0.65f * f);

    float3 rgb = oklabToOutput(lab) + dither3(devicePx, frame);
    return half4(half3(clamp(rgb, 0.0f, 1.0f)), 1.0h);
}

// =====================================================================================
// mrhRingGlow — score ring / arc (Recovery, Strain, Sleep, day circles).
// Swift: Rectangle().colorEffect(ShaderLibrary.mrhRingGlow(
//   .boundingRect, .float(progress), .float(lineWidth), startLab, endLab, trackLab,
//   .float(trackAlpha), .float(glow), .float(scale), .float(night)))
// The ring is inset by 1.5 x lineWidth so the glow has room. Output is premultiplied, so the
// ring sits on any card. 0 at 12 o'clock, clockwise. night: 0 = light theme, 1 = night.
// =====================================================================================
[[ stitchable ]] half4 mrhRingGlow(float2 position, half4 color, float4 bounds,
                                    float progress, float lineWidth,
                                    float3 startLab, float3 endLab, float3 trackLab,
                                    float trackAlpha, float glow, float scale, float night)
{
    float2 c = bounds.xy + bounds.zw * 0.5f;
    float2 p = position - c;
    float hw = lineWidth * 0.5f;
    float R = min(bounds.z, bounds.w) * 0.5f - lineWidth * 1.5f;
    float r = length(p);

    float ang = atan2(p.x, -p.y);                       // 0 at top, clockwise (y down)
    float u = ang < 0.0f ? ang / TAU + 1.0f : ang / TAU; // [0,1)
    float prog = clamp(progress, 0.0f, 1.0f);

    float dRing = abs(r - R) - hw;
    float th1 = prog * TAU;
    float2 headC = float2(sin(th1), -cos(th1)) * R;
    float2 tailC = float2(0.0f, -R);
    float dHead = length(p - headC) - hw;
    float dTail = length(p - tailC) - hw;
    float dBody = (u <= prog) ? dRing : min(dHead, dTail);

    // Colour along the arc, mixed in OKLab; tube lighting gives it volume at 1px-crisp edges.
    float along = (u <= prog) ? clamp(u / max(prog, 1e-3f), 0.0f, 1.0f) : (dHead < dTail ? 1.0f : 0.0f);
    float3 lab = mix(startLab, endLab, along);
    float tube = clamp(1.0f - abs(r - R) / max(hw, 1e-3f), 0.0f, 1.0f);
    lab.x += mix(0.03f, 0.04f, night) * tube;

    float4 outc = float4(0.0f);

    // 1. Track
    overPremul(outc, oklabToOutput(trackLab), aaCoverage(dRing, scale) * trackAlpha);

    // 2. Glow (only near the head: the "live" end of the score)
    if (prog > 0.0f && glow > 0.0f) {
        float headW = exp(-length(p - headC) / (lineWidth * 2.5f));
        float ga = glow * 0.55f * exp(-max(dBody, 0.0f) / (lineWidth * 0.7f)) * headW;
        float3 gl = endLab; gl.x += 0.06f; gl.yz *= 1.15f;
        overPremul(outc, oklabToOutput(gl), clamp(ga, 0.0f, 1.0f) * (1.0f - aaCoverage(dBody, scale)));
    }

    // 3. Body
    float bodyCov = prog > 0.0f ? aaCoverage(dBody, scale) : 0.0f;
    overPremul(outc, oklabToOutput(lab), bodyCov);

    // 4. Head cap on top with a small forward shadow (covers the seam when the ring is full).
    if (prog > 0.85f) {
        float2 tangent = float2(cos(th1), sin(th1));
        float ds = length(p - (headC + tangent * hw * 0.35f)) - hw;
        float sh = 0.22f * (1.0f - smoothstep(-hw * 0.2f, hw * 0.9f, ds)) * bodyCov;
        outc.rgb *= (1.0f - sh);
        float3 hl = endLab; hl.x += mix(0.03f, 0.04f, night) * tube;
        overPremul(outc, oklabToOutput(hl), aaCoverage(dHead, scale));
    }

    float2 devicePx = position * scale;
    outc.rgb += dither3(devicePx, 0.0f) * step(1e-3f, outc.a);
    outc = clamp(outc, 0.0f, 1.0f);
    outc.rgb = min(outc.rgb, float3(outc.a));            // keep premultiplied invariant
    return half4(outc);
}

// =====================================================================================
// mrhChartLine — glowing line chart with gradient area fill.
// Swift: Rectangle().colorEffect(ShaderLibrary.mrhChartLine(
//   .boundingRect, .floatArray(ys), .float(lineWidth), lineLab, .float(fillAlpha),
//   .float(glow), .float(scale)))
// ys: normalised 0 (bottom) .. 1 (top), evenly spaced in x; a negative value is a gap.
// lineWidth in points; pass 1/scale for a true device-pixel hairline.
// Only +-8 neighbouring segments are tested per pixel, so cost is O(1) in the series length.
// =====================================================================================
[[ stitchable ]] half4 mrhChartLine(float2 position, half4 color, float4 bounds,
                                     device const float *ys, int count,
                                     float lineWidth, float3 lineLab, float fillAlpha,
                                     float glow, float scale)
{
    if (count < 2) { return half4(0.0h); }
    float2 p = position - bounds.xy;
    float w = max(bounds.z, 1.0f);
    float h = max(bounds.w, 1.0f);
    float dx = w / float(count - 1);

    float fi = p.x / dx;
    int i0 = clamp(int(floor(fi)), 0, count - 2);
    float glowR = max(lineWidth * 5.0f, 7.0f);
    int k = min(int(ceil(glowR / dx)) + 1, 8);

    float d = 1e6f;
    int jEnd = min(i0 + k, count - 2);
    for (int j = max(i0 - k, 0); j <= jEnd; ++j) {
        float ya = ys[j];
        float yb = ys[j + 1];
        if (ya < 0.0f || yb < 0.0f) { continue; }
        float2 a = float2(float(j) * dx, (1.0f - ya) * h);
        float2 b = float2(float(j + 1) * dx, (1.0f - yb) * h);
        d = min(d, sdSegment(p, a, b));
    }

    float2 devicePx = position * scale;
    float3 rgb = oklabToOutput(lineLab);
    float4 outc = float4(0.0f);

    // Area fill: fades from the line down to the baseline (local ramp, eased), dithered alpha.
    float ya = ys[i0];
    float yb = ys[i0 + 1];
    if (fillAlpha > 0.0f && ya >= 0.0f && yb >= 0.0f) {
        float tt = clamp(fi - float(i0), 0.0f, 1.0f);
        float yLine = (1.0f - mix(ya, yb, tt)) * h;
        if (p.y >= yLine) {
            float v = 1.0f - (p.y - yLine) / max(h - yLine, 1.0f);
            float a = fillAlpha * pow(v, 1.8f);
            a = max(a + triPDF(ign(devicePx)) * (1.0f / 255.0f), 0.0f);
            float3 fl = lineLab; fl.x += 0.04f;               // fill slightly lighter than line
            overPremul(outc, oklabToOutput(fl), clamp(a, 0.0f, 1.0f));
        }
    }

    // Glow (gaussian, finite support = glowR)
    if (glow > 0.0f && d < glowR) {
        float x = d / (glowR * 0.4f);
        overPremul(outc, rgb, glow * 0.35f * exp(-x * x));
    }

    // Core line: exact 1-device-pixel anti-aliased edge.
    overPremul(outc, rgb, clamp((lineWidth * 0.5f - d) * scale + 0.5f, 0.0f, 1.0f));

    outc = clamp(outc, 0.0f, 1.0f);
    outc.rgb = min(outc.rgb, float3(outc.a));
    return half4(outc);
}
