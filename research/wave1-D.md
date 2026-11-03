# Wave 1 · D · App shell

Files: `MRH1/MRH1App.swift`, `ContentView.swift`, `Routes.swift`, `MenuView.swift`, `GuideMenu.swift`, `DataSourcesView.swift`.
Build (`build/D`): **BUILD SUCCEEDED**, full app, 0 errors.

## What was built
- **MRH1App**: forced dark mode removed, so the app follows the system appearance. `-uiLight` / `-uiDark` pin the appearance for screenshots (`MRH1App.forcedScheme`). It creates `HealthStore`, `LiveStore`, `JournalStore` and `AppNav` and injects all four with `.environment`.
- **Routes.swift**:
  - `Route` keeps every v0.4 case and adds `.dataSources` (same screen as `.sources`), `.live`, `.menu` and `.journal`.
  - It adds `AppTab` (today/live/body/trends, with title and SF Symbol).
  - It adds `@Observable @MainActor AppNav`: `tab`, `showMenu`, `showJournal`, per-tab `paths`, `open(_:in:)` and `applyLaunchArguments()`.
- **Launch args**:
  - `-tab today|live|body|trends`
  - `-open recovery|strain|sleep` pushes the score detail on Today.
  - `-open menu|journal` opens that sheet.
  - `-open guide|sources` pushes that page.
  - `-onboarding` shows the first-launch screen.
- **ContentView**:
  - `TabView(selection:)` with the system bar hidden and a custom floating round-icon bar. The selected tab is a 44 pt ink circle with a card-coloured icon; the others are graphite. Labels use micro. Switching has no animation (transaction animations off) and gives a selection haptic. The bar is a frosted material with a hair stroke and a 2-layer shadow, radius 28, 20 pt gutter.
  - Each tab has its own `NavigationStack(path:)` with `withRoutes()`, plus a bottom safe-area inset so content scrolls under the bar.
  - The menu and journal are sheets bound to `AppNav`.
  - `LiveStore`: `live.start(health:)` runs after access is granted, or right away in demo. It re-attaches on `health.lastRefresh`, stops in the background and starts again when the app is active.
- **Demo**: `Demo.isOn` skips onboarding and never triggers the HealthKit or notification prompts. The menu's notification toggles also skip the prompt in demo.
- **Onboarding (ConnectView)**:
  - Title and intro.
  - A card titled "How your data gets here" with the data path drawn as 4 stops on an ink line: Fitbit Air → Google Health → Apple Health → MRH1. The MRH1 stop is the ember dot. Below it, a note on batch sync lag.
  - Three points: computed on this iPhone with no internet code; learns your normal over 14 days; "Turn On All, then Allow".
  - An ink capsule button, "Connect Apple Health", with a spinner, then the error line.
  - Footer: "Works with Fitbit Air via Google Health and Apple Health. Not affiliated with Google. Wellness estimates, not medical advice."
- **MenuView** (a sheet with its own NavigationStack and a close RoundIconButton). `MenuList` is reused for `Route.menu`. It contains:
  - Results guide and Data sources links.
  - Notifications: "Morning summary" (`mrh1.notif.morning`) and "Signals outside your usual range" (`mrh1.notif.drift`).
  - Live heart rate: "Bluetooth live heart rate (beta)" (`mrh1.ble.enabled`). The toggle calls `live.setBluetooth(enabled:)` and shows `live.bluetoothStatusText`.
  - About: Version 1.0, the on-device privacy line, "Works with Fitbit Air via Google Health and Apple Health. Not affiliated with Google.", and a sample-data note in demo.
  - Footer: "Wellness estimates, not medical advice. See a doctor for symptoms."
  - Also adds a `MenuButton` view: a drop-in RoundIconButton that sets `nav.showMenu`.
- **GuideView** rewritten on paper and cards:
  - Colours: `StatusChip(tier:)` for In range / Watch / Out of range, each with a word. The ember dot and "Not sent" are explained. No blue.
  - Scores: recovery bands in tier words, plus "3 of 4 signals".
  - An "Early reads" (14 days) entry.
  - Every panel metric, with typical adult range and a Not-sent note.
  - The disclaimer.
- **DataSourcesView** restyled: FreshnessChip, one card with hairline-separated rows (value, 6 pt status dot plus a "N samples" word, relative date, sources), the batch-sync footer, and `.refreshable`. Same data as v0.4.

## Menu-button pattern (integration decision)
**Tab views own their top-left button (`RoundIconButton("line.3.horizontal") { nav.showMenu = true }` or `MenuButton()`); the shell adds none.**
Current state: Today (E) has one, Live (F) has one, and Body (G) has one when it is the tab root.
**Trends (H) has no menu button.** Integrator: add `MenuButton()` (or the same RoundIconButton) at the top-left of the `TrendsView` header/toolbar.

## v0.4 features kept
#1 ConnectView (expanded), #2 tabs (Guide moved to the menu, Panels → Body), #15 pull to refresh (still in the tab views and on Data sources), #16 Data sources (menu, and `Route.sources`), #26 Results guide (menu), #28–29 notification toggles (new UI for the existing behaviour), #30 notification permission at launch (real mode only), #31 disclaimer (onboarding, menu, guide).

## Checklist research/03 §9 (my screens: tab bar, onboarding, menu, guide, data sources)
Passes:
- 1–3: one primary element per screen (onboarding = Connect, menu = links), value before label.
- 4: groups 32 apart, 4–16 inside.
- 6–7: all text uses Typo roles (UIFontMetrics), nothing below 11, no light weights.
- 10: sentence case, no caps, no mono.
- 11: only spacing tokens.
- 14: every tap target ≥44 pt.
- 16–17: ember only for the MRH1 stop; status dots always paired with a word.
- 20: no text on orbs.
- 27: no tab animation, press 0.97.
- 30: tab buttons are labelled with the selected trait, the data path is one accessibility element, and rows are combined.
- No AI tells: no tinted icon circles, no emoji, no exclamation marks.

Not verified: 15 (AX sizes), 29 (Increase Contrast / Bold Text). Not applicable: 21–26 (my screens have no charts).

## Screenshots
`screenshots/D-tab-today|live|body|trends.png`, `D-menu.png`, `D-guide.png`, `D-sources.png`, `D-onboarding.png` (light, `-demo`).
- Cold launches on this simulator take more than 8 s to draw, so wait about 18 s before `simctl io screenshot`.
- A notification alert left by a pre-fix run stayed in SpringBoard across reinstalls and was cleared only by a simulator shutdown and boot.
- `-onboarding` now takes priority over demo.

## Open issues
- Trends menu button (above).
- On iOS 26+ the menu sheet's close `RoundIconButton` gets the system's toolbar glass capsule around it, which shows as a faint double ring. It's minor. To fix it, move the close button out of `.toolbar` into an overlay, or have A add `.glassEffect`/`sharedBackgroundVisibility(.hidden)` handling.
- `JournalSheet()` is presented with no parameters. If E's Today also presents its own journal sheet, `nav.showJournal` (used by Trends and `-open journal`) is the second path to the same view, which is fine.
- `MetricRow` opens MetricSheet itself (A), so no `Route.metric` was added.
- Version "1.0" is hard-coded in About because I can't change MARKETING_VERSION without editing the pbxproj.
