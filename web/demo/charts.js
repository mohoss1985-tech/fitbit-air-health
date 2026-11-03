/* charts.js — MRH1 v1.0 chart primitives on <canvas>, drawn at devicePixelRatio.
 * Chart spec (research/04 + DESIGN_SPEC §3):
 *  line 1.75 px, round caps/joins, monotone cubic (Fritsch-Carlson, no overshoot), null = gap;
 *  grained fill (series 24 % -> 0 %, +-3 % grain) only when opts.fill (Live + Strain HR charts);
 *  gridlines horizontal, hair, 1 device px, dotted 1 on / 3 off, max 3;
 *  current point 6 px ember + 2 px card ring; dark mode only: 6 px blur glow at 22 %.
 *  Colours come from CSS custom properties, so light/dark both work.
 */
(function (root) {
  'use strict';

  // ---------------------------------------------------------------- tokens + colour
  function tok(name) { return getComputedStyle(document.documentElement).getPropertyValue('--' + name).trim(); }
  function isDark() { return document.documentElement.dataset.theme === 'dark'; }
  function hexA(hex, a) {
    var n = parseInt(hex.replace('#', ''), 16);
    return 'rgba(' + ((n >> 16) & 255) + ',' + ((n >> 8) & 255) + ',' + (n & 255) + ',' + a + ')';
  }
  // OKLab mix for gradients and dot ramps (never mix in sRGB)
  function toLin(v) { v /= 255; return v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4); }
  function toSrgb(v) { v = Math.max(0, Math.min(1, v)); return Math.round(255 * (v <= 0.0031308 ? v * 12.92 : 1.055 * Math.pow(v, 1 / 2.4) - 0.055)); }
  function hexLab(hex) {
    var n = parseInt(hex.replace('#', ''), 16), r = toLin((n >> 16) & 255), g = toLin((n >> 8) & 255), b = toLin(n & 255);
    var l = Math.cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b);
    var m = Math.cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b);
    var s = Math.cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b);
    return [0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s, 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s, 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s];
  }
  function labRgb(c) {
    var l_ = c[0] + 0.3963377774 * c[1] + 0.2158037573 * c[2], m_ = c[0] - 0.1055613458 * c[1] - 0.0638541728 * c[2], s_ = c[0] - 0.0894841775 * c[1] - 1.2914855480 * c[2];
    var l = l_ * l_ * l_, m = m_ * m_ * m_, s = s_ * s_ * s_;
    return 'rgb(' + toSrgb(4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s) + ',' + toSrgb(-1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s) + ',' + toSrgb(-0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s) + ')';
  }
  function oklabMix(a, b, t) { var A = hexLab(a), B = hexLab(b); return labRgb([A[0] + (B[0] - A[0]) * t, A[1] + (B[1] - A[1]) * t, A[2] + (B[2] - A[2]) * t]); }

  // ---------------------------------------------------------------- canvas at device pixels
  function prep(cv) {
    var r = cv.getBoundingClientRect(), dpr = root.devicePixelRatio || 1;
    var w = Math.max(1, Math.round(r.width * dpr)), h = Math.max(1, Math.round(r.height * dpr));
    if (cv.width !== w) cv.width = w;
    if (cv.height !== h) cv.height = h;
    var ctx = cv.getContext('2d');
    ctx.setTransform(1, 0, 0, 1, 0, 0); ctx.clearRect(0, 0, w, h);
    ctx.setTransform(w / r.width, 0, 0, h / r.height, 0, 0);
    return { ctx: ctx, w: r.width, h: r.height, dpr: w / r.width };
  }
  // snap a horizontal hairline to the device-pixel grid
  function snap(y, dpr) { return (Math.floor(y * dpr) + 0.5) / dpr; }

  // static grain tile (per device pixel, deterministic), cached per dpr
  var grainCache = {};
  function grain(ctx, dpr) {
    var key = dpr.toFixed(2);
    if (!grainCache[key]) {
      var c = document.createElement('canvas'); c.width = c.height = 128;
      var g = c.getContext('2d'), img = g.createImageData(128, 128), s = 1234567;
      for (var i = 0; i < img.data.length; i += 4) {
        s = (s * 16807) % 2147483647; var v = s / 2147483647;
        var light = v > 0.5; img.data[i] = img.data[i + 1] = img.data[i + 2] = light ? 255 : 0;
        img.data[i + 3] = Math.round(Math.abs(v - 0.5) * 2 * 26);               // up to ~10 % -> +-3 % L
      }
      g.putImageData(img, 0, 0); grainCache[key] = c;
    }
    var p = ctx.createPattern(grainCache[key], 'repeat');
    if (p.setTransform && root.DOMMatrix) p.setTransform(new DOMMatrix().scale(1 / dpr));
    return p;
  }

  // ---------------------------------------------------------------- monotone cubic path
  function monotone(ctx, pts, moveFirst) {
    var n = pts.length; if (!n) return;
    if (moveFirst) ctx.moveTo(pts[0][0], pts[0][1]); else ctx.lineTo(pts[0][0], pts[0][1]);
    if (n === 1) return;
    if (n === 2) { ctx.lineTo(pts[1][0], pts[1][1]); return; }
    var d = [], m = [], i;
    for (i = 0; i < n - 1; i++) d.push((pts[i + 1][1] - pts[i][1]) / ((pts[i + 1][0] - pts[i][0]) || 1e-6));
    m[0] = d[0]; m[n - 1] = d[n - 2];
    for (i = 1; i < n - 1; i++) m[i] = d[i - 1] * d[i] <= 0 ? 0 : (d[i - 1] + d[i]) / 2;
    for (i = 0; i < n - 1; i++) {
      if (d[i] === 0) { m[i] = m[i + 1] = 0; continue; }
      var a = m[i] / d[i], b = m[i + 1] / d[i], s = a * a + b * b;
      if (s > 9) { var t = 3 / Math.sqrt(s); m[i] = t * a * d[i]; m[i + 1] = t * b * d[i]; }
    }
    for (i = 0; i < n - 1; i++) {
      var h = (pts[i + 1][0] - pts[i][0]) / 3;
      ctx.bezierCurveTo(pts[i][0] + h, pts[i][1] + h * m[i], pts[i + 1][0] - h, pts[i + 1][1] - h * m[i + 1], pts[i + 1][0], pts[i + 1][1]);
    }
  }
  function segments(values, X, Y) {
    var segs = [], cur = [];
    values.forEach(function (p) {
      if (p.y == null || isNaN(p.y)) { if (cur.length) segs.push(cur); cur = []; }
      else cur.push([X(p.x), Y(p.y)]);
    });
    if (cur.length) segs.push(cur);
    return segs;
  }
  function niceTicks(lo, hi, count) {
    var span = hi - lo, step = Math.pow(10, Math.floor(Math.log10(span / count)));
    [1, 2, 2.5, 5, 10].some(function (k) { if (span / (step * k) <= count) { step *= k; return true; } return false; });
    var out = []; for (var v = Math.ceil(lo / step) * step; v <= hi + 1e-9; v += step) out.push(+v.toFixed(6));
    return out;
  }

  // ---------------------------------------------------------------- line chart
  /* opts: values [{x,y}], color, fill (bool), xDomain [a,b], yDomain [a,b] (else padded auto),
     grid (bool, default true), yTicks (array), xLabels [{x,label}], band {lo,hi}, shade [{x0,x1,label}],
     point (bool), padR (label gutter), padB, lineWidth, dots (bool) */
  function line(cv, o) {
    var P = prep(cv), ctx = P.ctx, W = P.w, H = P.h, dpr = P.dpr;
    var vals = o.values.filter(function (p) { return p.y != null; });
    if (!vals.length) return null;
    var xs = o.values.map(function (p) { return p.x; });
    var x0 = o.xDomain ? o.xDomain[0] : Math.min.apply(null, xs), x1 = o.xDomain ? o.xDomain[1] : Math.max.apply(null, xs);
    var ys = vals.map(function (p) { return p.y; });
    if (o.band) ys.push(o.band.lo, o.band.hi);
    (o.refLines || []).forEach(function (r) { ys.push(r.v); });
    var lo = Math.min.apply(null, ys), hi = Math.max.apply(null, ys), pad = (hi - lo) * 0.14 || 1;
    var y0 = o.yDomain ? o.yDomain[0] : lo - pad, y1 = o.yDomain ? o.yDomain[1] : hi + pad;
    var grid = o.grid !== false, padR = o.padR != null ? o.padR : (grid ? 28 : 4), padB = o.padB != null ? o.padB : (o.xLabels ? 20 : 4);
    var padT = o.padT != null ? o.padT : 6, padL = o.padL != null ? o.padL : 0;
    var pw = W - padL - padR, ph = H - padT - padB;
    var X = function (x) { return padL + (x - x0) / ((x1 - x0) || 1) * pw; };
    var Y = function (y) { return padT + (1 - (y - y0) / ((y1 - y0) || 1)) * ph; };
    var ink = tok('ink'), hair = tok('hair'), graphite = tok('graphite'), card = tok('card'), ember = tok('ember');
    var color = o.color || ink, font = '400 11px ' + tok('font-ui');

    // sleep / context shading
    (o.shade || []).forEach(function (s) {
      ctx.fillStyle = hexA(tok('iris'), isDark() ? 0.14 : 0.10);
      var a = Math.max(padL, X(s.x0)), b = Math.min(padL + pw, X(s.x1));
      ctx.fillRect(a, padT, b - a, ph);
      if (s.label) { ctx.fillStyle = graphite; ctx.font = font; ctx.textBaseline = 'top'; ctx.fillText(s.label, a + 6, padT + 4); }
    });
    // baseline ribbon band (personal normal = ink 10 %)
    if (o.band) {
      ctx.fillStyle = hexA(ink, isDark() ? 0.12 : 0.08);
      ctx.fillRect(padL, Y(o.band.hi), pw, Y(o.band.lo) - Y(o.band.hi));
      if (o.bandLabel) { ctx.fillStyle = graphite; ctx.font = font; ctx.textBaseline = 'bottom'; ctx.fillText(o.bandLabel, padL + 4, Y(o.band.hi) - 3); }
    }
    // dotted hairline grid + right labels
    if (grid) {
      var ticks = o.yTicks || niceTicks(y0, y1, 4);
      while (ticks.length > 3) ticks = ticks.filter(function (_, i) { return i % 2 === 0; });
      ctx.save(); ctx.strokeStyle = hair; ctx.lineWidth = 1 / dpr; ctx.setLineDash([1, 3]);
      ticks.forEach(function (t) { var y = snap(Y(t), dpr); ctx.beginPath(); ctx.moveTo(padL, y); ctx.lineTo(padL + pw, y); ctx.stroke(); });
      ctx.restore();
      ctx.fillStyle = graphite; ctx.font = font; ctx.textAlign = 'right'; ctx.textBaseline = 'middle';
      ticks.forEach(function (t) { ctx.fillText(String(t), W, Y(t)); });
      ctx.textAlign = 'left';
    }
    if (o.xLabels) {
      ctx.fillStyle = graphite; ctx.font = font; ctx.textBaseline = 'alphabetic';
      o.xLabels.forEach(function (l, i) {
        ctx.textAlign = i === 0 ? 'left' : (i === o.xLabels.length - 1 ? 'right' : 'center');
        ctx.fillText(l.label, i === 0 ? padL : (i === o.xLabels.length - 1 ? padL + pw : X(l.x)), H - 4);
      });
      ctx.textAlign = 'left';
    }
    var segs = segments(o.values, X, Y);
    // grained fill (Live + Strain only)
    if (o.fill) {
      segs.forEach(function (sg) {
        if (sg.length < 2) return;
        ctx.save(); ctx.beginPath(); monotone(ctx, sg, true);
        ctx.lineTo(sg[sg.length - 1][0], padT + ph); ctx.lineTo(sg[0][0], padT + ph); ctx.closePath(); ctx.clip();
        var top = Math.min.apply(null, sg.map(function (p) { return p[1]; }));
        var gr = ctx.createLinearGradient(0, top, 0, padT + ph);
        var fc = o.fillColor || ember;
        gr.addColorStop(0, hexA(fc, isDark() ? 0.30 : 0.24)); gr.addColorStop(1, hexA(fc, 0));
        ctx.fillStyle = gr; ctx.fillRect(padL, top, pw, padT + ph - top);
        ctx.fillStyle = grain(ctx, dpr); ctx.globalAlpha = 0.9; ctx.fillRect(padL, top, pw, padT + ph - top);
        ctx.restore();
      });
    }
    // line (+ dark-mode glow)
    ctx.save();
    ctx.lineWidth = o.lineWidth || 1.75; ctx.lineCap = 'round'; ctx.lineJoin = 'round'; ctx.strokeStyle = color;
    if (isDark() && o.glow !== false) { ctx.shadowColor = hexA(color.charAt(0) === '#' ? color : '#F2EFEA', 0.22); ctx.shadowBlur = 6 * dpr; }
    segs.forEach(function (sg) {
      ctx.beginPath(); monotone(ctx, sg, true);
      if (sg.length === 1) { ctx.arc(sg[0][0], sg[0][1], 0.9, 0, 6.3); }
      ctx.stroke();
    });
    ctx.restore();
    (o.refLines || []).forEach(function (r) {
      var y = snap(Y(r.v), dpr);
      ctx.save(); ctx.strokeStyle = r.color; ctx.lineWidth = r.width || 1.75; ctx.lineCap = 'round'; if (r.dash) ctx.setLineDash(r.dash);
      ctx.beginPath(); ctx.moveTo(X(r.x0), y); ctx.lineTo(X(r.x1), y); ctx.stroke(); ctx.restore();
    });
    if (o.dots) {
      o.values.forEach(function (p) { if (p.y == null) return; ctx.beginPath(); ctx.fillStyle = p.color || color; ctx.arc(X(p.x), Y(p.y), 3, 0, 6.3); ctx.fill(); });
    }
    // current point
    var lastP = null;
    if (o.point) {
      var lv = vals[vals.length - 1]; lastP = { x: X(lv.x), y: Y(lv.y) };
      ctx.beginPath(); ctx.fillStyle = card; ctx.arc(lastP.x, lastP.y, 5, 0, 6.3); ctx.fill();
      ctx.beginPath(); ctx.fillStyle = o.pointColor || ember; ctx.arc(lastP.x, lastP.y, 3, 0, 6.3); ctx.fill();
    }
    return { X: X, Y: Y, last: lastP, w: W, h: H };
  }

  // ---------------------------------------------------------------- bars (stress, steps, trends)
  /* opts: bars [{v, color, future, faint}], max, gap 3, radius 2, grain, refLines [{v,color,dash,label}],
     xLabels [{i,label}], padB */
  function bars(cv, o) {
    var P = prep(cv), ctx = P.ctx, W = P.w, H = P.h, dpr = P.dpr;
    var n = o.bars.length, gap = o.gap != null ? o.gap : 3, padB = o.xLabels ? 18 : 0, padR = o.padR || 0;
    var bw = (W - padR - gap * (n - 1)) / n, ph = H - padB, max = o.max || 1;
    var hair = tok('hair'), graphite = tok('graphite');
    o.bars.forEach(function (b, i) {
      var x = i * (bw + gap);
      if (b.future || b.v == null) {
        ctx.strokeStyle = hair; ctx.lineWidth = 1 / dpr;
        var hh = Math.max(4, ph * 0.12);
        rr(ctx, Math.round(x * dpr) / dpr + 0.5 / dpr, ph - hh + 0.5 / dpr, bw - 1 / dpr, hh - 1 / dpr, 2); ctx.stroke();
        return;
      }
      var h = Math.max(2, (b.v / max) * ph);
      ctx.fillStyle = b.color; ctx.globalAlpha = b.faint ? 0.45 : 1;
      rr(ctx, x, ph - h, bw, h, Math.min(2, bw / 2)); ctx.fill();
      ctx.globalAlpha = 1;
    });
    if (o.grain !== false) {   // print grain over the marks only
      ctx.save(); ctx.globalCompositeOperation = 'source-atop'; ctx.fillStyle = grain(ctx, dpr); ctx.fillRect(0, 0, W, ph); ctx.restore();
    }
    (o.refLines || []).forEach(function (r) {
      var y = snap(ph - (r.v / max) * ph, dpr), xa = r.from != null ? r.from * (bw + gap) : 0, xb = r.to != null ? (r.to + 1) * (bw + gap) - gap : W - padR;
      ctx.save(); ctx.strokeStyle = r.color; ctx.lineWidth = r.width || 1.75; ctx.lineCap = 'round';
      if (r.dash) ctx.setLineDash(r.dash);
      ctx.beginPath(); ctx.moveTo(xa, y); ctx.lineTo(xb, y); ctx.stroke(); ctx.restore();
    });
    if (o.xLabels) {
      ctx.fillStyle = graphite; ctx.font = '400 11px ' + tok('font-ui'); ctx.textBaseline = 'alphabetic';
      o.xLabels.forEach(function (l) {
        var cx = l.i * (bw + gap) + bw / 2;
        ctx.textAlign = l.align || 'center'; ctx.fillText(l.label, l.align === 'left' ? l.i * (bw + gap) : l.align === 'right' ? l.i * (bw + gap) + bw : cx, H - 3);
      });
    }
  }
  function rr(ctx, x, y, w, h, r) {
    ctx.beginPath(); ctx.moveTo(x, y + h); ctx.lineTo(x, y + r); ctx.arcTo(x, y, x + r, y, r);
    ctx.lineTo(x + w - r, y); ctx.arcTo(x + w, y, x + w, y + r, r); ctx.lineTo(x + w, y + h); ctx.closePath();
  }

  // ---------------------------------------------------------------- strain capsule gauge
  function capsule(cv, o) {
    var P = prep(cv), ctx = P.ctx, W = P.w, H = P.h, dpr = P.dpr;
    var th = o.thickness || 10, y = (H - th) / 2, r = th / 2, max = o.max || 21;
    var ink = tok('ink');
    ctx.fillStyle = tok('track'); pill(ctx, 0, y, W, th, r); ctx.fill();
    var fw = Math.max(th, W * Math.min(1, o.value / max));
    ctx.save(); pill(ctx, 0, y, fw, th, r); ctx.clip();
    var g = ctx.createLinearGradient(0, 0, Math.max(fw, 1), 0);
    for (var i = 0; i <= 6; i++) g.addColorStop(i / 6, oklabMix('#F0582A', '#F3A79E', i / 6 * 0.85));
    ctx.fillStyle = g; ctx.fillRect(0, y, fw, th);
    ctx.fillStyle = grain(ctx, dpr); ctx.fillRect(0, y, fw, th);
    ctx.restore();
    // target zone = two ink ticks
    ctx.fillStyle = ink;
    (o.target || []).forEach(function (t) {
      var x = Math.round((t / max) * W * dpr) / dpr;
      ctx.fillRect(x - 0.75, y - 4, 1.5, th + 8);
    });
  }
  function pill(ctx, x, y, w, h, r) {
    ctx.beginPath(); ctx.moveTo(x + r, y); ctx.lineTo(x + w - r, y); ctx.arc(x + w - r, y + r, r, -Math.PI / 2, Math.PI / 2);
    ctx.lineTo(x + r, y + h); ctx.arc(x + r, y + r, r, Math.PI / 2, Math.PI * 1.5); ctx.closePath();
  }

  // ---------------------------------------------------------------- dot-matrix range strip
  /* opts: domain [a,b], band [lo,hi] (personal normal), value, status ('good'|'limit'|'danger'),
     rows (1|2), label (pill text, optional) */
  function strip(cv, o) {
    var P = prep(cv), ctx = P.ctx, W = P.w, H = P.h;
    var pitch = 6.5, dot = 4, cols = Math.floor((W - dot) / pitch) + 1, rows = o.rows || 2;
    var off = (W - ((cols - 1) * pitch + dot)) / 2 + dot / 2;
    var a = o.domain[0], b = o.domain[1], hair = tok('hair'), statusHex = tok(o.status || 'good');
    var baseY = H - (rows - 1) * pitch - dot / 2 - 1;
    var mid = (o.band[0] + o.band[1]) / 2, halfBand = (o.band[1] - o.band[0]) / 2 || 1;
    var vx = off + Math.max(0, Math.min(1, (o.value - a) / (b - a))) * (cols - 1) * pitch;
    var vcol = Math.round((vx - off) / pitch);
    for (var c = 0; c < cols; c++) {
      var v = a + (c / (cols - 1)) * (b - a), inBand = v >= o.band[0] && v <= o.band[1];
      // in-band dots step 30 -> 100 % toward the centre of your normal (OKLab, over the card)
      var t = inBand ? 0.3 + 0.7 * (1 - Math.abs(v - mid) / halfBand) : 0;
      var col = inBand ? oklabMix(tok('card'), statusHex, t) : hair;
      for (var r = 0; r < rows; r++) {
        ctx.beginPath(); ctx.fillStyle = c === vcol ? tok('ink') : col;
        ctx.arc(off + c * pitch, baseY + r * pitch, c === vcol ? 2.6 : dot / 2, 0, 6.3); ctx.fill();
      }
    }
    if (o.label) {
      ctx.font = '500 11px ' + tok('font-ui'); var tw = ctx.measureText(o.label).width + 14;
      var px = Math.max(0, Math.min(W - tw, off + vcol * pitch - tw / 2)), py = 0, ph = 20;
      ctx.fillStyle = tok('card'); ctx.strokeStyle = tok('hair'); ctx.lineWidth = 1;
      pill(ctx, px + 0.5, py + 0.5, tw - 1, ph - 1, (ph - 1) / 2); ctx.fill(); ctx.stroke();
      ctx.fillStyle = tok('ink'); ctx.textBaseline = 'middle'; ctx.textAlign = 'center'; ctx.fillText(o.label, px + tw / 2, py + ph / 2 + 0.5);
      ctx.textAlign = 'left';
    }
  }

  root.MRHCharts = { prep: prep, line: line, bars: bars, capsule: capsule, strip: strip, oklabMix: oklabMix, tok: tok, hexA: hexA };
})(window);
