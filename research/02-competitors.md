# 02 · Competitive UX research

Agent 02 · 2 Nov 2026 · Sources are web search, review sites, App Store listings, and Reddit/community snapshots (Reddit was only reachable through mirrors). Claims marked *(unverified)* rest on one secondary source.

## Sources

- Fitbit Air and Google Health: [Thurrott review](https://www.thurrott.com/smart-tech/338097), [Thurrott: GH writes to Apple Health](https://www.thurrott.com/wearables/339986/google-health-ios-app-can-now-write-data-to-apple-health), [Wareable launch](https://www.wareable.com/fitbit/fitbit-air-official-announcement-price-features-release-date), [the5krunner sampling and BLE](https://the5krunner.com/2026/06/03/fitbit-air-accuracy-sampling-rate/), [TechRadar "unbelievably bad"](https://techradar.com/health-fitness/fitness-apps/google-health-is-getting-heat-for-being-unbelievably-bad-after-replacing-the-fitbit-app-but-google-says-fixes-are-coming), [BGR](https://bgr.com/2182325/fitbit-users-cant-stand-latest-update/), [iPhoneInCanada fixes](https://www.iphoneincanada.ca/2026/06/06/google-health-app-update-fixes-broken-fitbit-account-transfers-and-sleep-scores/), r/fitbit snapshots ([1](https://reddit.sentinel-team.org/posts/1teu69p/snapshots/2026-05-16T16%3A28%3A29.337372Z)), plus local frames in `reference-captures/google-health/`
- Whoop: [5.0 app changes](https://www.community.whoop.com/t/what-s-new-with-how-the-app-looks/822), [home screen](https://www.whoop.com/thelocker/the-all-new-whoop-home-screen), [Daily Outlook](https://gadgetsandwearables.com/2025/01/24/whoop-daily-outlook/), [Coach (OpenAI)](https://whoop.com/thelocker/introducing-whoop-coach-powered-by-openai), [pricing](https://engadget.com/2242774/most-expensive-whoop-membership-life-why-pay/), [upgrade backlash](https://techcrunch.com/2025/05/11/fitness-tracker-whoop-faces-unhappy-customers-over-upgrade-policy), [coach ignores preferences](https://www.community.whoop.com/t/daily-outlook-coach-not-learning-from-my-preferences/15543), [r/whoop snapshot](https://reddit.sentinel-team.org/subreddits/whoop/snapshots/2026-05-16T17%3A44%3A25.911535Z)
- Oura: [Oura blog: new app](https://ouraring.com/blog/new-oura-app-experience/), [9to5Google](https://9to5google.com/2025/10/20/oura-app-redesign/), [Engadget](https://www.engadget.com/wearables/ouras-new-app-brings-enhanced-health-insights-and-longer-fertility-window-predictions-171329174.html)
- Apple: local frames in `reference-captures/apple-health/`, [Health+ scaled back (MacTrast)](https://www.mactrast.com/2026/02/apple-reportedly-scaling-back-plans-for-apple-health-in-ios-27/), [Cult of Mac](https://www.cultofmac.com/news/apple-shifts-ai-health-coach-plans)
- Garmin: [DC Rainmaker](https://dcrainmaker.com/2024/01/garmin-connect-through.html), [Advnture feedback](https://www.advnture.com/news/garmin-connect-feedback), [Body Battery insights](https://www.notebookcheck.net/Garmin-improving-Body-Battery-and-new-health-glance-features.1159529.0.html)
- Ultrahuman: [NBC Select](https://www.nbcnews.com/select/amp/rcna202789), [Tom's Guide](https://tomsguide.com/reviews/ultrahuman-ring-air-review-a-lighter-fitness-tracking-ring-without-a-subscription), [T3 Dynamic Recovery](https://www.t3.com/news/ultrahuman-dynamic-recovery-strava-0524)
- Samsung: [Android Central redesign](https://androidcentral.com/phones/samsung-galaxy/samsung-health-app-is-all-new-features-take-the-guesswork-your-wellbeing), [TechRadar bedtime guidance](https://www.techradar.com/health-fitness/smartwatches/the-next-galaxy-watch-will-read-toxins-give-you-useful-bedtime-guidance-and-become-the-running-coach-you-always-wanted)
- Indie: [Bevel App Store](https://apps.apple.com/us/app/6456176249), [Bevel review](https://www.autonomous.ai/ourblog/bevel-app-review), [Athlytic App Store](https://apps.apple.com/gb/app/id1543571755), [TechRadar Athlytic](https://techradar.com/computing/websites-apps/this-app-turns-my-apple-watch-into-a-whoop-band), [Gentler Streak (Digital Trends)](https://www.digitaltrends.com/?p=3165528), [Lifestack: Gentler Streak](https://lifestack.ai/blog/gentler-streak). I found no current coverage of Training Today or Cardiogram; both entries rely on prior knowledge *(unverified for 2026)*.

## The Fitbit Air itself (what MRH1 can count on)

- **Sensors:** optical HR, red/IR SpO2, device temperature, 3-axis accelerometer, gyroscope, vibration motor. No screen and no GPS. Bluetooth 5.0, about 7 days of battery, stores 30 days of daily totals offline. $99, or $130 for the Special Edition.
- **No standard BLE Heart Rate Service.** The Air uses a proprietary Bluetooth link that works only with Peloton and Concept2. Garmin and Wahoo head units cannot pair. **MRH1 cannot get true real-time HR over BLE**, so the Live tab must be built on HealthKit samples and be honest about lag. (This answers PROJECT_NOTES open item 4: no.)
- **HR sampling:** recorded every ~2 s at rest, and on the wrist during sport effectively every ~5 s *(Google says part of this was an export bug)*. Fine for resting HR and sleep, weak for intervals.
- **Google Health (GH) app:** four tabs, Today · Fitness · Sleep · Health. Today and Health are free. The Fitness and Sleep tabs, plus the Gemini "Health Coach", need Premium at $9.99/mo, with 3 months included with the band. GH computes HRV, skin temperature, and a Readiness score, but **only workouts, sleep, and some vitals are written to Apple Health**. The Readiness score and real-time HR are not.
- **Our frames show:** a "Cardio hebdomadaire" (weekly cardio load) ring with a 3×2 grid of colored tiles. Many tiles say "Aucune donnée" (no data). Blue CTAs ("Enregistrer" = Log, "Commencer" = Start) float over everything. Detail pages use Jour/Sem./Mois/3 mois/Année (day to year) segments, a big number with a sentence, then a list of weeks with check marks. The Sleep page has a stage timeline and "Qualité du sommeil" (sleep quality) range sliders labelled above or below range. That last pattern is close to MRH1's "blood-test" idea.

## Per-competitor table

| App | IA (tabs) | Home hierarchy | Signature viz | Live / real-time | Coaching style | Money | Top complaints |
|---|---|---|---|---|---|---|---|
| **Whoop 5.0** | Home · Health (Healthspan, Health Monitor, Stress Monitor) · Community · More | 3 dials (Sleep · Recovery · Strain), then "My Day", Daily Outlook button, timeline, Weekly Plan | Recovery dial in green/yellow/red (≥66 / 34–65 / <34); strain 0–21 with a recommended target band | Live HR and strain during activity; real-time Stress Monitor (0–3) | OpenAI Coach chat, Daily Outlook, Day in Review | $199 / $239 / $359 per year; band included | Upsell ads take screen space; coach ignores preferences; strain feels arbitrary; upgrade-fee backlash; "off body" bugs |
| **Oura** (Oct 2025) | Today · Vitals · My Health (cut down from 5 tabs) | Scores at top, then a time-of-day "one big thing" insight, then a day timeline with tags | Contributor bars; **baseline range band** per metric in Vitals; cumulative stress | Daytime HR and stress curves (not truly live) | Advisor (AI); "Discoveries" link tags to changes in scores | $349+ ring plus $5.99/mo | Membership paywall; frequent IA churn; little stays the same between redesigns |
| **Google Health + Air** | Today · Fitness · Sleep · Health | Weekly cardio ring with a colored tile grid; greeting; "Log / Start" CTAs | Ring with tile grid; range sliders for sleep quality; Readiness | HR during manual workouts only; no iOS widget or Live Activity | Gemini Coach (text only, too agreeable, forgets habits) | Free core; $9.99/mo Premium | "Busier and more cluttered" than Fitbit; forced AI; crashes; slow sync; ~10% iPhone battery use; no widget; old workouts hard to find |
| **Apple Health / Fitness** | Summary · Sharing · Browse | Pinned cards, then **Trends** (one sentence plus a two-average bar chart), then Highlights | Trend bars with two averages; Activity rings; Vitals app with outliers | None in Health; live HR only on the Watch | Sentence insights, no AI (Health+ coach scaled back for iOS 27) | Free | Data dump; no scores; no readiness; Browse is a list of 100 metrics |
| **Garmin Connect** | Customizable "My Day" plus Today's Activity | Big stacked cards (Body Battery, Sleep, Stress, HRV status) | **Body Battery** 5–100 energy curve | Real-time HR from the watch; Body Battery updates during the day | Contextual Body Battery insights; Connect+ AI (paid) | Free; Connect+ $6.99/mo | Redesign cards too big, so more scrolling; lost continuous 7-day/4-week graphs |
| **Ultrahuman** | Home · Ring · Metabolism · Zones / Profile | Home pushes Metabolism and Zones over ring scores | Dynamic Recovery (rises with naps and breathwork); Movement Index | Recovery updates during the day | Nudges ("take it easy") | No subscription for core features | Cluttered; every metric drawn in a different style; core scores buried |
| **Samsung Health** (2025) | Home: Sleep · Activity · Nutrition · Mindfulness · Vitals | Energy Score up top; Vitals vs resting baseline | Energy Score; bedtime guidance window | Watch live HR | AI Energy Score explanations; bedtime suggestions from the last 3 nights | Free (Android-first) | Android-only scores; feature scatter |
| **Bevel** | Home · Fitness · Nutrition · Biology / Journal | Rings (Recovery, Sleep, Strain) plus **Energy Bank** and a Timeline | Energy Bank (a combined battery); muscle-load charts | No | "Bevel Intelligence" AI plus credit packs | Free core; Pro $99/yr | Strain "always low"; metrics differ from Whoop; tracking SDK in privacy label; sync bugs |
| **Athlytic** | Recovery · Exertion · Sleep · Trends | Recovery % hero, then exertion target | Recovery/exertion gauges; Whoop clone | Live exertion during a workout on Watch | Light; AI coach add-on | ~$25–30/yr | Needs Apple Watch HRV; looks generic |
| **Gentler Streak** | Today · Activity Path · Workouts | Mascot (Yorhart) plus readiness copy | **Activity Path** band (too little / optimal / too much) | No | Kind, non-judgmental copy; rest days keep the streak | Free; Premium ~$40/yr | Needs Watch; less depth for athletes |
| **Training Today** | Single screen | One color and one sentence for "train / take it easy" | HRV traffic light | No | Single-verdict copy | Sub | Too thin; Watch HRV only *(unverified)* |
| **Cardiogram** | Heart · Insights | HR timeline per day | Annotated **24 h heart-rate "rope"** with tagged events | Near real-time from HealthKit | Card insights | Free / sub | Abandoned feel; slow updates *(unverified)* |

## Patterns worth stealing

1. **Oura "news front page" Today:** three scores, then **one** time-of-day insight, then a timeline of the day with tags. Most users' daily question is answered in one screen.
2. **Oura Vitals baseline band:** every metric drawn against *your* normal range, with today's dot inside or outside it. This is MRH1's blood-test idea, already validated by Oura and Samsung ("vs resting baseline").
3. **Whoop strain target:** a recommended strain band drawn on the strain dial based on today's recovery. Turns a number into an instruction.
4. **Apple Trends card:** a one-sentence headline, then grey bars with two average lines (old period vs new period). It is the cleanest "is this changing?" chart in the category. See our frames, sheet_01.
5. **GH sleep-quality sliders:** a pill track with a marker and an "above/below range" chip. Reuse it as the visual grammar for every metric row.
6. **Gentler Streak Activity Path:** a band chart of the right amount of activity for you, with copy that never shames. A good tone model.
7. **Cardiogram day rope:** a 24 h HR line annotated with sleep, workouts, and stress spikes. The best basis for the Live tab's 24H view.
8. **Garmin Body Battery's intraday curve:** a score that visibly charges overnight and drains during the day. Users love seeing the slope. MRH1's strain-so-far and stress hourly bars can tell the same story.
9. **Whoop "Hide metrics"** and Oura weekly/quarterly **shareable reports** for doctors: cheap to build, and loved.

## User pain points (what to avoid or fix)

- **Clutter and tile soup:** GH ("busier than Fitbit"), Ultrahuman ("every metric a different style"), Garmin (big cards, more scrolling). MRH1 should use one visual grammar, not a grid of colored tiles.
- **Paywalls on basics:** GH locks the Sleep and Fitness tabs; Whoop and Oura charge for health monitoring. Air buyers chose a $99 band *because* they did not want a subscription.
- **Forced, flaky AI coaches:** Gemini is too agreeable and forgets habits; Whoop's coach ignores preferences. People want a verdict, not a chat.
- **Opaque scores:** "strain always low" (Bevel), "rings make no sense" vs Whoop. Users distrust numbers they can't decompose.
- **Silent missing data:** GH shows "Aucune donnée" tiles everywhere. Users can't tell "not synced yet" from "not measured" from "not shared".
- **Battery and speed:** GH uses ~10% of iPhone battery per day and crashes. No iOS widget.
- **Privacy:** Bevel's label includes tracking. Whoop, Oura, and GH send everything to the cloud.

## Gaps MRH1 can win for Fitbit Air owners

1. **The only Whoop-style scores for the Air on iPhone without a subscription.** The Readiness score GH computes never reaches Apple Health. MRH1 fills that hole.
2. **Honest data provenance:** "Not sent by Google Health" vs "Waiting for sync" vs "No reading", plus a visible sync clock. Nobody does this.
3. **Free sleep detail:** stages, debt, and bedtime consistency, which GH paywalls.
4. **Private by architecture:** zero networking is a selling point to put on the App Store page.
5. **Calm single grammar** where GH has its tile grid and AI nagging.

## Decisions for MRH1

1. **Today, above the fold (iPhone 15 height, no scroll):**
   - (a) Top row: date, the menu (results guide) on the left, + (journal) on the right.
   - (b) **One verdict sentence** in serif ink over the ember orbs, e.g. "Recovered. Room for a hard session." This is the Oura "one big thing".
   - (c) **Recovery as the hero number with its ring**, and Sleep and Strain as two smaller dials beside or below it, in Whoop order Sleep · Recovery · Strain. Nothing else competes.
   - (d) A strain ring showing **today's target band** (Whoop pattern) and "so far" strain.
   - (e) A **freshness chip:** "Fitbit Air · synced 23 min ago". It turns yellow after 3 h and offers to open Google Health.
   - (f) Recovery shows its inputs as a "3 of 4 signals" footnote whenever HRV is missing. Below the fold: the 24 h stress chart, the health-monitor heat map, and the week card. All v0.4 features are kept.
2. **No tile grid anywhere.** Metrics are rows: label · value · **baseline range bar** (GH slider and Oura band) · 7-day sparkline. Every metric uses the same grammar on Today, Body, and Trends.
3. **Missing data has three explicit states**, each with its own glyph and copy, and never a zero or a blank tile: *Not sent by Google Health* (HRV, skin temperature, VO2 max), *Waiting for sync*, and *No reading*.
4. **Live tab = "latest truth", not fake real-time.** The Air has no standard BLE HR profile, so we do not promise a heartbeat stream.
   - **Header:** big latest HR, with a ticking **"latest sample 7 min ago"** that is always visible. A soft ember pulse plays only when a new sample lands (anchored query). The pulse is frozen under Reduce Motion.
   - **Chart:** a Cardiogram-style annotated line with Live · 1H · 24H · 7D · 30D segments (the GH/Apple segmented control) and a min · avg · max strip. The 24H view shades sleep and workouts and marks stress spikes. 7D/30D show daily resting HR inside the baseline band.
   - **"So far today" row:** strain (with its target), stress level now, steps, and active energy. Each uses a thin progress arc.
   - **"Last night" row:** breathing rate and SpO2 against their baseline ranges.
   - **Footer:** "Readings arrive in batches from Google Health" plus an "Open Google Health" button.
5. **Signature viz:** the **baseline ribbon**, a warm paper track. The personal normal range is a soft ink band, and today is an ember dot that turns green, yellow, or red only when it leaves the band (direction-aware). It appears on every metric row, in the detail sheets, and on the Live 7D/30D charts. This is MRH1's equivalent of Whoop's dial and Oura's contributor bars, and it shows the "blood test" story in one glance. The rings stay, but the ribbon is the brand shape.
6. **Trends use the Apple Trends grammar:** one sentence, then grey bars with an old-average line and a new-average line. Only trends that changed are shown. The full list sits behind "All metrics".
7. **Insight copy style:**
   - **Form:** deterministic templates, no chat, no LLM. Each insight is one sentence of at most 14 words: *what changed, by how much vs YOUR baseline, then one action*. Example: "Resting HR 5 bpm above your usual for 3 nights. Go easy today."
   - **Tone (Gentler Streak):** second person and calm. No exclamation marks, no shame, and no "Bravo!" (GH).
   - **Honesty:** say when data is thin: "Early read: 6 of 14 baseline days."
   - **Timing:** the Today headline changes by time of day (Oura): morning = recovery verdict, afternoon = strain so far against target, evening = wind-down and bedtime target (Samsung bedtime guidance, using last 3 nights + consistency).
8. **Score transparency:** tapping any score opens a sheet with its contributors as weighted bars, showing each input's z-score and weight (the `Scores.swift` weights). This answers the "strain makes no sense" complaint directly.
9. **Journal tags become "Discoveries":** after 5 or more tagged days, show "On days tagged *late meal*, sleep score averages 8 lower." This is Oura's best retention feature, and we have the data locally.
10. **Weekly report** gets an export button for a share sheet or PDF to take to a doctor (Oura). The "wellness estimates, not medical advice" line stays in the footer.
11. **Monetization and positioning for the sale:** one-time purchase or a small lifetime unlock, with **no subscription and no upsell banners inside the app**. App Store copy: "Whoop-style scores for your Fitbit Air. No subscription. Your data never leaves your iPhone."
12. **Roadmap after v1.0:**
    - **v1.1:** a WidgetKit widget for Recovery plus freshness, filling the gap GH leaves.
    - **Later:** a Lock Screen accessory. Revisit true live HR only if Google ships standard BLE HRS.
