import SwiftUI
import UIKit

// OKLab colour maths (Björn Ottosson, 2020) shared by the Metal graphics layer.
// Colours go into the shaders as OKLab float3 so mixing is exact and identical on iOS and web.

/// OKLab colour. L in 0...1, a/b roughly -0.4...0.4.
struct OKLab: Equatable, Sendable {
    var L: Float
    var a: Float
    var b: Float

    init(L: Float, a: Float, b: Float) {
        self.L = L
        self.a = a
        self.b = b
    }

    /// From a 0xRRGGBB sRGB hex value.
    init(hex: UInt32) {
        self.init(srgbR: Float((hex >> 16) & 0xFF) / 255,
                  g: Float((hex >> 8) & 0xFF) / 255,
                  b: Float(hex & 0xFF) / 255)
    }

    /// From gamma-encoded sRGB components in 0...1.
    init(srgbR r: Float, g: Float, b: Float) {
        let lr = OKLab.toLinear(r), lg = OKLab.toLinear(g), lb = OKLab.toLinear(b)
        let l: Float = cbrtf(0.4122214708 * lr + 0.5363325363 * lg + 0.0514459929 * lb)
        let m: Float = cbrtf(0.2119034982 * lr + 0.6806995451 * lg + 0.1073969566 * lb)
        let s: Float = cbrtf(0.0883024619 * lr + 0.2817188376 * lg + 0.6299787005 * lb)
        self.init(L: 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
                  a: 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
                  b: 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s)
    }

    /// From a UIColor (resolved for the given traits), ignoring alpha.
    init(_ ui: UIColor) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        if !ui.getRed(&r, green: &g, blue: &b, alpha: &a) {
            var w: CGFloat = 0
            ui.getWhite(&w, alpha: &a)
            r = w; g = w; b = w
        }
        self.init(srgbR: Float(r), g: Float(g), b: Float(b))
    }

    /// Gamma-encoded sRGB components, clamped to gamut.
    var srgb: (r: Float, g: Float, b: Float) {
        let l1 = L + 0.3963377774 * a + 0.2158037573 * b
        let m1 = L - 0.1055613458 * a - 0.0638541728 * b
        let s1 = L - 0.0894841775 * a - 1.2914855480 * b
        let l = l1 * l1 * l1, m = m1 * m1 * m1, s = s1 * s1 * s1
        let r: Float = 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
        let g: Float = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
        let bl: Float = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s
        return (OKLab.toGamma(r), OKLab.toGamma(g), OKLab.toGamma(bl))
    }

    var color: Color {
        let c = srgb
        return Color(.sRGB, red: Double(c.r), green: Double(c.g), blue: Double(c.b), opacity: 1)
    }

    var uiColor: UIColor {
        let c = srgb
        return UIColor(red: CGFloat(c.r), green: CGFloat(c.g), blue: CGFloat(c.b), alpha: 1)
    }

    /// Pass to a shader `float3` parameter.
    var arg: Shader.Argument { .float3(L, a, b) }

    static func mix(_ x: OKLab, _ y: OKLab, _ t: Float) -> OKLab {
        OKLab(L: x.L + (y.L - x.L) * t, a: x.a + (y.a - x.a) * t, b: x.b + (y.b - x.b) * t)
    }

    /// Multi-stop gradient sampled in OKLab (SwiftUI/Charts gradients otherwise interpolate in
    /// sRGB and go muddy in the middle). Opacity ramps from `fromOpacity` to `toOpacity`.
    static func stops(_ x: OKLab, _ y: OKLab, count: Int = 8,
                      fromOpacity: Double = 1, toOpacity: Double = 1) -> [Gradient.Stop] {
        let n = max(count, 2)
        return (0..<n).map { i in
            let t = Float(i) / Float(n - 1)
            let o = fromOpacity + (toOpacity - fromOpacity) * Double(t)
            return Gradient.Stop(color: mix(x, y, t).color.opacity(o), location: CGFloat(t))
        }
    }

    private static func toLinear(_ v: Float) -> Float {
        v <= 0.04045 ? v / 12.92 : powf((v + 0.055) / 1.055, 2.4)
    }

    private static func toGamma(_ v: Float) -> Float {
        let c = min(max(v, 0), 1)
        return c <= 0.0031308 ? c * 12.92 : 1.055 * powf(c, 1 / 2.4) - 0.055
    }
}

/// Exact hex tokens for the shaders (DESIGN_SPEC §2). SwiftUI views use `Theme`; shaders need
/// fixed OKLab values per appearance, so they live here.
enum GfxTokens {
    // light
    static let paper = OKLab(hex: 0xEDEBE7)
    static let card = OKLab(hex: 0xFAF9F7)
    static let hair = OKLab(hex: 0xDFDBD5)
    static let ink = OKLab(hex: 0x151413)
    static let graphite = OKLab(hex: 0x6B665F)
    static let ember = OKLab(hex: 0xF0582A)
    static let peach = OKLab(hex: 0xF3A79E)
    static let iris = OKLab(hex: 0x8B88F0)
    static let good = OKLab(hex: 0x2F9D68)
    static let limit = OKLab(hex: 0xE6B820)
    static let danger = OKLab(hex: 0xD23A3A)
    // dark / evening
    static let base = OKLab(hex: 0x151413)
    static let cardDark = OKLab(hex: 0x1F1D1B)
    static let hairDark = OKLab(hex: 0x2E2B28)
    static let inkDark = OKLab(hex: 0xF2EFEA)
}

extension Color {
    /// Mix two colours in OKLab (t = 0 → a, 1 → b). Stays adaptive: both inputs are resolved
    /// per trait collection (light/dark) before mixing. Alpha mixes linearly.
    static func oklabMix(_ a: Color, _ b: Color, t: Double) -> Color {
        let ua = UIColor(a), ub = UIColor(b)
        let tt = Float(min(max(t, 0), 1))
        return Color(UIColor { traits in
            let ra = ua.resolvedColor(with: traits), rb = ub.resolvedColor(with: traits)
            var aa: CGFloat = 1, ab: CGFloat = 1
            ra.getRed(nil, green: nil, blue: nil, alpha: &aa)
            rb.getRed(nil, green: nil, blue: nil, alpha: &ab)
            let mixed = OKLab.mix(OKLab(ra), OKLab(rb), tt).uiColor
            return mixed.withAlphaComponent(aa + (ab - aa) * CGFloat(tt))
        })
    }
}
