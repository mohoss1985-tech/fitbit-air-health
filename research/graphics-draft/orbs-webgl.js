/* orbs-webgl.js — MRH1 v1.0 ambient orbs, WebGL2 port of `mrhOrbField` (Shaders.metal).
 *
 * Same maths as iOS: OKLab inputs, SDF orbs with wobbling rims, lit body + rim band,
 * OKLab fade into paper, static luma grain at 1.5 device-px clusters, +-1 LSB triangular dither.
 *
 * Crispness: the canvas backing store is sized in exact device pixels
 *   (ResizeObserver 'device-pixel-content-box' where supported, else round(css * devicePixelRatio)),
 *   capped at MAX_PIXELS so 3x phones stay cheap. Grain/dither use real device pixels.
 * Battery: 30 fps cap, paused when off-screen (IntersectionObserver), when the tab is hidden,
 *   and under prefers-reduced-motion (one frozen frame, state changes snap).
 * Fallback: no WebGL2 -> CSS radial gradients on the canvas element.
 *
 * Usage (plain script, no bundler):
 *   <canvas id="orbs" style="position:absolute;inset:0;width:100%;height:100%"></canvas>
 *   const orbs = MRHOrbs.mount(document.getElementById('orbs'), { state: 'good' });
 *   orbs.setState('limit');   // 'good' | 'limit' | 'danger' | 'night' | 'neutral'
 *   orbs.destroy();
 */
