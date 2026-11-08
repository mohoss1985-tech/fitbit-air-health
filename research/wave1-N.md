# Wave 1 · N · Coach UI

Built against DESIGN_SPEC_v1.1 §2–§6, research/v11-03 and the v1.0 tokens. No new colours, no SF `sparkles`, no avatar, no emoji,
no network code. Builds clean into `build/N` (Debug, iOS Simulator).

## Files (all owned by N)
- `MRH1/Coach/CoachViews.swift`: fixed-name entry points + the signature glyph + previews.
- `MRH1/Coach/UI/CoachConversation.swift`: the chat screen shared by the tab and the sheet, plus `CoachComposer`.
- `MRH1/Coach/UI/CoachThread.swift`: UserBubble, DataPillView, SuggestionChip, CoachThinking, ReplyActions, CoachReplyView, StarterCard.
- `MRH1/Coach/UI/CoachPlanViews.swift`: PlanCard, PlanRunnerView, PlanFormat.
- `MRH1/Coach/UI/CoachSupport.swift`: CoachGreeting, CoachStarter/CoachStarterSource, CoachFlowLayout, CoachDemo, CoachPreviewHost.

## Public API
```swift
struct CoachBubbleShape: Shape { var bodyRatio: CGFloat = 0.8; static func bodyRect(in:bodyRatio:) -> CGRect }
struct CoachGlyph: View { init(width: CGFloat = 16, stroke: Color = Theme.graphite2, lineWidth: CGFloat = 1.25, dotOpacity: Double = 0.6) }
struct CoachMark: View { init(metric: MetricID?, name: String? = nil) }      // VO: "Ask Coach about <name ?? metric.info.name>"
struct CoachTabIcon: View { init(selected: Bool, stroke: Color? = nil) }     // 20 pt glyph; default stroke card (selected, on the ink circle) / graphite
struct CoachView: View { init() }                                            // tab root, hides nav bar
struct CoachSheet: View { init(metric: MetricID?) }                          // calls engine.start(about:) once on appear; .large detent
struct CoachNoteCard: View { init(note: CoachNote) }                         // ≤40 words, collapsible, tap → nav.openCoach(about: note.metric)

struct CoachConversation: View { init(context: CoachContext) }              // enum CoachContext { case tab, sheet(MetricID?) }
struct CoachComposer: View                                                  // text, placeholder, busy, focused, onSend, onStop
struct UserBubble: View { let text: String }
struct DataPillView: View { let pill: DataPill; let action: () -> Void }
struct SuggestionChip: View { init(text: String, dimmed: Bool = false, action: @escaping () -> Void) }
struct CoachThinking: View { var status: String? }
struct ReplyActions: View { @Binding vote: Bool?; copyText: String; onRetry: (() -> Void)? }
struct CoachReplyView: View                                                  // reply, finished, isLatest, vote, onChip, onPill, onRetry
struct StarterCard: View { let starters: [CoachStarter]; let onTap: (CoachStarter) -> Void }
struct PlanCard: View { let plan: CoachPlan }
struct PlanRunnerView: View { init(plan: CoachPlan, startAt: Int = 0, onClose: @escaping (Set<Int>) -> Void = { _ in }) }
enum CoachGreeting { static func sentence(_ health: HealthStore, now: Date = Demo.now) -> String }
struct CoachStarter: Identifiable, Hashable { topic, question, metric: MetricID? }
enum CoachStarterSource { static func make(_ health:) -> [CoachStarter]; static func about(_ metric:) -> [CoachStarter] }
struct CoachFlowLayout: Layout                                              // wrap row (JournalSheet has a private FlowLayout)
enum CoachDemo { static let plan, messages, note }
struct CoachPreviewHost<Content: View>: View                                // injects HealthStore, AppNav, JournalStore, CoachEngine(demo messages)
```

