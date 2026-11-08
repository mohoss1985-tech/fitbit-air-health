/* MRH1 v1.1 web demo — Coach tab. A SCRIPTED stand-in for the iPhone's on-device coach:
 * no network, no model. ~16 canned answers built from the same synthetic data as the rest of the demo (data.js),
 * a keyword matcher for typed text, and a polite fallback for anything else.
 * Loaded before app.js; app.js calls window.MRHCoach(ctx) once its helpers exist.
 */
(function () {
  'use strict';

  window.MRHCoach = function (X) {
    var D = X.D, S = X.S, M = X.M, esc = X.esc, stats = X.stats, fmtV = X.fmtV, hm = X.hm, state = X.state;
    var DAY = 864e5;
    var RMq = X.RM, SHOT = X.SHOT;
    function rm() { return SHOT || RMq.matches; }

    // ------------------------------------------------------------ glyph (CoachBubbleShape: r≈35 % of body, short tail bottom-left)
    var BUBBLE = 'M4.48 0H11.52A4.48 4.48 0 0 1 16 4.48V8.32A4.48 4.48 0 0 1 11.52 12.8H7.36Q4.8 13.92 2.56 16Q3.52 13.44 4.48 12.8A4.48 4.48 0 0 1 0 8.32V4.48A4.48 4.48 0 0 1 4.48 0Z';
    function glyph(sw, dotOp, cls) {
      return '<svg class="' + (cls || 'cg') + '" viewBox="-1 -1 18 18" fill="none" aria-hidden="true"><path d="' + BUBBLE + '" stroke="currentColor" stroke-width="' + sw +
        '" stroke-linejoin="round" vector-effect="non-scaling-stroke"/><circle cx="8" cy="6.4" r="2.18" fill="var(--ember)" fill-opacity="' + dotOp + '"/></svg>';
    }
    function thinkGlyph() {
      return '<svg class="cg think-g" viewBox="-1 -1 18 18" fill="none" aria-hidden="true"><path d="' + BUBBLE + '" stroke="currentColor" stroke-width="1.5" stroke-linejoin="round" vector-effect="non-scaling-stroke"/>' +
        '<circle class="d1" cx="4.9" cy="6.4" r="1.15" fill="var(--ember)"/><circle class="d2" cx="8" cy="6.4" r="1.15" fill="var(--ember)"/><circle class="d3" cx="11.1" cy="6.4" r="1.15" fill="var(--ember)"/></svg>';
    }
    var ICON = {
      tabOff: glyph(1.75, 0.6), tabOn: glyph(1.75, 1),
      edit: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round"><path d="M5 19h4L19 9l-4-4L5 15v4z"/><path d="M13.5 6.5l4 4"/></svg>',
      send: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 19V6M6.5 11.5L12 6l5.5 5.5"/></svg>',
      check: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.25" stroke-linecap="round" stroke-linejoin="round"><path d="M6.5 12.5l3.5 3.5 7.5-8"/></svg>',
      chev: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round"><path d="M10 7l5 5-5 5"/></svg>',
      back: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round"><path d="M14 7l-5 5 5 5"/></svg>',
      skip: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round"><path d="M7 7l5 5-5 5M13 7l5 5-5 5"/></svg>',
      pause: '<svg viewBox="0 0 24 24" fill="currentColor"><rect x="7" y="6" width="3.5" height="12" rx="1.2"/><rect x="13.5" y="6" width="3.5" height="12" rx="1.2"/></svg>',
      play: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M8 6.2v11.6c0 .8.9 1.3 1.6.8l8.6-5.8c.6-.4.6-1.2 0-1.6L9.6 5.4C8.9 4.9 8 5.4 8 6.2z"/></svg>'
    };

    // ------------------------------------------------------------ numbers (all from data.js, same maths as the other tabs)
    var rhr = stats('restingHR'), br = stats('breathing'), sl = stats('sleepTotal'), dp = stats('deepSleep'), sp = stats('spo2');
    var night = D.lastNight, nights7 = D.nights.slice(-7);
    var debt = nights7.reduce(function (s, n) { return s + Math.max(0, 480 - n.asleep); }, 0);
    var beds = nights7.map(function (n) { var b = new Date(n.start), m = b.getHours() * 60 + b.getMinutes(); return m < 720 ? m + 1440 : m; });
    var consist = Math.round(X.sdev(beds));
    var hist = D.history.slice().sort(function (a, b) { return b.d - a.d; });
    var low = hist.reduce(function (a, b) { return b.recovery < a.recovery ? b : a; });
    var lowDay = X.WD[new Date(D.today.getTime() - low.d * DAY).getDay()];
    var lowRhr = M.restingHR.s[M.restingHR.s.length - 1 - low.d].value;
    var wkRec = Math.round(X.mean(hist.map(function (h) { return h.recovery; })));
    var wkSleep = X.mean(nights7.map(function (n) { return n.asleep; }));
    var wkSteps = X.mean(hist.map(function (h) { return h.steps; }));
    var inTarget = hist.filter(function (h) { return h.strain >= D.strainTarget[0] && h.strain <= D.strainTarget[1]; }).length;
    var rv = M.restingHR.s.map(function (p) { return p.value; }), rNew = X.mean(rv.slice(-7)), rOld = X.mean(rv.slice(-14, -7));
    var brDelta = br.v - br.mu;
    var tgt = D.strainTarget[0] + '–' + D.strainTarget[1];
    var run = D.workoutsToday[0];
    var WORDS = ['zero', 'one', 'two', 'three', 'four', 'five', 'six', 'seven'];
    function rng(id) { var st = stats(id); return fmtV(id, st.band[0]) + '–' + fmtV(id, st.band[1]); }
    function pill(text, tier, sheet) { return { text: text, tier: tier, sheet: sheet }; }
    var P = {
      recovery: pill('Recovery ' + S.recovery + ' % · ' + X.TIER[X.recFlag].toLowerCase(), X.recFlag, 'recovery'),
      rhr: pill('RHR ' + fmtV('restingHR', rhr.v) + ' · normal ' + rng('restingHR'), rhr.flag, 'metric:restingHR'),
      rhrLow: pill('RHR ' + fmtV('restingHR', lowRhr) + ' on ' + lowDay.slice(0, 3) + ' · normal ' + rng('restingHR'), rhr.nightFlag(lowRhr), 'metric:restingHR'),
      breathing: pill('Breathing ' + fmtV('breathing', br.v) + ' · normal ' + rng('breathing'), br.flag, 'metric:breathing'),
      spo2: pill('SpO2 ' + fmtV('spo2', sp.v) + ' % · normal ' + rng('spo2'), sp.flag, 'metric:spo2'),
      sleep: pill('Sleep ' + hm(night.asleep) + ' · score ' + S.sleep, 'good', 'sleep'),
      deep: pill('Deep ' + hm(dp.v) + ' · normal ' + rng('deepSleep'), dp.flag, 'metric:deepSleep'),
      consist: pill('Bedtime ±' + consist + ' min · aim under ±45', consist <= 45 ? 'good' : 'limit', 'sleep'),
      strain: pill('Strain ' + S.strain + ' · target ' + tgt, null, 'strain'),
      weekRec: pill('Recovery ' + wkRec + ' % · 7-day average', X.tierOf(wkRec), 'recovery'),
      weekSleep: pill('Sleep ' + (wkSleep / 60).toFixed(1) + ' h · 7-night average', wkSleep >= 420 ? 'good' : 'limit', 'metric:sleepTotal'),
      hrv: pill('HRV · not sent by Google Health', 'ns', 'metric:hrv'),
      skin: pill('Skin temp · not sent', 'ns', 'metric:skinTemp')
    };

    // ------------------------------------------------------------ plans (CoachPlan / PlanStep shapes, §8)
    var PLANS = {
      walk30: { id: 'walk30', title: '30-min brisk walk', sub: 'Fits your ' + tgt + ' strain target', steps: [
        { name: 'Easy walk', sec: 240, cue: 'Start slow and let your shoulders drop.' },
        { name: 'Brisk walk', sec: 1140, cue: 'Fast enough to breathe harder, slow enough to talk.' },
        { name: 'Easy walk', sec: 240, cue: 'Ease off and let your breathing settle.' },
        { name: 'Calf stretch', sec: 60, cue: '30 s each side, heel down.' },
        { name: 'Hip flexor stretch', sec: 60, cue: '30 s each side, hips tucked under.' },
        { name: 'Hamstring stretch', sec: 60, cue: 'Soft knee, hinge from the hips.' }] },
      walk15: { id: 'walk15', title: '15-min brisk walk', sub: 'About halfway to your strain target', steps: [
        { name: 'Easy walk', sec: 180, cue: 'Start slow and let your shoulders drop.' },
        { name: 'Brisk walk', sec: 540, cue: 'Fast enough to breathe harder, slow enough to talk.' },
        { name: 'Easy walk', sec: 120, cue: 'Ease off and let your breathing settle.' },
        { name: 'Calf stretch', sec: 60, cue: '30 s each side, heel down.' }] },
      circuit15: { id: 'circuit15', title: '15-min indoor circuit', sub: 'Bodyweight only, no jumps', steps: [
        { name: 'Warm-up march', sec: 240, cue: 'Easy pace, swing your arms.' },
        { name: 'Squats', reps: '×12', sec: 60, cue: 'Sit back, chest up.' },
        { name: 'Rest', sec: 30, cue: 'Breathe out slowly.' },
        { name: 'Wall push-ups', reps: '×10', sec: 60, cue: 'Body in one straight line.' },
        { name: 'Rest', sec: 30, cue: 'Breathe out slowly.' },
        { name: 'Glute bridges', reps: '×15', cue: 'Squeeze at the top for a second. Tap Done when finished.' },
        { name: 'Easy march', sec: 240, cue: 'Keep moving, nice and light.' },
        { name: 'Cool-down stretch', sec: 180, cue: 'Calves, hips and chest, slow breaths.' }] },
      wind: { id: 'wind', title: '15-min wind-down', sub: 'Lights out by 23:30', steps: [
        { name: 'Phone on charge, away from bed', sec: 120, cue: 'Out of reach is the point.' },
        { name: 'Dim the lights', sec: 60, cue: 'Lamps only from here.' },
        { name: 'Warm shower or wash', sec: 300, cue: 'Warm, not hot. It helps you cool down after.' },
        { name: 'Slow breathing', sec: 240, cue: 'In for 4, out for 6.' },
        { name: 'Write tomorrow’s top 3', sec: 180, cue: 'Get it out of your head and onto paper.' },
        { name: 'Lights out', reps: 'when ready', cue: 'Tap Done when the lights are off.' }] }
    };
    var FAMILY = { walk30: 'move', walk15: 'move', circuit15: 'move', wind: 'wind' };   // a new plan replaces an older one of the same kind
    function planMin(p) { return Math.round(p.steps.reduce(function (s, x) { return s + (x.sec || 60); }, 0) / 60); }

    // ------------------------------------------------------------ the script: headline ≤ 14 words, ≤ 3 sentences, 3 chips
    var A = {
      recovery: { status: 'Comparing with your normal…', q: 'Why is my recovery low?', r: {
        headline: 'Recovery isn’t low today: ' + S.recovery + ' %, above your usual.',
        body: ['Your heart settled early last night and sleep was close to your normal.',
          'Your low this week was ' + low.recovery + ' % on ' + lowDay + ', when resting heart rate rose to ' + fmtV('restingHR', lowRhr) + '.',
          'Today is a good day to push toward a strain of ' + D.strainTarget[1] + '.'],
        pills: [P.recovery, P.rhrLow], chips: ['Plan my workout today', 'Why is RHR up?', 'Weekly review'] } },
      plan: { status: 'Checking today’s strain target…', q: 'Plan my workout today', r: {
        headline: 'A 30-minute brisk walk gets you into today’s target.',
        body: ['You already ran ' + run.minutes + ' min at ' + X.hhmm(run.start) + ', so keep this easy to moderate.', 'You should be able to talk the whole way.'],
        pills: [P.strain, P.recovery], plan: 'walk30', chips: ['Make it shorter', 'Indoor option instead?', 'Why is strain low?'] } },
      planShort: { status: 'Finding a shorter session…', q: 'Make it shorter', r: {
        headline: 'Here is a 15-minute version.',
        body: ['It gets you about halfway to your target, which is fine on a day you already ran.'],
        pills: [P.strain], plan: 'walk15', chips: ['Indoor option instead?', 'Help me sleep better', 'Weekly review'] } },
      planIndoor: { status: 'Finding an indoor session…', q: 'Indoor option instead?', r: {
        headline: 'A 15-minute bodyweight circuit, no jumps and no equipment.',
        body: ['Keep the pace steady; you should be able to talk.', 'Recovery is green, so moderate effort is fine.'],
        pills: [P.recovery, P.strain], plan: 'circuit15', chips: ['Make it shorter', 'Why is strain low?', 'Help me sleep better'] } },
      sleep: { status: 'Reading your last 7 nights…', q: 'Help me sleep better', r: {
        headline: 'A good night. The next gain is a steadier bedtime.',
        body: ['You slept ' + hm(night.asleep) + ' with deep sleep ' + dp.dirWord + '.',
          'Bedtimes moved ±' + consist + ' min this week, and sleep debt is ' + hm(debt) + ' over 7 nights.',
          'Aim for lights out by 23:30 again tonight.'],
        pills: [P.sleep, P.deep, P.consist], chips: ['Plan tonight’s wind-down', 'Does caffeine affect me?', 'Weekly review'] } },
      wind: { status: 'Building a wind-down…', q: 'Plan tonight’s wind-down', r: {
        headline: 'Fifteen quiet minutes, starting around 23:15.',
        body: ['Screens away first, then warm water and slow breathing.', 'Same time every night matters more than any single step.'],
        pills: [P.consist], plan: 'wind', chips: ['Does caffeine affect me?', 'Why is breathing high?', 'Weekly review'] } },
      week: { status: 'Summing up your last 7 days…', q: 'Weekly review', r: {
        headline: 'A steady week: recovery averaged ' + wkRec + ' %, ' + WORDS[inTarget] + ' days in target.',
        body: ['You slept ' + (wkSleep / 60).toFixed(1) + ' h a night and walked ' + (wkSteps / 1000).toFixed(1) + 'k steps a day.',
          'The dip to ' + low.recovery + ' % on ' + lowDay + ' bounced back the next day.',
          'Keep the same rhythm and protect your bedtime.'],
        pills: [P.weekRec, P.weekSleep, P.strain], chips: ['Why is RHR up?', 'Plan my workout today', 'Help me sleep better'] } },
      rhr: { status: 'Comparing with your normal…', q: 'Why is RHR up?', r: {
        headline: rhr.flag === 'good' ? 'It isn’t up today: ' + fmtV('restingHR', rhr.v) + ' bpm, within your usual.' : 'Resting heart rate is ' + rhr.dirWord + ' today.',
        body: ['It peaked at ' + fmtV('restingHR', lowRhr) + ' on ' + lowDay + ', the night recovery dipped to ' + low.recovery + ' %.',
          'This week averaged ' + rNew.toFixed(1) + ' bpm against ' + rOld.toFixed(1) + ' the week before.',
          'Hard training, alcohol, late meals and short nights all push it up.'],
        pills: [P.rhr, P.rhrLow], chips: ['Explain my recovery today', 'Does caffeine affect me?', 'Weekly review'] } },
      breathing: { status: 'Checking last night’s vitals…', q: 'Why is breathing high?', r: {
        headline: 'Breathing rate ran ' + brDelta.toFixed(1) + ' above your usual last night.',
        body: ['Everything else, including blood oxygen, was in range.',
          'One night rarely means much; it can follow hard training, alcohol or your body fighting something off.',
          'Worth an early night, and see if it settles.'],
        pills: [P.breathing, P.spo2], chips: ['Plan tonight’s wind-down', 'Should I train today?', 'What can you see?'] } },
      train: { status: 'Weighing recovery and vitals…', q: 'Should I train today?', r: {
        headline: 'Yes, at an easy-to-moderate effort.',
        body: ['Recovery is ' + S.recovery + ' %, but breathing ran high last night, so skip anything all-out.', 'A brisk walk reaches your target.'],
        pills: [P.recovery, P.breathing], chips: ['Plan my workout today', 'Why is breathing high?', 'Help me sleep better'] } },
      strain: { status: 'Reading today’s heart rate…', q: 'Why is strain low?', r: {
        headline: 'Strain ' + S.strain + ' so far, under your ' + tgt + ' target.',
        body: ['Your ' + run.minutes + '-minute run at ' + X.hhmm(run.start) + ' did most of it.', 'About 30 minutes of brisk walking reaches the low end.'],
        pills: [P.strain, P.recovery], chips: ['Plan my workout today', 'Indoor option instead?', 'Weekly review'] } },
      stress: { status: 'Reading today’s stress…', q: 'Why was I stressed?', r: {
        headline: 'Stress was high from 9 to 11, low the rest of the day.',
        body: ['Your heart rate rose while you were still, which is how MRH1 spots stress.', 'A short walk or slow breathing helps bring it down.'],
        pills: [pill('Stress 09–11 · high', 'danger', null), pill('Stress now · low', 'good', null)], chips: ['Plan tonight’s wind-down', 'Plan my workout today', 'What can you see?'] } },
      caffeine: { status: 'Reading your journal tags…', q: 'Does caffeine affect me?', r: {
        headline: 'Late caffeine lines up with a lower sleep score for you.',
        body: ['On days you tagged late caffeine, your sleep score averaged 9 points lower.', 'That is from 11 tagged days, so treat it as a hint.', 'Try a 14:00 cut-off for a week.'],
        pills: [P.sleep], chips: ['Help me sleep better', 'Plan tonight’s wind-down', 'Weekly review'] } },
      notsent: { status: 'Checking what Google Health sends…', q: 'What about HRV?', r: {
        headline: 'Google Health hasn’t sent HRV, so I’m leaving it out.',
        body: ['Skin temperature and VO2 max aren’t sent either.', 'Recovery uses resting heart rate, sleep and breathing instead.'],
        pills: [P.hrv, P.skin], chips: ['Explain my recovery today', 'What can you see?', 'Why is RHR up?'] } },
      see: { status: 'Listing what I can read…', q: 'What can you see?', r: {
        headline: 'Only what MRH1 reads from Apple Health, on this iPhone.',
        body: ['Heart rate, resting heart rate, breathing, blood oxygen, sleep stages, steps, workouts and your journal tags.',
          'Nothing leaves the phone and chats stay on it for 30 days.', 'In this demo it is all sample data.'],
        pills: [P.hrv], chips: ['What can you do?', 'Explain my recovery today', 'Help me sleep better'] } },
      help: { status: 'Reading your question…', q: 'What can you do?', r: {
        headline: 'Your sleep, recovery and training, from your own numbers.',
        body: ['I explain what changed, plan a session that fits today, and suggest a wind-down.', 'For anything medical, a doctor is the right person.'],
        pills: [P.recovery], chips: ['Plan my workout today', 'Help me sleep better', 'Weekly review'] } },
      live: { status: 'Reading the last few minutes…', q: 'What is my heart doing?', r: {
        headline: 'Resting zone right now, about ' + Math.round(D.liveSample(40)) + ' bpm.',
        body: ['That is close to your normal for a quiet afternoon.', 'Your ' + run.minutes + '-minute run at ' + X.hhmm(run.start) + ' was today’s peak.'],
        pills: [P.rhr], chips: ['Why is strain low?', 'Why was I stressed?', 'Why is RHR up?'] } },
      medical: { status: 'Reading your question…', fast: true, q: 'Is this chest pain serious?', r: {
        notice: true,
        headline: 'That’s one for a doctor.',
        body: ['If it’s sudden or severe, call your local emergency number.', 'I can help with sleep, training and recovery from your own data.'],
        pills: [], chips: ['What can you do?', 'Help me sleep better', 'Explain my recovery today'] } },
      fallback: { status: 'Reading your question…', fast: true, q: 'Will it rain tomorrow?', r: {
        headline: 'In this demo I answer the suggested questions.',
        body: ['On the iPhone the coach answers anything about your sleep, recovery and training.', 'Here, try one of these.'],
        pills: [], chips: ['Explain my recovery today', 'Plan my workout today', 'Help me sleep better'] } }
    };
    // Chip / starter text → answer key (exact, case-insensitive). Typed text falls through to keywords.
    var EXACT = {};
    Object.keys(A).forEach(function (k) { if (A[k].q) EXACT[A[k].q.toLowerCase()] = k; });
    EXACT['explain my recovery today'] = 'recovery';
    EXACT['anything outside my range?'] = 'breathing';
    EXACT['how was my week?'] = 'week';

    var MED = /\b(pain|chest|dizz|faint|symptom|diagnos|medic|pill|drug|dose|doctor|sick|ill(ness)?\b|fever|covid|flu\b|afib|a-fib|apn(o)?ea|arrhythm|palpitat|blood pressure|heart attack|stroke|cancer|diabet|pregnan|injur|hurt|emergency|suicid|numb)/;
    var KEYS = [
      [/short|quick|15.?min|less time/, 'planShort'],
      [/indoor|inside|bodyweight|at home|circuit|rain|no walk/, 'planIndoor'],
      [/wind.?down|routine|relax|before bed/, 'wind'],
      [/should i (train|work ?out|exercise)|train today|rest day/, 'train'],
      [/plan|workout|work out|exercise|session|training/, 'plan'],
      [/caffeine|coffee|tag|journal|alcohol/, 'caffeine'],
      [/hrv|variability|skin|vo2|not sent|missing/, 'notsent'],
      [/help with|can you do|what do you do|who are you/, 'help'],
      [/see|know|data|privacy|private|read/, 'see'],
      [/week|review|summary/, 'week'],
      [/rhr|resting/, 'rhr'],
      [/breath|respirat|oxygen|spo2|outside|range|watch/, 'breathing'],
      [/stress|anxious|meeting/, 'stress'],
      [/strain|target|load|steps/, 'strain'],
      [/recover|tired|ready|readiness|low|energy/, 'recovery'],
      [/sleep|bed|night|insomnia|deep|rem\b|nap/, 'sleep'],
      [/heart|bpm|live|pulse/, 'live']
    ];
    function route(text) {
      var t = text.toLowerCase().trim();
      if (EXACT[t]) return EXACT[t];
      if (MED.test(t)) return 'medical';
      for (var i = 0; i < KEYS.length; i++) if (KEYS[i][0].test(t)) return KEYS[i][1];
      return 'fallback';
    }
    // CoachMark / "Ask about this" topic → the question the mark sends.
    function topicQuestion(topic) {
      var map = { recovery: 'Explain my recovery today', strain: 'Why is strain low?', stress: 'Why was I stressed?', sleep: 'Help me sleep better',
        panels: 'Anything outside my range?', monitor: 'Anything outside my range?', live: 'What is my heart doing?', week: 'Weekly review',
        'metric:restingHR': 'Why is RHR up?', 'metric:sleepingHR': 'Why is RHR up?', 'metric:breathing': 'Why is breathing high?', 'metric:spo2': 'Why is breathing high?',
        'metric:sleepTotal': 'Help me sleep better', 'metric:deepSleep': 'Help me sleep better', 'metric:remSleep': 'Help me sleep better', 'metric:awake': 'Help me sleep better',
        'metric:steps': 'Why is strain low?', 'metric:energy': 'Why is strain low?', 'metric:workoutMinutes': 'Plan my workout today',
        'metric:hrv': 'What about HRV?', 'metric:skinTemp': 'What about HRV?', 'metric:vo2max': 'What about HRV?' };
      return map[topic] || 'What can you do?';
    }
    function topicName(topic) {
      if (topic.indexOf('metric:') === 0) return M[topic.slice(7)] ? M[topic.slice(7)].label : 'this';
      return { recovery: 'Recovery', strain: 'Strain', stress: 'Stress', sleep: 'Sleep', panels: 'body panels', monitor: 'the health monitor', live: 'your heart rate', week: 'this week' }[topic] || 'this';
    }

    // ------------------------------------------------------------ state
    var C = { msgs: [], busy: false, timer: 0, seq: 0, checks: {}, noteDismissed: false, runner: null, draft: '' };

    // ------------------------------------------------------------ rendering
    var TIERC = { good: 'var(--good)', limit: 'var(--limit)', danger: 'var(--danger)', ns: 'var(--graphite2)' };
    function pillHTML(p) {
      var dot = '<i style="background:' + (TIERC[p.tier] || 'var(--graphite2)') + '"></i>';
      var label = { good: ', in range', limit: ', watch', danger: ', out of range', ns: '' }[p.tier] || '';
      return p.sheet ? '<button class="pill press" data-sheet="' + p.sheet + '" aria-label="' + esc(p.text + label) + '. Opens the detail">' + dot + '<span>' + esc(p.text) + '</span></button>'
        : '<span class="pill">' + dot + '<span>' + esc(p.text) + '</span></span>';
    }
    function mmss(s) { s = Math.max(0, Math.ceil(s)); return Math.floor(s / 60) + ':' + String(s % 60).padStart(2, '0'); }
    function planHTML(m, d) {
      var p = PLANS[m.r.plan], ch = C.checks[m.id] || {};
      if (m.replaced) return '<p class="caption replaced' + (d != null ? ' fi' : '') + '"' + (d != null ? ' style="animation-delay:' + d + 'ms"' : '') + '>Replaced by the ' + esc(m.replaced) + '.</p>';
      var done = p.steps.filter(function (_, i) { return ch[i]; }).length;
      return '<div class="plan' + (d != null ? ' enter' : '') + '"' + (d != null ? ' style="animation-delay:' + d + 'ms"' : '') + '>' +
        '<p class="headline">' + esc(p.title) + '</p><p class="caption">' + esc(p.sub) + ' · ' + planMin(p) + ' min</p><div class="hairline" style="margin:12px 0 4px"></div>' +
        p.steps.map(function (s, i) {
          var on = !!ch[i];
          return '<button class="pstep" role="checkbox" aria-checked="' + on + '" data-check="' + m.id + ':' + i + '" aria-label="' + esc(s.name + (s.reps ? ' ' + s.reps : '') + (s.sec ? ', ' + mmss(s.sec) : '')) + '">' +
            '<span class="box">' + (on ? ICON.check : '') + '</span><span class="pn">' + esc(s.name) + (s.reps ? ' <span class="caption">' + esc(s.reps) + '</span>' : '') + '</span>' +
            '<span class="mono pt">' + (s.sec ? mmss(s.sec) : '—') + '</span></button>';
        }).join('') +
        '<div class="hairline" style="margin:4px 0 12px"></div><div class="row center"><button class="startbtn press" data-run="' + m.id + '">' + (done && done < p.steps.length ? 'Resume' : 'Start') + '</button>' +
        '<span class="caption num">' + done + ' of ' + p.steps.length + ' done</span></div></div>' +
        '<p class="caption">Stop if you feel pain or dizziness.</p>';
    }
    function msgHTML(m, anim, isLast) {
      if (m.role === 'user') return '<div class="turn u' + (anim ? ' anim' : '') + '" aria-label="You: ' + esc(m.text) + '"><p class="ubub fi">' + esc(m.text) + '</p></div>';
      if (m.role === 'note') {
        return '<div class="turn c" aria-label="Coach note: ' + esc(m.r.headline + ' ' + m.r.body.join(' ')) + '"><p class="label clab">' + glyph(1.25, 0.6, 'cg sm') + 'Coach note</p>' +
          '<p class="headline">' + esc(m.r.headline) + '</p><p class="body">' + esc(m.r.body.join(' ')) + '</p></div>';
      }
      var r = m.r, d = 0, step = 120, out = '';
      function dl() { var s = anim ? ' style="animation-delay:' + d + 'ms"' : ''; d += step; return s; }
      if (r.notice) {
        out += '<div class="notice enter"' + dl() + '><span class="bar"></span><div class="gap4"><p class="headline">' + esc(r.headline) + '</p><p class="body">' + esc(r.body.join(' ')) + '</p></div></div>';
      } else {
        out += '<p class="headline fi"' + dl() + '>' + esc(r.headline) + '</p><p class="body">' +
          r.body.map(function (s) { return '<span class="fi"' + dl() + '>' + esc(s) + '</span>'; }).join(' ') + '</p>';
      }
      if (r.pills.length) out += '<div class="pills fi"' + dl() + '>' + r.pills.map(pillHTML).join('') + '</div>';
      if (r.plan) out += planHTML(m, anim ? (d += 60) : null);
      d += 80;
      out += '<div class="cchips" role="group" aria-label="Suggested questions">' + r.chips.slice(0, 3).map(function (c, i) {
        return '<button class="cchip fi' + (isLast ? '' : ' dim') + '" data-ask="' + esc(c) + '"' + (anim ? ' style="animation-delay:' + (d + i * 40) + 'ms"' : '') + '>' + esc(c) + '</button>';
      }).join('') + '</div>';
      return '<div class="turn c' + (anim ? ' anim' : '') + '" id="m' + m.id + '" aria-label="Coach: ' + esc(r.headline + ' ' + r.body.join(' ')) + '"><p class="label clab">Coach</p>' + out + '</div>';
    }
    function thinkingHTML(status) {
      return '<div class="turn c anim" id="thinking"><p class="label clab">Coach</p><div class="think fi">' + thinkGlyph() + '<span class="caption">' + esc(status) + '</span></div></div>';
    }
    function lastCoachIdx() { for (var i = C.msgs.length - 1; i >= 0; i--) if (C.msgs[i].role === 'coach') return i; return -1; }
    function threadHTML() {
      var lc = lastCoachIdx();
      return C.msgs.map(function (m, i) { return msgHTML(m, false, i === lc); }).join('');
    }
    function greeting() {
      var pod = X.partOfDay;
      if (pod === 'morning') return 'Morning. Recovery ' + S.recovery + ' %, sleep ' + hm(night.asleep) + '.';
      if (pod === 'afternoon') return 'Afternoon. Recovery ' + S.recovery + ' %, strain ' + S.strain + ' of ' + tgt + '.';
      return 'Evening. Strain ' + S.strain + ', last night ' + hm(night.asleep) + '.';
    }
    var STARTERS = [['Recovery', 'Explain my recovery today'], ['Sleep', 'Help me sleep better'], ['Strain', 'Why is strain low?'], ['Plan', 'Plan my workout today']];

    function view() {
      return '<div class="screen coach"><div class="hdr" id="hdr"><canvas class="orbs" id="orbs" aria-hidden="true" style="opacity:.55"></canvas>' +
        X.topbar('Coach', 'On this iPhone', '<button class="rbtn press" data-newchat="1" aria-label="New chat">' + ICON.edit + '</button>') +
        '<div class="chips"><span class="chip plain">Demo · scripted sample answers</span></div>' +
        '<p class="title verdict">' + esc(greeting()) + '</p><p class="body cgreet">Here’s what I can help with.</p></div>' +
        '<div id="starters">' + (C.msgs.length ? '' : startersHTML()) + '</div>' +
        '<div class="thread" id="thread">' + threadHTML() + '</div>' +
        '<div class="foot"><p class="caption">AI coach on this iPhone · can be wrong · wellness, not medical advice.</p>' +
        '<p class="caption">Demo · scripted sample answers. No AI runs in this browser.</p></div>' +
        '<p class="vh" aria-live="polite" id="coachLive"></p></div>';
    }
    function startersHTML() {
      return '<div class="card starters">' + STARTERS.map(function (s) {
        return '<button class="srow press" data-ask="' + esc(s[1]) + '"><span><span class="label">' + s[0] + '</span><span class="headline">' + esc(s[1]) + '</span></span>' + ICON.chev + '</button>';
      }).join('') + '</div><p class="caption cdisc">Uses your Apple Health data on this iPhone. Wellness estimates, not medical advice.</p>';
    }
    function composerHTML() {
      return '<form class="composer" id="composer" autocomplete="off"><label class="vh" for="cin">Ask Coach</label>' +
        '<textarea id="cin" rows="1" maxlength="300" placeholder="Ask about sleep, training…" enterkeyhint="send">' + esc(C.draft) + '</textarea>' +
        '<button class="send" type="submit" aria-label="Send"' + (C.busy ? ' disabled' : '') + '>' + ICON.send + '</button></form>';
    }

    // ------------------------------------------------------------ engine
    function scrollEnd() {
      var sc = document.getElementById('scroll'); if (!sc) return;
      sc.scrollTo({ top: sc.scrollHeight, behavior: rm() ? 'auto' : 'smooth' });
    }
    function announce(t) { var l = document.getElementById('coachLive'); if (l) l.textContent = t; }
    function append(html) {
      var th = document.getElementById('thread'); if (!th) return;
      th.insertAdjacentHTML('beforeend', html);
    }
    function setBusy(b) {
      C.busy = b; var s = document.querySelector('#composer .send'); if (s) s.disabled = b;
    }
    function ask(text, opts) {
      opts = opts || {};
      text = String(text || '').trim(); if (!text || C.busy) return;
      var key = opts.key || route(text), a = A[key];
      var onTab = state.tab === 'coach' && document.getElementById('thread');
      var st = document.getElementById('starters'); if (st) st.innerHTML = '';
      // Dim earlier chips: only the latest reply's chips stay ink.
      Array.prototype.forEach.call(document.querySelectorAll('#thread .cchip'), function (c) { c.classList.add('dim'); });
      C.msgs.push({ role: 'user', text: text });
      var fast = SHOT || opts.instant;
      if (onTab) append(msgHTML(C.msgs[C.msgs.length - 1], !fast, false));
      var reply = { role: 'coach', id: ++C.seq, key: key, r: a.r };
      function land() {
        if (reply.r.plan) C.msgs.forEach(function (m) { if (m.role === 'coach' && m.r.plan && !m.replaced && FAMILY[m.r.plan] === FAMILY[reply.r.plan]) m.replaced = PLANS[reply.r.plan].title; });
        C.msgs.push(reply); setBusy(false);
        if (state.tab !== 'coach' || !document.getElementById('thread')) return;
        if (reply.r.plan) { var th = document.getElementById('thread'); th.innerHTML = threadHTML(); var el = document.getElementById('m' + reply.id); if (el) el.outerHTML = msgHTML(reply, !fast, true); }
        else { var t = document.getElementById('thinking'); if (t) t.outerHTML = msgHTML(reply, !fast, true); else append(msgHTML(reply, !fast, true)); }
        announce('Coach replied'); scrollEnd();
      }
      if (fast) { land(); return; }
      C.pending = function () { C.pending = null; clearTimeout(C.timer); land(); };
      setBusy(true);
      if (onTab) { append(thinkingHTML(a.status)); announce('Coach is replying'); scrollEnd(); }
      C.timer = setTimeout(C.pending, a.fast ? 650 : 1100 + Math.min(600, a.r.body.join(' ').length * 3));
    }
    function goCoach(question, note) {
      if (C.busy && C.pending) C.pending();
      state.sheet = null;
      if (note) C.msgs.push({ role: 'note', r: note });
      if (state.tab !== 'coach') { state.tab = 'coach'; X.rerender(); }
      else X.renderSheet();
      if (question) ask(question);
    }
    function newChat() {
      clearTimeout(C.timer); C.pending = null; C.busy = false; C.msgs = []; C.checks = {}; C.draft = '';
      X.rerender();
    }

    // ------------------------------------------------------------ CoachMark + Today note
    function mark(topic, style) {
      return '<button class="cmark" data-coach="' + esc(topic) + '" aria-label="Ask Coach about ' + esc(topicName(topic)) + '"' + (style ? ' style="' + style + '"' : '') + '>' + glyph(1.25, 0.6) + '</button>';
    }
    function slot(topic) { return '<span class="cslot">' + mark(topic) + '</span>'; }
    function wrap(html, topic, cls) { return '<div class="cmw' + (cls ? ' ' + cls : '') + '">' + html + mark(topic) + '</div>'; }
    function askRow(topic) {
      return '<button class="card tap askrow" data-coach="' + esc(topic) + '"><span class="row center"><span class="row center" style="gap:12px;justify-content:flex-start">' +
        '<span class="askg">' + glyph(1.25, 0.6) + '</span><span class="body">Ask Coach about this</span></span>' + ICON.chev + '</span></button>';
    }
    // Rule-based (no model): mirrors CoachRules priority — red recovery → rest; a vital outside range → early night; strain under target → session.
    function noteRule() {
      if (X.recFlag === 'danger') return { headline: 'Recovery is red. Make today a recovery day.', body: ['A walk is plenty.'], ask: 'Explain my recovery today' };
      if (br.flag !== 'good') return { headline: 'Breathing ran ' + brDelta.toFixed(1) + ' above your usual last night.', body: ['Everything else is in range. Worth an early night.'], ask: 'Why is breathing high?' };
      if (S.strain < D.strainTarget[0]) return { headline: 'Room for a session. 30 min brisk walking reaches your target.', body: [], ask: 'Plan my workout today' };
      return null;
    }
    function noteCard() {
      var n = noteRule(); if (!n || C.noteDismissed) return '';
      return '<div class="card cnote"><div class="row center"><p class="label clab" style="margin:0">' + glyph(1.25, 0.6, 'cg sm') + 'Coach</p>' +
        '<button class="xbtn" data-note-x="1" aria-label="Dismiss coach note">' + X.I.close + '</button></div>' +
        '<p class="headline" style="margin-top:4px">' + esc(n.headline) + '</p>' + (n.body.length ? '<p class="body" style="margin-top:4px">' + esc(n.body.join(' ')) + '</p>' : '') +
        '<div class="cchips" style="margin-top:12px"><button class="cchip" data-note-ask="' + esc(n.ask) + '">' + esc(n.ask) + '</button><button class="cchip" data-note-x="1">Not today</button></div>' +
        '<p class="caption" style="margin-top:8px">Rule-based note from your numbers. Sample data.</p></div>';
    }

    // ------------------------------------------------------------ plan runner (step timer)
    function findMsg(id) { id = +id; for (var i = 0; i < C.msgs.length; i++) if (C.msgs[i].id === id) return C.msgs[i]; return null; }
    function openRunner(id) {
      var m = findMsg(id); if (!m) return;
      var p = PLANS[m.r.plan], ch = C.checks[id] || {}, start = 0;
      while (start < p.steps.length - 1 && ch[start]) start++;
      C.runner = { id: +id, plan: p, i: start, left: p.steps[start].sec || 0, paused: false, last: Date.now(), done: false, prev: document.activeElement };
      var layer = document.getElementById('runnerLayer') || (function () { var d = document.createElement('div'); d.id = 'runnerLayer'; X.app.appendChild(d); return d; })();
      layer.innerHTML = '<div class="runner" role="dialog" aria-modal="true" aria-label="' + esc(p.title) + '"></div><p class="vh" aria-live="assertive" id="runLive"></p>';
      drawRunner(true);
      clearInterval(C.rt); C.rt = setInterval(tickRunner, 250);
      var b = layer.querySelector('[data-rn="toggle"],[data-rn="done"]'); if (b) b.focus({ preventScroll: true });
    }
    function tickRunner() {
      var R = C.runner; if (!R || R.done) return;
      var now = Date.now(), dt = (now - R.last) / 1000; R.last = now;
      var s = R.plan.steps[R.i];
      if (R.paused || !s.sec) return;
      var before = Math.ceil(R.left);
      R.left -= dt;
      if (R.left <= 0) { finishStep(); return; }
      if (Math.ceil(R.left) !== before) drawRunner();
    }
    function finishStep() {
      var R = C.runner; (C.checks[R.id] = C.checks[R.id] || {})[R.i] = true;
      if (navigator.vibrate) try { navigator.vibrate(20); } catch (_) {}
      moveTo(R.i + 1);
    }
    function moveTo(i) {
      var R = C.runner;
      if (i >= R.plan.steps.length) { R.done = true; drawRunner(true); var l = document.getElementById('runLive'); if (l) l.textContent = 'Done.'; return; }
      R.i = Math.max(0, i); R.left = R.plan.steps[R.i].sec || 0; R.last = Date.now();
      drawRunner(true);
      var lv = document.getElementById('runLive'); if (lv) lv.textContent = 'Step ' + (R.i + 1) + ': ' + R.plan.steps[R.i].name;
    }
    function drawRunner(full) {
      var R = C.runner, el = document.querySelector('#runnerLayer .runner'); if (!R || !el) return;
      var p = R.plan, n = p.steps.length;
      if (R.done) {
        var got = p.steps.filter(function (_, i) { return (C.checks[R.id] || {})[i]; }).length;
        el.innerHTML = '<div class="rtop"><span></span><p class="label" style="text-align:center">' + esc(p.title) + '</p><button class="rbtn press" data-rn="close" aria-label="Close">' + X.I.close + '</button></div>' +
          '<div class="rmid"><span class="ring" style="width:220px;height:220px">' + X.tickRing(220, 1, 'var(--ember)', { ticks: 60, tl: 10, tw: 2.5 }) + '<span class="rv"><b class="display">' + got + '<span class="unit" style="font-size:17px">of ' + n + '</span></b></span></span>' +
          '<p class="title" style="margin-top:32px">Done.</p><p class="body" style="margin-top:8px;color:var(--graphite)">' + got + ' of ' + n + ' steps done. Not saved to Apple Health.</p></div>' +
          '<div class="rctl"><button class="startbtn press big" data-rn="close">Close</button></div>';
        return;
      }
      var s = p.steps[R.i], prog = s.sec ? 1 - R.left / s.sec : 1, nx = p.steps[R.i + 1];
      var ring = X.tickRing(220, prog, 'var(--ember)', { ticks: 60, tl: 10, tw: 2.5 });
      var big = s.sec ? mmss(R.left) : esc(s.reps || '');
      if (!full) {
        var rg = el.querySelector('.rring'), bg = el.querySelector('.rbig');
        if (rg && bg) { rg.innerHTML = ring; bg.textContent = big; return; }
      }
      el.innerHTML = '<div class="rtop"><span></span><p class="label" style="text-align:center">Step ' + (R.i + 1) + ' of ' + n + '</p><button class="rbtn press" data-rn="close" aria-label="Close">' + X.I.close + '</button></div>' +
        '<div class="rmid"><span class="ring" style="width:220px;height:220px"><span class="rring">' + ring + '</span><span class="rv"><b class="display rbig">' + big + '</b></span></span>' +
        '<p class="title" style="margin-top:32px">' + esc(s.name) + (s.reps && s.sec ? ' <span class="label">' + esc(s.reps) + '</span>' : '') + '</p>' +
        '<p class="body" style="margin-top:8px;color:var(--graphite)">' + esc(s.cue) + '</p>' +
        '<p class="caption" style="margin-top:16px">' + (nx ? 'Next: ' + esc(nx.name) + (nx.sec ? ', ' + mmss(nx.sec) : '') : 'Last step') + '</p></div>' +
        '<div class="rctl"><button class="rbtn press" data-rn="back" aria-label="Previous step"' + (R.i ? '' : ' disabled') + '>' + ICON.back + '</button>' +
        (s.sec ? '<button class="playbtn press" data-rn="toggle" aria-label="' + (R.paused ? 'Resume' : 'Pause') + '">' + (R.paused ? ICON.play : ICON.pause) + '</button>'
          : '<button class="startbtn press big" data-rn="done">Done</button>') +
        '<button class="rbtn press" data-rn="skip" aria-label="Skip step">' + ICON.skip + '</button></div>' +
        '<p class="caption" style="text-align:center;margin-top:16px">Stop if you feel pain or dizziness.</p>';
    }
    function closeRunner() {
      var R = C.runner; clearInterval(C.rt); C.runner = null;
      var layer = document.getElementById('runnerLayer'); if (layer) layer.innerHTML = '';
      if (R) refreshPlan(R.id);
      if (R && R.prev && R.prev.isConnected) R.prev.focus({ preventScroll: true });
    }
    function refreshPlan(id) {
      var m = findMsg(id), el = document.getElementById('m' + id); if (!m || !el) return;
      var tmp = document.createElement('div'); tmp.innerHTML = planHTML(m, null);
      var plan = el.querySelector('.plan'); if (plan) plan.replaceWith(tmp.firstChild);
    }

    // ------------------------------------------------------------ events
    X.app.addEventListener('click', function (e) {
      var t = e.target.closest('[data-ask],[data-coach],[data-newchat],[data-check],[data-run],[data-rn],[data-note-x],[data-note-ask]');
      if (!t) return;
      var ds = t.dataset;
      if (ds.ask) ask(ds.ask);
      else if (ds.coach) goCoach(topicQuestion(ds.coach));
      else if (ds.newchat) newChat();
      else if (ds.noteAsk) { var n = noteRule(); goCoach(ds.noteAsk, n ? { headline: n.headline, body: n.body } : null); }
      else if (ds.noteX) { C.noteDismissed = true; var c = t.closest('.cnote'); if (c) c.remove(); }
      else if (ds.check) {
        var k = ds.check.split(':'), ch = (C.checks[k[0]] = C.checks[k[0]] || {});
        ch[k[1]] = !ch[k[1]]; refreshPlan(k[0]);
        var nb = document.querySelector('[data-check="' + ds.check + '"]'); if (nb) nb.focus({ preventScroll: true });
      }
      else if (ds.run) openRunner(ds.run);
      else if (ds.rn) {
        var R = C.runner; if (!R) return;
        if (ds.rn === 'close') closeRunner();
        else if (ds.rn === 'toggle') { R.paused = !R.paused; R.last = Date.now(); drawRunner(true); var tb = document.querySelector('[data-rn="toggle"]'); if (tb) tb.focus(); }
        else if (ds.rn === 'done') { finishStep(); var db = document.querySelector('[data-rn="done"],[data-rn="toggle"],[data-rn="close"]'); if (db) db.focus(); }
        else if (ds.rn === 'skip') { moveTo(R.i + 1); }
        else if (ds.rn === 'back') { moveTo(R.i - 1); }
      }
    });
    document.addEventListener('keydown', function (e) { if (e.key === 'Escape' && C.runner) { e.stopImmediatePropagation(); closeRunner(); } }, true);

    function mounted() {
      var f = document.getElementById('composer'), ta = document.getElementById('cin');
      if (!f || !ta) return;
      function grow() { ta.style.height = 'auto'; ta.style.height = Math.min(ta.scrollHeight, 5 * 21 + 20) + 'px'; }
      ta.addEventListener('input', function () { C.draft = ta.value; grow(); });
      ta.addEventListener('keydown', function (e) { if (e.key === 'Enter' && !e.shiftKey && !e.isComposing) { e.preventDefault(); f.requestSubmit ? f.requestSubmit() : f.dispatchEvent(new Event('submit', { cancelable: true })); } });
      f.addEventListener('submit', function (e) { e.preventDefault(); if (C.busy || !ta.value.trim()) return; var v = ta.value; ta.value = ''; C.draft = ''; grow(); ask(v); });
      grow();
      if (C.msgs.length) { var sc = document.getElementById('scroll'); if (sc) sc.scrollTop = sc.scrollHeight; }
    }

    // ?tab=coach&ask=recovery,plan seeds a finished conversation (screenshots).
    var seed = X.Q.get('ask');
    if (seed) seed.split(',').forEach(function (k) { if (A[k]) ask(A[k].q || k, { key: k, instant: true }); });

    return { view: view, mounted: mounted, composer: composerHTML, mark: mark, slot: slot, wrap: wrap, askRow: askRow, note: noteCard,
      tabIcon: function (on) { return on ? ICON.tabOn : ICON.tabOff; }, goCoach: goCoach, _route: route, _answers: A };
  };
})();
