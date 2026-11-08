# v13-01 · Home-screen layouts (Today re-order)

Agent v13-01 · 8 Nov 2026 · Scope: only the vertical order of the home/Today screen. The competitor overview from v1.0 (`02-competitors.md`) is not repeated here. *(unverified)* = the claim comes from one secondary source or from memory of the app, not from a page I read.

## Sources

- **WHOOP:** [All-new home screen](https://www.whoop.com/us/en/thelocker/the-all-new-whoop-home-screen/) (blocked with 403; I used the search summary), [What's new with how the app looks](https://www.community.whoop.com/t/what-s-new-with-how-the-app-looks/822), [the5krunner, Oct 2025 revamp](https://the5krunner.com/2025/10/15/whoop-homescreen-gets-a-revamp), [Feature request: make My Plan/Journal movable above My Day (Apr 2026)](https://www.community.whoop.com/t/feature-request-make-my-plan-my-journal-movable-above-my-day/14411), [Can I customize my home screen?](https://www.community.whoop.com/t/can-i-customize-my-home-screen/570), [Key metrics all in one place](https://www.whoop.com/thelocker/your-key-whoop-metrics-all-in-one-place), [Back nav resets to today (calendar)](https://www.community.whoop.com/t/back-navigation-resets-to-today-from-every-day-detail-page-not-just-activities/15611)
- **Oura:** [New Oura app experience](https://ouraring.com/blog/new-oura-app-experience/), [9to5Google redesign](https://9to5google.com/2025/10/20/oura-app-redesign/), [Support: shortcuts/navigation](https://support.ouraring.com/hc/en-us/articles/360058599753), [Support: Using Tags (calendar at top)](https://support.ouraring.com/hc/en-us/articles/360038676993-Using-Tags)
- **Google Health / Fitbit:** [Google feature map of Google Health](https://support.google.com/product-documentation/answer/17081467), [Google blog: new Fitbit app](https://blog.google/products-and-platforms/devices/fitbit/introducing-the-all-new-fitbit-app/), [TechCrunch Gemini coach](https://techcrunch.com/2025/10/27/fitbits-revamped-app-with-gemini-powered-health-coach-rolls-out-to-premium-users/), [Android Central: customizations](https://androidcentral.com/wearables/fitbit/i-made-the-new-google-health-app-my-own), [Android Authority 5.03 tiles](https://androidauthority.com/google-health-5-03-3685549), plus local frames `reference-captures/google-health/sheet_01.png`
- **Garmin:** [Garmin blog: new Connect mobile](https://www.garmin.com/en-US/blog/fitness/new-garmin-connect-mobile/), [DC Rainmaker: Connect redesign](https://dcrainmaker.com/2024/01/garmin-connect-through.html), [Forum: Edit My Day at bottom](https://forums.garmin.com/apps-software/mobile-apps-web/f/garmin-connect-mobile-ios/148606/my-day-resets-to-defaults), [Forum: cards keep rearranging](https://forums.garmin.com/apps-software/mobile-apps-web/f/garmin-connect-mobile-ios/267089/why-do-my-day-cards-keep-rearranging-and-removed-ones-keep-coming-back)
- **Apple:** [iPhone in Canada: Edit Summary (Fitness, iOS 18)](https://www.iphoneincanada.ca/2025/01/02/customize-your-fitness-app-summary-tab/), [iDrop: customize Fitness summary](https://www.idropnews.com/how-to/how-to-customize-your-iphones-fitness-summary/227225), plus local frames `reference-captures/apple-health/`
- **Bevel / Athlytic:** [ScreensDesign Bevel teardown](https://screensdesign.com/showcase/bevel-health-performance), [Bevel App Store](https://apps.apple.com/app/id6456176249), [Athlytic App Store](https://apps.apple.com/us/app/athlytic-ai-fitness-coach/id1543571755)

## Findings

### Module order, top to bottom

"Fold" means a 6.3″ iPhone with no scroll, about 700 pt of content under the status bar.

| App | 1 (fold) | 2 (fold) | 3 (fold / edge) | 4 | 5 | 6+ | Day selector | Week view | Body/vitals reached |
|---|---|---|---|---|---|---|---|---|---|
| **WHOOP 2025 home** | Header: date "Today", calendar, Coach top-right | **3 dials: Sleep · Recovery · Strain** (moved to the top) | Streak / Daily Outlook entry | "My Day" (activities, strain timeline) | My Plan / Weekly Plan, Journal | **"My Dashboard"** tiles (Customize) → trends | Calendar from the header; no day strip on home | Weekly Plan card on home; trends in each dial's deep dive | Health Monitor and Stress live in a separate **Health tab**; Dashboard tiles about 2–3 scrolls down |
| **Oura (Oct 2025)** | Header with date and calendar | **Score shortcuts row** (Readiness · Sleep · Activity, then HR, Stress, Cycle) | **One "daily highlight"** insight (changes with time of day) | Timeline of the day (tags, activities) | Discoveries (tags vs scores) | none | Swipe left/right or tap the **calendar at the top** to change day; the strip only opens on demand | Vitals tab and Trends (menu); My Health holds the weekly/quarterly reports | Separate **Vitals tab**, 0 scrolls (one tap) |
| **Google Health Today** (frames, 2026) | Header (battery, title, avatar) | **Weekly cardio ring + 6 coloured tiles**, paged ×3 | **Log / Start** buttons + edit pencil | **Coach greeting card** ("Bonjour Mo…") with chips | Coach messages and insights | History of earlier messages | **No day strip on Today.** Day/Wk/Mo/3 mo/Yr tabs and ‹ › arrows only inside the detail pages | Tap a tile → "Wk" tab → "This week / 25–31 Oct" rows | Vitals tiles are in the **first fold** (HR tile), the rest in the Health tab |
| **Garmin Connect (2024+)** | Today's activity (done/planned) | **"In Focus"**: up to 5 swipeable panels | Coach panel (e.g. Sleep Coach) | **At a Glance**: up to 8 small cards, overflow on a second page | Plans / challenges / events (toggle on/off) | 7-day averages card at week end | None on home; Calendar is a separate page *(reader comment)* | Week-end summary card, otherwise each metric's page | Body Battery / HRV / Stress live in In Focus or At a Glance: **0–1 scrolls** |
| **Apple Fitness Summary** | Activity Rings card (fixed, cannot be moved) | Step/distance, Trends | Sessions, Awards, etc. | none | none | "Edit Summary" at the **bottom**: drag to reorder, minus to remove | None: Summary is always today; history via ring card → calendar | Trends card | n/a |
| **Apple Health Summary** | Pinned metrics (user picks, Edit top-right) | Highlights (auto charts, often "this week vs last") | Trends / Get more from Health | none | none | none | None | Highlights are **week-framed by default** | Pinned: 0 scrolls if pinned |
| **Bevel** | Date header | **3 circles: Strain · Recovery · Sleep** | Stress & Energy card | Nutrition, Timeline | Editable cards | none | Date header chevrons *(unverified)* | Per-metric detail | Cards right under the circles: about 1 scroll |
| **Athlytic** | **Week date strip** at top *(unverified)* | Recovery · Exertion · Sleep rings | Target exertion | HRV/RHR cards, workouts | none | none | Top strip *(unverified)* | Per-metric charts | about 1 scroll |

### Concrete patterns

1. **The scores come first.** Every major app (WHOOP, Oura, Bevel, Apple Fitness, Google Health) puts its main scores or rings directly under the header. In WHOOP's 2025 redesign, the change users noticed was the three dials moving to the very top. Only Athlytic *(unverified)* puts a date strip above the scores.
2. **The day selector is the header date or a swipe, not a permanent strip.** Oura uses swipe plus a calendar that opens on demand. WHOOP uses a calendar from the header. Google Health and Garmin have no home-screen day control at all; day/week switching lives inside each metric's page.
3. **There is one insight, then detail.** Oura: scores, then one daily highlight. Google Health: tiles, then the coach greeting. WHOOP: dials, then Daily Outlook. Coach text sits directly under the scores and comes before any secondary cards.
4. **Body/vitals sit high or get their own tab.** Google Health puts HR in the first fold. Garmin's At a Glance sits about one fold down. WHOOP and Oura move vitals to a tab one tap away. Nobody puts vitals 7+ cards deep.
5. **Week data is shown as a card, not a mode.** Google Health has a "Weekly cardio" hero ring. Garmin shows a 7-day averages card. WHOOP has a Weekly Plan card. Apple Highlights are framed as "this week vs last".
6. **Customization is reorder plus hide, from one Edit entry**, either at the bottom (Apple, Garmin) or next to the section label (WHOOP "Customize"). The hero (Apple rings, WHOOP dials) is **fixed**. WHOOP users are now asking for whole sections to be movable; Google Health users complain that reordering means removing and re-adding tiles.

## Decisions for MRH1 v1.3

1. **New Today order.** Above the fold on a 6.3″ phone, items 1–5 (about 690 pt):
   1. **Header**: menu · greeting + date · **+** journal. The date line becomes the day selector (see 2).
   2. **Verdict headline** (≤14 words, time-of-day aware).
   3. **Gauges: Sleep · Recovery · Strain**, recovery as the hero, with the CoachMark kept.
   4. **Freshness chips**, plus "3 of 4 signals" when HRV is missing.
   5. **Coach note card**, only when the Coach is on. Pattern 3: one insight right under the scores. It must agree with the headline (B1).

   Below the fold, in order (1 scroll):

   6. **Body panels strip** (4 capsules, "N to watch"), moved up from 7th card to 2nd. This answers owner ask 3 and matches pattern 4.
   7. **Drift banner**. It stays glued to the panels, because it explains them.
   8. **Your week**: section label, then **sleep balance** (debt + consistency), then **week strip** (day cards). Moved from about the 7th card to about 1.5 scrolls. This answers owner ask 2 and matches pattern 5.
   9. **Strain target** capsule + advice.
   10. **Stress 24 h**.
   11. **Last night** (StageBar).
   12. **Health monitor** heat map.
   13. **Weekly report** (Mondays only). It moves up to sit directly under item 8 on Mondays, so all the week material stays together.
   14. **Journal discoveries**.
   15. **Footer**.
2. **Remove the Mon–Sun day-circle strip from the top** (owner ask 1; pattern 2). Today it only scrolls to "week" when tapped (`TodayView.swift` `DayCircles` → `proxy.scrollTo("week")`), so it already belongs to Your week. Put the **day circles inside the "Your week" section header**, as the row that selects a `WeekStrip` card. The recovery-ringed circles stay, and the tap now selects in place with no scroll jump.
3. **Header shortcut to the week.** Tapping the date under the greeting scrolls to "Your week" with `Motion.morph` (the same `proxy.scrollTo("week")`). This is the Oura/WHOOP "date at top" affordance without the permanent strip. Add an accessibility hint: "Shows your week".
4. **No swipe-between-days on Today in v1.3.** Pager gestures conflict with the edge-swipe back added in v1.2.1, and Google Health and Garmin manage without one. Past days stay in `WeekStrip` cards and the Trends tab.
5. **Item 9 (strain target) stays below the week block** because the verdict headline (item 2) already states the strain target in the afternoon. Exception: in the afternoon (12–18 h), move the strain target up to sit right after the Coach note, because strain is then the day's question. This is the only time-of-day reorder; keep it as a simple `if` with no layout animation.
6. **Customization (v1.3, minimal):** add an **"Edit Today"** button above the footer (Apple/Garmin placement). It lets the user **hide** items 9–14 and drag to reorder them. Items 1–8 are fixed, like the hero rings at Apple and WHOOP. Store this in `Settings` as `[String]` card IDs. Coach off still gives the v1.0 default order minus the Coach card. If the build budget is tight, ship hide-only and leave reorder for v1.4.
7. **Update `DESIGN_SPEC` §4 and the `TodayView.swift` header comment** with this order, so later agents do not restore the strip.
8. **Screenshots for "done":** take three, in light and dark. *Top*: items 1–5, with the gauges visible without scrolling. *Middle*: items 6–8, with the panels and Your week on one screen. *Bottom*: items 12–15.