(function (root) {
  'use strict';

  const MAX_PIXELS = 2.4e6;          // ~ 390x620 css px at 3x
  const FRAME_MS = 1000 / 30;
  const MORPH_MS = 1200;
  const FROZEN_T = 8;

  // ------------------------------------------------------------------ palettes (hex, sRGB)
  const PALETTES = {
    good:    { paper: '#EDEBE7', peach: '#F3A79E', glow: '#F6C9B8', status: '#9AD3B2', ember: '#F0582A', night: 0, grain: 0.010 },
    limit:   { paper: '#EDEBE7', peach: '#F3A79E', glow: '#F6CFAE', status: '#F2D46A', ember: '#F0582A', night: 0, grain: 0.010 },
    danger:  { paper: '#EDEBE7', peach: '#F3A79E', glow: '#F4B9B0', status: '#E77A86', ember: '#F0582A', night: 0, grain: 0.010 },
    neutral: { paper: '#EDEBE7', peach: '#F3A79E', glow: '#F6CDBB', status: '#E9D9C8', ember: '#F0582A', night: 0, grain: 0.010 },
    night:   { paper: '#141318', peach: '#6E4A63', glow: '#3A2E48', status: '#5B53A8', ember: '#B8442A', night: 1, grain: 0.016 },
  };
  const KEYS = ['paper', 'peach', 'glow', 'status', 'ember'];

  // ------------------------------------------------------------------ OKLab (CPU side)
  function hexToLinear(hex) {
    const n = parseInt(hex.slice(1), 16);
    return [(n >> 16) & 255, (n >> 8) & 255, n & 255].map(v => {
      v /= 255;
      return v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
    });
  }
  function linearToOklab([r, g, b]) {
    const l = Math.cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b);
    const m = Math.cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b);
    const s = Math.cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b);
    return [
      0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
      1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
      0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s,
    ];
  }
  const lab = hex => linearToOklab(hexToLinear(hex));
  function paletteLab(name) {
    const p = PALETTES[name] || PALETTES.neutral;
    const out = { night: p.night, grain: p.grain };
    KEYS.forEach(k => { out[k] = lab(p[k]); });
    return out;
  }
  const mix3 = (a, b, t) => [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t];
  function mixPalette(a, b, t) {
    const out = { night: a.night + (b.night - a.night) * t, grain: a.grain + (b.grain - a.grain) * t };
    KEYS.forEach(k => { out[k] = mix3(a[k], b[k], t); });
    return out;
  }
  const easeInOut = x => (x < 0.5 ? 4 * x * x * x : 1 - Math.pow(-2 * x + 2, 3) / 2);

  // ------------------------------------------------------------------ shaders
  const VS = `#version 300 es
in vec2 aPos;
void main() { gl_Position = vec4(aPos, 0.0, 1.0); }`;

  const FS = `#version 300 es
precision highp float;
precision highp int;
uniform vec2  uRes;        // device px
uniform float uDpr;        // device px per css px
uniform float uTime, uGrain, uFadeStart, uFadeEnd, uFrame, uNight;
uniform vec3  uPaper, uPeach, uGlow, uStatus, uEmber;
out vec4 fragColor;

vec3 oklabToLinear(vec3 c) {
  float l_ = c.x + 0.3963377774 * c.y + 0.2158037573 * c.z;
  float m_ = c.x - 0.1055613458 * c.y - 0.0638541728 * c.z;
  float s_ = c.x - 0.0894841775 * c.y - 1.2914855480 * c.z;
  float l = l_ * l_ * l_, m = m_ * m_ * m_, s = s_ * s_ * s_;
  return vec3( 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
              -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
              -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s);
}
vec3 linearToSRGB(vec3 c) {
  c = clamp(c, 0.0, 1.0);
  return mix(1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, c * 12.92, vec3(lessThanEqual(c, vec3(0.0031308))));
}
uint pcg(uint v) {
  uint s = v * 747796405u + 2891336453u;
  uint w = ((s >> ((s >> 28u) + 4u)) ^ s) * 277803737u;
  return (w >> 22u) ^ w;
}
float hash01(uvec2 p, uint seed) { return float(pcg(p.x + pcg(p.y + pcg(seed)))) * (1.0 / 4294967295.0); }
float ign(vec2 p) { return fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715)))); }
float triPDF(float n) { float v = n * 2.0 - 1.0; return sign(v) * (1.0 - sqrt(1.0 - abs(v))); }
vec3 dither3(vec2 px, float frame) {
  vec2 o = vec2(5.588238) * mod(frame, 64.0);
  return vec3(triPDF(ign(px + o)), triPDF(ign(px + o + vec2(17.0, 59.0))), triPDF(ign(px + o + vec2(41.0, 23.0)))) / 255.0;
}

struct Orb { float coverage; float rim; float light; };
Orb orb(vec2 p, vec2 c, float r, float t, float seed) {
  vec2 d2 = p - c;
  float d = length(d2);
  float th = d > 1e-5 ? atan(d2.y, d2.x) : 0.0;
  float wobble = 0.035 * sin(3.0 * th + t * 0.21 + seed) + 0.020 * sin(5.0 * th - t * 0.17 + seed * 1.7);
  float re = r * (1.0 + wobble);
  float softIn = r * 0.30, softOut = r * 0.06;
  Orb o;
  o.coverage = 1.0 - smoothstep(re - softIn, re + softOut, d);
  float x = (d - (re - softIn * 0.35)) / (r * 0.10);
  o.rim = exp(-x * x);
  vec2 lp = c + vec2(-0.35, -0.45) * r;
  o.light = clamp(1.0 - length(p - lp) / (r * 1.2), 0.0, 1.0);
  return o;
}
vec3 shadeOrb(vec3 lab, Orb o, float lightAmt) {
  vec3 s = lab;
  s.x += lightAmt * o.light * o.light;
  s.x += 0.030 * o.rim;
  s.yz *= 1.0 + 0.14 * o.rim;
  return s;
}

void main() {
  // Top-down coordinates in css px, matching SwiftUI points.
  vec2 dev = vec2(gl_FragCoord.x, uRes.y - gl_FragCoord.y);
  vec2 css = dev / uDpr;
  float w = uRes.x / uDpr, h = uRes.y / uDpr;
  vec2 p = css / w;
  float vy = css.y / h;
  float t = uTime;

  float breath = 1.0 + 0.015 * sin(t * 0.785);
  vec2 cPeach  = vec2(0.14 + 0.06 * cos(t * 0.13),       0.22 + 0.05 * sin(t * 0.10 + 1.0));
  vec2 cGlow   = vec2(0.42 + 0.10 * sin(t * 0.09 + 3.0), 0.04 + 0.03 * cos(t * 0.16));
  vec2 cStatus = vec2(0.60 + 0.12 * cos(t * 0.11 + 2.0), 0.44 + 0.04 * sin(t * 0.14));
  vec2 cEmber  = vec2(0.90 + 0.05 * sin(t * 0.15),       0.10 + 0.04 * cos(t * 0.12));

  float lightAmt = mix(0.055, 0.035, uNight);
  vec3 lab = uPaper;
  Orb o;
  o = orb(p, cPeach, 0.44, t, 0.0);           lab = mix(lab, shadeOrb(uPeach, o, lightAmt), o.coverage * 0.85);
  o = orb(p, cGlow, 0.28, t, 1.3);            lab = mix(lab, shadeOrb(uGlow, o, lightAmt), o.coverage * 0.75);
  o = orb(p, cStatus, 0.38 * breath, t, 2.1); lab = mix(lab, shadeOrb(uStatus, o, lightAmt), o.coverage * 0.92);
  o = orb(p, cEmber, 0.30, t, 4.7);           lab = mix(lab, shadeOrb(uEmber, o, lightAmt), o.coverage * 0.90);

  float f = 1.0 - smoothstep(uFadeStart, uFadeEnd, vy);
  f = f * f * (3.0 - 2.0 * f);
  lab = mix(uPaper, lab, f);

  uvec2 cell = uvec2(floor(dev / 1.5));
  lab.x += (hash01(cell, 7u) - 0.5) * uGrain * (0.35 + 0.65 * f);

  vec3 rgb = linearToSRGB(oklabToLinear(lab)) + dither3(dev, uFrame);
  fragColor = vec4(clamp(rgb, 0.0, 1.0), 1.0);
}`;

  // ------------------------------------------------------------------ mount
  function mount(canvas, opts) {
    opts = opts || {};
    const fade = opts.fade || [0.38, 0.95];
    let stateName = opts.state || 'neutral';
    let from = null;
    let to = paletteLab(stateName);
    let morphStart = 0;

    const motionQuery = root.matchMedia ? root.matchMedia('(prefers-reduced-motion: reduce)') : null;
    let reduce = !!(motionQuery && motionQuery.matches);
    let onScreen = true;
    let pageVisible = !document.hidden;
    let raf = 0, lastDraw = -Infinity, frameCount = 0;
    const epoch = performance.now();

    const gl = canvas.getContext('webgl2', {
      alpha: false, antialias: false, depth: false, stencil: false,
      premultipliedAlpha: false, preserveDrawingBuffer: false, powerPreference: 'low-power',
    });

    // ---- CSS fallback
    function cssFallback() {
      const p = PALETTES[stateName] || PALETTES.neutral;
      canvas.style.background =
        'radial-gradient(circle at 90% 10%,' + p.ember + ' 0,' + p.ember + 'cc 18%,transparent 34%),' +
        'radial-gradient(circle at 14% 22%,' + p.peach + ' 0,transparent 46%),' +
        'radial-gradient(circle at 60% 44%,' + p.status + ' 0,transparent 40%),' +
        'linear-gradient(' + p.paper + ',' + p.paper + ')';
      canvas.style.maskImage = 'linear-gradient(#000 40%, transparent 95%)';
    }
    if (!gl) {
      cssFallback();
      return { setState(s) { stateName = s; cssFallback(); }, destroy() {} };
    }

    let prog = null, vao = null, U = {};
    function build() {
      const compile = (type, src) => {
        const s = gl.createShader(type);
        gl.shaderSource(s, src);
        gl.compileShader(s);
        if (!gl.getShaderParameter(s, gl.COMPILE_STATUS)) throw new Error(gl.getShaderInfoLog(s) || 'shader');
        return s;
      };
      prog = gl.createProgram();
      gl.attachShader(prog, compile(gl.VERTEX_SHADER, VS));
      gl.attachShader(prog, compile(gl.FRAGMENT_SHADER, FS));
      gl.bindAttribLocation(prog, 0, 'aPos');
      gl.linkProgram(prog);
      if (!gl.getProgramParameter(prog, gl.LINK_STATUS)) throw new Error(gl.getProgramInfoLog(prog) || 'link');
      gl.useProgram(prog);
      vao = gl.createVertexArray();
      gl.bindVertexArray(vao);
      const buf = gl.createBuffer();
      gl.bindBuffer(gl.ARRAY_BUFFER, buf);
      gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 3, -1, -1, 3]), gl.STATIC_DRAW); // one big triangle
      gl.enableVertexAttribArray(0);
      gl.vertexAttribPointer(0, 2, gl.FLOAT, false, 0, 0);
      U = {};
      ['uRes', 'uDpr', 'uTime', 'uGrain', 'uFadeStart', 'uFadeEnd', 'uFrame', 'uNight',
       'uPaper', 'uPeach', 'uGlow', 'uStatus', 'uEmber'].forEach(k => { U[k] = gl.getUniformLocation(prog, k); });
    }
    try { build(); } catch (e) { console.warn('[MRHOrbs] WebGL2 build failed, CSS fallback', e); cssFallback(); return { setState(s) { stateName = s; cssFallback(); }, destroy() {} }; }

    // ---- exact device-pixel sizing
    let dpr = 1;
    function applySize(devW, devH, cssW) {
      let w = Math.max(1, Math.round(devW)), h = Math.max(1, Math.round(devH));
      const px = w * h;
      if (px > MAX_PIXELS) { const k = Math.sqrt(MAX_PIXELS / px); w = Math.round(w * k); h = Math.round(h * k); }
      dpr = cssW > 0 ? w / cssW : 1;
      if (canvas.width !== w || canvas.height !== h) { canvas.width = w; canvas.height = h; }
      draw(performance.now(), true);
    }
    const ro = new ResizeObserver(entries => {
      const e = entries[0];
      const cssW = e.contentRect.width;
      if (e.devicePixelContentBoxSize && e.devicePixelContentBoxSize[0]) {
        const s = e.devicePixelContentBoxSize[0];
        applySize(s.inlineSize, s.blockSize, cssW);           // Chrome / Firefox: exact
      } else {
        const r = root.devicePixelRatio || 1;                  // Safari: round(css * dpr)
        applySize(e.contentRect.width * r, e.contentRect.height * r, cssW);
      }
    });
    try { ro.observe(canvas, { box: 'device-pixel-content-box' }); } catch (_) { ro.observe(canvas); }

    // ---- rendering
    function palette(now) {
      if (!from) return to;
      const k = Math.min(1, Math.max(0, (now - morphStart) / MORPH_MS));
      if (k >= 1) { from = null; return to; }
      return mixPalette(from, to, easeInOut(k));
    }
    function draw(now, force) {
      if (!force && now - lastDraw < FRAME_MS - 1) return;     // 30 fps cap
      lastDraw = now;
      const p = palette(now);
      const t = reduce ? FROZEN_T : FROZEN_T + ((now - epoch) / 1000) % 10000;
      gl.viewport(0, 0, canvas.width, canvas.height);
      gl.useProgram(prog);
      gl.bindVertexArray(vao);
      gl.uniform2f(U.uRes, canvas.width, canvas.height);
      gl.uniform1f(U.uDpr, dpr);
      gl.uniform1f(U.uTime, t);
      gl.uniform1f(U.uGrain, p.grain);
      gl.uniform1f(U.uFadeStart, fade[0]);
      gl.uniform1f(U.uFadeEnd, fade[1]);
      gl.uniform1f(U.uFrame, reduce ? 0 : (frameCount++ & 1023));
      gl.uniform1f(U.uNight, p.night);
      gl.uniform3fv(U.uPaper, p.paper);
      gl.uniform3fv(U.uPeach, p.peach);
      gl.uniform3fv(U.uGlow, p.glow);
      gl.uniform3fv(U.uStatus, p.status);
      gl.uniform3fv(U.uEmber, p.ember);
      gl.drawArrays(gl.TRIANGLES, 0, 3);
    }
    const running = () => !reduce && onScreen && pageVisible;
    function loop(now) { raf = 0; if (!running()) return; draw(now, false); raf = requestAnimationFrame(loop); }
    function sync() {
      if (running()) { if (!raf) raf = requestAnimationFrame(loop); }
      else { if (raf) cancelAnimationFrame(raf); raf = 0; draw(performance.now(), true); }
    }

    // ---- pause triggers
    const io = new IntersectionObserver(es => { onScreen = es[0].isIntersecting; sync(); });
    io.observe(canvas);
    const onVis = () => { pageVisible = !document.hidden; sync(); };
    document.addEventListener('visibilitychange', onVis);
    const onMotion = e => { reduce = e.matches; sync(); };
    if (motionQuery) motionQuery.addEventListener('change', onMotion);

    // ---- context loss
    const onLost = e => { e.preventDefault(); if (raf) cancelAnimationFrame(raf); raf = 0; };
    const onRestored = () => { try { build(); sync(); } catch (_) { cssFallback(); } };
    canvas.addEventListener('webglcontextlost', onLost);
    canvas.addEventListener('webglcontextrestored', onRestored);

    sync();

    return {
      setState(name) {
        if (name === stateName) return;
        const now = performance.now();
        stateName = name;
        from = reduce ? null : palette(now);                    // Reduce Motion: snap
        to = paletteLab(name);
        morphStart = now;
        sync();
        if (!running()) draw(now, true);
      },
      destroy() {
        if (raf) cancelAnimationFrame(raf);
        ro.disconnect(); io.disconnect();
        document.removeEventListener('visibilitychange', onVis);
        if (motionQuery) motionQuery.removeEventListener('change', onMotion);
        canvas.removeEventListener('webglcontextlost', onLost);
        canvas.removeEventListener('webglcontextrestored', onRestored);
        const ext = gl.getExtension('WEBGL_lose_context'); if (ext) ext.loseContext();
      },
    };
  }

  root.MRHOrbs = { mount, PALETTES };
})(typeof window !== 'undefined' ? window : globalThis);
