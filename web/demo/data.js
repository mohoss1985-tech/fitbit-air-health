/* MRH1 web demo — synthetic sample data (not a real person's readings).
   Shapes and ranges mirror what a Google Fitbit Air writes into Apple Health. */
(function () {
  "use strict";

  // Deterministic pseudo-random so screenshots are reproducible.
  let seed = 42;
  function rnd() { seed = (seed * 16807) % 2147483647; return (seed - 1) / 2147483646; }
  function noise(sd) { return (rnd() + rnd() + rnd() - 1.5) * sd * 1.15; }

  const DAY = 86400000;
  const today = new Date(); today.setHours(0, 0, 0, 0);
  const days = [];
  for (let i = 30; i >= 0; i--) days.push(new Date(today.getTime() - i * DAY));

  function series(base, sd, overrides) {
    return days.map((d, i) => {
      const fromEnd = days.length - 1 - i;
      const v = overrides && overrides[fromEnd] !== undefined ? overrides[fromEnd] : base + noise(sd);
      return { date: d, value: v };
    });
  }

  // Index 0 = today (last night), 1 = yesterday...
  const data = {
    restingHR: series(61, 1.6, { 0: 60, 1: 62, 2: 64.5, 3: 61, 4: 60, 5: 59, 6: 61 }),
    hrv: series(50, 5, { 0: 56, 1: 52, 2: 41, 3: 49, 4: 53, 5: 55, 6: 51 }),
    breathing: series(14.8, 0.35, { 0: 15.9, 1: 14.9, 2: 15.1, 3: 14.6, 4: 14.7, 5: 14.8, 6: 14.5 }),
    spo2: series(96.4, 0.5, { 0: 96.6, 3: 94.9 }),
    skinTemp: series(0, 0.18, { 0: 0.2, 2: 0.4 }),
    sleepingHR: series(56, 1.6, { 0: 55, 2: 59 }),
    steps: series(8900, 2100, { 0: 9420, 1: 12850, 2: 6120, 3: 10340, 4: 8770, 5: 11400, 6: 7930 }),
    energy: series(690, 140, { 0: 720, 1: 980, 2: 470, 3: 760 }),
    workoutMinutes: series(190, 30, { 0: 212, 1: 205, 2: 180 })
  };

  // Sleep: one session per night, with stages.
  function makeNight(dayIdxFromEnd, asleepMin, deep, rem, awake, bedH, bedM) {
    const wakeDay = days[days.length - 1 - dayIdxFromEnd];
    const start = new Date(wakeDay.getTime() - DAY);
    start.setHours(bedH, bedM, 0, 0);
    const light = asleepMin - deep - rem;
    // Build a plausible hypnogram: 90-min cycles, deep early, REM late.
    const segs = [];
    let t = start.getTime();
    const cycles = Math.max(4, Math.round(asleepMin / 90));
    const deepPer = [0.34, 0.28, 0.2, 0.1, 0.05, 0.03];
    const remPer = [0.08, 0.14, 0.18, 0.2, 0.2, 0.2];
    const sumD = deepPer.slice(0, cycles).reduce((a, b) => a + b, 0);
    const sumR = remPer.slice(0, cycles).reduce((a, b) => a + b, 0);
    for (let c = 0; c < cycles; c++) {
      const d = deep * (deepPer[c] || 0.02) / sumD;
      const r = rem * (remPer[c] || 0.2) / sumR;
      const l = light / cycles;
      const add = (stage, min) => { if (min > 1) { segs.push({ stage, start: t, end: t + min * 60000 }); t += min * 60000; } };
      add("light", l * 0.55);
      add("deep", d);
      add("light", l * 0.45);
      add("rem", r);
      if (c < cycles - 1 && awake > 0) add("awake", awake / (cycles - 1));
    }
    return { start: start.getTime(), end: t, segments: segs, asleep: asleepMin, deep, rem, awake, light };
  }

  const nights = [];
  const plan = [
    // [asleep, deep, rem, awake, bedH, bedM] for nights 13..0 days ago
    [418, 68, 88, 34, 23, 40], [455, 80, 97, 28, 23, 5], [402, 61, 79, 41, 0, 25],
    [470, 84, 104, 26, 22, 55], [436, 72, 93, 30, 23, 30], [389, 58, 72, 46, 0, 50],
    [481, 86, 108, 22, 22, 45], [445, 77, 95, 29, 23, 20], [428, 70, 90, 33, 23, 50],
    [396, 55, 70, 52, 1, 5], [462, 81, 102, 27, 23, 0], [451, 79, 99, 31, 23, 15],
    [438, 74, 96, 35, 23, 25], [432, 82, 101, 31, 23, 35]
  ];
  plan.forEach((p, i) => nights.push(makeNight(plan.length - 1 - i, ...p)));

  data.sleepTotal = nights.map(n => ({ date: new Date(new Date(n.end).setHours(0, 0, 0, 0)), value: n.asleep }));
  data.deepSleep = nights.map(n => ({ date: new Date(new Date(n.end).setHours(0, 0, 0, 0)), value: n.deep }));
  data.remSleep = nights.map(n => ({ date: new Date(new Date(n.end).setHours(0, 0, 0, 0)), value: n.rem }));
  data.awake = nights.map(n => ({ date: new Date(new Date(n.end).setHours(0, 0, 0, 0)), value: n.awake }));

  // Today's heart rate (for strain chart) and hourly stress, up to "now" = 17:40 in the demo.
  const nowHour = 17;
  const hr = [];
  for (let m = 7 * 60; m <= nowHour * 60 + 40; m += 2) {
    let base = 66 + 6 * Math.sin(m / 95);
    if (m > 12 * 60 + 10 && m < 12 * 60 + 55) base = 132 + 12 * Math.sin(m / 4); // lunchtime run
    if (m > 9 * 60 && m < 11 * 60) base += 14;                                       // stressful meeting
    hr.push({ t: new Date(today.getTime() + m * 60000), bpm: base + noise(3) });
  }
  const stress = [];
  for (let h = 0; h <= nowHour; h++) {
    if (h < 7) { stress.push({ hour: h, level: 0.2 + rnd() * 0.3 }); continue; }
    if (h === 12) { stress.push({ hour: h, level: null }); continue; }      // moving
    if (h === 9 || h === 10) { stress.push({ hour: h, level: 2.2 + rnd() * 0.4 }); continue; }
    if (h === 15) { stress.push({ hour: h, level: 1.3 }); continue; }
    stress.push({ hour: h, level: 0.4 + rnd() * 0.5 });
  }

  // ---- v1 additions. A second, independent generator so the series above stay byte-identical.
  let seed2 = 7;
  function rnd2() { seed2 = (seed2 * 16807) % 2147483647; return (seed2 - 1) / 2147483646; }
  function noise2(sd) { return (rnd2() + rnd2() + rnd2() - 1.5) * sd * 1.15; }

  const NOW_MIN = nowHour * 60 + 40;                       // demo clock: 17:40 today
  const now = new Date(today.getTime() + NOW_MIN * 60000);
  const lastNight = nights[nights.length - 1];

  // 24 h of heart rate ending at "now": evening + asleep (5-min) then today's 2-min series.
  const hr24 = [];
  for (let t = now.getTime() - DAY; t < today.getTime() + 7 * 3600000; t += 300000) {
    const asleep = t >= lastNight.start && t <= lastNight.end;
    const h = new Date(t).getHours() + new Date(t).getMinutes() / 60;
    let b = asleep ? 55 + 3 * Math.sin((t - lastNight.start) / 5.4e6) : (h > 19 && h < 20 ? 96 : 72 - (h > 21 ? 4 : 0));
    hr24.push({ t: new Date(t), bpm: b + noise2(asleep ? 1.4 : 3) });
  }
  hr.forEach(p => hr24.push(p));

  // Last hour at 1-min resolution (the "1H" range).
  const hr1h = [];
  for (let m = NOW_MIN - 60; m <= NOW_MIN; m++) {
    const walk = m > NOW_MIN - 34 && m < NOW_MIN - 18 ? 22 : 0;  // short walk at ~17:10
    hr1h.push({ t: new Date(today.getTime() + m * 60000), bpm: 70 + walk + 4 * Math.sin(m / 7) + noise2(2.2) });
  }

  // Daily min / avg / max heart rate for 7D and 30D.
  const dailyHR = days.map((d, i) => {
    const rest = data.restingHR[i].value;
    const avg = rest + 14 + noise2(2.5) + (i % 7 === 5 ? 6 : 0);
    return { date: d, min: Math.round(rest - 3 + noise2(1)), avg: Math.round(avg), max: Math.round(avg + 60 + noise2(14)) };
  });

  // Live samples: a pure function of the index, so every visitor sees the same stream.
  function liveSample(i) {
    const h = Math.sin((i + 1) * 12.9898) * 43758.5453;
    const n = (h - Math.floor(h)) - 0.5;
    return Math.round((70 + 3.5 * Math.sin(i / 9) + 1.2 * Math.sin(i / 3.7) + n * 1.2) * 10) / 10;   // one decimal: no integer staircase
  }

  window.MRH1_DATA = {
    today, days, data, nights, hr, stress,
    now, nowMin: NOW_MIN, hr24, hr1h, dailyHR, liveSample, lastNight,
    notSent: ["hrv", "skinTemp", "vo2max"],
    strainTarget: [12, 15], activeEnergy: 512, syncedMinAgo: 23,
    scores: { recovery: 78, strain: 9.4, sleep: 86, maxHR: 182, age: 38 },
    zones: [64, 38, 22, 14, 3],
    workoutsToday: [{ name: "Run", start: new Date(today.getTime() + (12 * 60 + 10) * 60000), minutes: 45 }],
    history: [
      { d: 6, recovery: 71, sleep: 445, strain: 11.2, steps: 7930 },
      { d: 5, recovery: 84, sleep: 428, strain: 13.6, steps: 11400 },
      { d: 4, recovery: 66, sleep: 396, strain: 8.1, steps: 8770 },
      { d: 3, recovery: 74, sleep: 462, strain: 12.4, steps: 10340 },
      { d: 2, recovery: 41, sleep: 451, strain: 6.3, steps: 6120 },
      { d: 1, recovery: 69, sleep: 438, strain: 14.8, steps: 12850 },
      { d: 0, recovery: 78, sleep: 432, strain: 9.4, steps: 9420 }
    ],
    bodyAge: {
      estimate: 35.7, age: 38,
      factors: [
        ["Resting heart rate", -0.5, "61 bpm (14-day average). Lower is younger; 60 or below is excellent."],
        ["Daily steps", -0.9, "9 230 a day. 8 000+ a day is linked to longer life."],
        ["Exercise", -0.4, "212 min of workouts in the last 7 days. 150+ is the target."],
        ["HRV", 0.3, "51 ms vs about 54 typical for your age."],
        ["Sleep duration", -0.5, "7 h 15 a night on average. 7 – 8.5 h is the sweet spot."],
        ["Sleep regularity", -0.3, "Bedtime varies ±31 min. Under ±45 min helps."]
      ]
    }
  };
})();
