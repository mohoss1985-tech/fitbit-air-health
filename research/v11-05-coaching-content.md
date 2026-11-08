# v11-05 · Coaching content: evidence, rules, skills, grounding

Scope: what the coach may recommend, when, from which MRH1 numbers, and how the model fetches them. Works with an on-device or cloud model and is sized for Apple's small on-device context.

## Sources

| # | Guidance | Used for |
|---|---|---|
| S1 | WHO 2020: 150–300 min moderate or 75–150 vigorous a week, strength ≥2 days. https://www.ncbi.nlm.nih.gov/pmc/articles/PMC7719906/ | weekly targets |
| S2 | AASM/SRS: adults ≥7 h, ≤6 h inadequate. https://aasm.org/aasm-and-srs-publish-new-sleep-duration-consensus-statement/ · https://www.aasm.org/resources/pdf/adultsleepdurationconsensus.pdf | sleep floor |
| S3 | Windred 2023: regularity predicts mortality more than duration (n≈61k). https://www.ncbi.nlm.nih.gov/pmc/articles/PMC10782489/ | consistency rules |
| S4 | Drake 2013: caffeine 6 h before bed cut sleep >1 h, unnoticed. https://pmc.ncbi.nlm.nih.gov/articles/PMC3805807/ | caffeine cut-off |
| S5 | Readiness-guided training RCTs: equal or better gains, fewer hard days. https://pmc.ncbi.nlm.nih.gov/articles/PMC9518028 · https://clinicaltrials.gov/study/NCT04150952 | readiness-guided intensity |
| S6 | Mishra 2020: RHR above personal baseline preceded most COVID symptoms; travel, cycle, altitude also trigger. https://www.medrxiv.org/content/10.1101/2020.07.06.20147512v1 · https://medicalxpress.com/news/2020-12-smartwatch-early-illness.pdf | RHR/breathing "watch" flag |
| S7 | Gabbett 2016 ACWR 0.8–1.3, >1.5 spike; contested (coupling). https://www.frontiersin.org/journals/physiology/articles/10.3389/fphys.2020.01034/full | load spikes (soft guidance only) |
| S8 | Seiler 80/20 intensity mix (descriptive, not a rule for amateurs). https://roadmancycling.com/blog/stephen-seiler-80-20-polarised-training-cyclists | zone mix |
| S9 | Paluch 2022: step benefit plateaus 6–8k (60+), 8–10k (<60). https://doaj.org/article/c3639c468b4348958202e52793ab979d | step goals |
| S10 | Balban 2023: 5 min cyclic sighing beat mindfulness for mood. https://med.stanford.edu/news/insights/2023/02/cyclic-sighing-can-help-breathe-away-anxiety.html | breathing skill |
| S11 | Zaccaro 2018: breathing <10/min raises HRV, relaxation. https://pubmed.ncbi.nlm.nih.gov/30245619/ | resonance breathing |
| S12 | ACSM: stretch 2–3 days/wk, hold 10–30 s (30–60 s older). https://www.acsm.org/blog-detail/acsm-certified-blog/2021/03/18/stretching-and-flexibility-guidelines-update | mobility skill |
| S13 | Neck check: above-neck → light; below-neck or fever → rest. https://face.meei.harvard.edu/should-you-workout-when-sick | "Feeling unwell" tag |
| S14 | App Store 5.1.2(i) (Nov 2025): explicit consent before data goes to third-party AI. https://techcrunch.com/2025/11/13/apples-new-app-review-guidelines-clamp-down-on-apps-sharing-personal-data-with-third-party-ai | consent, safety |
| S15 | Foundation Models: `Tool` protocol, `@Generable` output. https://blakecrosley.com/blog/foundation-models-on-device-llm · https://www.atelier-socle.com/en/articles/foundation-models-api-guide | tool design |

Caveats: S5/S6 are small and HRV-based; MRH1 has no HRV, so readiness rests on RHR, breathing and sleep. S7 is contested, so load advice stays soft.

## Rules

Rules run in Swift (`CoachRules`); the model only explains fired rules from `get_signals`. Field names are real APIs.

