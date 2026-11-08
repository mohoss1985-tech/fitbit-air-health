# v11-01 · AI health coach competitor teardown

Agent v11-01 · 7 Nov 2026. Sources are official help and blog pages, reviews, and community or Reddit threads (Reddit read through mirrors). Several pages returned 403 (Android Authority, TechRadar body, WHOOP Locker, BusinessWire), so their claims come from search snippets and are marked *(snippet)*. No public source states how many quick-reply chips Google shows, or their exact wording. The chip counts below are MRH1 decisions, not copied values.

## Sources

- **Google Health Coach:** [Google blog: Coach GA, 19 May 2026](https://blog.google/products-and-platforms/products/google-health/google-health-coach/) · [Help: Get started with the Coach](https://support.google.com/googlehealth/answer/16961408?hl=en) · [9to5Google preview UI, Oct 2025](https://9to5google.com/2025/10/27/fitbit-coach-preview/) · [9to5Google Air review](https://9to5google.com/2026/05/28/fitbit-air-review/) · [CGMagazine review](https://www.cgmagonline.com/review/hardware/fitbit-air-and-google-health-coach/) · [TechCrunch preview](https://techcrunch.com/2025/10/27/fitbits-revamped-app-with-gemini-powered-health-coach-rolls-out-to-premium-users/) · [TechCrunch $9.99 launch](https://techcrunch.com/2026/05/07/googles-9-99-per-month-ai-health-coach-launches-may-19/) · [Android Police: I turned off the Coach](https://www.androidpolice.com/turned-off-google-health-coach-fitbit-app/) · [Android Police: Gemini vs Coach](https://www.androidpolice.com/i-let-gemini-track-meals-workouts-it-is-brilliant-health-coach/) · [Android Authority: Premium not worth it](https://www.androidauthority.com/google-health-premium-not-worth-it-3685642/) *(snippet)* · [TechRadar: "unhinged" advice](https://techradar.com/ai-platforms-assistants/fitbits-gemini-ai-coach-is-giving-users-unhinged-fitness-advice-heres-why-users-are-saying-they-cannot-wait-for-my-trial-to-end) *(snippet)* · [Android Authority APK: mute toggle](https://androidauthority.com/google-health-ai-coach-mute-toggle-apk-teardown-3693291) *(snippet)* · [r/fitbit snapshot: "paragraphs of AI slop"](https://reddit.sentinel-team.org/posts/1tp75w2/snapshots/2026-06-05T19%3A13%3A21.214778Z) · [Fitbit community: "Too much to read"](https://community.fitbit.com/t5/Personal-Health-Coach-Public-Preview/Too-much-to-read/td-p/5798615) *(snippet)*
- **WHOOP:** [Coach powered by OpenAI](https://whoop.com/thelocker/introducing-whoop-coach-powered-by-openai) *(snippet)* · [9to5Google hands-on](https://9to5google.com/2023/09/26/whoop-ai-coach-game-changer-hands-on/) · [Daily Outlook](https://gadgetsandwearables.com/2025/01/24/whoop-daily-outlook/) · [2026 roadmap: Proactive Check-Ins, My Memory](https://www.whoop.com/us/en/thelocker/2026-whats-next/) *(snippet)* · [BusinessWire May 2026](https://businesswire.com/news/home/20260508464188/en/WHOOP-Expands-Health-Platform-with-On-Demand-Clinician-Access-and-New-AI-Features) *(snippet)* · [Community: "new Coach feels very different"](https://www.community.whoop.com/t/the-new-whoop-coach-feels-very-different-and-not-in-a-good-way/15960) · [Community: ignores preferences](https://www.community.whoop.com/t/daily-outlook-coach-not-learning-from-my-preferences/15543)
- **Oura:** [Oura Advisor launch](https://ouraring.com/blog/oura-advisor) · [How to use Advisor](https://ouraring.com/blog/how-to-use-oura-advisor/)
- **Ultrahuman:** [IT Brief: Ring PRO and Jade](https://itbrief.co.uk/story/ultrahuman-unveils-ring-pro-jade-ai-health-coach) · [Emerald update: UltraSphere](https://www.daily-tribune.com/online_features/press_releases/ultrahuman-rolls-out-emerald-app-update-with-ultrasphere-decision-engine-for-ring-users/article_6063de53-7830-5372-bf52-c99329af843a.html) *(snippet)*
- **Garmin, Strava, Fitbod:** [DC Rainmaker Connect+ walkthrough](https://dcrainmaker.com/2025/03/garmin-connect-plus-subscription-walkthrough.html) · [TechRadar: Garmin AI "hilariously bad"](https://www.techradar.com/health-fitness/smartwatches/garmins-new-subscription-ai-feature-is-hilariously-bad-so-far) *(snippet)* · [Strava Athlete Intelligence GA](https://www.androidcentral.com/wearables/strava-announces-stable-athlete-intelligence-anti-cheating-and-flyover-sharing) *(snippet)* · [Cycling Weekly: "pointless"](https://cyclingweekly.com/news/strava-says-its-new-ai-feature-is-not-a-novelty-but-i-think-its-pointless) *(snippet)* · [Fitbod blog](https://fitbod.me/blog/the-future-of-ai-in-fitness-how-fitbod-is-redefining-personalized-training/) *(snippet)*
- **Apple:** [9to5Mac: Mulberry delayed](https://9to5mac.com/2026/05/24/apple-improving-heart-rate-tracking-in-watchos-27-mulberry-health-coach-delays/) · [Macworld: "on life support"](https://www.macworld.com/article/3055235/apples-ai-powered-health-service-is-reportedly-on-life-support.html) · [Gizbot: pulled from iOS 27.2 beta 4](https://www.gizbot.com/news/apple-has-been-building-an-ai-health-coach-since-2025-129449.html)

## Findings

### Google Health Coach: concrete anatomy

- **Access and price:** Generally available on 19 May 2026, with 100% rollout on 26 May. It needs Google Health Premium at $9.99/mo or $99/yr. The Fitbit Air includes 3 months. The trial needs a payment method and auto-renews at $9.99. Premium is free with Google AI Pro or Ultra. Users must be 18 or older, live in a listed country, and keep Wi-Fi or internet on. Premium users see a home screen "dedicated primarily to … your Health Coach" (9to5Google).
- **Consent gate:** Before the first chat, a screen shows what data the Coach can access and asks for authorization.
- **Onboarding:** Tap "Chat with Coach" and you get a 5–10 minute text interview. It covers goals, starting point, barriers, routine, equipment, and injuries, and you can skip it. A skipped setup comes back later as a Today top card ("Start your journey with the Google Health Coach") or by typing "Help me set up a goal".
- **Entry points:** A floating "Ask Coach" button on every tab, with History at the top right of the chat. The Fitness tab has a "Create Workout" button. Health has "Summarize my records". Each tab has its own sample prompts (Sleep: "Why did I wake up tired?", "Suggest a wind-down routine". Fitness: "30-min hotel-room upper body workout").
- **Proactive cadence:** Up to 3 Today-tab messages a day: a **morning** note on sleep and readiness, a **post-workout** breakdown, and an **evening** recap of the day and plan progress. Push notifications are not documented. In July 2026, after complaints, Google added "Coach messages on Today → No Coach insights", which applies only to future messages.
- **Chat UI:** Plain chat with text, mic, photo, or PDF input. "Quick-reply chips" sit under Coach messages (the official blog names them, without a count). Inline charts. Thumbs up/down on every reply. Logging works through conversation: the Coach asks follow-ups, then shows a confirm-and-summary card.
- **Plans:** A weekly plan on the Fitness tab sets weekly *targets*, not a fixed calendar. Every day the Coach suggests a focus "based on readiness, progress, and weather". You can change it in chat ("travel, busy treadmill, injury") or with Adjust or Make changes buttons. The plan can be regenerated and takes up to 10 minutes.
- **Workouts:** Generated from natural language ("20-minute Pilates"). Structure is warm-up, main, cool-down. The player is full screen and can shrink to a list. You check off exercises and log reps and weight. A difficulty rating afterwards tunes the next plan. Users can bookmark, edit, reorder, and link a watch-recorded session.
- **Data citing:** Charts can appear inline. Neither the docs nor the reviews show per-claim data references. Reviewers found the Coach invented a 6-mile run and a 15-minute kickboxing session, miscounted the week (rolling vs Sunday start), and forgot workouts (9to5Google).
- **Loved:** Sleep-aware workout timing, memory of goals, meal-photo logging, natural voice and text chat, and plans built around your equipment (CGMagazine, 9to5Google).
- **Hated:**
  1. Verbosity. Users complain of "paragraphs of AI slop on every tab before I can see my data". The Fitbit community team admitted it "erred on the side of verbose".
  2. Constant rest advice: it "suggested I take the day off EVERY SINGLE DAY", and kept urging rest while the user was on vacation.
  3. "Ditch your dog" when the dog slowed the user's pace.
  4. It repeats the graph back: "I already knew everything it told me".
  5. Chips lose context. After tapping "Yes" then "Tonight", the Coach forgot the thread.
  6. It asked about a 3:30 AM wake-up for 3 weeks.
  7. It hides the charts people came for.
  8. The weather tip is generic: "walk before 10 AM".

### Comparison

| | Google Health Coach | WHOOP Coach | Oura Advisor | Ultrahuman Jade | Garmin Active Intelligence | Strava Athlete Intel. | Fitbod | Apple |
|---|---|---|---|---|---|---|---|---|
| Model | Gemini (cloud) | OpenAI (cloud). WHOOP says data is anonymized, zero-retention | Proprietary + LLM (cloud) | Proprietary (cloud) | Cloud, opt-in to model training | Cloud | Algorithmic, not chat | Mulberry unreleased, pulled from 27.2 beta 4 (13 Oct) |
| Chat | Yes, FAB on every tab | Yes, recommended prompts | Yes, "+" on Today plus pre-written prompts | Yes, own tab (Sep 2026), Deep Research mode | No chat, cards only | No chat, text per activity | No | — |
| Proactive | Morning / post-workout / evening cards on Today | Daily Outlook (morning), Day in Review (evening), Proactive Check-Ins (2026: before a big day, after poor sleep) | Opt-in check-ins with **user-set frequency**, nudges (breathwork) | 60+ "next best actions" (UltraSphere) | "Snippets" several times a day, tied to activity and time of day | One summary after each activity | Next workout ready | — |
| Entry from data | Per-tab sample prompts | Home summary button | "Explore in Advisor" link inside Readiness insight | Tab | Strip at top of home | Activity page | — | — |
| Plans / workouts | Weekly targets, daily focus, generated structured workouts with player | Strain target; workout lists in chat, no import to Strength Trainer | Suggestions only | Actions (start breathwork) | — | — | Per-muscle recovery heat map drives the next session | — |
| Memory | Goals kept; History tab | My Memory (2026), viewable | Memories, **review and delete in Settings** | — | — | — | Training history | — |
| Style control | "Ask it to be less verbose" (moderator) | None. Users ask for Data only through Strict styles | **Conversational vs Direct** | Standard vs Deep Research | — | — | — | — |
| Feedback | Thumbs per reply | — | — | — | Thumbs per snippet | — | — | — |
| Price | $9.99/mo, $99/yr, 3 mo free with Air | In membership $199–359/yr | In membership ~$5.99/mo *(1 source)* | In app, no fee stated | Connect+ $6.99/mo, 30-day trial | Subscription | ~$15.99/mo *(1 source)* | — |
| Top complaint | Verbose, rest every day, hallucinated workouts | Deficit framing ("side dish, not a real workout"), labels vacation "stress", can't turn off goals, chats not linked | Few public complaints | Unverified marketing | Platitudes, wrong maths | "Pointless", restates numbers | — | Absent |

**Patterns that recur:**
1. Proactive messages come at 3 fixed moments: wake, after a workout, evening.
2. On-demand chat is one tap from anywhere.
3. Prompts are seeded per context.
4. Every app has a cloud LLM and a paywall. The Coach *is* the premium tier (Google, Garmin), or it is bundled into a membership (WHOOP, Oura).
5. Complaints are mostly about **tone and volume**, not capability: too long, too prescriptive, deficit-framed, repeating the chart, ignoring context such as travel and vacation.

## Gaps MRH1 can win

1. **Privacy.** Every competitor sends health data to the cloud. An on-device coach (Apple Foundation Models, iOS 26+) keeps the v1.0 promise, and no competitor can claim that.
2. **Brevity as a feature.** The top complaint everywhere is length. MRH1's copy rule (≤14 words per insight) can become the coach's identity.
3. **Shows its work.** No competitor shows *which* data a claim used. MRH1 can attach tappable data pills that open existing MetricSheets. That is a direct fix for the hallucinated runs and miscounted weeks.
4. **Honest gaps.** The coach can say "Google Health doesn't send HRV" instead of guessing.
5. **Context from journal tags.** MRH1 already has tags (travel, alcohol, illness). Using them fixes the "rest on vacation" and "pharmacy ride ≠ training" failures.
6. **User-controlled proactivity and style.** WHOOP users ask for these and only Oura has half of it.
7. **Charts stay first.** The coach adds at most one card and never pushes data below the fold.
8. **No subscription treadmill.** Google's coach costs $120/yr after 3 months. On-device inference has no per-user cost.

## Decisions for MRH1 v1.1

1. **One proactive Coach card on Today**, placed directly below the verdict sentence and above the rings. It has three slots: morning (after sleep sync), post-workout (when a new HKWorkout arrives), and evening (from 20:00). There is **at most 1 card visible at a time** and **at most 3 a day**. It is collapsible to a single line, and its state persists.
2. **Proactivity setting:** Off · Important only (only when ≥1 signal is outside its usual range) · Daily (morning only) · Every moment (3/day). The default is **Daily**. A push notification only goes out under "Important only" and is capped at 1 per day.
3. **Style setting:** Direct (default) · Supportive · Numbers only. "Numbers only" turns the coach off and gives plain data sentences.
4. **Length limits:**
   - A proactive card holds 1 headline of ≤14 words plus up to 2 short sentences, ≤40 words total.
   - A chat reply defaults to ≤60 words, with a "More detail" chip to expand it.
   - Hard ceiling: 150 words.
   - No markdown headings and no bullet walls. Lists are allowed only in workouts.
5. **Chips:**
   - Every coach message ends with **exactly 3 tappable chips** of ≤4 words each, chosen from context.
   - Each chip is a full standalone question ("Why is my RHR up?"), never "Yes" or "Tonight", so a tap can't lose the thread.
   - The empty chat shows **4 starter chips**, one each for Recovery, Sleep, Strain, and Plan.
6. **Data pills on every claim.** Each number the coach cites renders as a pill (e.g. "RHR 58 · normal 54–57"). Tapping it opens the existing MetricSheet. The coach may only cite values the app passes in its context. Prompt rule: never invent workouts or values.
7. **Missing data is stated, not guessed.** For HRV, skin temperature, VO2 max, and blood pressure, the coach replies with the NotSent wording ("Not sent by Google Health") plus one sentence on what it can use instead.
8. **Rest rule:**
   - The coach suggests rest only when Recovery is in the red tier, or when sleep debt is ≥2 h *and* Strain is above target.
   - No more than 2 rest suggestions in a row. On the third day it offers a light-movement option instead.
   - Journal tags "travel", "vacation", and "sick" switch the coach to a gentle mode with no strain targets.
9. **No judgments of activity.** The coach never calls a session "not a real workout". Low-strain days are worded as "recovery day", never "below target". Commutes and walks are not tied to goals unless the user tags them.
10. **Entry points:**
    - (a) A Coach round button on the Today header, top-right next to "+".
    - (b) An "Ask about this" chip at the bottom of every MetricSheet and score detail sheet, prefilled with that metric.
    - (c) Tapping the Today coach card opens the chat with that message threaded.
    - The chat opens as a large sheet, not as a 5th tab, so v1.0's IA stays intact.
11. **Onboarding takes ≤60 seconds and is optional.** It is 4 chip-answer questions: goal (Sleep better · Train smarter · Lower stress · Just understand my data), weekly active days (2·3·4·5+), equipment (None · Dumbbells · Gym), and limits (None · Injury · Other). A free-text field follows. Users can skip it, and it can be redone from the menu.
12. **Memory screen in the menu ("What the coach knows")** lists every stored fact (goal, injury, preferences) with delete per item and "Forget everything". Memory is stored on device only.
13. **Weekly targets, not a calendar.** Users set active days and a strain-target range. Each morning the card suggests one focus (e.g. "Easy 30 min, Recovery is 48"), and "Change today" re-plans it in chat.
14. **Workout generator, v1.1 scope:**
    - A structured card: Warm-up · Main · Cool-down, 3–8 exercises, sets×reps or duration, 10–45 min.
    - It is a text card with checkboxes and a "Done" button that writes a journal tag. There is no full-screen player and no video.
    - A difficulty rating afterwards (Easy · Right · Hard) feeds the next suggestion.
    - Bodyweight and dumbbell exercise list only.
15. **Feedback:** Thumbs up/down per message, stored locally, plus a "That's wrong" chip that asks what is wrong and saves the correction to memory.
16. **Safety copy:**
    - Every chat sheet footer reads "Wellness guidance, not medical advice. The coach can make mistakes."
    - Messages about chest pain, fainting, or self-harm get a fixed, non-LLM reply that points to emergency services or a professional.
    - No diagnoses and no medication advice.
17. **Privacy and pricing:**
    - The primary path is on-device inference only, so there is no new network code.
    - If a cloud model is ever added, it is opt-in per user behind a consent screen that lists the exact fields sent, as Google does.
    - Do not copy the trial-with-auto-renew paywall. Price the coach as a one-time unlock or include it in the app price.
    - No paywall interrupts a conversation.
18. **Never hide data.** Body and Trends tabs get no coach cards. On Today, the coach card is the only AI surface.
19. **Repetition guard:** The coach doesn't raise the same observation (same metric and direction) more than once in 3 days unless asked. This fixes the "3:30 AM wake-up for 3 weeks" failure.
20. **No restating the chart.** A proactive card must contain one action or one comparison the UI doesn't already show, such as a link to a journal tag or a multi-day pattern. Otherwise the card is skipped.
