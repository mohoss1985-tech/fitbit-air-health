/* orbs.js — MRH1 v1.0 header orbs, WebGL2. Same maths as the iOS Metal shader (DESIGN_SPEC §3).
 *
 *  - 3 brand orbs (peach, iris, ember) + 1 small status orb (good / limit / danger at 0.5).
 *  - Each orb: solid inner 70 % of r, smoothstep edge 70 -> 100 % (no Gaussian fog).
 *  - Composited back-to-front in OKLab (premultiplied: mix(lab, orb, alpha)), never sRGB.
 *  - Halftone fringe: in the coverage band 0.12-0.40 the smooth fade turns into a 3 css-px dot
 *    screen rotated 15 deg; dot area == coverage, so the tone does not jump, only the texture.
 *  - Static per-device-pixel grain, +-4 % L inside orbs scaled by coverage (+-1 % on bare paper),
 *    reseeded once per day. Triangular dither +-1 LSB after the sRGB encode (no banding).
 *  - Drift: Lissajous, periods 41 / 53 / 67 s, amplitude 0.05 w. Position only, never scale.
 *  - pulse(): ember radius +3 %, decays over 500 ms (Live tab, one per new sample).
 *  - Evening: ink base, orbs at 0.55, iris 0.6, grain +-3 %.
 *  - Crisp: backing store = exact device pixels (device-pixel-content-box, else round(css*dpr)).
 *  - Battery: 30 fps cap, pauses off-screen / hidden tab; prefers-reduced-motion freezes it.
 *  - No WebGL2, compile failure or unrecoverable context loss -> CSS radial fallback.
 *
 *  const o = MRHOrbs.mount(canvas, { status: 'good', evening: false, frozen: false,
 *                                    unit: w => w, fadeStart: h => h*.62, fadeEnd: h => h });  // unit = css px per 'w'
 *  o.setStatus('limit'); o.setEvening(true); o.pulse(); o.destroy();
 */
