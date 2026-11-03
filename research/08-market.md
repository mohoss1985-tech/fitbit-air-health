# 08 · Market, legal and naming: can MRH1 be sold?

Short answer: yes, as a paid wellness app on the App Store, **if it ships under its own brand (not "Fitbit")**, keeps every claim on the wellness side, and has a paid Apple Developer account. The market is narrow but has no clear owner yet.

## Sources

- Apple App Review Guidelines (1.4.1, 2.3.7, 2.5.1, 4.1, 5.1.1–5.1.3, 5.2.1): https://developer.apple.com/app-store/review/guidelines/
- Works with Apple Health badge rules: https://developer.apple.com/licensing-trademarks/works-with-apple-health/ · HealthKit HIG update: https://developer.apple.com/news/?id=04202020a
- Privacy labels: https://www.apple.com/privacy/labels/ · https://support.apple.com/en-gb/HT211970
- Developer Program, free vs paid: https://flaviocopes.com/apple-developer-free-vs-paid/ · https://hexsign.io/glossary/testflight
- Google Brand Resource Center: https://about.google/brand-resource-center/guidance/ · Chrome "for / compatible with" wording: https://developer.chrome.com/docs/webstore/branding · Google Fit branding (no Google marks in titles): https://developers.google.com/fit/branding · Fitbit developer terms (logo licence tied to its Trademark Policy): https://dev.fitbit.com/new-developer/
- FDA General Wellness guidance, revised 6 Jan 2026: https://www.cov.com/en/news-and-insights/insights/2026/01/fda-issues-revised-guidance-on-general-wellness-products · https://www.afslaw.com/perspectives/alerts/fda-issues-updated-guidance-low-risk-general-wellness-devices-and-clinical
- EU MDR / MDCG 2019-11: https://health.ec.europa.eu/system/files/2020-09/md_mdcg_2019_11_guidance_en_0.pdf · https://openregulatory.com/mdcg/mdcg-2019-11
- Fitbit Air launch ($99.99, 7 May 2026, on sale 26 May): https://9to5google.com/2026/05/07/fitbit-air-launch/ · https://www.androidcentral.com/wearables/fitbit/google-fitbit-air-launch-specs-price
- Google Health → Apple Health sync (v5.05, 3 Aug 2026, no HRV): https://www.macrumors.com/2026/08/03/fitbit-apple-health-syncing/ · https://www.techtimes.com/articles/322971/20260804/fitbit-reaches-apple-health-new-google-health-update-hrv-still-blocked.htm
- Volumes: https://www.businessofapps.com/data/fitbit-statistics/ (4.3M Fitbit units, 2025) · https://flapen.com/research/uk/sports-outdoors/fitbit-air (rough Amazon UK estimate) · https://the5krunner.com/2026/05/15/fitbit-air-cost-breakdown/
- Comparable pricing: https://www.healthappinsider.com/en/comparisons/athlytic-vs-bevel-vs-gentler-streak · https://www.healthappinsider.com/en/reviews/gentler-streak-review · https://apps.apple.com/us/app/training-today/id1507992127 · https://trackervs.com/pricing/whoop-pricing/ · https://www.measureprotocol.com/insights/oura-ring-vs-whoop-buying-guide
- Competitors to watch: Cinder (on-device, publishes its formulas, no data collected): https://the5krunner.com/2026/08/18/cinder-apple-watch-recovery/ · Ness / Livity (work with Fitbit Air through Apple Health): https://lifestack.ai/blog/apps-to-use-with-fitbit

## Legal and App Store must-dos (checklist)

