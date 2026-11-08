/* MRH1 v1.1 web demo — browser replica of the iOS app on synthetic data (data.js).
 * Tabs: Today · Live · Body · Trends · Coach (scripted, coach.js). Menu (results guide) top-left, + journal on Today.
 * Query: ?tab=today|live|body|trends|coach  &open=menu|journal|recovery|strain|sleep|metric:<id>  &ask=<answer keys, comma-separated>  &coach=off
 *        &theme=dark|light  &range=live|1h|24h|7d|30d  &panel=heart|lungs|sleep|activity  &shot (screenshot mode)
 */
(function () {
  'use strict';
  var D = window.MRH1_DATA, C = window.MRHCharts;
  var Q = new URLSearchParams(location.search);
  var SHOT = Q.has('shot');
  var RM = matchMedia('(prefers-reduced-motion: reduce)');
  var DAY = 864e5;
  var app = document.getElementById('app');

  // ---------------------------------------------------------------- helpers
  function esc(s) { return String(s).replace(/[&<>"]/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]; }); }
  function mean(a) { return a.reduce(function (s, v) { return s + v; }, 0) / (a.length || 1); }
  function sdev(a) { var m = mean(a); return Math.sqrt(mean(a.map(function (v) { return (v - m) * (v - m); }))); }
  function hm(min) { min = Math.round(min); var h = Math.floor(min / 60), m = min % 60; return h ? h + ' h ' + String(m).padStart(2, '0') : m + ' min'; }
  function n0(v) { return Math.round(v).toLocaleString('en-US'); }
  function hhmm(d) { d = new Date(d); return String(d.getHours()).padStart(2, '0') + ':' + String(d.getMinutes()).padStart(2, '0'); }
  var WD = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
  var MO = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
  function dayLetter(d) { return 'SMTWTFS'[d.getDay()]; }
  function clamp(v, a, b) { return Math.max(a, Math.min(b, v)); }

  // ---------------------------------------------------------------- icons (one weight)
  var I = {
    menu: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round"><path d="M5 8h14M5 12h14M5 16h9"/></svg>',
    plus: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round"><path d="M12 5v14M5 12h14"/></svg>',
    close: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round"><path d="M7 7l10 10M17 7L7 17"/></svg>',
    info: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round"><circle cx="12" cy="12" r="8.5"/><path d="M12 11v5.5"/><circle cx="12" cy="7.8" r=".6" fill="currentColor"/></svg>',
    today: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round"><circle cx="12" cy="12" r="3.6"/><path d="M12 3.5v2M12 18.5v2M3.5 12h2M18.5 12h2M6 6l1.4 1.4M16.6 16.6L18 18M6 18l1.4-1.4M16.6 7.4L18 6"/></svg>',
    live: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round"><path d="M3 12h4l2-5 4 10 2.5-5H21"/></svg>',
    body: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75"><rect x="4.5" y="4.5" width="6" height="6" rx="2"/><rect x="13.5" y="4.5" width="6" height="6" rx="2"/><rect x="4.5" y="13.5" width="6" height="6" rx="2"/><rect x="13.5" y="13.5" width="6" height="6" rx="2"/></svg>',
    trends: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round"><path d="M4 17l5-5 3.5 3.5L20 8"/><path d="M15 8h5v5"/></svg>'
  };

  // ---------------------------------------------------------------- metrics + flags
  var M = {
    restingHR:  { label: 'Resting heart rate', unit: 'bpm', dec: 0, panel: 'heart', dir: 'lower', domain: [44, 80], minSd: 1.2, s: D.data.restingHR,
      what: 'Your lowest steady heart rate, measured while you sleep.', hi: 'Higher than usual often follows hard training, alcohol, late meals or poor sleep.', lo: 'Lower than usual usually means you are well rested.' },
    sleepingHR: { label: 'Heart rate asleep', unit: 'bpm', dec: 0, panel: 'heart', dir: 'lower', domain: [40, 76], minSd: 1.2, s: D.data.sleepingHR,
      what: 'Your average heart rate across the night.', hi: 'Higher often follows a late meal, alcohol or a warm room.', lo: 'Lower usually means a calm night.' },
    hrv:        { label: 'Heart rate variability', short: 'HRV', panel: 'heart', notSent: true,
      what: 'The variation between heartbeats. Google Health does not send HRV to Apple Health yet, so Recovery uses the other signals.' },
    breathing:  { label: 'Breathing rate', unit: 'br/min', dec: 1, panel: 'lungs', dir: 'both', domain: [12, 18], minSd: 0.25, s: D.data.breathing, vital: true,
      what: 'Breaths per minute while you sleep. It is usually very steady from night to night.', hi: 'A rise can follow hard training, alcohol, or your body fighting something off. Rest and see if it settles.', lo: 'Lower than usual is rarely a concern.' },
    spo2:       { label: 'Blood oxygen', short: 'SpO2', unit: '%', dec: 1, panel: 'lungs', dir: 'higher', domain: [92, 100], minSd: 0.4, s: D.data.spo2, vital: true,
      what: 'Oxygen saturation while you sleep, read with red and infrared light.', hi: 'Higher is fine.', lo: 'A dip can follow altitude, congestion or a band worn loosely.' },
    skinTemp:   { label: 'Skin temperature', panel: 'lungs', notSent: true,
      what: 'Change in skin temperature against your usual night. Google Health does not send it to Apple Health yet.' },
    sleepTotal: { label: 'Time asleep', unit: '', fmt: hm, panel: 'sleep', dir: 'higher', domain: [330, 540], minSd: 15, s: D.data.sleepTotal,
      what: 'Time actually asleep, not time in bed.', hi: 'More sleep than usual often follows a hard day or a short night.', lo: 'Less sleep than usual lowers Recovery the next day.' },
    deepSleep:  { label: 'Deep sleep', unit: '', fmt: hm, panel: 'sleep', dir: 'higher', domain: [30, 120], minSd: 6, s: D.data.deepSleep,
      what: 'The most restorative stage, mostly early in the night.', hi: 'More deep sleep usually follows a hard training day.', lo: 'Less deep sleep can follow alcohol or a late night.' },
    remSleep:   { label: 'REM sleep', unit: '', fmt: hm, panel: 'sleep', dir: 'higher', domain: [40, 140], minSd: 6, s: D.data.remSleep,
      what: 'The dreaming stage, mostly late in the night.', hi: 'More REM is common after a short previous night.', lo: 'Less REM often follows an early alarm.' },
    awake:      { label: 'Awake in the night', unit: '', fmt: hm, panel: 'sleep', dir: 'lower', domain: [10, 70], minSd: 4, s: D.data.awake,
      what: 'Minutes awake between falling asleep and getting up.', hi: 'More wake time can follow caffeine, alcohol or noise.', lo: 'Less is better.' },
    steps:      { label: 'Steps', unit: '', dec: 0, panel: 'activity', dir: 'higher', domain: [2000, 16000], minSd: 800, s: D.data.steps,
      what: 'Steps counted by the band today.', hi: 'More movement than usual.', lo: 'A quieter day than usual.' },
    energy:     { label: 'Active energy', unit: 'kcal', dec: 0, panel: 'activity', dir: 'higher', domain: [200, 1200], minSd: 60, s: D.data.energy,
      what: 'Energy burned through movement, on top of your resting burn.', hi: 'A more active day than usual.', lo: 'A quieter day than usual.' },
    workoutMinutes: { label: 'Exercise, last 7 days', unit: 'min', dec: 0, panel: 'activity', dir: 'higher', domain: [60, 300], minSd: 15, s: D.data.workoutMinutes,
      what: 'Workout minutes in the last 7 days. 150 or more is the usual guideline.', hi: 'More training than usual.', lo: 'Less training than usual.' },
    vo2max:     { label: 'Cardio fitness', short: 'VO2 max', panel: 'activity', notSent: true,
      what: 'An estimate of aerobic fitness. Google Health does not send it to Apple Health yet.' }
  };
  var PANELS = [['heart', 'Heart'], ['lungs', 'Lungs'], ['sleep', 'Sleep'], ['activity', 'Activity']];
  var TIER = { good: 'In range', limit: 'Watch', danger: 'Out of range' };
  var RANK = { good: 0, limit: 1, danger: 2 };

  function flagOf(m, v, mu, sd) {
    var z = (v - mu) / sd, a = Math.abs(z);
    if (m.dir === 'lower' && z < 0) a = 0;
    if (m.dir === 'higher' && z > 0) a = 0;
    return a <= 1.5 ? 'good' : a <= 2.5 ? 'limit' : 'danger';
  }
  var statsCache = {};
  function stats(id) {
    if (statsCache[id]) return statsCache[id];
    var m = M[id]; if (m.notSent) return (statsCache[id] = { notSent: true });
    var vals = m.s.map(function (p) { return p.value; });
    var v = vals[vals.length - 1], base = vals.slice(0, -1);
    var mu = mean(base), sd = Math.max(sdev(base), m.minSd || 0);
    var flag = flagOf(m, v, mu, sd);
    var dirWord = v > mu + 1.5 * sd ? 'above your usual' : v < mu - 1.5 * sd ? 'below your usual' : 'within your usual';
    return (statsCache[id] = { v: v, vals: vals, mu: mu, sd: sd, band: [mu - 1.5 * sd, mu + 1.5 * sd], flag: flag, dirWord: dirWord,
      nightFlag: function (val) { return flagOf(m, val, mu, sd); } });
  }
  function fmtV(id, v) { var m = M[id]; return m.fmt ? m.fmt(v) : (m.dec ? v.toFixed(m.dec) : n0(v)); }
  function valHTML(id, v, cls) {
    var m = M[id], s = fmtV(id, v);
    if (m.fmt === hm) {   // "7 h 12": numbers big, units small
      s = esc(s).replace(/ (h|min) ?/g, function (_, u) { return '<span class="unit">' + u + '</span> '; }).replace(/ $/, '');
      return '<b class="' + (cls || '') + '">' + s + '</b>';
    }
    return '<b class="' + (cls || '') + '">' + esc(s) + '</b>' + (m.unit ? '<span class="unit">' + esc(m.unit) + '</span>' : '');
  }
  function chip(flag, text) { return '<span class="chip ' + flag + '"><i></i>' + esc(text || TIER[flag]) + '</span>'; }
  function nsChip(text) { return '<span class="chip ns"><i></i>' + esc(text || 'Not sent') + '</span>'; }
  function panelFlag(p) {
    var worst = 'good', n = 0;
    Object.keys(M).forEach(function (id) {
      if (M[id].panel !== p || M[id].notSent) return;
      var f = stats(id).flag; if (f !== 'good') n++;
      if (RANK[f] > RANK[worst]) worst = f;
    });
    return { flag: worst, watch: n };
  }
  function ribbon(id) {
    var st = stats(id), m = M[id], lo = Math.min(m.domain[0], st.v), hi = Math.max(m.domain[1], st.v);
    var p = function (v) { return clamp((v - lo) / (hi - lo) * 100, 0, 100).toFixed(2) + '%'; };
    var col = st.flag === 'good' ? 'var(--ember)' : 'var(--' + st.flag + ')';
    return '<div class="ribbon" aria-hidden="true"><div class="tr"></div><div class="bd" style="left:' + p(st.band[0]) + ';width:calc(' + p(st.band[1]) + ' - ' + p(st.band[0]) + ')"></div>' +
      '<div class="dt" style="left:' + p(st.v) + ';background:' + col + '"></div></div>';
  }
  function usual(id) { var st = stats(id); return 'Your usual ' + fmtV(id, st.band[0]) + '–' + fmtV(id, st.band[1]) + (M[id].unit && M[id].fmt !== hm ? ' ' + M[id].unit : ''); }

  // ---------------------------------------------------------------- scores
  var S = D.scores;
  var recFlag = S.recovery >= 67 ? 'good' : S.recovery >= 34 ? 'limit' : 'danger';
  var last7 = D.history.slice().sort(function (a, b) { return b.d - a.d; });   // d 6 .. 0
  var rec14 = [];
  for (var di = 13; di >= 0; di--) {
    var h = D.history.filter(function (x) { return x.d === di; })[0];
    rec14.push({ d: di, v: h ? h.recovery : Math.round(68 + 11 * Math.sin(di * 1.9) + 4 * Math.cos(di * 0.7)) });
  }
  function tierOf(v) { return v >= 67 ? 'good' : v >= 34 ? 'limit' : 'danger'; }
  var nowMin = D.nowMin;
  var partOfDay = nowMin < 12 * 60 ? 'morning' : nowMin < 18 * 60 ? 'afternoon' : 'evening';
  var verdict = {
    morning: 'Recovery 78 %, above your usual. A good day to push toward a strain of 14.',
    afternoon: 'Strain ' + S.strain + ' of a ' + D.strainTarget[0] + '–' + D.strainTarget[1] + ' target. A 30-minute walk gets you there.',
    evening: 'A full day. Wind down by 23:00 to protect tomorrow’s recovery.'
  }[partOfDay];

  // ---------------------------------------------------------------- tick rings + arcs (SVG, crisp at any DPR)
  var ringAnimate = (function () {
    if (SHOT || RM.matches) return false;
    try { var k = 'mrh1-rings', t = new Date().toDateString(); if (localStorage.getItem(k) === t) return false; localStorage.setItem(k, t); } catch (_) {}
    return true;
  })();
  function tickRing(size, progress, color, opts) {
    opts = opts || {};
    var n = opts.ticks || 48, tw = opts.tw || 2, tl = opts.tl || 7, r = size / 2 - tw / 2, lit = Math.round(clamp(progress, 0, 1) * n), out = '';
    for (var i = 0; i < n; i++) {
      var a = (i / n) * Math.PI * 2 - Math.PI / 2, c = Math.cos(a), s = Math.sin(a);
      var on = i < lit, col = on ? color : 'var(--hair)';
      var anim = on && opts.animate;
      out += '<line class="tk' + (anim ? ' lt' : '') + '" x1="' + (size / 2 + c * (r - tl + tw / 2)).toFixed(2) + '" y1="' + (size / 2 + s * (r - tl + tw / 2)).toFixed(2) +
        '" x2="' + (size / 2 + c * r).toFixed(2) + '" y2="' + (size / 2 + s * r).toFixed(2) + '" stroke="' + (anim ? 'var(--hair)' : col) + '"' +
        (anim ? ' data-c="' + color + '" style="transition-delay:' + i * 8 + 'ms"' : '') + '/>';
    }
    return '<svg width="' + size + '" height="' + size + '" viewBox="0 0 ' + size + ' ' + size + '" stroke-width="' + tw + '" stroke-linecap="round" aria-hidden="true">' + out + '</svg>';
  }
  function arc(size, progress, color) {
    var sw = 3, r = (size - sw) / 2, cx = size / 2, L = 2 * Math.PI * r, span = 0.75 * L;
    var common = 'cx="' + cx + '" cy="' + cx + '" r="' + r + '" fill="none" stroke-width="' + sw + '" stroke-linecap="round" transform="rotate(135 ' + cx + ' ' + cx + ')"';
    return '<svg width="' + size + '" height="' + size + '" aria-hidden="true"><circle ' + common + ' stroke="var(--track)" stroke-dasharray="' + span + ' ' + L + '"/>' +
      '<circle ' + common + ' stroke="' + color + '" stroke-dasharray="' + (span * clamp(progress, 0.01, 1)) + ' ' + L + '"/></svg>';
  }

  // ---------------------------------------------------------------- state
  var state = {
    tab: ['today', 'live', 'body', 'trends', 'coach'].indexOf(Q.get('tab')) >= 0 ? Q.get('tab') : 'today',
    coachOn: Q.get('coach') !== 'off',
    range: ['live', '1h', '24h', '7d', '30d'].indexOf(Q.get('range')) >= 0 ? Q.get('range') : 'live',
    panel: ['heart', 'lungs', 'sleep', 'activity'].indexOf(Q.get('panel')) >= 0 ? Q.get('panel') : 'heart',
    sheet: Q.get('open') || null,
    tags: { 'Late caffeine': false, 'Alcohol': false, 'Late meal': true, 'Stretching': false, 'Travel': false, 'Sauna': false },
    notif: { morning: true, drift: true, strain: false }
  };
  var orbs = null;

  // Live stream: 40 samples 3 s apart, then one more every 3 s.
  var live = [], liveIdx = 0, t0 = Date.now();
  for (; liveIdx < 40; liveIdx++) live.push({ t: t0 - (39 - liveIdx) * 3000 - 2000, bpm: D.liveSample(liveIdx) });

  // ---------------------------------------------------------------- shared pieces
  function topbar(title, sub, right) {
    return '<div class="topbar"><button class="rbtn press" data-sheet="menu" aria-label="Menu and results guide">' + I.menu + '</button>' +
      '<div class="mid"><p class="headline">' + esc(title) + '</p>' + (sub ? '<p class="caption ink" style="opacity:.72">' + esc(sub) + '</p>' : '') + '</div>' +
      (right || '<span></span>') + '</div>';
  }
  function footer(extra) {
    return '<div class="foot">' + (extra ? '<p class="caption">' + esc(extra) + '</p>' : '') +
      '<p class="caption">Wellness estimates, not medical advice.</p><p class="caption">Sample data. Not a real person.</p></div>';
  }
  function tabs() {
    var list = [['today', 'Today'], ['live', 'Live'], ['body', 'Body'], ['trends', 'Trends']];
    if (state.coachOn) list.push(['coach', 'Coach']);
    return '<nav class="tabs" aria-label="Tabs" style="grid-template-columns:repeat(' + list.length + ',1fr)">' + list.map(function (t) {
      var on = state.tab === t[0], ic = t[0] === 'coach' ? CO.tabIcon(on) : I[t[0]];
      return '<button class="tab' + (on ? ' on' : '') + '" data-tab="' + t[0] + '"' + (on ? ' aria-current="page"' : '') + '><span class="ic">' + ic + '</span>' + t[1] + '</button>';
    }).join('') + '</nav>';
  }
  // Coach entry points vanish when the coach is switched off (v1.0 exactly).
  function cmSlot(topic) { return state.coachOn ? CO.slot(topic) : ''; }
  function cmWrap(html, topic, cls) { return state.coachOn ? CO.wrap(html, topic, cls) : html; }
  function cmAbs(topic, style) { return state.coachOn ? CO.mark(topic, style) : ''; }
  function cmAsk(topic) { return state.coachOn ? CO.askRow(topic) : ''; }
  function cv(name, arg, cls, label) { return '<canvas class="c ' + (cls || '') + '" data-draw="' + name + '"' + (arg != null ? ' data-arg="' + esc(arg) + '"' : '') + ' role="img" aria-label="' + esc(label || '') + '"></canvas>'; }

  // ================================================================ TODAY
  function viewToday() {
    var d = D.today;
    var greet = { morning: 'Good morning', afternoon: 'Good afternoon', evening: 'Good evening' }[partOfDay];
    var week = last7.map(function (h) {
      var date = new Date(d.getTime() - h.d * DAY), on = h.d === 0;
      return '<div class="wd' + (on ? ' on' : '') + '"><span class="micro">' + dayLetter(date) + '</span><span class="dc">' +
        tickRing(36, h.recovery / 100, 'var(--' + tierOf(h.recovery) + ')', { ticks: 24, tw: 1.5, tl: 4 }) + '<b>' + date.getDate() + '</b></span></div>';
    }).join('');
    var fresh = D.syncedMinAgo >= 180 ? 'limit' : 'plain';
    var st = D.stress, hourLevel = st.map(function (x) { return x.level; });
    var pf = PANELS.map(function (p) { return { id: p[0], name: p[1], f: panelFlag(p[0]) }; });
    var watchN = pf.reduce(function (s, p) { return s + p.f.watch; }, 0);
    var drift = ['restingHR', 'sleepingHR', 'breathing', 'spo2'].filter(function (id) { return stats(id).flag !== 'good'; });
    var night = D.lastNight;
    var stageMin = { deep: night.deep, light: night.light, rem: night.rem, awake: night.awake };
    var nights7 = D.nights.slice(-7);
    var debt = nights7.reduce(function (s, n) { return s + Math.max(0, 480 - n.asleep); }, 0);
    var beds = nights7.map(function (n) { var b = new Date(n.start); var m = b.getHours() * 60 + b.getMinutes(); return m < 12 * 60 ? m + 1440 : m; });
    var consist = Math.round(sdev(beds));
    var monitorRows = [['restingHR', 'Resting HR'], ['sleepingHR', 'HR asleep'], ['breathing', 'Breathing'], ['spo2', 'Blood oxygen'], ['hrv', 'HRV'], ['skinTemp', 'Skin temp']];
    var heat = '<span></span>' + last7.map(function (h) { return '<span class="micro hd">' + dayLetter(new Date(d.getTime() - h.d * DAY)) + '</span>'; }).join('') +
      monitorRows.map(function (r) {
        var m = M[r[0]];
        return '<span class="label nm">' + r[1] + (m.notSent ? ' <span class="caption">not sent</span>' : '') + '</span>' + last7.map(function (h) {
          if (m.notSent) return '<i class="ns"></i>';
          var s = stats(r[0]), val = m.s[m.s.length - 1 - h.d].value, f = s.nightFlag(val);
          return '<i style="background:var(--' + f + ')' + (f === 'good' ? ';opacity:.55' : '') + '" title="' + esc(fmtV(r[0], val)) + '"></i>';
        }).join('');
      }).join('');
    var wkRec = Math.round(mean(last7.map(function (h) { return h.recovery; })));
    var wkSleep = mean(nights7.map(function (n) { return n.asleep; }));
    var rhr = stats('restingHR');
    var rhrOld = mean(rhr.vals.slice(-14, -7)), rhrNew = mean(rhr.vals.slice(-7));

    return '<div class="screen"><div class="hdr" id="hdr"><canvas class="orbs" id="orbs" aria-hidden="true"></canvas>' +
      topbar(greet, WD[d.getDay()] + ' ' + d.getDate() + ' ' + MO[d.getMonth()], '<button class="rbtn press" data-sheet="journal" aria-label="Add journal tags">' + I.plus + '</button>') +
      '<div class="chips"><span class="chip plain">Sample data</span></div>' +
      '<p class="title verdict">' + esc(verdict) + '</p>' +
      '</div>' +

      // hero rings
      '<div class="card" id="hero">' + cmAbs('recovery', 'top:6px;right:6px') + '<div class="rings" style="grid-template-columns:1fr 1.35fr 1fr">' +
        '<button class="ringcell press" data-sheet="sleep" aria-label="Sleep score ' + S.sleep + '"><span class="ring" style="width:84px;height:84px">' +
          tickRing(84, S.sleep / 100, 'var(--iris)', { tl: 6, animate: ringAnimate }) + '<span class="rv"><b class="headline num">' + S.sleep + '</b></span></span><span class="label">Sleep</span></button>' +
        '<button class="ringcell press" data-sheet="recovery" aria-label="Recovery ' + S.recovery + ' percent, ' + TIER[recFlag] + '"><span class="ring" style="width:128px;height:128px">' +
          tickRing(128, S.recovery / 100, 'var(--' + recFlag + ')', { animate: ringAnimate }) +
          '<span class="rv"><b class="metric">' + S.recovery + '<span class="unit">%</span></b></span></span><span class="label">Recovery</span></button>' +
        '<button class="ringcell press" data-sheet="strain" aria-label="Strain ' + S.strain + ' of 21"><span class="ring" style="width:84px;height:84px">' +
          tickRing(84, S.strain / 21, 'var(--ember)', { tl: 6, animate: ringAnimate }) + '<span class="rv"><b class="headline num">' + S.strain + '</b></span></span><span class="label">Strain</span></button>' +
      '</div>' +
      '<div class="signals">' + chip(recFlag, TIER[recFlag] + ', above your usual') + '<span class="chip ' + fresh + '">Synced ' + D.syncedMinAgo + ' min ago</span></div>' +
      '<p class="caption" style="margin-top:12px">Recovery uses 3 of 4 signals. HRV is not sent by Google Health.</p></div>' +

      // panels strip
      '<div class="card"><div class="row center"><p class="headline">Body panels</p><span class="row center" style="gap:12px"><span class="label">' + (watchN ? watchN + ' to watch' : 'All in range') + '</span>' + cmSlot('panels') + '</span></div><div class="panels">' +
      pf.map(function (p) {
        return '<button class="press" data-goto="' + p.id + '" aria-label="' + p.name + ', ' + TIER[p.f.flag] + '"><span class="cap" style="background:var(--' + p.f.flag + ')"></span><span class="label ink">' + p.name + '</span><span class="caption">' + TIER[p.f.flag] + '</span></button>';
      }).join('') + '</div></div>' +

      // v1.3: pinned mini gauges + Today | Week switch
      '<div class="pin" id="pin"><div class="mini" aria-hidden="true">' +
        [['sleep', S.sleep, S.sleep / 100, 'var(--iris)', 'Sleep', ''], ['recovery', S.recovery, S.recovery / 100, 'var(--' + recFlag + ')', 'Recovery', '%'], ['strain', S.strain, S.strain / 21, 'var(--ember)', 'Strain', '']].map(function (g) {
          return '<button class="press" data-sheet="' + g[0] + '" tabindex="-1"><span class="ring" style="width:32px;height:32px">' + tickRing(32, g[2], g[3], { ticks: 24, tw: 1.5, tl: 4 }) + '</span><span><b class="num">' + g[1] + g[5] + '</b><span class="caption">' + g[4] + '</span></span></button>';
        }).join('') + '</div>' +
      '<div class="seg" role="group" aria-label="Today or week">' + [['today', 'Today'], ['week', 'Week']].map(function (o) {
        return '<button class="press" data-seg="' + o[0] + '" aria-pressed="' + (state.seg === o[0]) + '">' + o[1] + '</button>';
      }).join('') + '</div></div>' +
      (state.seg === 'week' ? '' +
      // day circles (moved down from the header in v1.3)
      '<div class="card"><div class="row"><p class="headline">Recovery by day</p><span class="label">Last 7 days</span></div><div class="week" aria-label="Recovery, last 7 days">' + week + '</div></div>' +
      // weekly report
      '<div class="card"><div class="row"><p class="headline">Weekly report</p><span class="label">Last 7 days</span></div>' +
      '<div class="rings" style="grid-template-columns:repeat(3,1fr);margin-top:16px;align-items:start">' +
      '<div class="gap4"><b class="metric" style="font-size:28px">' + wkRec + '<span class="unit">%</span></b><p class="caption">Recovery</p></div>' +
      '<div class="gap4"><b class="metric" style="font-size:28px">' + (wkSleep / 60).toFixed(1) + '<span class="unit">h</span></b><p class="caption">Sleep a night</p></div>' +
      '<div class="gap4"><b class="metric" style="font-size:28px">' + (mean(last7.map(function (h) { return h.steps; })) / 1000).toFixed(1) + '<span class="unit">k</span></b><p class="caption">Steps a day</p></div></div>' +
      '<p class="body" style="margin-top:16px">Resting heart rate ' + (rhrNew < rhrOld ? 'eased' : 'rose') + ' ' + Math.abs(rhrNew - rhrOld).toFixed(1) + ' bpm against the week before.</p></div>' +

      // sleep balance
      '<div class="card">' + cmAbs('metric:sleepTotal', 'top:6px;right:6px') + '<div class="rings" style="grid-template-columns:1fr 1fr;align-items:start;gap:16px">' +
      '<div class="gap4"><p class="label">Sleep debt</p><p><b class="metric" style="font-size:28px">' + hm(debt).replace(/ (h|min) ?/g, '<span class="unit">$1</span> ') + '</b></p><p class="caption">Last 7 nights against 8 h</p></div>' +
      '<div class="gap4"><p class="label">Bedtime consistency</p><p><b class="metric" style="font-size:28px">±' + consist + '<span class="unit">min</span></b></p><p class="caption">' + (consist <= 45 ? 'Steady. Under ±45 min helps.' : 'Varies a lot. Under ±45 min helps.') + '</p></div></div></div>' +

      // this week
      '<div class="card"><div class="row"><p class="headline">This week</p><span class="label">Recovery, strain, sleep</span></div><div class="days">' +
      last7.map(function (h) {
        var date = new Date(d.getTime() - h.d * DAY);
        return '<div class="d' + (h.d === 0 ? ' on' : '') + '"><span class="micro">' + dayLetter(date) + '</span><span class="ring" style="width:36px;height:36px">' +
          tickRing(36, h.recovery / 100, 'var(--' + tierOf(h.recovery) + ')', { ticks: 24, tw: 1.5, tl: 4 }) + '<span class="rv"><b class="micro ink num">' + h.recovery + '</b></span></span>' +
          '<span class="num">' + h.strain.toFixed(1) + '</span><span class="num">' + (h.sleep / 60).toFixed(1) + ' h</span></div>';
      }).join('') + '</div></div>' +

      '' : '' +
      // coach note (rule-based, no model)
      (state.coachOn ? CO.note() : '') +

      // strain target
      cmWrap('<button class="card tap" data-sheet="strain"><div class="row"><p class="headline">Strain target</p><span class="label"><b class="ink num">' + S.strain + '</b> of ' + D.strainTarget[0] + '–' + D.strainTarget[1] + '</span></div>' +
      '<div style="margin-top:16px">' + cv('capsule', null, '', 'Strain ' + S.strain + ' of 21, target 12 to 15').replace('class="c ', 'style="height:22px" class="c ') + '</div>' +
      '<div class="row" style="margin-top:4px"><span class="caption num">0</span><span class="caption">Target ' + D.strainTarget[0] + '–' + D.strainTarget[1] + '</span><span class="caption num">21</span></div>' +
      '<p class="body" style="margin-top:12px">About 30 minutes of brisk walking reaches the low end of your target.</p></button>', 'strain') +

      // last night
      cmWrap('<button class="card tap" data-sheet="sleep"><div class="row"><p class="headline">Last night</p><span class="val">' + valHTML('sleepTotal', night.asleep, 'headline num') + '</span></div>' +
      '<div class="stagebar" aria-hidden="true">' + night.segments.map(function (sg) {
        var col = { deep: 'var(--stageDeep)', light: 'var(--stageCore)', rem: 'var(--stageREM)', awake: 'var(--stageAwake)' }[sg.stage];
        return '<span style="flex:' + ((sg.end - sg.start) / 6e4).toFixed(1) + ';background:' + col + '"></span>';
      }).join('') + '</div>' +
      '<div class="row" style="margin-top:4px"><span class="caption num">' + hhmm(night.start) + '</span><span class="caption num">' + hhmm(night.end) + '</span></div>' +
      '<div class="legend">' + [['deep', 'Deep', 'stageDeep'], ['light', 'Core', 'stageCore'], ['rem', 'REM', 'stageREM'], ['awake', 'Awake', 'stageAwake']].map(function (s) {
        return '<span class="caption"><i style="background:var(--' + s[2] + ')"></i>' + s[1] + ' <b class="ink num" style="font-weight:500">' + hm(stageMin[s[0]]) + '</b></span>';
      }).join('') + '</div></button>', 'sleep') +

      // stress
      '<div class="card"><div class="row center"><p class="headline">Stress today</p><span class="row center" style="gap:12px"><span class="label">Mostly low</span>' + cmSlot('stress') + '</span></div>' +
      cv('stress', null, '', 'Hourly stress today. High from 9 to 11, moving at noon, low otherwise.').replace('class="c ', 'style="height:72px;margin-top:16px" class="c ') +
      '<div class="row" style="margin-top:4px"><span class="caption num">00</span><span class="caption num">06</span><span class="caption num">12</span><span class="caption num">18</span><span class="caption num">24</span></div>' +
      '<div class="legend"><span class="caption"><i style="background:var(--good)"></i>Low</span><span class="caption"><i style="background:var(--limit)"></i>Raised</span><span class="caption"><i style="background:var(--danger)"></i>High</span><span class="caption"><i style="background:var(--graphite2)"></i>Moving</span></div></div>' +

      // drift banner
      (drift.length ? '<button class="card tap" data-sheet="metric:' + drift[0] + '"><div class="banner"><span class="bar" style="background:var(--' + stats(drift[0]).flag + ')"></span><div class="gap4">' +
        '<p class="headline">' + (drift.length > 1 ? drift.length + ' signals are outside your usual range' : M[drift[0]].label + ' is ' + stats(drift[0]).dirWord.replace('your usual', 'your usual range')) + '</p>' +
        '<p class="body">' + esc(fmtV(drift[0], stats(drift[0]).v) + ' ' + M[drift[0]].unit) + ' last night. ' + esc(usual(drift[0])) + '. Everything else is in range.</p>' +
        '<p class="caption">One night rarely means much. Rest if you feel run down.</p></div></div></button>' : '') +

      // health monitor
      (drift.length || state.monitorOpen ? '' : '<button class="card tap" data-monitor="1" aria-expanded="false"><div class="row center"><p class="headline">Health monitor</p><span class="label">All vitals in your usual range ›</span></div></button>') +
      (drift.length || state.monitorOpen ? '<div class="card">' + cmAbs('monitor', 'top:9px;right:6px') + '<p class="headline">Health monitor</p><p class="caption">Last 7 nights against your usual range</p><div class="heat">' + heat + '</div>' +
      '<div class="legend"><span class="caption"><i style="background:var(--good);opacity:.55"></i>In range</span><span class="caption"><i style="background:var(--limit)"></i>Watch</span><span class="caption"><i style="background:var(--danger)"></i>Out of range</span></div></div>' : '') +
      // journal discoveries
      '<button class="card tap" data-sheet="journal"><div class="row"><p class="headline">What your tags show</p><span class="label">11 tagged days</span></div>' +
      '<p class="body" style="margin-top:8px">On days you tagged late caffeine, your sleep score averaged 9 points lower.</p>' +
      '<p class="caption" style="margin-top:8px">Tap + to tag today.</p></button>' +

      '') +
      footer() + '</div>';
  }

  // ================================================================ LIVE
  function viewLive() {
    var lv = live[live.length - 1];
    var sp = D.stress[D.stress.length - 1].level, spFlag = sp < 1 ? 'good' : sp < 2 ? 'limit' : 'danger';
    return '<div class="screen"><div class="hdr" id="hdr"><canvas class="orbs" id="orbs" aria-hidden="true"></canvas>' +
      topbar('Live', 'Heart rate', '<button class="rbtn press" data-sheet="menu" aria-label="Results guide">' + I.info + '</button>') +
      '<div class="livehead"><div class="row"><span class="display" id="hrNow">' + Math.round(lv.bpm) + '</span><span class="unit" style="font-size:15px">bpm</span></div>' +
      '<div class="ticker mono" aria-live="off"><i></i><span id="tick">latest sample 2 s ago</span></div>' +
      '<div class="chips"><span class="chip plain">Resting zone</span><span class="chip plain">Sample data</span></div></div></div>' +
      '<div class="card" id="liveCard">' + liveCard() + '</div>' +

      '<div class="card"><div class="row"><p class="headline">So far today</p><span class="label">Updates as it syncs</span></div>' +
      '<div style="margin-top:16px"><div class="row"><span class="label ink">Strain</span><span class="label"><b class="ink num">' + S.strain + '</b> of ' + D.strainTarget[0] + '–' + D.strainTarget[1] + '</span></div>' +
      cv('capsule', null, '', 'Strain ' + S.strain).replace('class="c ', 'style="height:22px;margin-top:8px" class="c ') + '</div>' +
      '<div class="arcs">' +
      '<button class="press" data-sheet="metric:steps"><span class="ring" style="width:72px;height:72px">' + arc(72, (D.data.steps[30].value) / 10000, 'var(--ink)') + '<span class="rv"><b class="label ink num">' + (D.data.steps[30].value / 1000).toFixed(1) + 'k</b></span></span><span class="caption">Steps</span></button>' +
      '<button class="press" data-sheet="metric:energy"><span class="ring" style="width:72px;height:72px">' + arc(72, D.activeEnergy / 700, 'var(--ember)') + '<span class="rv"><b class="label ink num">' + D.activeEnergy + '</b></span></span><span class="caption">Active kcal</span></button>' +
      '<div><span class="ring" style="width:72px;height:72px">' + arc(72, sp / 3, 'var(--' + spFlag + ')') + '<span class="rv"><b class="label ink">' + (spFlag === 'good' ? 'Low' : spFlag === 'limit' ? 'Raised' : 'High') + '</b></span></span><span class="caption">Stress now</span></div>' +
      '</div></div>' +

      '<div class="card"><div class="row"><p class="headline">Last night</p><span class="label">' + hhmm(D.lastNight.start) + '–' + hhmm(D.lastNight.end) + '</span></div>' +
      ['breathing', 'spo2'].map(function (id) {
        var st = stats(id);
        return cmWrap('<button class="mrow" data-sheet="metric:' + id + '"><div class="top"><div><p class="body">' + M[id].label + '</p><p class="caption">' + esc(usual(id)) + '</p></div>' +
          '<div class="gap4" style="text-align:right"><span class="val">' + valHTML(id, st.v) + '</span><div>' + chip(st.flag) + '</div></div></div><div style="margin-top:12px">' + ribbon(id) + '</div></button>', 'metric:' + id, 'r');
      }).join('') + '</div>' +
      footer('Readings arrive in batches from Google Health. Fitbit Air has no blood-pressure sensor.') + '</div>';
  }
  function rangeData() {
    var r = state.range;
    if (r === 'live') return live.map(function (p) { return { x: p.t, y: p.bpm }; });
    if (r === '1h') return D.hr1h.map(function (p) { return { x: +p.t, y: p.bpm }; });
    if (r === '24h') return D.hr24.map(function (p) { return { x: +p.t, y: p.bpm }; });
    var days = r === '7d' ? 7 : 30;
    return D.dailyHR.slice(-days).map(function (p) { return { x: +p.date, y: p.avg, min: p.min, max: p.max }; });
  }
  function liveCard() {
    var vals = rangeData(), r = state.range, ys = vals.map(function (v) { return v.y; });
    var daily = r === '7d' || r === '30d';
    var mn = Math.round(daily ? Math.min.apply(null, vals.map(function (v) { return v.min; })) : Math.min.apply(null, ys));
    var mx = Math.round(daily ? Math.max.apply(null, vals.map(function (v) { return v.max; })) : Math.max.apply(null, ys));
    var note = { live: 'Last 2 minutes. A new sample every 3 s in this demo.', '1h': 'Last hour, one reading a minute.', '24h': 'Shaded: asleep.', '7d': 'Daily average. Band: your usual.', '30d': 'Daily average. Band: your usual.' }[r];
    return '<div class="seg" role="group" aria-label="Range" style="margin-top:0">' + [['live', 'Live'], ['1h', '1H'], ['24h', '24H'], ['7d', '7D'], ['30d', '30D']].map(function (o) {
      return '<button data-range="' + o[0] + '" aria-pressed="' + (r === o[0]) + '">' + o[1] + '</button>';
    }).join('') + '</div>' +
      '<div class="chartwrap">' + cv('live', null, '', 'Heart rate chart, ' + r + ', min ' + mn + ', max ' + mx + ' bpm').replace('class="c ', 'style="height:184px" class="c ') + '<span class="ripple" id="ripple"></span></div>' +
      '<div class="row center" style="margin-top:8px;min-height:16px"><p class="caption">' + note + '</p>' + cmSlot('live') + '</div>' +
      '<div class="mam"><div><b>' + mn + '</b><span class="caption">Min</span></div><div><b>' + Math.round(mean(ys)) + '</b><span class="caption">Average</span></div><div><b>' + mx + '</b><span class="caption">Max</span></div></div>';
  }

  // ================================================================ BODY
  function viewBody() {
    var total = Object.keys(M).length, sent = Object.keys(M).filter(function (id) { return !M[id].notSent; }).length;
    return '<div class="screen"><div class="hdr">' + topbar('Body', '4 panels, ' + total + ' results') +
      '<div class="seg" role="group" aria-label="Panel">' + PANELS.map(function (p) {
        return '<button data-panel="' + p[0] + '" aria-pressed="' + (state.panel === p[0]) + '">' + p[1] + '</button>';
      }).join('') + '</div></div><div id="bodyPanel">' + bodyPanel() + '</div>' +
      footer(sent + ' of ' + total + ' results arrive from Google Health. The rest are not sent yet.') + '</div>';
  }
  // v1.2: home-cuff blood pressure (sample) + metabolic health signals (lifestyle only, never a glucose number).
  var BP = (function () {
    var v = [[118, 76], [124, 79], [121, 77], [126, 81], [119, 75], [123, 78], [122, 77], [127, 80], [120, 76], [124, 78], [121, 77], [125, 79]];
    var now = new Date(), out = v.map(function (x, i) {
      var d = new Date(now.getFullYear(), now.getMonth(), now.getDate() - (v.length - 1 - i) * 2, 7, 30);
      return { d: d, sys: x[0], dia: x[1] };
    });
    return out;
  })();
  function bpBand(s, d) {
    if (s >= 180 || d >= 120) return ['danger', 'Very high'];
    if (s >= 130 || d >= 80) return ['danger', 'High'];
    if (s >= 120) return ['limit', 'Elevated'];
    return ['good', 'Normal'];
  }
  function bpSummary() {
    var last = BP[BP.length - 1], cut = Date.now() - 30 * 864e5, w = BP.filter(function (r) { return r.d.getTime() >= cut; });
    var as = mean(w.map(function (r) { return r.sys; })), ad = mean(w.map(function (r) { return r.dia; }));
    return { last: last, avg: Math.round(as) + '/' + Math.round(ad), n: w.length, band: bpBand(as, ad) };
  }
  function dayFmt(d) { return d.toLocaleDateString('en-GB', { weekday: 'short', day: 'numeric', month: 'short' }); }
  function bpRow() {
    var b = bpSummary();
    return '<button class="mrow" data-sheet="bp"><div class="top"><div><p class="body">Blood pressure</p><p class="caption">30-day average ' + b.avg + ' · ' + b.n + ' readings</p></div>' +
      '<div class="gap4" style="text-align:right"><span class="val"><b class="metric">' + b.last.sys + '/' + b.last.dia + '</b><span class="unit">mmHg</span></span><div>' + chip(b.band[0], b.band[1]) + '</div></div></div>' +
      '<p class="caption" style="margin-top:8px">Latest ' + dayFmt(b.last.d) + ' · Home cuff (sample data). Measured by your cuff, not the Fitbit Air.</p></button>';
  }
  function metabolicCard() {
    var st = M.steps.s.slice(-7).map(function (p) { return p.value; }), steps = mean(st);
    var ex = stats('workoutMinutes').v;
    var sl = mean(M.sleepTotal.s.slice(-7).map(function (p) { return p.value; }));
    var spread = 41;
    var rh = M.restingHR.s.map(function (p) { return p.value; }), rNew = mean(rh.slice(-7)), rOld = mean(rh.slice(0, -7)), diff = rNew - rOld;
    var sig = [
      ['Daily steps', n0(steps) + ' a day', '7 000+', steps >= 7000, 'Walking after meals helps your muscles use sugar.'],
      ['Exercise', n0(ex) + ' min this week', '150+ min', ex >= 150, 'Regular exercise is the strongest habit for insulin sensitivity.'],
      ['Sleep length', hm(sl) + ' a night', '7 h+', sl >= 420, 'Short nights make the body handle sugar less well the next day.'],
      ['Bedtime regularity', '±' + spread + ' min', '±45 min or less', spread <= 45, 'A steady body clock keeps your metabolism in rhythm.'],
      ['Resting heart rate trend', Math.round(rNew) + ' bpm · ' + (Math.abs(diff) < 1 ? 'steady' : (diff > 0 ? '+' : '−') + Math.round(Math.abs(diff)) + ' bpm'), 'Steady or falling', diff < 2, 'A resting heart rate that creeps up often follows less fitness or sleep.']
    ];
    var good = sig.filter(function (x) { return x[3]; }).length;
    return '<div class="card" style="margin-top:16px"><div class="row center"><p class="headline">Metabolic health signals</p><span class="label">' + good + ' of ' + sig.length + ' on track</span></div>' +
      '<p class="caption" style="margin-top:4px">Habits research links to insulin sensitivity. Not a blood-sugar or insulin measurement.</p>' +
      sig.map(function (x) {
        return '<details class="mrow" style="display:block"><summary style="list-style:none;cursor:pointer"><div class="top" style="align-items:center"><p class="body"><i style="display:inline-block;width:7px;height:7px;border-radius:50%;margin-right:8px;vertical-align:middle;background:var(--' + (x[3] ? 'good' : 'limit') + ')"></i>' + x[0] + '</p>' +
          '<span class="label" style="color:var(--ink)">' + esc(x[1]) + '</span></div><p class="caption" style="margin-left:15px">Goal ' + esc(x[2]) + '</p></summary>' +
          '<p class="caption" style="margin:4px 0 0 15px">' + esc(x[4]) + '</p></details>';
      }).join('') + '</div>';
  }
  function bodyPanel() {
    var p = state.panel, name = PANELS.filter(function (x) { return x[0] === p; })[0][1], pf = panelFlag(p);
    var rows = Object.keys(M).filter(function (id) { return M[id].panel === p; }).map(function (id) {
      var m = M[id];
      if (m.notSent) {
        var ns = '<button class="mrow" data-sheet="metric:' + id + '"><div class="top"><div><p class="body">' + m.label + '</p><p class="caption">' + esc(m.short || '') + '</p></div>' + nsChip() + '</div>' +
          '<p class="caption" style="margin-top:8px">Google Health does not send this to Apple Health yet.</p></button>';
        return state.coachOn ? '<div class="cmw r nm">' + ns + '</div>' : ns;
      }
      var st = stats(id);
      return cmWrap('<button class="mrow" data-sheet="metric:' + id + '"><div class="top"><div><p class="body">' + m.label + '</p><p class="caption">' + esc(usual(id)) + '</p></div>' +
        '<div class="gap4" style="text-align:right"><span class="val">' + valHTML(id, st.v) + '</span><div>' + chip(st.flag) + '</div></div></div>' +
        '<div class="bot">' + (m.vital || m.dir === 'lower' && m.unit === 'bpm' ? cv('strip', id, 'strip', 'Range strip') : ribbon(id)) + cv('spark', id, 'spark', '7-day trend') + '</div></button>', 'metric:' + id, 'r');
    }).join('');
    if (p === 'heart') rows += bpRow();
    return '<div class="card"><div class="row center"><p class="headline">' + name + '</p>' + (pf.watch ? chip(pf.flag, pf.watch + ' to watch') : chip('good', 'All in range')) + '</div>' + rows + '</div>' + metabolicCard();
  }

  // ================================================================ TRENDS
  var trendIds = ['restingHR', 'sleepingHR', 'breathing', 'spo2', 'steps', 'energy', 'sleepTotal', 'deepSleep'];
  function trendOf(id) {
    var v = M[id].s.map(function (p) { return p.value; }), k = v.length;
    var oldA = v.slice(0, k - 7), newA = v.slice(k - 7), o = mean(oldA), n = mean(newA);
    var rel = (n - o) / Math.max(sdev(oldA), M[id].minSd || 0);
    return { id: id, old: o, nu: n, rel: rel, vals: v };
  }
  function viewTrends() {
    var all = trendIds.map(trendOf).sort(function (a, b) { return Math.abs(b.rel) - Math.abs(a.rel); });
    var changed = all.filter(function (t) { return Math.abs(t.rel) >= 0.5; });
    if (changed.length < 2) changed = all.slice(0, 2);
    var rest = all.filter(function (t) { return changed.indexOf(t) < 0; });
    function sentence(t) {
      var m = M[t.id], up = t.nu > t.old, nm = m.label.toLowerCase().replace('rem', 'REM');
      var word = { restingHR: up ? 'higher' : 'lower', sleepingHR: up ? 'higher' : 'lower', breathing: up ? 'higher' : 'lower', spo2: up ? 'higher' : 'lower', steps: up ? 'up' : 'down', energy: up ? 'up' : 'down' }[t.id] || (up ? 'longer' : 'shorter');
      return 'Your ' + nm + ' is ' + word;
    }
    var bage = D.bodyAge;
    return '<div class="screen"><div class="hdr">' + topbar('Trends', 'Last 7 days against the 3 weeks before') + '</div>' +
      '<div class="section" style="margin-top:20px"><p class="label">Changed</p>' +
      changed.map(function (t) {
        var m = M[t.id];
        return cmWrap('<button class="card tap" data-sheet="metric:' + t.id + '"><p class="headline">' + esc(sentence(t)) + '</p>' +
          '<p class="caption" style="margin-top:4px">Last 7 days averaged ' + esc(fmtV(t.id, t.nu)) + (m.unit && m.fmt !== hm ? ' ' + m.unit : '') + ', ' + (t.nu > t.old ? 'up' : 'down') + ' from ' + esc(fmtV(t.id, t.old)) + '.</p>' +
          cv('trend', t.id, 'tchart', 'Daily values, last ' + t.vals.length + ' days') +
          '<div class="tkey"><span class="caption"><i style="border-color:var(--graphite);border-top-style:dashed"></i>Before</span><span class="caption"><i style="border-color:var(--ember)"></i>Last 7 days</span></div></button>', 'metric:' + t.id);
      }).join('') + '</div>' +
      '<div class="section"><p class="label">All metrics</p><div class="card" style="padding-top:4px;padding-bottom:4px">' +
      rest.map(function (t) {
        return '<button class="mrow" data-sheet="metric:' + t.id + '"><div class="top" style="align-items:center"><div><p class="body">' + M[t.id].label + '</p><p class="caption">No clear change</p></div>' +
          '<span class="val">' + valHTML(t.id, t.nu) + '</span></div></button>';
      }).join('') + '</div></div>' +
      '<div class="section"><p class="label">Fitness age</p><div class="card"><div class="row"><p class="headline">Body age</p><span class="val"><b class="metric">' + bage.estimate.toFixed(1) + '</b><span class="unit">years</span></span></div>' +
      '<p class="caption" style="margin-top:4px">A rough fitness estimate against your age of ' + bage.age + '. Left of the line makes you younger.</p>' +
      bage.factors.map(function (f) {
        var v = f[1], w = Math.min(50, Math.abs(v) / 1.0 * 50);
        return '<div class="factor"><span class="label ink">' + esc(f[0]) + '</span><span class="zbar"><span style="' + (v < 0 ? 'right:50%' : 'left:50%') + ';width:' + w + '%;background:var(--' + (v < 0 ? 'good' : 'limit') + ')"></span></span>' +
          '<span class="label num" style="text-align:right">' + (v > 0 ? '+' : '−') + Math.abs(v).toFixed(1) + '</span></div>';
      }).join('') + '</div></div>' + footer() + '</div>';
  }

  // ================================================================ SHEETS
  function sheetHTML(key) {
    var title = '', sub = '', body = '';
    if (key === 'menu') {
      title = 'Menu';
      body = '<div class="section" style="margin-top:8px"><p class="label">Results guide</p><div class="card"><dl class="guide" style="margin:0">' +
        '<dt style="margin-top:0">' + chip('good') + '</dt><dd class="body">Inside your usual range, built from your own last 30 days.</dd>' +
        '<dt>' + chip('limit') + '</dt><dd class="body">A little outside your usual range. Worth a look if it repeats.</dd>' +
        '<dt>' + chip('danger') + '</dt><dd class="body">Well outside your usual range. One night rarely means much; rest and see if it settles.</dd>' +
        '<dt>' + nsChip() + '</dt><dd class="body">Google Health does not send HRV, skin temperature or VO2 max to Apple Health yet. These show as not sent, never as zero.</dd>' +
        '<dt>Waiting for sync</dt><dd class="body">Readings arrive in batches, minutes to hours late. The sync time is always shown.</dd>' +
        '<dt>Early read</dt><dd class="body">Ranges need about 14 days. Before that, results say “Early read: 6 of 14 baseline days.”</dd></dl></div></div>' +
        '<div class="section"><p class="label">Scores</p><div class="card stack">' +
        '<p class="body"><b>Recovery</b> compares resting heart rate, sleep and breathing with your usual. 67 and up is green, 34 to 66 yellow.</p>' +
        '<p class="body"><b>Strain</b> is all-day heart-rate load on a 0 to 21 scale. Your target follows your recovery.</p>' +
        '<p class="body"><b>Sleep</b> scores duration against need, deep and REM share, and time awake.</p></div></div>' +
        '<div class="section"><p class="label">Data sources</p><div class="flow">' +
        '<div><span class="body">Fitbit Air</span><span class="caption">Heart rate, motion, SpO2</span></div>' +
        '<div><span class="body">Google Health app</span><span class="caption">Writes to Apple Health</span></div>' +
        '<div><span class="body">Apple Health</span><span class="caption">Read-only access</span></div>' +
        '<div><span class="body">MRH1</span><span class="caption">Scores on your iPhone</span></div></div>' +
        '<p class="caption" style="margin:8px 4px 0">No servers, no account, no analytics. Nothing leaves the phone.</p></div>' +
        '<div class="section"><p class="label">Coach</p><div class="card" style="padding-top:8px;padding-bottom:8px">' +
        '<button class="toggle" role="switch" aria-checked="' + state.coachOn + '" data-coachtoggle="1"><span class="body">Coach</span><span class="sw"></span></button></div>' +
        '<p class="caption" style="margin:8px 4px 0">On the iPhone the coach runs on this device with Apple Intelligence: free, private, no internet. Off brings back v1.0: no Coach tab, notes or marks. In this demo the answers are scripted.</p></div>' +
        '<div class="section"><p class="label">Notifications</p><div class="card" style="padding-top:8px;padding-bottom:8px">' +
        [['morning', 'Morning recovery'], ['drift', 'Signals outside your usual range'], ['strain', 'Strain target reached']].map(function (n) {
          return '<button class="toggle" role="switch" aria-checked="' + state.notif[n[0]] + '" data-notif="' + n[0] + '"><span class="body">' + n[1] + '</span><span class="sw"></span></button>';
        }).join('') + '</div><p class="caption" style="margin:8px 4px 0">Made on the device. In this demo the switches do nothing.</p></div>' +
        '<div class="section"><p class="label">About</p><div class="card stack"><p class="body">MRH1 gives wellness estimates from a wrist sensor. It is not a medical device and does not diagnose anything. See a doctor about any symptoms.</p>' +
        '<p class="caption">Works with Fitbit Air via Google Health and Apple Health. Not affiliated with Google. Fitbit and Fitbit Air are trademarks of Google LLC.</p>' +
        '<p class="caption">This demo runs on synthetic sample data.</p></div></div>';
    } else if (key === 'journal') {
      title = 'Journal'; sub = 'Tags for today';
      body = '<p class="body" style="margin-top:12px">Tag what happened today. After a few weeks, MRH1 shows which tags line up with better or worse nights.</p>' +
        '<div class="tags">' + Object.keys(state.tags).map(function (t) { return '<button class="tag press" data-tag="' + esc(t) + '" aria-pressed="' + state.tags[t] + '">' + esc(t) + '</button>'; }).join('') + '</div>' +
        '<div class="card"><p class="headline">What your tags show</p><p class="body" style="margin-top:8px">On days you tagged late caffeine, your sleep score averaged 9 points lower.</p><p class="body" style="margin-top:8px">Stretching days come with 6 minutes more deep sleep.</p><p class="caption" style="margin-top:8px">Based on 11 tagged days. Stored only on this device.</p></div>';
    } else if (key === 'recovery') {
      title = 'Recovery'; sub = WD[D.today.getDay()] + ' ' + D.today.getDate() + ' ' + MO[D.today.getMonth()];
      var contrib = [['Resting HR', 40, -(stats('restingHR').v - stats('restingHR').mu) / stats('restingHR').sd, (stats('restingHR').v - stats('restingHR').mu).toFixed(1).replace('-', '−') + ' bpm'],
        ['Sleep', 35, (stats('sleepTotal').v - stats('sleepTotal').mu) / stats('sleepTotal').sd + 0.6, hm(stats('sleepTotal').v)],
        ['Breathing', 25, -Math.abs(stats('breathing').v - stats('breathing').mu) / stats('breathing').sd, '+' + (stats('breathing').v - stats('breathing').mu).toFixed(1)],
        ['HRV', 0, null, 'not sent']];
      body = '<div class="card"><div class="row"><span class="val"><b class="display" style="font-size:56px">' + S.recovery + '</b><span class="unit">%</span></span>' + chip(recFlag, TIER[recFlag] + ', above your usual') + '</div>' +
        '<p class="body" style="margin-top:12px">Your heart settled early last night. A good day to push.</p></div>' +
        '<div class="card"><div class="row"><p class="headline">What drove it</p><span class="caption">Against your 30-day usual</span></div>' +
        contrib.map(function (c) {
          var z = c[2]; var w = z == null ? 0 : Math.min(50, Math.abs(z) / 3 * 50);
          return '<div class="factor" style="grid-template-columns:minmax(0,1fr) 110px 64px"><span class="label ink">' + c[0] + ' <span class="caption">' + (c[1] ? c[1] + '%' : '') + '</span></span>' +
            '<span class="zbar">' + (z == null ? '' : '<span style="' + (z >= 0 ? 'left:50%' : 'right:50%') + ';width:' + w + '%;background:var(--' + (z >= 0 ? 'good' : 'limit') + ')"></span>') + '</span>' +
            '<span class="label num" style="text-align:right">' + esc(c[3]) + '</span></div>';
        }).join('') +
        '<p class="caption" style="margin-top:8px">Right of the line helped your score, left pulled it down. Percentages are the weights. HRV is not sent, so its weight moves to the others.</p></div>' +
        '<div class="card"><div class="row"><p class="headline">Last 14 days</p><span class="caption">0–100</span></div>' + cv('rec14', null, '', '14-day recovery').replace('class="c ', 'style="height:140px;margin-top:12px" class="c ') + '</div>' +
        '<div class="card"><p class="headline">How it’s computed</p><p class="body" style="margin-top:8px">Each signal is compared with your own last 30 days and scaled by how much it usually varies. The weighted sum maps to 0–100. 67 and up is green, 34 to 66 yellow, below 34 red.</p></div>' + cmAsk('recovery');
    } else if (key === 'strain') {
      title = 'Strain'; sub = 'Today so far';
      var zn = ['Zone 1', 'Zone 2', 'Zone 3', 'Zone 4', 'Zone 5'], zmax = Math.max.apply(null, D.zones);
      body = '<div class="card"><div class="row"><span class="val"><b class="display">' + S.strain + '</b><span class="unit">of 21</span></span><span class="label">Target ' + D.strainTarget[0] + '–' + D.strainTarget[1] + '</span></div>' +
        cv('capsule', null, '', 'Strain').replace('class="c ', 'style="height:22px;margin-top:16px" class="c ') + '</div>' +
        '<div class="card"><div class="row"><p class="headline">Heart rate today</p><span class="caption">bpm</span></div>' + cv('strainhr', null, '', 'Heart rate from 07:00, run at 12:10').replace('class="c ', 'style="height:168px;margin-top:12px" class="c ') + '</div>' +
        '<div class="card"><p class="headline">Time in zones</p>' + D.zones.map(function (z, i) {
          return '<div class="factor" style="grid-template-columns:64px minmax(0,1fr) 52px"><span class="label">' + zn[i] + '</span><span class="zbar" style="background:var(--track)"><span style="left:0;width:' + (z / zmax * 100) + '%;background:' + C.oklabMix('#F3A79E', '#F0582A', i / 4) + '"></span></span><span class="label num ink" style="text-align:right">' + z + ' min</span></div>';
        }).join('').replace(/zbar"/g, 'zbar nz"') + '<p class="caption" style="margin-top:8px">Run at ' + hhmm(D.workoutsToday[0].start) + ', ' + D.workoutsToday[0].minutes + ' min.</p></div>' + cmAsk('strain');
    } else if (key === 'sleep') {
      var n = D.lastNight;
      title = 'Sleep'; sub = hhmm(n.start) + '–' + hhmm(n.end);
      body = '<div class="card"><div class="row"><span class="val"><b class="display">' + S.sleep + '</b><span class="unit">score</span></span>' + chip('good') + '</div>' +
        '<p class="body" style="margin-top:12px">' + hm(n.asleep) + ' asleep, with deep sleep above your usual.</p></div>' +
        '<div class="card"><p class="headline">Stages</p>' + cv('hypno', null, '', 'Hypnogram of last night').replace('class="c ', 'style="height:132px;margin-top:12px" class="c ') + '</div>' +
        '<div class="card" style="padding-top:4px;padding-bottom:4px">' + ['sleepTotal', 'deepSleep', 'remSleep', 'awake'].map(function (id) {
          var st = stats(id);
          return '<button class="mrow" data-sheet="metric:' + id + '"><div class="top"><div><p class="body">' + M[id].label + '</p><p class="caption">' + esc(usual(id)) + '</p></div><div class="gap4" style="text-align:right"><span class="val">' + valHTML(id, st.v) + '</span><div>' + chip(st.flag) + '</div></div></div></button>';
        }).join('') + '</div>' + cmAsk('sleep');
    } else if (key === 'bp') {
      var b = bpSummary();
      title = 'Blood pressure'; sub = 'From your home cuff';
      body = '<div class="card"><p class="headline">' + b.band[1] + '</p><p class="body" style="margin-top:8px">' +
        ({ Normal: 'Under 120/80, the range guidelines call normal.', Elevated: 'Top number 120–129. Movement, less salt and good sleep help.', High: '130/80 or more on average. Worth discussing with a doctor.', 'Very high': '180/120 or more. Measure again after 5 min of rest. If it stays this high or you feel unwell, get medical help now.' })[b.band[1]] + '</p></div>' +
        '<div class="card"><p class="headline">Last readings</p>' + BP.slice(-10).reverse().map(function (r) {
          var bb = bpBand(r.sys, r.dia);
          return '<div class="row center" style="margin-top:8px"><span class="caption">' + dayFmt(r.d) + '</span><span class="body">' + r.sys + '/' + r.dia + ' mmHg ' + chip(bb[0], bb[1]) + '</span></div>';
        }).join('') + '</div>' +
        '<div class="card"><p class="headline">How to read it</p><p class="body" style="margin-top:8px">Top number (systolic): pressure while your heart beats. Bottom (diastolic): between beats. Under 120/80 normal · 120–129 elevated · 130/80 or more high. One reading swings a lot; the 30-day average matters more.</p>' +
        '<p class="caption" style="margin-top:8px">Sit 5 minutes, feet flat, arm at heart level, same time each day. Wellness information, not medical advice.</p></div>';
    } else if (key.indexOf('metric:') === 0) {
      var id = key.slice(7), m = M[id];
      if (!m) return '';
      title = m.label; sub = m.short || PANELS.filter(function (p) { return p[0] === m.panel; })[0][1];
      if (m.notSent) {
        body = '<div class="card"><div class="row"><b class="metric">—</b>' + nsChip('Not sent by Google Health') + '</div><p class="body" style="margin-top:12px">' + esc(m.what) + '</p></div>' + cmAsk(key);
      } else {
        var st = stats(id);
        body = '<div class="card"><div class="row center"><span class="val">' + valHTML(id, st.v, 'display') + '</span><span>' + chip(st.flag) + '</span></div>' +
          '<p class="caption" style="margin-top:8px">' + esc(usual(id)) + '. Today is ' + st.dirWord + '.</p>' +
          cv('strip', id + '|big', 'strip big', 'Range strip').replace('class="c ', 'style="margin-top:16px" class="c ') + '</div>' +
          '<div class="card"><div class="row"><p class="headline">Last ' + Math.min(14, m.s.length) + ' days</p><span class="caption">Band: your usual</span></div>' + cv('m14', id, '', '14-day chart').replace('class="c ', 'style="height:140px;margin-top:12px" class="c ') + '</div>' +
          '<div class="card stack"><p class="headline">What it is</p><p class="body">' + esc(m.what) + '</p><div class="gap4"><p class="label">If it’s higher than usual</p><p class="body">' + esc(m.hi) + '</p></div><div class="gap4"><p class="label">If it’s lower than usual</p><p class="body">' + esc(m.lo) + '</p></div></div>' + cmAsk(key);
      }
    }
    return '<div class="scrim" data-close="1"></div><div class="sheet" role="dialog" aria-modal="true" aria-label="' + esc(title) + '"><div class="grab"></div>' +
      '<div class="sh"><span></span><div class="mid"><p class="headline">' + esc(title) + '</p>' + (sub ? '<p class="caption">' + esc(sub) + '</p>' : '') + '</div>' +
      '<button class="rbtn press" data-close="1" aria-label="Close">' + I.close + '</button></div><div class="sb">' + body + '<div class="foot"><p class="caption">Wellness estimates, not medical advice.</p></div></div></div>';
  }

  // ================================================================ canvas drawers
  var DRAW = {
    capsule: function (c) { C.capsule(c, { value: S.strain, max: 21, target: D.strainTarget }); },
    stress: function (c) {
      var bars = [];
      for (var h = 0; h < 24; h++) {
        var x = D.stress[h];
        if (!x) { bars.push({ future: true }); continue; }
        if (x.level == null) { bars.push({ v: 1.0, color: C.tok('graphite2') }); continue; }
        bars.push({ v: Math.max(0.15, x.level), color: C.tok(x.level < 1 ? 'good' : x.level < 2 ? 'limit' : 'danger'), faint: h < 7 });
      }
      C.bars(c, { bars: bars, max: 3, gap: 3 });
    },
    spark: function (c, id) {
      var v = M[id].s.slice(-7).map(function (p, i) { return { x: i, y: p.value }; });
      C.line(c, { values: v, grid: false, padR: 6, padT: 6, padB: 6, padL: 2, lineWidth: 1.5, point: true, pointColor: C.tok(stats(id).flag === 'good' ? 'ember' : stats(id).flag), glow: false });
    },
    strip: function (c, arg) {
      var parts = arg.split('|'), id = parts[0], big = parts[1] === 'big', st = stats(id), m = M[id];
      var lo = Math.min(m.domain[0], st.v), hi = Math.max(m.domain[1], st.v);
      if (big) { c.style.height = '52px'; }
      C.strip(c, { domain: [lo, hi], band: st.band, value: st.v, status: 'good', rows: big ? 2 : 2, label: big ? TIER[st.flag] : null });
    },
    trend: function (c, id) {
      var t = trendOf(id), k = t.vals.length;
      if (['spo2', 'breathing', 'restingHR', 'sleepingHR'].indexOf(id) >= 0) {   // rates: a line, bars from 0 would hide the change
        C.line(c, { values: t.vals.map(function (v, i) { return { x: i, y: v }; }), color: C.tok('graphite2'), lineWidth: 1.5, glow: false, padR: 34,
          refLines: [{ v: t.old, color: C.tok('graphite'), dash: [3, 3], width: 1.5, x0: 0, x1: k - 8 }, { v: t.nu, color: C.tok('ember'), width: 2, x0: k - 7, x1: k - 1 }] });
        return;
      }
      C.bars(c, { bars: t.vals.map(function (v) { return { v: v, color: C.tok('graphite2'), faint: false }; }), max: Math.max.apply(null, t.vals) * 1.08, gap: 2, grain: false,
        refLines: [{ v: t.old, color: C.tok('graphite'), dash: [3, 3], width: 1.5, from: 0, to: k - 8 }, { v: t.nu, color: C.tok('ember'), width: 2, from: k - 7, to: k - 1 }] });
    },
    live: function (c) {
      var vals = rangeData(), r = state.range, o = { values: vals, fill: r === 'live' || r === '1h' || r === '24h', point: true, padB: 20 };
      if (r === 'live') {
        var now = Date.now(); o.xDomain = [now - 120000, now]; o.xLabels = [{ x: now - 120000, label: '2 min ago' }, { x: now - 60000, label: '1 min' }, { x: now, label: 'now' }];
      } else if (r === '1h') {
        o.xLabels = [{ label: hhmm(D.hr1h[0].t) }, { x: +D.hr1h[30].t, label: hhmm(D.hr1h[30].t) }, { label: hhmm(D.now) }];
      } else if (r === '24h') {
        var a = vals[0].x, b = vals[vals.length - 1].x;
        o.shade = [{ x0: D.lastNight.start, x1: D.lastNight.end, label: 'Asleep' }];
        o.xLabels = [{ label: hhmm(a) }, { x: a + (b - a) / 3, label: hhmm(a + (b - a) / 3) }, { x: a + 2 * (b - a) / 3, label: hhmm(a + 2 * (b - a) / 3) }, { label: 'now' }];
      } else {
        var avgs = D.dailyHR.map(function (p) { return p.avg; }).slice(0, -1), mu = mean(avgs), sd = sdev(avgs);
        o.band = { lo: mu - 1.5 * sd, hi: mu + 1.5 * sd }; o.bandLabel = 'Your usual';
        o.dots = r === '7d';
        var f = new Date(vals[0].x), l = new Date(vals[vals.length - 1].x);
        o.xLabels = [{ label: f.getDate() + ' ' + MO[f.getMonth()].slice(0, 3) }, { label: 'today' }];
      }
      var res = C.line(c, o);
      if (res && res.last) { var rp = document.getElementById('ripple'); if (rp) { rp.style.left = res.last.x + 'px'; rp.style.top = res.last.y + 'px'; } }
    },
    strainhr: function (c) {
      var t0 = D.hr[0].t.getTime(), te = D.hr[D.hr.length - 1].t.getTime();
      C.line(c, { values: D.hr.map(function (p) { return { x: +p.t, y: p.bpm }; }), fill: true, point: true, yTicks: [60, 100, 140],
        xLabels: [{ label: hhmm(t0) }, { x: (t0 + te) / 2, label: hhmm((t0 + te) / 2) }, { label: hhmm(te) }] });
    },
    rec14: function (c) {
      C.line(c, { values: rec14.map(function (r) { return { x: -r.d, y: r.v, color: C.tok(tierOf(r.v)) }; }), yDomain: [0, 100], yTicks: [0, 50, 100], dots: true, lineWidth: 1.5,
        xLabels: [{ label: '14 days ago' }, { label: 'today' }], color: C.tok('graphite2'), padL: 4 });
    },
    m14: function (c, id) {
      var st = stats(id), s = M[id].s.slice(-14);
      C.line(c, { values: s.map(function (p, i) { return { x: i, y: p.value }; }), band: { lo: st.band[0], hi: st.band[1] }, point: true,
        pointColor: C.tok(st.flag === 'good' ? 'ember' : st.flag), xLabels: [{ label: s[0].date.getDate() + ' ' + MO[s[0].date.getMonth()].slice(0, 3) }, { label: 'today' }] });
    },
    hypno: function (c) {
      var P = C.prep(c), ctx = P.ctx, n = D.lastNight, W = P.w, H = P.h - 18;
      var lv = { awake: 0, rem: 1, light: 2, deep: 3 }, col = { awake: 'stageAwake', rem: 'stageREM', light: 'stageCore', deep: 'stageDeep' };
      var names = ['Awake', 'REM', 'Core', 'Deep'], lab = 44, rowH = H / 4;
      ctx.font = '400 11px ' + C.tok('font-ui'); ctx.textBaseline = 'middle'; ctx.fillStyle = C.tok('graphite');
      names.forEach(function (nm, i) { ctx.fillText(nm, 0, i * rowH + rowH / 2); });
      var X = function (t) { return lab + (t - n.start) / (n.end - n.start) * (W - lab); };
      n.segments.forEach(function (s) {
        var y = lv[s.stage] * rowH + 3; ctx.fillStyle = C.tok(col[s.stage]);
        ctx.beginPath(); if (ctx.roundRect) ctx.roundRect(X(s.start), y, Math.max(1.5, X(s.end) - X(s.start) - 1), rowH - 6, 3); else ctx.rect(X(s.start), y, Math.max(1.5, X(s.end) - X(s.start) - 1), rowH - 6); ctx.fill();
      });
      ctx.fillStyle = C.tok('graphite'); ctx.textBaseline = 'alphabetic';
      ctx.textAlign = 'left'; ctx.fillText(hhmm(n.start), lab, P.h - 3); ctx.textAlign = 'right'; ctx.fillText(hhmm(n.end), W, P.h - 3); ctx.textAlign = 'left';
    }
  };
  function hydrate(rootEl) {
    (rootEl || app).querySelectorAll('canvas[data-draw]').forEach(function (c) {
      if (!c.getBoundingClientRect().width) return;
      try { DRAW[c.dataset.draw](c, c.dataset.arg); } catch (e) { console.error('[MRH1] draw ' + c.dataset.draw, e); }
    });
  }
  function lightRings() {
    var ticks = app.querySelectorAll('line.lt');
    if (!ticks.length) return;
    requestAnimationFrame(function () { requestAnimationFrame(function () {
      ticks.forEach(function (l) { l.setAttribute('stroke', l.dataset.c); l.classList.remove('lt'); });
    }); });
  }

  // ================================================================ coach (scripted, coach.js)
  var CO = window.MRHCoach({ D: D, S: S, M: M, Q: Q, SHOT: SHOT, RM: RM, I: I, app: app, state: state, esc: esc, stats: stats, fmtV: fmtV, hm: hm, hhmm: hhmm,
    mean: mean, sdev: sdev, WD: WD, TIER: TIER, recFlag: recFlag, tierOf: tierOf, partOfDay: partOfDay, tickRing: tickRing, topbar: topbar,
    rerender: function () { renderScreen(); }, renderSheet: function () { renderSheet(); } });
  if (!state.coachOn && state.tab === 'coach') state.tab = 'today';
  state.seg = Q.get('seg') || (D.today.getDay() === 1 ? 'week' : 'today'); state.monitorOpen = false;
  if (Q.has('test')) window.__coach = CO;   // test hook (routing checks)

  // ================================================================ render
  function mountOrbs() {
    if (orbs) { orbs.destroy(); orbs = null; }
    var cvs = document.getElementById('orbs'), hdr = document.getElementById('hdr');
    if (!cvs || !hdr) return;
    var h = hdr.offsetHeight + 28;
    cvs.style.height = h + 'px';
    orbs = window.MRHOrbs.mount(cvs, { status: state.tab === 'today' ? recFlag : 'none', evening: document.documentElement.dataset.theme === 'dark', frozen: SHOT,
      fadeStart: function (H) { return H * 0.55; }, fadeEnd: function (H) { return H; } });
  }
  function renderScreen() {
    var view = { today: viewToday, live: viewLive, body: viewBody, trends: viewTrends, coach: CO.view }[state.tab]();
    app.innerHTML = '<div class="scroll" id="scroll">' + view + '</div>' + (state.tab === 'coach' ? CO.composer() : '') + tabs() + '<div id="sheetLayer"></div><div id="runnerLayer"></div>';
    mountOrbs();
    hydrate();
    lightRings();
    renderSheet();
    if (state.tab === 'live') updateTicker();
    if (state.tab === 'coach') CO.mounted();
    if (state.tab === 'today') { document.getElementById('scroll').addEventListener('scroll', pinWatch, { passive: true }); pinWatch(); }
  }
  function pinWatch() {
    var sc = document.getElementById('scroll'), hero = document.getElementById('hero'), pin = document.getElementById('pin');
    if (!sc || !hero || !pin) return;
    pin.classList.toggle('on', hero.getBoundingClientRect().bottom - sc.getBoundingClientRect().top < 40);
  }
  var lastFocus = null;
  function renderSheet() {
    var layer = document.getElementById('sheetLayer');
    if (!state.sheet) { layer.innerHTML = ''; document.getElementById('scroll').removeAttribute('aria-hidden'); if (lastFocus && lastFocus.isConnected) lastFocus.focus(); return; }
    lastFocus = document.activeElement;
    layer.innerHTML = sheetHTML(state.sheet);
    document.getElementById('scroll').setAttribute('aria-hidden', 'true');
    hydrate(layer);
    var close = layer.querySelector('.sh .rbtn'); if (close && !SHOT) close.focus({ preventScroll: true });
  }

  app.addEventListener('click', function (e) {
    var t = e.target.closest('[data-tab],[data-sheet],[data-close],[data-range],[data-panel],[data-goto],[data-tag],[data-notif],[data-coachtoggle],[data-seg],[data-monitor]');
    if (!t) return;
    var ds = t.dataset;
    if (ds.tab) { if (ds.tab !== state.tab) { state.tab = ds.tab; state.sheet = null; renderScreen(); } else { var sc = document.getElementById('scroll'); if (sc.scrollTop < 4 && state.tab === 'today' && state.seg !== 'today') { state.seg = 'today'; renderScreen(); } else sc.scrollTo({ top: 0, behavior: RM.matches ? 'auto' : 'smooth' }); } }
    else if (ds.seg) { var pin = document.getElementById('pin'), pinned = pin && pin.classList.contains('on'), keep = document.getElementById('scroll').scrollTop; state.seg = ds.seg; renderScreen(); var sc3 = document.getElementById('scroll'); sc3.scrollTop = pinned ? document.getElementById('pin').offsetTop : keep; pinWatch(); }
    else if (ds.monitor) { var k = document.getElementById('scroll').scrollTop; state.monitorOpen = true; renderScreen(); document.getElementById('scroll').scrollTop = k; }
    else if (ds.close) { state.sheet = null; renderSheet(); }
    else if (ds.sheet) { state.sheet = ds.sheet; renderSheet(); }
    else if (ds.range) { state.range = ds.range; var lc = document.getElementById('liveCard'); lc.innerHTML = liveCard(); hydrate(lc); }
    else if (ds.panel) { state.panel = ds.panel; var bp = document.getElementById('bodyPanel'); bp.innerHTML = bodyPanel(); hydrate(bp); app.querySelectorAll('[data-panel]').forEach(function (b) { b.setAttribute('aria-pressed', b.dataset.panel === state.panel); }); }
    else if (ds.goto) { state.tab = 'body'; state.panel = ds.goto; renderScreen(); }
    else if (ds.tag) { state.tags[ds.tag] = !state.tags[ds.tag]; t.setAttribute('aria-pressed', state.tags[ds.tag]); }
    else if (ds.notif) { state.notif[ds.notif] = !state.notif[ds.notif]; t.setAttribute('aria-checked', state.notif[ds.notif]); }
    else if (ds.coachtoggle) {
      state.coachOn = !state.coachOn;
      if (!state.coachOn && state.tab === 'coach') state.tab = 'today';
      var sb = app.querySelector('.sheet .sb'), y = sb ? sb.scrollTop : 0;
      renderScreen();
      var sb2 = app.querySelector('.sheet .sb'); if (sb2) sb2.scrollTop = y;
      var tg = app.querySelector('[data-coachtoggle]'); if (tg) tg.focus({ preventScroll: true });
    }
  });
  document.addEventListener('keydown', function (e) { if (e.key === 'Escape' && state.sheet) { state.sheet = null; renderSheet(); } });

  // redraw canvases on size / DPR change
  var rT = 0;
  new ResizeObserver(function () { clearTimeout(rT); rT = setTimeout(function () { hydrate(); }, 60); }).observe(app);
  (function watchDpr() {
    var mq = matchMedia('(resolution: ' + (window.devicePixelRatio || 1) + 'dppx)');
    mq.addEventListener('change', function once() { mq.removeEventListener('change', once); hydrate(); watchDpr(); });
  })();
  matchMedia('(prefers-color-scheme: dark)').addEventListener('change', function (e) {
    if (Q.get('theme')) return;
    document.documentElement.dataset.theme = e.matches ? 'dark' : 'light';
    if (orbs) orbs.setEvening(e.matches);
    hydrate();
  });

  // ================================================================ live loop
  function updateTicker() {
    var el = document.getElementById('tick'); if (!el) return;
    var s = Math.max(1, Math.round((Date.now() - live[live.length - 1].t) / 1000));
    el.textContent = 'latest sample ' + s + ' s ago';
  }
  if (!SHOT) {
    setInterval(updateTicker, 1000);
    setInterval(function () {
      live.push({ t: Date.now(), bpm: D.liveSample(liveIdx++) });
      if (live.length > 60) live.shift();
      if (state.tab !== 'live') return;
      var n = document.getElementById('hrNow'); if (n) n.textContent = Math.round(live[live.length - 1].bpm);
      updateTicker();
      if (orbs) orbs.pulse();
      if (state.range === 'live') {
        var c = document.querySelector('#liveCard canvas[data-draw="live"]');
        if (c) DRAW.live(c);
        var rp = document.getElementById('ripple');
        if (rp && !RM.matches) { rp.classList.remove('go'); void rp.offsetWidth; rp.classList.add('go'); }
      }
    }, 3000);
  }

  // fonts change metrics: draw once now, again when Geist arrives
  renderScreen();
  if (Q.get('y')) { document.getElementById('scroll').scrollTop = +Q.get('y'); pinWatch(); }   // screenshot hook
  if (document.fonts && document.fonts.ready) document.fonts.ready.then(function () { hydrate(); });
})();