(function (root) {
  'use strict';

  var MAX_PIXELS = 2.6e6;
  var FRAME_MS = 1000 / 30;
  var MORPH_MS = 1200;
  var PULSE_MS = 500;
  var FROZEN_T = 8;

  var COLORS = {
    paper: '#EDEBE7', ink: '#151413',
    peach: '#F3A79E', iris: '#8B88F0', ember: '#F0582A',
    good: '#9AD3B2', limit: '#F2D46A', danger: '#E77A86', none: '#EDEBE7'   // status tints (light), not the chip fills
  };

  // ---------------------------------------------------------------- OKLab on the CPU
  function hexToLinear(hex) {
    var n = parseInt(hex.slice(1), 16);
    return [(n >> 16) & 255, (n >> 8) & 255, n & 255].map(function (v) {
      v /= 255; return v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
    });
  }
  function lab(hex) {
    var c = hexToLinear(hex), r = c[0], g = c[1], b = c[2];
    var l = Math.cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b);
    var m = Math.cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b);
    var s = Math.cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b);
    return [0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
            1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
            0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s];
  }
  // A "look" = every uniform that morphs between states.
  function look(status, evening) {
    var e = evening ? 1 : 0;
    return {
      paper: lab(evening ? COLORS.ink : COLORS.paper),
      peach: lab(COLORS.peach), iris: lab(COLORS.iris), ember: lab(COLORS.ember),
      status: lab(COLORS[status] || COLORS.none),
      op: evening ? [0.55, 0.60, 0.55, 0.40] : [0.90, 0.35, 1.0, 0.85],     // peach, iris, ember, status
      statusOn: COLORS[status] && status !== 'none' ? 1 : 0,
      grain: evening ? 0.03 : 0.04,
      evening: e
    };
  }
  function lerp(a, b, t) { return a + (b - a) * t; }
  function mixLook(a, b, t) {
    var o = {};
    ['paper', 'peach', 'iris', 'ember', 'status', 'op'].forEach(function (k) {
      o[k] = a[k].map(function (v, i) { return lerp(v, b[k][i], t); });
    });
    ['statusOn', 'grain', 'evening'].forEach(function (k) { o[k] = lerp(a[k], b[k], t); });
    return o;
  }
  var easeInOut = function (x) { return x < 0.5 ? 4 * x * x * x : 1 - Math.pow(-2 * x + 2, 3) / 2; };

  // ---------------------------------------------------------------- shaders
  var VS = '#version 300 es\nin vec2 aPos;\nvoid main(){gl_Position=vec4(aPos,0.0,1.0);}';

  var FS = [
    '#version 300 es',
    'precision highp float; precision highp int;',
    'uniform vec2 uRes; uniform float uUnit, uDpr, uTime, uPulse, uGrain, uSeed, uFadeA, uFadeB, uStatusOn;',
    'uniform vec3 uPaper, uPeach, uIris, uEmber, uStatus; uniform vec4 uOp;',
    'out vec4 fragColor;',
    'vec3 oklabToLinear(vec3 c){',
    '  float l_=c.x+0.3963377774*c.y+0.2158037573*c.z, m_=c.x-0.1055613458*c.y-0.0638541728*c.z, s_=c.x-0.0894841775*c.y-1.2914855480*c.z;',
    '  float l=l_*l_*l_, m=m_*m_*m_, s=s_*s_*s_;',
    '  return vec3(4.0767416621*l-3.3077115913*m+0.2309699292*s, -1.2684380046*l+2.6097574011*m-0.3413193965*s, -0.0041960863*l-0.7034186147*m+1.7076147010*s);}',
    'vec3 toSRGB(vec3 c){ c=clamp(c,0.0,1.0); return mix(1.055*pow(c,vec3(1.0/2.4))-0.055, c*12.92, vec3(lessThanEqual(c,vec3(0.0031308)))); }',
    'uint pcg(uint v){ uint s=v*747796405u+2891336453u; uint w=((s>>((s>>28u)+4u))^s)*277803737u; return (w>>22u)^w; }',
    'float h01(uvec2 p, uint k){ return float(pcg(p.x+pcg(p.y+pcg(k))))*(1.0/4294967295.0); }',
    'float tri(float n){ float v=n*2.0-1.0; return sign(v)*(1.0-sqrt(1.0-abs(v))); }',
    // coverage of one orb: solid core 70 %, smoothstep 70 -> 100 %
    'float cov(vec2 p, vec2 c, float r){ return 1.0-smoothstep(0.70*r, r, length(p-c)); }',
    // halftone: dot screen in the 0.12-0.40 band, dot area == coverage
    'float screenDots(float c, vec2 css){',
    '  const float PITCH=3.0; const float A=0.2617994;',          // 15 deg
    '  vec2 q=mat2(cos(A),-sin(A),sin(A),cos(A))*css/PITCH;',
    '  vec2 f=fract(q)-0.5; float d=length(f)*PITCH;',           // css px from cell centre
    '  float rad=PITCH*sqrt(c/3.14159265);',
    '  return clamp(0.5-(d-rad)*uDpr, 0.0, 1.0);',               // 1 device-px AA edge
    '}',
    'float fringe(float c, vec2 css){',
    '  float band=smoothstep(0.08,0.14,c)*(1.0-smoothstep(0.36,0.42,c));',
    '  return mix(c, screenDots(c,css), band);',
    '}',
    'vec2 drift(vec2 base, float px, float py, float ph){',
    '  base.x*=uRes.x/uDpr/uUnit;\n  return base+0.05*vec2(sin(6.2831853*uTime/px+ph), sin(6.2831853*uTime/py+ph*1.7));',
    '}',
    'void main(){',
    '  vec2 dev=vec2(gl_FragCoord.x, uRes.y-gl_FragCoord.y);',
    '  vec2 css=dev/uDpr;',
    '  vec2 p=css/uUnit;',                                       // units of the orb scale (phone width), y down
    '  vec3 lab=uPaper; float tot=0.0; float c;',
    '  c=fringe(cov(p, drift(vec2(0.12,-0.02),53.0,41.0,0.0), 0.60), css)*uOp.x; lab=mix(lab,uPeach,c); tot=max(tot,c);',
    '  c=fringe(cov(p, drift(vec2(0.52,-0.10),67.0,53.0,2.0), 0.24), css)*uOp.y; lab=mix(lab,uIris,c); tot=max(tot,c);',
    '  c=fringe(cov(p, drift(vec2(0.42,0.06),41.0,67.0,4.0), 0.20), css)*uOp.w*uStatusOn; lab=mix(lab,uStatus,c); tot=max(tot,c);',
    '  c=fringe(cov(p, drift(vec2(0.86,0.04),41.0,53.0,1.0), 0.46*(1.0+0.03*uPulse)), css)*uOp.z; lab=mix(lab,uEmber,c); tot=max(tot,c);',
    // fade to exact paper at the bottom of the header (OKLab)
    '  float f=1.0-smoothstep(uFadeA,uFadeB,css.y);',
    '  lab=mix(uPaper,lab,f); tot*=f;',
    // static grain per device pixel, scaled by coverage
    '  float g=tri(h01(uvec2(dev), uint(uSeed)));',
    '  lab.x+=g*mix(0.01,uGrain,tot);',
    '  vec3 rgb=toSRGB(oklabToLinear(lab));',
    '  rgb+=vec3(tri(h01(uvec2(dev),11u)), tri(h01(uvec2(dev),23u)), tri(h01(uvec2(dev),37u)))/255.0;',
    '  fragColor=vec4(clamp(rgb,0.0,1.0),1.0);',
    '}'
  ].join('\n');

  // ---------------------------------------------------------------- mount
  function mount(canvas, opts) {
    opts = opts || {};
    var status = opts.status || 'none', evening = !!opts.evening;
    var target = look(status, evening), from = null, morphStart = 0;
    var pulseAt = -1e9;
    var mq = root.matchMedia ? root.matchMedia('(prefers-reduced-motion: reduce)') : null;
    var reduce = !!(mq && mq.matches) || !!opts.frozen;
    var onScreen = true, visible = !document.hidden, raf = 0, last = -1e9, dead = false;
    var epoch = performance.now();
    var seed = Math.floor(Date.now() / 864e5) % 100000;          // reseed once per day
    var dpr = 1, gl = null, prog = null, vao = null, U = {};

    function fallback() {
      dead = true;
      var p = evening ? COLORS.ink : COLORS.paper, a = evening ? '8c' : 'ff';
      canvas.style.background =
        'radial-gradient(circle at 86% 4%,' + COLORS.ember + a + ' 0 32%,transparent 46%),' +
        'radial-gradient(circle at 12% 0%,' + COLORS.peach + a + ' 0 40%,transparent 60%),' +
        'radial-gradient(circle at 52% -10%,' + COLORS.iris + '59 0 16%,transparent 24%),' + p;
      canvas.style.maskImage = canvas.style.webkitMaskImage = 'linear-gradient(#000 60%,transparent)';
    }
    var api = {
      setStatus: function (s) { if (s === status) return; status = s; retarget(); },
      setEvening: function (e) { e = !!e; if (e === evening) return; evening = e; retarget(); },
      pulse: function () { if (!reduce) { pulseAt = performance.now(); sync(); } },
      destroy: destroy,
      get webgl() { return !dead; }
    };

    try {
      gl = canvas.getContext('webgl2', { alpha: false, antialias: false, depth: false, stencil: false,
        premultipliedAlpha: false, preserveDrawingBuffer: !!opts.frozen, powerPreference: 'low-power' });
    } catch (_) { gl = null; }
    if (!gl) { fallback(); return api; }

    function build() {
      function sh(type, src) {
        var s = gl.createShader(type); gl.shaderSource(s, src); gl.compileShader(s);
        if (!gl.getShaderParameter(s, gl.COMPILE_STATUS)) throw new Error(gl.getShaderInfoLog(s) || 'shader');
        return s;
      }
      prog = gl.createProgram();
      gl.attachShader(prog, sh(gl.VERTEX_SHADER, VS));
      gl.attachShader(prog, sh(gl.FRAGMENT_SHADER, FS));
      gl.bindAttribLocation(prog, 0, 'aPos');
      gl.linkProgram(prog);
      if (!gl.getProgramParameter(prog, gl.LINK_STATUS)) throw new Error(gl.getProgramInfoLog(prog) || 'link');
      vao = gl.createVertexArray(); gl.bindVertexArray(vao);
      var buf = gl.createBuffer(); gl.bindBuffer(gl.ARRAY_BUFFER, buf);
      gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 3, -1, -1, 3]), gl.STATIC_DRAW);
      gl.enableVertexAttribArray(0); gl.vertexAttribPointer(0, 2, gl.FLOAT, false, 0, 0);
      U = {};
      ['uRes', 'uUnit', 'uDpr', 'uTime', 'uPulse', 'uGrain', 'uSeed', 'uFadeA', 'uFadeB', 'uStatusOn',
       'uPaper', 'uPeach', 'uIris', 'uEmber', 'uStatus', 'uOp'].forEach(function (k) { U[k] = gl.getUniformLocation(prog, k); });
    }
    try { build(); } catch (e) { console.warn('[MRHOrbs] WebGL2 failed, CSS fallback:', e.message); fallback(); return api; }

    // ---- exact device-pixel backing store
    var cssW = 1, cssH = 1;
    function applySize(devW, devH, cw, ch) {
      var w = Math.max(1, Math.round(devW)), h = Math.max(1, Math.round(devH));
      if (w * h > MAX_PIXELS) { var k = Math.sqrt(MAX_PIXELS / (w * h)); w = Math.round(w * k); h = Math.round(h * k); }
      cssW = cw || 1; cssH = ch || 1; dpr = w / cssW;
      if (canvas.width !== w || canvas.height !== h) { canvas.width = w; canvas.height = h; }
      draw(performance.now(), true);
    }
    var ro = new ResizeObserver(function (es) {
      var e = es[0], r = e.contentRect;
      if (e.devicePixelContentBoxSize && e.devicePixelContentBoxSize[0]) {
        applySize(e.devicePixelContentBoxSize[0].inlineSize, e.devicePixelContentBoxSize[0].blockSize, r.width, r.height);
      } else {
        var d = root.devicePixelRatio || 1; applySize(r.width * d, r.height * d, r.width, r.height);
      }
    });
    try { ro.observe(canvas, { box: 'device-pixel-content-box' }); } catch (_) { ro.observe(canvas); }

    function current(now) {
      if (!from) return target;
      var k = (now - morphStart) / MORPH_MS;
      if (k >= 1) { from = null; return target; }
      return mixLook(from, target, easeInOut(Math.max(0, k)));
    }
    function retarget() {
      var now = performance.now();
      if (dead) { fallback(); return; }
      from = reduce ? null : current(now);
      target = look(status, evening); morphStart = now;
      sync(); if (!running()) draw(now, true);
    }
    function draw(now, force) {
      if (dead || gl.isContextLost()) return;
      if (!force && now - last < FRAME_MS - 1) return;
      last = now;
      var L = current(now);
      var t = reduce ? FROZEN_T : FROZEN_T + ((now - epoch) / 1000) % 10000;
      var pk = (now - pulseAt) / PULSE_MS, pulse = pk >= 0 && pk < 1 ? 1 - (1 - Math.pow(1 - pk, 3)) : 0;
      var fadeB = opts.fadeEnd ? opts.fadeEnd(cssH) : cssH, fadeA = opts.fadeStart ? opts.fadeStart(cssH) : cssH * 0.62;
      gl.viewport(0, 0, canvas.width, canvas.height);
      gl.useProgram(prog); gl.bindVertexArray(vao);
      gl.uniform2f(U.uRes, canvas.width, canvas.height);
      gl.uniform1f(U.uDpr, dpr); gl.uniform1f(U.uUnit, opts.unit ? opts.unit(cssW) : cssW); gl.uniform1f(U.uTime, t); gl.uniform1f(U.uPulse, pulse);
      gl.uniform1f(U.uGrain, L.grain); gl.uniform1f(U.uSeed, seed);
      gl.uniform1f(U.uFadeA, fadeA); gl.uniform1f(U.uFadeB, fadeB);
      gl.uniform1f(U.uStatusOn, L.statusOn);
      gl.uniform3fv(U.uPaper, L.paper); gl.uniform3fv(U.uPeach, L.peach); gl.uniform3fv(U.uIris, L.iris);
      gl.uniform3fv(U.uEmber, L.ember); gl.uniform3fv(U.uStatus, L.status); gl.uniform4fv(U.uOp, L.op);
      gl.drawArrays(gl.TRIANGLES, 0, 3);
    }
    function pulsing(now) { return now - pulseAt < PULSE_MS; }
    function running() { return !dead && onScreen && visible && (!reduce || from !== null || pulsing(performance.now())); }
    function loop(now) {
      raf = 0; if (!running()) { draw(now, true); return; }
      draw(now, false); raf = requestAnimationFrame(loop);
    }
    function sync() {
      if (running()) { if (!raf) raf = requestAnimationFrame(loop); }
      else { if (raf) cancelAnimationFrame(raf); raf = 0; draw(performance.now(), true); }
    }

    var io = new IntersectionObserver(function (es) { onScreen = es[es.length - 1].isIntersecting; sync(); });
    io.observe(canvas);
    function onVis() { visible = !document.hidden; sync(); }
    document.addEventListener('visibilitychange', onVis);
    function onMotion(e) { reduce = e.matches || !!opts.frozen; sync(); }
    if (mq) mq.addEventListener('change', onMotion);

    // ---- context loss: stop, wait for restore, rebuild; give up -> CSS
    var lostTimer = 0;
    function onLost(e) { e.preventDefault(); if (raf) cancelAnimationFrame(raf); raf = 0;
      lostTimer = setTimeout(function () { if (gl.isContextLost()) fallback(); }, 3000); }
    function onRestored() { clearTimeout(lostTimer); try { build(); dead = false; canvas.style.background = ''; sync(); } catch (_) { fallback(); } }
    canvas.addEventListener('webglcontextlost', onLost);
    canvas.addEventListener('webglcontextrestored', onRestored);

    function destroy() {
      if (raf) cancelAnimationFrame(raf); raf = 0; clearTimeout(lostTimer);
      if (ro) ro.disconnect(); if (io) io.disconnect();   // undefined when WebGL was unavailable (CSS fallback)
      document.removeEventListener('visibilitychange', onVis);
      if (mq) mq.removeEventListener('change', onMotion);
      canvas.removeEventListener('webglcontextlost', onLost);
      canvas.removeEventListener('webglcontextrestored', onRestored);
      var ext = gl && gl.getExtension('WEBGL_lose_context'); if (ext) ext.loseContext();
      dead = true;
    }

    sync();
    return api;
  }

  root.MRHOrbs = { mount: mount, COLORS: COLORS };
})(typeof window !== 'undefined' ? window : globalThis);