- [ ] **Paid Apple Developer Program, $99/yr.** A free account can't use TestFlight or the App Store, and its installs expire after 7 days. Enrol as an individual or an LLC. An LLC puts the company name on the store page instead of your personal name.
- [ ] **Join the App Store Small Business Program** (15% commission instead of 30%).
- [ ] **Privacy policy URL** in App Store Connect and inside the app (5.1.1(i)). This applies even though the app collects nothing. Say: reads Apple Health read-only, processes on device, sends nothing, no analytics, no ads.
- [ ] **Only ask for the HealthKit types the app actually uses** (5.1.1(iii)). Write `NSHealthShareUsageDescription` in plain words. Don't request write access unless journal tags really write to Health. No `NSHealthUpdateUsageDescription` otherwise.
- [ ] **Never write estimated scores into HealthKit as if they were measurements** (5.1.3(ii)). **No iCloud/CloudKit sync of health data** (5.1.3(ii)), so keep history and journal in local storage only.
- [ ] **No health data for ads, marketing or data mining** (5.1.2(vi), 5.1.3(i)). That's easy here: no SDKs at all, no crash reporter with device IDs.
- [ ] **Privacy nutrition label: "Data Not Collected."** This holds only while there is zero networking and no third-party SDKs. Adding TelemetryDeck, Sentry or Firebase later would mean updating the label.
- [ ] **1.4.1 accuracy:** Apple rejects health-measurement accuracy claims it can't validate. Ship the methodology in the app (the existing explanation sheets plus a "How scores work" page) and call every score an *estimate*. Never claim clinical accuracy, and never compare against Whoop or Oura numbers as "equivalent".
- [ ] **Wellness wording (FDA 2026 general-wellness policy, EU MDR/MDCG 2019-11).** The intended purpose has to be general wellness: sleep, fitness, stress awareness. In app, store and web copy, avoid disease names, diagnostic thresholds, "detect", "diagnose", "monitor your heart condition", "AFib", "hypoxia" and "sleep apnea". Concrete edits:
  - Rename the red tier from "danger" to "well outside your usual range".
  - Rename the 2+ vitals drift alert to "your numbers look unusual, consider rest", not "you may be ill".
  - Keep "Body age" framed as a fitness estimate.
  - Keep the "wellness estimates, not medical advice; see a doctor for symptoms" line on onboarding, the results guide and the store description.
  - SpO2 and breathing rate stay "for wellness" with no clinical cut-offs shown.
- [ ] **EU Digital Services Act trader status.** Selling in the EU requires a declared trader, with address, phone and email shown publicly. Use a business address or virtual office if privacy matters.
- [ ] **Age rating questionnaire** (likely 4+; medical/treatment info "infrequent"). **Export compliance:** no non-exempt encryption.
- [ ] **Screenshots and demo data must not show Google Health or Apple Health screenshots or logos** (Apple Health badge rules). Use synthetic data only. Never show real owner data.
- [ ] Let reviewers in without a Fitbit Air: a **demo mode** behind a toggle, explained in the App Review notes ("data source: Google Health app writing to Apple Health; demo mode for review").

## Naming and trademark risk: "Fitbit" in the name

**Don't ship "Fitbit Air on Steroids" or any name that contains "Fitbit".**

- Apple 4.1(c): you can't use another developer's brand or product name in your app's name or icon without their approval. 5.2.1 bans protected third-party marks without permission. 2.3.7 bans keyword-stuffing with trademarks.
- Google's Brand Resource Center: "Don't use, incorporate, or combine any of our trademarks… into your brand name, product name…". Fitbit is a Google trademark. Google allows plain-text, informational references only.
- A few old apps such as "Fitbit Sync to Health App" have survived, but a rights-holder complaint through Apple's IP dispute process gets an app removed. Google enforces its marks actively. A paid app with "Fitbit" in the name is a takedown waiting to happen.
- "On Steroids" is a second problem. It refers to drugs in a health category, sounds unprofessional on the store, and can trip review.

What's allowed (nominative fair use, following Google's own "for / compatible with" wording):
- Store **subtitle or description**, not the name: "Works with Fitbit Air via Google Health and Apple Health." Add once: "Fitbit and Fitbit Air are trademarks of Google LLC. [App] is not affiliated with or endorsed by Google."
- No Fitbit logo, no Google colours, no device renders in the icon. Product photos only if you shot them yourself, and even then show the band small and unbranded.
- Keywords: "fitbit" as a keyword is a grey area under 2.3.7. Put "Fitbit Air" in the description text, where it ranks for search, instead.
- **"Works with Apple Health" badge is allowed** on web, ads and email, since the data is read through Apple Health. Badge rules: one per layout, unaltered, no Apple logo, no "HealthKit" in marketing copy (say "Apple Health"), and no Apple Health screenshots.

## Pricing recommendation

| App | Price (US) |
|---|---|
| Fitbit/Google Health Premium | $9.99/mo · $79/yr |
| Whoop | $199–$359/yr (hardware included) |
| Oura | $5.99/mo · $69.99/yr + ring |
| Bevel Pro | $14.99/mo · $99.99/yr (core free) |
| Gentler Streak | ~$7.99–8.99/mo · $39.99–54.99/yr · lifetime ~$59.99 |
| Athlytic | ~$4.99/mo · $29.99/yr |
| Training Today | $2.95/mo · $29.99/yr |

People who buy a $99 band with no required subscription are price-sensitive and wary of subscriptions. MRH1 has no server costs, so it can undercut everyone on the list and use that in marketing.