## Engine members used (L)
`messages`, `isThinking`, `statusText`, `mode` (`.rules(reason:)` → one caption line under the header), `send(_:about:) async`,
`start(about:)`, `newChat()`, `deleteAll()`. Also writes `engine.messages = …` in `CoachPreviewHost` only (previews).
- **Stop** cancels the `Task` that awaits `engine.send`; L's send should check `Task.isCancelled` / use cooperative cancellation.
- **Retry** re-sends the user text that preceded the reply (no engine API needed; L may add `retry()` and I'll switch).
- **Finished** = not (latest coach message && (engine.isThinking || send task running)). Actions + chips appear only then.
- **Thinking** shows while `isThinking` and the last coach reply has no headline/body yet; streaming text updates in place
  (`reply.body` changes fade 160 ms). Status text = `engine.statusText` (fallback "Reading your data…").
- Thumbs up/down are UI state only (keyed by message id); no persistence yet.

## Behaviour notes
- Greeting: Morning → recovery + sleep, Afternoon → recovery + strain, Evening → strain + sleep; missing → "Waiting for today’s data from Google Health."
- Starters: 4 rows (Recovery, Sleep, Strain, Plan); questions from K's `CoachRules.starters(health:)`, local fallback if the
  count is not 4. Sheet shows 3 metric starters only if the chat is empty (L's `start(about:)` normally inserts an opener).
- Uses L's `reply.isStreaming` (no pills/plan/actions/chips while streaming) and `reply.isSample` ("Sample data" caption).
- DataPill tap → `MetricSheet(state: health.state(pill.metric))` presented from the conversation (works in tab and sheet).
- Chips: `reply.chips.prefix(3)`; earlier turns' chips stay, dimmed to graphite text. 40 ms stagger, `.selection` haptic.
- Menu (…): New chat · Coach settings (tab only, opens `nav.showMenu`) · Delete coach history (confirmation dialog).
- Footer caption on every coach screen: "AI coach on this iPhone · can be wrong · wellness, not medical advice."
- Demo: "Sample data" chip next to the title when `health.isDemo`.
- PlanRunner: ember TickRing countdown, `.display` mm:ss with numericText, Back / Pause–Resume / Skip, reps-only steps
  wait for "Done", light haptic at 3-2-1, medium on step change, success at the end, idle timer off while open,
  VoiceOver announces each step, magic tap = pause. End copy: "Done. N of M steps done. Not saved to Apple Health."
- A11y: each turn one element ("You: …" / "Coach: …"), streaming not a live region, single "Coach is replying" /
  "Coach replied" announcements, chips/pills/starters are buttons with hints, everything wraps at AX sizes (flow layout,
  no horizontal scroll), 44 pt hits throughout. Reduce Motion: thinking dots static, enter → opacity.

## Deviations
- Reply action icons use `Theme.graphite`, not graphite2 (graphite2 fails 3:1 for UI icons).
- Tab icon selected stroke defaults to `Theme.card`, because the existing tab bar puts the selected icon on an ink circle;
  pass `stroke: Theme.ink` for the §3 look on a plain background (O already does this in one place).
- No "Jump to latest" capsule; the thread auto-scrolls on new turns, thinking changes and streamed body updates.

## Open issues
1. **O:** the tab's NavigationStack adds a 76 pt bottom safe-area inset for the floating tab bar. With the keyboard up the
   composer will sit 76 pt above the keyboard. Suggest dropping the inset (or hiding the bar) while the keyboard shows on the Coach tab.
2. Not checked visually: the simulator install hung (other agents using CoreSimulator), so no screenshots of the Coach tab yet. Wave 2 should screenshot light/dark/AX5.
3. **L:** if `messages` becomes `private(set)`, `CoachPreviewHost` needs a demo seeding hook (e.g. `CoachEngine.preview()`).
4. L exposes `history` / `open(_:)`; a History list UI is not built yet. History list, "What Coach knows" and memory "Undo" (research/v11-03 screen 5) are not built (out of this brief).
5. Feedback votes are not persisted; plan checkbox state lives in the card view only.
