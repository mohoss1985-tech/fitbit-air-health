# Wave 1 · M · Coach safety

Owner files: `MRH1/Coach/CoachSafety.swift`, `MRH1/Coach/CoachSafetyCases.swift`. No other files touched. No network code.

## What was built
- **Deterministic pre-check (G1, G3, G4, G5).** A keyword/phrase classifier runs on the user's text before the model.
  Text is folded (lowercase, no diacritics, apostrophes dropped so "can't" → "cant", "1,000" → "1000") and tokenised.
  Rules use phrases (`*` = prefix, `.` = sentence end), proximity (`near` within N tokens), `unless` exclusions and
  a few custom checks (age, low kcal intake, lose N kg). Priority order:
  crisis → emergency → minor → eatingDisorder → medication → threshold → diagnosis → pain → weightTarget → jailbreak →
  healthWrite → condition.
- **Fixed, localised replies** (`String(localized:)`, `isTemplate = true`, no pills, headline ≤ 14 words, ≤ 2 sentences,
  exactly 3 chips of ≤ 4 words, no "!", no banned words). Each one is checked by the self-test in 8 regions.
- **Templated follow-up chips.** The chips on emergency, crisis, minor and eating replies ("Who should I call?",
  "What do I say?", "What if it eases?", "Who can I call?", "Can I text someone?", "What helps right now?",
  "Who offers support?", "Why is Coach 18+?", "What does Coach see?", "Do other tabs work?") are answered by
  `preCheck` with fixed copy, so tapping them never reaches the model.
- **Region numbers.** Emergency: 911 (US/CA/MX and the Americas), 999 or 112 (GB/IE), 15 or 112 (FR), 144 or 112 (CH),
  000 (AU), 111 (NZ), 119 (JP/KR/TW), 120 (CN), 192 (BR), 995 (SG), 101 (IL), 1669 (TH), 112 default.
  Crisis lines: US/CA 988 (text 988), GB/IE Samaritans 116 123 (text 85258 / 50808), FR 3114, DE TelefonSeelsorge,
  AT 142, ES 024, NL 113, AU Lifeline 13 11 14, NZ 1737; elsewhere findahelpline.com. Eating support: GB Beat,
  AU Butterfly, elsewhere findahelpline.com.
- **postCheck (G6, §5).** Rejects banned words (diagnos*, detect*, apnea/apnoea, AFib/a-fib/atrial fibrillation,
  hypox*, arrhythmi*, abnormal*, danger*, dose/dosage/dosing, mg, injur*, "below target"), calorie and weight targets
  (calorie target/goal/deficit, "in a deficit", lose N kg, target/goal weight, eat N kcal, burn it off, earn your food,
  fasting) across headline, body, pills, chips and plan text. Numbers in headline, body and pills must be in
  `allowedNumbers`. Normalisation: "58 bpm" → 58, "7 h 12" → 7 and 12, "54–57" → 54 and 57, "14,5" = "14.5",
  "1,000" = "1000", "07" = "7", "7.0" = "7". An allowed decimal also allows its rounded forms (58.4 allows 58).
  Digits inside names are ignored (SpO2, VO2, CO2, Zone 1–5, Z2). Numbers from the attached `reply.plan` (minutes,
  step seconds and minutes, reps) are allowed automatically.

## Public API (all `static` on `enum CoachSafety`)
```swift
enum Category: String, CaseIterable { case crisis, emergency, minor, eatingDisorder, medication, threshold, diagnosis,
                                      pain, weightTarget, jailbreak, healthWrite, condition
                                      var endsCoaching: Bool }        // crisis, emergency, minor
func preCheck(_ text: String) -> CoachReply?                         // uses Locale.current.region
func preCheck(_ text: String, region: String?) -> CoachReply?
func category(of text: String) -> Category?                          // .condition is NOT blocked by preCheck
func modelGuidance(for: Category?) -> String?                        // prompt note for .condition (pregnancy, diabetes…)
func reply(for: Category, region: String? = currentRegion) -> CoachReply?
func postCheck(_ reply: CoachReply, allowedNumbers: Set<String>) -> Bool
func violations(_ reply: CoachReply, allowedNumbers: Set<String>) -> [String]   // reasons, for logs / debug
var footer: String            // "AI coach on this iPhone · can be wrong · wellness, not medical advice."
var intendedPurpose: String   // §5 sentence, verbatim
struct PhoneNumber { display; dial; url /* tel:// */ }   struct Helpline { name; phone; text }
var currentRegion: String?
func emergencyNumber(region:) -> PhoneNumber;  func crisisLine(region:) -> Helpline;  func eatingLine(region:) -> Helpline
func tokenize(_:) -> [String];  func numbers(in:exemptTerms:) -> [String];  func canonical(_:) -> String
```
`CoachSafetyCases.selfTest() -> [String]` (empty = pass), `CoachSafetyCases.preCases` (68 prompt → category, 22 of them
false-positive guards such as "Give me a chest workout", "How do I improve my breaststroke?", "I'm 16 weeks into training"),
`CoachSafetyCases.postCases` (18 reply → pass/fail).

## Self-test result
Compiled standalone with `swiftc` against stub models and run on macOS: **0 failures** (68 pre-check cases, 18 post-check
cases, every template and follow-up in US/GB/FR/DE/AU/JP/BR/unknown regions). Covers G9 items 1–4, 6, 7, 9–13
(5, 8 and 14 are engine / rules / demo behaviour, not text classification).

## Notes for other agents
- **L (engine):** call `preCheck` first; if `category(of:)?.endsCoaching == true`, stop model turns for that chat
  (and for `.minor` keep the coach off). Add `modelGuidance(for: category(of: text))` to the prompt when non-nil.
  Run `postCheck`; on false retry once, then template. Put every number from tool output into `allowedNumbers`
  (scores, baselines, ranges, "21" for the Strain scale, "30" if the reply mentions the 30-day normal).
- **N (UI):** emergency/crisis replies should show a call button: `CoachSafety.emergencyNumber().url`,
  `CoachSafety.crisisLine().phone?.url`. Footer text: `CoachSafety.footer`.
- **O (onboarding/store):** `CoachSafety.intendedPurpose`.

## Open issues
- **Verify every helpline number before release** (they change; NEDA's US line closed in 2023, so the US eating reply
  points to findahelpline.com). A lawyer/clinician should review the fixed copy.
- Multilingual triggers are a small FR/DE/ES set for emergency, crisis, medication, condition, weight; full FR/DE/ES
  pattern lists and translated `.xcstrings` are still needed (G9 item 15).
- Keyword rules lean toward over-triggering on crisis ("I want to die laughing" → crisis card) and medication
  ("sleep better without pills"). That is the safe direction, but watch real usage.
- postCheck does not reject "!" or chip-count problems; the engine/UI should sanitise those.
- Spelled-out numbers ("three nights") are not checked.

## Build
`xcodebuild … -derivedDataPath build/M`: no errors or warnings in CoachSafety.swift / CoachSafetyCases.swift. The build
fails only on `MRH1/Coach/CoachRules.swift:371` (agent K's file: CGFloat `<` BinaryInteger), which is outside my scope.