**Inputs:** `recovery.score` (bands ≥67/34–66/<34), `contributors[].z`, `signalsText` (HRV never sent → "3 of 4"), `Scores.strainTarget` (14–17/10–14/5–10; 8–12 if nil), `strain.value`, `zoneMinutes[5]` (% of maxHR = 208−0.7·age, else 185), `Insights.sleepDebt` (min short of 480, 7 nights), `bedtimeSpread`, `states[id]` (latest, baseline, flag, isConcern, missing, baselineDays), `stressHours[].level` 0–3, `history[]` (14 d), `states[.workoutMinutes].series` (7-day totals, 31 d), journal tags/discoveries.

**Readiness / intensity**
- R1 · recovery <34 **and** sleep debt >300 min → offer only rest, walk or Zone 1–2 ≤30 min, plus mobility. Cite both numbers. (S5, S2)
- R2 · recovery <34 with debt ≤300 → Zone 1–2 up to 45 min. No intervals. Strength allowed at 2 reps in reserve or more.
- R3 · recovery 34–66 → steady Zone 2, or technique and strength work. At most one short Zone 3 block. Aim inside `strainTarget`.
- R4 · recovery ≥67 **and** no hard day (strain ≥14) yesterday → intervals (Zone 4–5) allowed, aiming 14–17.
- R5 · two hard days in a row (strain ≥14 on both) → day 3 is easy whatever the recovery. This is the "no two consecutive hard days" rule from S5.
- R6 · today's strain ≥ upper bound of target → "Target reached", suggest a cool-down or walk only. This extends the v1.0 copy.
- R7 · no recovery score (`nil`, calibrating) → keep it general and moderate, and say "Early read: N of 14 baseline days."

**Watch signals** (use the "Watch" tier, never a diagnosis)
- W1 · resting HR ≥ baseline.mean + 5 bpm on **2 nights in a row**. Compute the mean from the series without its last 2 values. → flag it, suggest easy days, fluids and sleep. Mention alcohol, heat, travel or illness as *possible* causes. (S6, existing `ifHigh` copy)
- W2 · breathing rate ≥ baseline + 1.0 /min with W1 → "2 signals are outside your usual range", rest day suggested.
- W3 · SpO2 <93 % on 3 or more of the last 7 nights → state it neutrally, suggest asking a doctor. Any night <90 % → "see a doctor" line (existing copy). No training advice either way.
- W4 · journal tag "Feeling unwell" today or yesterday → apply the neck check: light only, or rest with fever or chest symptoms. Override R3 and R4. (S13)
- W5 · 3 or more hours with stress `level ≥2` today while not moving → offer the breathing skill.

**Sleep**
- S-a · last night <420 min (7 h) → mention it. If ≤360 (6 h), call it "short" and apply R2 as a cap. (S2)
- S-b · `bedtimeSpread` >45 min (consistency <64) → "Keep bedtime within 30 min" ranks above duration tips. (S3)
- S-c · discovery or tag "Caffeine after 2 pm" linked to a lower sleep score → caffeine cut-off 8 h before bed (S4: ≥6 h, plus margin).
- S-d · deep or REM below baseline on a night tagged "Alcohol" or "Late meal" → name the tag and the minutes lost.
- S-e · sleep debt >300 min → suggest one earlier night (+30–45 min). Do not suggest long lie-ins (S3).

**Load and weekly volume**
- L1 · weekly moderate minutes = `workoutMinutes` latest. <150 → "N min to the 150 a week guideline". ≥300 → praise, then check recovery trend. (S1)
- L2 · acute:chronic = latest 7-day workout minutes ÷ mean of the 4 prior weekly totals. >1.5 → "Big jump vs your usual week: ease in." Soft wording only (S7).
- L3 · zone mix over 7 days from `zoneMinutes`: if Zone 3 share > Zone 1–2 share on training days → suggest one session be truly easy. (S8)
- L4 · no strength workout in the last 7 days (`WorkoutItem.name == "Strength"`) → suggest 2 sessions this week. (S1)
- L5 · yesterday's steps (`states[.steps]`) under 5,000 → walking nudge. Goal is 8–10k under 60, 6–8k for 60+, by `age`. (S9)