- **Free download, 14-day full trial.** The baselines need about 14 days anyway, so the trial ends the moment flags become meaningful. That's a good conversion point.
- **$2.99/mo · $19.99/yr · $39.99 lifetime** (lifetime is cheaper than half a year of Google Health Premium).
- After the trial, the free tier keeps raw vitals and the Live tab. Pro covers scores, Trends, weekly report, body age and notifications.
- Launch promo: lifetime at $29.99 for the first 30 days. Use StoreKit 2 with no third-party paywall SDK, which keeps "Data Not Collected" true.

**Market size, honestly:** Google publishes no Fitbit Air sales figures. Fitbit shipped about 4.3M units in 2025 across all models. One third-party tool estimates Amazon UK Air sales at 13–15k a year. The Apple Health path has only worked since 3 Aug 2026. A plausible addressable base is low hundreds of thousands of iPhone-owning Air users in year one. At 1–3% paid conversion, expect revenue in the low five figures per year. Treat it as a niche to own, and plan v1.x to support any band that writes HR and sleep to Apple Health without HRV (other Fitbits, Amazfit, Xiaomi). That widens the market without a rebrand.

## Positioning statement

> For people who wear a Fitbit Air with an iPhone, [Name] turns the data Google Health sends to Apple Health into recovery, strain, sleep and stress scores you can actually read, with every number explained like a lab result. Unlike Google Health Premium or Whoop, it costs a few dollars, never leaves your phone, and tells you plainly when data isn't sent instead of guessing.

Three proof points: **On-device, nothing collected** · **Shows its math** (Cinder is winning attention with this on Apple Watch) · **Honest about gaps** ("Not sent", sync age always visible).

## Name candidates

A quick web and App Store search found no health/fitness app using names 1–6 (search only, not a trademark clearance).

| # | Name | Why | Tagline |
|---|---|---|---|
| 1 | **Kiln** | Warm, ember-fired; heat turns raw data into something solid. Kiln apps exist only in pottery and games. | "Your band's data, fired into meaning." |
| 2 | **Banked** | A banked fire = stored energy = recovery. Short, verb-like. | "Know what's in the tank." |
| 3 | **Restline** | Readable baseline of rest and readiness. | "Where your body's numbers line up." |
| 4 | **Bandnote** | Notes from the band, results-sheet tone. | "Every reading, explained." |
| 5 | **Pulseprint** | Your personal fingerprint of pulse and sleep. | "Your baseline, not anyone else's." |
| 6 | **Hearthbeat** | Hearth + heartbeat; warm paper and ember mood. | "Warm insight from a quiet band." |
| 7 | **Emberline** | Uses the brand colour directly. **Risk:** an "Ember" sleep app is announced as coming to iPhone, so this needs a check. | "Steady signal, softly lit." |
| 8 | **MRH1** | Neutral, ownable, already in use. Weak for search and meaning. | "Fitbit Air, fully read." (describe it, don't name it) |

Rejected after searching: **Cinder** (direct competitor), **Ember** (sleep app), **Morrow** (longevity platform using wearables), **Inkwell** (InkWell Health), **Afterglow** (wellness app), **Airlog** (pilot logbook).

**Recommendation: Kiln or Banked.** Before committing, check the USPTO/EUIPO class 9 and 44 registers and the App Store name, and buy the .app domain.

## Launch checklist

1. Owner decisions: pick a name, enrol in the paid Developer Program (individual or LLC), join the Small Business Program.
2. Rebrand the bundle display name, icon, web site and README. Remove "Fitbit" and "Steroids" from every user-facing title. Keep `com.mrh.MRH1` or move to a reverse-domain ID you own.
3. Wording pass for wellness language (list above) across the app, notifications, the results guide and the web.
4. Add an in-app "How scores work" page, a privacy policy page, the not-medical-advice line and the trademark disclaimer.
5. Use StoreKit 2 for the trial, subscription and lifetime purchase, with Restore Purchases and links to terms and privacy on the paywall.
6. Demo mode for App Review, plus review notes explaining the data source.
7. App Store assets: 6.9" and 6.5" screenshots on synthetic data, an optional preview video, a subtitle such as "Recovery & sleep for Fitbit Air", and privacy label "Data Not Collected".
8. TestFlight beta with about 20–50 Fitbit Air iPhone users from r/fitbit and the Fitbit Air forums, collecting feedback on sync lag and wording.
9. Fill in EU DSA trader info, age rating and export compliance, then submit.
10. Launch posts: r/fitbit, r/QuantifiedSelf, the5krunner/DC Rainmaker tip lines, and a Product Hunt post built around "no subscription needed, nothing leaves your phone".
11. After launch: support other bands that write to Apple Health (v1.1), localisation (FR/DE/ES), and a watch complication.

*Not legal advice. Get a short trademark clearance and a review of the EU wording before spending on marketing.*