**Explaining**
- E1 · "Why is X low/high" → name the contributor with the most negative `z`, its value against `yourRangeText`, and one journal tag from the day before if present. Never invent a cause. Give at most 2 possible causes from `MetricInfo.ifHigh` / `ifLow`.

## Skill catalogue

Each skill = one intent + required tools + output card. Every reply ends with 3 chips. Card types: `Plan` (workout from the library), `Routine` (timed steps), `Explain` (numbers vs your normal), `Review` (week table), `Breathe` (animated pacer), `Tip` (one action).

| # | Skill (chip text) | Tools | Card | Follow-up chips |
|---|---|---|---|---|
| 1 | Plan my workout today | today, signals, load, profile, library | Plan | Make it shorter · Indoor version · Why this? |
| 2 | Why is my recovery low? | today, metric(restingHR, breathing), journal | Explain | What helps today? · Show 14 days · Is this a concern? |
| 3 | Why is my recovery high? | same | Explain | Plan a hard session · Weekly review · Keep it going |
| 4 | How hard should I go? | today, signals | Tip (target band) | Plan my workout · What's strain? · Tomorrow? |
| 5 | Help me sleep better | sleep, journal, signals | Routine (evening plan) | Wind-down now · Caffeine cut-off · Track tags |
| 6 | Why did I sleep badly? | sleep, journal, metric(awake) | Explain | Help me sleep better · Last 7 nights · Tag tonight |
| 7 | Pay back my sleep debt | sleep | Tip | Set bedtime nudge · Is a nap OK? · Weekly review |
| 8 | Wind-down routine (10 min) | library(wind-down) | Routine | Breathing only · Longer · Done |
| 9 | Make a 10-min mobility routine | profile, library(mobility) | Routine | Hips focus · Desk version · 5 min |
| 10 | Post-run stretch | today(workouts), library | Routine | Longer holds · Next run? · Done |
| 11 | Calm me down (breathing) | today(stress), library(breath) | Breathe | Another round · Why it works · Done |
| 12 | Breathing to fall asleep | library(breath) | Breathe | Wind-down routine · Done |
| 13 | Weekly review | weekly, load, sleep, journal | Review | Plan next week · Best change · What slipped? |
| 14 | Plan my week | load, profile, signals, library | Review (7-day grid) | Fewer days · Add strength · Swap a day |
| 15 | Am I training too much? | load, signals | Explain | Plan a deload · Show strain 14 days · Weekly review |
| 16 | Explain my strain | today(zones) | Explain | How hard should I go? · Zones explained |
| 17 | What are my heart rate zones? | profile | Explain (zone table in bpm) | Plan Zone 2 · Set my max HR |
| 18 | My resting heart rate is up | metric(restingHR), signals, journal | Explain | Should I train? · Show 30 days · Tag cause |
| 19 | I feel unwell | signals, today | Tip (neck check) | Rest-day plan · When to train again? |
| 20 | Rest-day plan | library(recovery) | Routine | Mobility · Walk only · Breathing |
| 21 | Quick strength (20 min, no gear) | profile, library(strength) | Plan | Harder · Easier · Add warm-up |
| 22 | Walk more | metric(steps), today | Tip | Plan a walk · Step goal for me |
| 23 | What do my tags show? | journal | Explain (discoveries) | Help me sleep better · Add a tag |
| 24 | Set my goal | profile (write) | Form (goal, days a week, gear, limits) | Plan my week |
| 25 | What can you see? | none | Explain (data list, "Not sent" items, privacy) | Plan my workout · Weekly review |

Home chips by time of day: morning 1, 2/3, 4 · afternoon 4, 21, 11 · evening 5, 8, 12 · Monday 13 first.

### Workout / exercise library format

Bundled, human-reviewed `CoachLibrary.json` (~60 entries). The model selects and sets duration; it never writes exercises.

```json
{ "id": "z2-run-30", "name": "Easy Zone 2 run", "kind": "cardio",
  "modes": ["run","ride","walk","row"], "minutes": [20, 45], "zones": [1, 2],
  "strainEstimate": [5, 9], "recoveryMin": 0, "equipment": [],
  "steps": [ {"label":"Warm up","minutes":5,"zone":1,"cue":"Easy enough to chat"},
             {"label":"Steady","minutes":"rest","zone":2,"cue":"Nose breathing if you can"},
             {"label":"Cool down","minutes":5,"zone":1} ],
  "avoidIf": ["fever","chestSymptoms"], "source": "S1,S8" }
```
Strength/mobility steps: `{"reps":"8–12","sets":2,"holdSec":30,"sides":true}`; breath: `{"pattern":[4,0,6,0],"rounds":10}`. Starter set: cyclic sigh (S10), 6/min resonance (S11), box breathing, Zone 2, 4×4 intervals (R4 only), 20-min bodyweight strength A/B, 10-min mobility (30 s holds, S12), desk mobility, post-run stretch, wind-down. Swift renders zones in bpm.

## Tools & system prompt

Read-only wrappers over the `HealthStore` snapshot (no HealthKit query per call); compact JSON <400 tokens; numbers pre-formatted so the model copies, never computes.

| Tool | Params | Returns (maps to) |
|---|---|---|
| `get_today` | — | `{recovery:{score,band:"green|yellow|red",signals:"3 of 4",contributors:[{metric,value,z}]}, sleepScore, strain:{now,target:[lo,hi],zoneMin:[5]}, stressNow:"Calm|Medium|High", steps, activeKcal, workouts:[{name,min}], syncedMinAgo, demo}` ← `recovery`, `sleepScore`, `strain`, `Scores.strainTarget`, `stressHours.last`, `stepsToday`, `activeEnergyToday`, `todayWorkouts`, `syncAge`, `isDemo` |
| `get_metric` | `id` (MetricID rawValue), `days` ≤30 | `{name,latest,unit,yourRange,flag,isConcern,missing,earlyRead,trend,series:[[date,v]]}` ← `MetricState`, `Insights.trend` |
| `get_sleep` | `nights` ≤14 | `{last:{asleep,inBed,efficiency,deep,rem,light,awake,start,end}, debtMin, bedtimeSpreadMin, consistency, nights:[[date,asleepMin,score]]}` ← `lastSleep`, `recentNights`, `Insights.sleepDebt/bedtimeSpread/consistencyScore` |
| `get_load` | `days` ≤14 | `{days:[[date,recovery,strain,sleepMin,steps]], weekWorkoutMin, acwr, strengthDays7, zoneMix7}` ← `history`, `states[.workoutMinutes]`, workouts |
| `get_signals` | — | `{fired:[{rule:"W1",text,metrics:[...]}], cap:"rest|easy|moderate|any"}` ← `CoachRules` (new) |
| `get_journal` | `days` ≤7 | `{tags:[[date,[tag]]], discoveries:[String]}` ← `JournalStore` |
| `get_weekly` | — | `WeeklyReport` fields + best/worst trend sentences |
| `get_profile` | — | `{age, maxHR, zonesBpm:[[lo,hi]x5], goal, daysPerWeek, equipment, limits}` ← `age`, `maxHeartRate()`, new `CoachProfile` (@AppStorage) |
| `find_sessions` | `kind`, `minutes`, `maxZone`, `equipment` | ≤3 library entries, filtered in Swift by `cap` and `avoidIf` |

**Output is typed**, using `@Generable` (S15) or JSON schema for a cloud model:
`CoachReply { headline: String /*≤14 words*/, body: [String] /*≤3 sentences*/, cites: [Cite{metric, value, vsNormal}], card: CardKind?, sessionID: String?, sessionMinutes: Int?, chips: [String] /*exactly 3*/ }`.
SwiftUI renders the card. A validator rejects any number not found in tool results or a session above `cap`; one retry, then a template reply.

**System prompt draft**

```
You are the MRH1 coach. You help one person train, sleep and recover using their own
Fitbit Air data from Apple Health. You give wellness guidance, not medical advice.

Always:
- Call tools before answering. Use only numbers returned by tools; never estimate or compute.
- Lead with one headline of 14 words or fewer: the change, vs their normal, one action.
- Cite 1–3 numbers with "your normal" (e.g. "Resting HR 58 bpm, your normal 51–55").
- At most 3 short sentences after the headline. Second person, calm, sentence case.
  No exclamation marks, no emoji.
- Respect get_signals.cap. Never suggest intensity above it.
- Pick workouts and routines only with find_sessions. Do not invent exercises.
- If data is missing, say so with the app's words: "Not sent by Google Health",
  "Waiting for sync" or "No reading". HRV, skin temperature and VO2 max are never sent.
- If the baseline is young, say "Early read: N of 14 baseline days."
- End with exactly 3 short follow-up chips.

Never:
- Name or suggest a disease, diagnosis, medication, supplement dose or diet plan.
- Say "danger", "abnormal" or "risk of injury". Use "outside your usual range" and "Watch".
- Give advice about pregnancy, eating disorders, heart conditions or medication.
  Instead say this needs a doctor and offer general rest guidance.
- Claim certainty about causes. Use "often", "can", "possible".

If the person mentions chest pain, fainting, severe shortness of breath, thoughts of
self-harm, or asks for emergency help: reply only with "This needs a person, not an app.
Please contact local emergency services or a doctor now." and no chips except "OK".
```

The emergency branch is also detected in Swift with keyword matching *before* the model runs, so it works even if the model fails.

**Short and grounded:** typed length caps, pre-formatted numbers, numeric validator, thresholds in code; history trimmed to 6 turns plus a local "what we agreed" note.

## Decisions for MRH1 v1.1

1. **Rules engine in Swift (`CoachRules.swift`)** implements R1–R7, W1–W5, S-a–S-e, L1–L5 exactly as written above. It outputs `fired[]` and `cap` (rest / easy / moderate / any). The LLM explains rules. It never decides them.
2. **Intensity cap is hard.** `find_sessions` filters out any session above `cap`, and the reply validator rejects any reply that breaks it.
3. **W1 uses 2 consecutive nights** at +5 bpm over a mean that leaves those 2 nights out, so one bad night cannot wash out the baseline. W2 needs W1 plus breathing +1.0 /min. Copy: "2 signals are outside your usual range."
4. **ACWR from rolling 7-day workout minutes** (`states[.workoutMinutes].series`, 31 days), because strain history is only 14 days. Soft copy only ("ease in"). The word "injury" never appears.
5. **Sleep advice priority:** regularity (spread >45 min) → duration <7 h → tag-linked causes → debt payback. Caffeine cut-off 8 h before usual bedtime.
6. **Weekly targets:** 150 moderate minutes and 2 strength days (WHO). Step goal 8–10k under 60, 6–8k for 60+ (by HealthKit age, 8k if unknown). No 10,000 dogma.
7. **25 skills ship as in the table**, with time-of-day home chips. Every reply ends with exactly 3 chips. Skills 1, 5, 11 and 13 also work with no model at all (template + rules), so the feature degrades gracefully on devices without Apple Intelligence.
8. **Bundled, human-reviewed `CoachLibrary.json`** (~60 entries, schema above). The model selects and sets duration only. Zones are rendered in bpm from `208 − 0.7·age`.
9. **Nine read-only tools** as listed, each reading the `HealthStore` snapshot with a result under 400 tokens. One new store is needed: `CoachProfile` (goal, days a week, gear, limits) in @AppStorage.
10. **Typed `CoachReply`** with a 14-word headline, ≤3 sentences, 1–3 citations each shown as a "value · your normal" pill, and a numeric validator with one retry, then a template fallback.
11. **Safety:** the system prompt above, plus a Swift pre-filter for emergency keywords, plus no disease, supplement or medication content. Every coach card carries the footer "Wellness estimates, not medical advice."
12. **"What can you see?" skill (#25)** lists exactly which data the coach reads and where it is processed. It is also the 5.1.2(i) consent screen when any off-device model is used (S14). It must be the first coach screen and shown before any send.
13. **Demo mode:** with `isDemo` set, the coach runs on demo data and labels replies "Sample data", so App Review can test every skill without a Fitbit.
