# Smart TDL — Product Requirements Document & Plan

**Status:** Draft v1.1 · **Owner:** David Xie · **Last updated:** 2026-06-28
**Platforms:** iPhone + Mac (SwiftUI multiplatform), shipping now; **Android** newly in scope as a **demand-gated conditional fork** ([`PRD-android.md`](PRD-android.md) §0); a **marketing landing page** newly in scope ([`PRD-landing-page.md`](PRD-landing-page.md)) · **Repo:** `github.com/davidaxie/smart-tdl` (Xcode project at root)
**Companion PRDs:** [Mac](PRD-mac.md) · [iPhone](PRD-iphone.md) · [Android](PRD-android.md) · [Landing page](PRD-landing-page.md). This master owns the **shared** facts (data model, principles, the `Ranker` seam, design languages); each companion owns its platform specifics and defers to this doc on the shared facts.

> **2026-06-28 scope amendment.** This product was expanded from Apple-only to add (a) a **conditional Android fork** and (b) a **marketing landing page**. The updated non-goals are in §4.1, the Apple-only sync caveat in §7.8/§9.2, and the re-opened decision in §14.C. A web *app* and a Windows app remain permanently refused; "no operated backend by default" still holds (the Android fork is sequenced to preserve it as long as possible).

> This document is both a **PRD** (what we're building and why) and a **plan** (the order to build it in). It is grounded in (a) the user research on why to-do apps fail, (b) a competitive teardown of the major apps, and (c) the existing Smart TDL codebase. Sections 1–8 are the product; sections 9–14 are the build.

---

## 1. Executive summary

Smart TDL is a **deliberately minimal, TeuxDeux-style day planner with a genuinely intelligent core that never shows itself.** You see a calm, near-chromeless list of days. Underneath, a ranking engine (local heuristic, upgrading to Claude Haiku 4.5 when you supply a key) continuously decides what matters most and quietly floats it to the top — no badges, no scores, no priority pickers, no setup.

**The one-sentence thesis:** *Every other app makes you do the deciding and the organizing; Smart TDL does both invisibly, so the only thing left for you is the doing.*

The research below shows that nearly every complaint about to-do apps reduces to a single mismatch: **a to-do app is supposed to reduce mental load and help you act, but most either add friction (overwhelm, maintenance, decision fatigue) or stop short of the hard part (deciding what to do, and actually doing it).** Smart TDL's entire design is a bet on resolving exactly that mismatch — keep the surface as quiet as Things 3, but move all the "deciding" work into an ambient AI the user never has to operate.

**What makes this defensible and different:**
- **No organizing UI to procrastinate inside.** The single deepest failure mode ("organizing isn't doing") is structurally impossible when there are no tags, no projects, no priority flags, no color-coding to fiddle with.
- **No subscription.** Users bring their own Anthropic API key (already built). The app is a one-time/free local app; intelligence costs pennies and is billed to the user's own key. This sidesteps subscription fatigue entirely.
- **Honest confidence.** When the AI isn't sure which task is #1, the UI says so (flattened gravity ramp) instead of asserting false certainty. This builds trust rather than teaching blind obedience.

---

## 2. The problem (synthesized from research)

### 2.1 The seven tensions

| # | Tension | What it feels like | Root cause |
|---|---------|--------------------|------------|
| 1 | **Guilt, not help** | 150 items pile up; the list becomes a monument to everything you're behind on, so you avoid the app | The app shows everything, equally, forever |
| 2 | **Capture is too much work** | Adding "call dentist" takes five taps and a menu, so you stop bothering and the list drifts from reality | Friction at the moment of intent |
| 3 | **Everything looks equally important** | A flat list treats "buy milk" and "file taxes" the same; you still have to prioritize in your head | The app stores tasks but won't judge them |
| 4 | **No connection to time** | 40 tasks, 3 free hours. The pile is detached from your actual day and calendar | Tasks live in a separate universe from time |
| 5 | **Too simple or too complicated** | Bare apps can't handle real life; powerful apps make maintenance its own job | No app lands the Goldilocks zone of "smart but quiet" |
| 6 | **Organizing isn't doing** | Color-coding and rearranging *feels* productive while the work doesn't happen | The app rewards tidying over completing |
| 7 | **The app graveyard** | Excited for two weeks, then drift to the next app | No habit/ritual hook; maintaining any system is the real challenge |

Plus three practical gripes: **subscription fatigue**, **sync problems across devices**, and **notifications that either nag or get ignored**.

### 2.2 The root mismatch (the thing we're actually solving)

> A to-do app should *reduce* mental load and help you *act*. Most either **add friction** (1, 2, 5, 6) or **stop short of the hard part** (3, 4) — and almost none solve the meta-problem of **staying used** (7).

Smart TDL's design is organized entirely around removing friction and closing the gap to action, with retention treated as a first-class feature rather than an afterthought.

---

## 3. Competitive landscape & positioning

### 3.1 The field

| App | Genuinely good at | Where it falls short | Lesson for Smart TDL |
|-----|-------------------|----------------------|----------------------|
| **Todoist** | Fast natural-language capture ("submit report Friday 5pm"); rock-solid sync; scales flat→projects; AI voice | Free plan capped at 5 projects; a task manager, not a planner (no time-blocking); price rose late 2025 | NL capture is table stakes — match it. Don't copy the project sprawl. |
| **TickTick** | Best value: calendar + habits + Pomodoro in one; cheap (~$36/yr) | Lags on long lists; tight free tier, no trial | Bundling is attractive but adds surface. We bundle *intelligence*, not *features*. |
| **Things 3** | Most beautiful, calm; one-time purchase | Apple-only; no time-of-day reminders; no collaboration | This is our aesthetic north star. We match the calm, add the brain. |
| **Microsoft To Do** | Free; Outlook/email integration | Simple to a fault; weak power features | Email→task is a strong context signal (see §7.5). |
| **Google Tasks** | Free; baked into Gmail + Calendar | No labels/priorities/location; barely standalone | Calendar adjacency matters; our time layer (§7.4) is the counter. |
| **Apple Reminders** | Free, capable, auto-syncs | Apple ecosystem lock-in | We're Apple-only too — lean into native quality, accept the constraint. |
| **Notion** | Build-your-own system; tasks+notes+DBs | Slow; decision fatigue; weak notifications/offline | The anti-pattern. Infinite flexibility *is* the disease. |
| **Trello** | Visual Kanban | Cluttered at scale; needs internet; no reminders | Manual card-dragging = organizing-isn't-doing made literal. |
| **OmniFocus** | GTD gold standard | Apple-only, expensive, steep | Power-user complexity is exactly what we refuse. |
| **Motion / Sunsama** | Auto time-blocking around your calendar | Pricey; for heavy jugglers | The *outcome* (time-aware planning) is right; the price and busy UI are wrong. We deliver the outcome invisibly and key-funded. |

### 3.2 The positioning map

Two axes the research keeps returning to: **Simplicity ↔ Power**, and **Dumb storage ↔ Active intelligence.**

- The simple/free apps (Google, Microsoft, Apple) are *simple + dumb*.
- The power apps (OmniFocus, Notion, Todoist-maxed) are *complex + dumb* (they store more, they don't decide more).
- The AI planners (Motion, Sunsama) are *complex + smart* (but the smartness is loud and expensive).
- **The empty quadrant is *simple + smart*. That is Smart TDL.** Things 3's calm, with an OmniFocus-grade brain that never surfaces.

### 3.3 Our wedge (one line)

**The calm of Things 3, the brain of an AI planner, the price of a free app, and zero organizing busywork — because the intelligence is invisible and you bring your own key.**

---

## 4. Product principles (the constitution)

These are non-negotiable. Every feature decision is checked against them.

1. **Intelligence is ambient — it never adds UI.** The AI's only job is to *reorder*, *roll forward*, and *connect context*. It never asks the user to configure it, label tasks, or read a score. If a feature requires a new screen or badge, it's wrong by default.
2. **Capture is one gesture.** Adding a task is a single tap-and-type, inline, on the relevant day. Natural language ("call Sam friday") is parsed silently. No menus, no required fields.
3. **The surface stays minimal.** Day-based lists. Tap to complete (strikethrough). Edit in place. That's the whole app. No tags, no projects, no sub-tasks, no priority pickers — *forever*. (See non-goals.)
4. **The right task floats up by itself.** Importance ranking drives an invisible auto-sort; the most important task sits at the top of its day. The user never sorts manually unless they want to.
5. **Never reorder under the user's hand.** Re-ranking is buffered and committed only at "safe moments" (no row is being touched/hovered/edited, after a short idle). The list must never shuffle beneath a tap or cursor.
6. **Honest confidence over false certainty.** When the AI can't confidently separate the top tasks, the UI hedges (flattened gravity ramp, softened hero) rather than crowning a random #1. Trust is the moat.
7. **The list must never become a wall of guilt.** Unfinished day-tasks roll forward to today; completed tasks dim into a quiet pool; undated "someday" items live in parking lots, out of the daily field of view.
8. **No subscription. Bring your own key.** Intelligence is funded by the user's own Anthropic key, stored in the Keychain. The app itself is free/one-time. We never gate core function behind a recurring charge.
9. **Local-first, private by default.** Tasks live on-device (JSON now, iCloud sync planned). Context sent to the model is the minimum needed to rank, and only when a key is present.
10. **Degrade gracefully.** With no key, the local `HeuristicRanker` still sorts sensibly and the app is fully usable offline. The AI is an *upgrade*, never a *dependency*.

### 4.1 Explicit non-goals (what we will NOT build)

Saying no is the product. These are permanent refusals, not backlog:

- ❌ **Projects, tags, labels, folders, sub-tasks.** They are the organizing-isn't-doing trap (pain #6) and the Notion decision-fatigue trap (#5).
- ❌ **Manual priority flags / P1–P4 / color-coding.** The AI does priority; a manual flag would re-introduce the busywork we removed.
- ❌ **Visible AI surfaces** — no chat box, no "AI suggestions" panel, no scores, no "why is this ranked here" explainer in the main flow. (A single optional "why" affordance is allowed only if it stays hidden behind a long-press; default is invisible.)
- ❌ **Team collaboration / shared lists / assignments.** This is a personal tool. Collaboration is the OmniFocus/Things gap we accept on purpose.
- ❌ **A cross-platform web *app* and a Windows app — permanently refused.** ⚠️ *But two prior absolutes were re-opened **2026-06-28**:* (a) a **marketing landing page** — a static site, **not** a web app — is now in scope ([`PRD-landing-page.md`](PRD-landing-page.md)); (b) **Android** moves from a flat permanent refusal to a **demand-gated conditional fork**, built only if launch demand justifies it, on a separate native codebase with its own sync story ([`PRD-android.md`](PRD-android.md) §0). The *spirit* of the non-goal stands: no cross-platform UI runtime, and no operated backend by default.
- ❌ **A backend we operate (by default).** No accounts, no servers holding user data on Apple platforms. Sync rides Apple infrastructure (iCloud/CloudKit); intelligence rides the user's own key. *Caveat (2026-06-28):* CloudKit cannot reach Android, so cross-platform Android sync may eventually pressure this — the Android PRD sequences sync to preserve "no operated backend" as long as possible (island → user-owned cloud → only-if-forced operated backend). See [`PRD-android.md`](PRD-android.md) §0.3.
- ❌ **Gamification (streaks-as-points, badges, confetti spam).** Retention comes from genuine daily usefulness and a calm ritual, not dark patterns.

---

## 5. Target user & personas

**Primary — "The overwhelmed competent."** Knowledge worker / student / founder who has tried Todoist, Notion, and Apple Reminders and abandoned each. They don't lack discipline; they lack a tool that does the deciding. They want to open one calm screen and be told, implicitly, "do this next." Apple devices. Comfortable pasting an API key once. (This is the builder's own profile — "almost for personal use" — which is a feature: dogfooding keeps the surface honest.)

**Secondary — "The calm seeker."** A Things 3 lover who wishes it were a little smarter about what to do first and connected to their real day. Aesthetic-sensitive; will not tolerate clutter or nagging.

**Anti-persona — "The system tinkerer."** Power user who *enjoys* building elaborate GTD systems, contexts, and perspectives. Smart TDL deliberately frustrates them; they should use OmniFocus. We do not chase them.

**Jobs to be done:**
- *When* I have a fleeting thought, *I want* to capture it in one gesture, *so I can* trust the list reflects reality. (→ §7.2)
- *When* I open the app, *I want* the single most important thing already at the top, *so I can* start without deciding. (→ §7.3)
- *When* I have limited hours today, *I want* the app to reconcile my tasks with my actual calendar, *so I can* plan realistically. (→ §7.4)
- *When* I finish, *I want* a quiet sense of closure, *so I* come back tomorrow. (→ §7.6, §7.7)

---

## 6. The core mapping: pain → principle → feature

This table is the spine of the product. Every pain point from the research maps to a principle and a concrete (built or planned) feature.

| Research pain | Principle | Smart TDL response | Status |
|---------------|-----------|--------------------|--------|
| **1. Guilt, not help** | P7 no wall of guilt | Day-based roll-forward; dimmed completed pool; undated parking lots keep "someday" out of view; only Today + a short window is the field of attention | **Built** (roll-forward, completed pool, lists) |
| **2. Capture too hard** | P2 one-gesture capture | Inline add per day; natural-language date parsing (`DateParser`, "call Sam friday"); ⌘N quick-add; (planned: share-sheet & widget capture, voice) | **Built** (inline + NL); voice/widget **planned** |
| **3. Everything equal** | P4 right task floats up | Invisible importance ranking → auto-sort to top of day; `Gravity` ramp on Mac steps type/weight/ink down by rank | **Built** |
| **4. No connection to time** | (new) Time layer | **Calendar-aware planning** — read the day's events, compute free hours, reconcile task load vs. available time, gently flag over-commitment. The biggest gap and the next big bet | **Planned (Phase 2)** |
| **5. Too simple/complicated** | P3 minimal + P1 ambient AI | The empty "simple + smart" quadrant: Things-grade calm surface, OmniFocus-grade brain underneath, nothing to maintain | **Core thesis** |
| **6. Organizing isn't doing** | P3 non-goals | No tags/projects/flags to fiddle with — productivity theater is structurally impossible; the AI does all sorting | **Built (by omission)** |
| **7. App graveyard** | (new) Ritual & retention | A once-daily calm "today" moment; gentle end-of-day sweep; peak-end "all clear" line; (planned) a single well-timed notification, not a nag stream | **Partial** ("all clear" built; ritual & nudge **planned**) |
| Subscription fatigue | P8 BYO key | No subscription; user's own Anthropic key funds intelligence; app is free/one-time | **Built** (Keychain key) |
| Sync problems | P9 local-first | Local JSON now → **iCloud/CloudKit sync** so iPhone + Mac stay identical | JSON **built**; sync **planned (Phase 1)** |
| Bad notifications | P7 + ritual | At most one meaningful, well-timed nudge; honest and skippable; never a count-badge guilt machine | **Planned (Phase 2)** |

---

## 7. Product specification

### 7.1 Information architecture

**Two surfaces, one model.**

- **iPhone** — a vertical, scrollable **day list** (`TaskListView`): Today, then the next days. Inline add per day. Tap to complete. This is the capture-and-glance surface, used in motion.
- **Mac** — a **week board** (`WeekBoardView`), the primary and only Mac view as of the latest direction. Each day is a full-height lane (`DayColumn`); Today's lane is warmer. A **day-count toggle** (3/5/7) sizes lanes to fill the viewport. **Undated parking-lot lists** (Later / Misc / Reminders) render as trailing lanes to the right (scroll right). This is the planning surface, used at a desk.
  - *Retained but not presented:* the earlier vertical "Gravity Field" list (`MacListView` / `MacRow` / `SideRail`, with the crowned Playfair "NOW" hero). Keep in source; the user may want it back. **Do not delete.**

**The model (shared):**
- A **day-task** (`TodoItem` with `list == nil`) is scheduled on a day, rolls forward if unfinished, and is gravity-ranked.
- A **parking-lot task** (`list != nil`, one of `Later` / `Misc` / `Reminders`) is undated, never rolls forward, and is not ranked. It's the "someday/maybe" pressure valve that keeps the daily view from becoming a guilt wall.

**Reaching the parking lots per surface (the two phones must mirror each other):** on **Mac** they are trailing lanes you scroll right to; on **iPhone and Android** they live *below* the day list as the same vertical-scroll target (**no tab bar**) — see [`PRD-iphone.md`](PRD-iphone.md) §3 and [`PRD-android.md`](PRD-android.md) §2, which must describe an identical mechanism.

### 7.2 Capture (pain #2)

**Goal: capture latency ≈ 0.** From intent to captured task in one gesture.

Built:
- **Inline add per day** — tap into a day, type, return. No modal, no required fields.
- **Natural-language dates** (`DateParser.swift`) — "call Sam friday" files the task on Friday and strips the date token from the title. Silent; no date picker required.
- **⌘N quick-add** (Mac) via `requestNewTask` token.

Planned (Phase 2–3):
- **System-wide capture** — Share Sheet extension (send a link/selection straight to a parking lot or Today) and a **Lock Screen / Home Screen widget** with a one-tap "add to Today."
- **Voice capture** — dictate a thought; it's parsed into a task (and date) the same way Todoist's AI voice does, but funneled through the same silent `DateParser` + ranker rather than a separate "AI" surface.
- **Capture defaults to Today** unless a date is parsed; ambiguous "someday" phrasing ("learn rust") can be nudged to a parking lot by the ranker without interrupting the user.

Acceptance: a new user can add five tasks in under 15 seconds without opening a single menu.

### 7.3 The invisible ranking engine (pain #3) — the heart of the product

**Goal: the single most important open task is already at the top of its day, every time the user looks, without the user ever sorting.**

**Architecture (built):**
- A `Ranker` protocol seam: `rank(_ tasks:context:) -> [UUID: Double]` returning an importance score 0…1 per task.
- `HeuristicRanker` (always on, no key, offline): urgency-word scoring + day-proximity boost. Sensible defaults so the app is useful with zero setup.
- `HaikuRanker` (Claude **Haiku 4.5**, `claude-haiku-4-5`, raw `URLSession` to the Messages API — no Swift SDK): sends the task list + a `context` string, gets back per-task scores. Activated automatically when a key is present.
- **Safe-moment commit (the trust mechanism):** scores are buffered in `pendingScores` and only applied when `interacting` is empty (no row touched/hovered/edited) and after a brief idle (`scheduleIdleCommit`, ~1s). The list never reshuffles under the user's hand. This is principle P5 made concrete and must never regress.
- **Honest-confidence hedge:** `topScoresClustered` (gated on real AI via `usingAI`) detects when the top two scores are within 0.06 and tells the UI to flatten the gravity ramp and soften the hero, rather than crowning a near-tie. (Heuristic scores tie too often to be honest, so this only engages with a real key.)
- **Ordering rule** (`TaskStore.order`): completed sink → pinned first → importance desc (**unranked = `-1`, sorts last**) → manual `sortIndex`. A user can still **pin** a task to override the AI (the one sanctioned manual lever, because it's a one-tap intent, not a system to maintain). *(The `-1` sentinel is canonical here; companion docs reference it rather than re-deriving it.)*

**Roadmap for the engine (Phase 2+):**
- **Richer signals into the prompt:** due-date proximity, recurrence, age (how long it's rolled forward), and — crucially — **calendar/context** (see §7.4–7.5). The `context` parameter is already the seam for this.
- **Batched/cheap calls:** debounce (already 350ms) + only rank the visible window (already done) keeps token cost in pennies. Consider caching scores by `title` hash to avoid re-ranking unchanged tasks.
- **Structured output:** migrate the Haiku call to tool-use / JSON-schema structured output for robustness (currently parses a raw JSON object with code-fence stripping). Lower priority — current parsing works.
- **Explainability (optional, hidden):** a long-press "why is this first?" that asks Haiku for a one-line rationale. Must remain invisible by default (principle P1).

### 7.4 The time-connection layer (pain #4) — the next big bet

This is the **largest gap** between the current app and the research, and the highest-leverage Phase 2 work. Pain #4 ("40 tasks, 3 free hours") is unaddressed today.

**Principle-compatible design — stay ambient.** We do *not* become Motion/Sunsama with a loud time-blocking grid. Instead:

1. **Read the day, don't run it.** With Calendar access (EventKit on-device, no backend), compute **free hours remaining today** from the user's real events.
2. **Feed time into the ranker.** The `context` string gains a quiet line: "User has ~2.5 free hours today before a 4pm meeting." Haiku already weighs this; now it weighs it against reality.
3. **Gentle over-commitment signal — ambient, not alarming.** When open Today tasks plausibly exceed available time, the UI gives the *quietest possible* honest cue (e.g., a faint hairline under the day, or the lower-ranked tasks dimming slightly toward "tomorrow" weight) — never a red warning, never a number. The message is "the day is full," felt not announced.
4. **No auto-scheduling onto the calendar (initially).** We don't write events. We reconcile *awareness*. (A later, opt-in "block time for the top task" is possible but is a Phase 3 experiment, kept behind a single deliberate gesture.)

This delivers Motion's core *outcome* — a plan that respects your real day — while honoring P1 (ambient) and P3 (minimal).

### 7.5 Context connectors — "connect everything" (Phase 3)

The vision's long-term bet: feed real context into the ranker so importance reflects the user's actual life, not just task text.

- **Sources:** Calendar (Phase 2, above), Gmail / email flags (Microsoft-To-Do-style "this email became important"), and other work/personal accounts.
- **How it feeds in:** every connector resolves to additions to the same `context` string the ranker already consumes. No new ranking pathway, no new UI — connectors are *inputs*, the auto-sort is the only *output*. This is the architectural elegance: one seam absorbs unlimited context.
- **Auth pragmatism:** "almost for personal use" → favor local/native OAuth over a backend we operate. Prototyping note: this session has Gmail + Calendar MCP connected and can be used to validate what context actually improves ranking *before* building native in-app OAuth.
- **Privacy bar:** only derived, minimal context goes to the model (e.g., "has 3 unread threads from "Dana" who appears in a task" — not raw email bodies). Connectors are opt-in, per-source, and revocable.

### 7.6 Completion & the anti-guilt system (pain #1)

Built:
- **Tap-to-complete** with ink-stroke strikethrough; completed tasks sink into a **dimmed completed pool** (`completedTasks(on:)`), present for satisfaction but out of the active field.
- **Roll-forward** (`rollForward`): unfinished day-tasks from the past move to Today on launch, so the past never accumulates as a guilt ledger.
- **End-of-day sweep** (`pushAllToTomorrow`): one action moves everything unfinished from Today to Tomorrow — a clean slate, deliberately.
- **Peak-end "all clear" line:** when the day's tasks are cleared, a calm closing message. (This is a retention lever disguised as a completion detail — see §7.7.)
- **⌘Z undo** across toggle / delete / move (50-step `undoStack`).
- **Recurrence** (`Recurrence`: daily / weekdays / weekly / monthly): completing a recurring task spawns the next occurrence automatically.

Planned:
- **Parking lots as the pressure valve** are built; consider a gentle "this has rolled forward 5 times — keep, park, or drop?" prompt for chronically deferred tasks (the honest anti-guilt move: help the user let go, don't shame them). Must be rare and quiet.

### 7.7 Notifications, ritual & retention (pain #7) — treat retention as a feature

The research is blunt: most apps die in the graveyard because **maintaining any system is the real challenge.** Smart TDL counters with *one calm daily ritual*, not a notification stream.

- **The daily moment.** At most **one** well-timed local notification per day (user-set time, default morning): "Your day is ready" — opening to Today with the #1 already on top. It's an *invitation to a calm screen*, not a count of overdue items. No badge counts (badges are the guilt machine).
- **Peak-end design.** The "all clear" line at completion gives the day a satisfying *end* — the peak-end rule says people remember the peak and the end, so we engineer a good end. This is the retention flywheel: a good end today → return tomorrow.
- **No streaks-as-points.** We may track a quiet private streak for the user's own sense of continuity, but never gamify it with points/leaderboards (a non-goal, P4.1).
- **Re-engagement, honestly.** If the user drifts, no nag escalation. At most a single gentle "still here when you need it" after a long absence — then silence.

Acceptance: the notification system can never produce more than one scheduled nudge per day by design, and never shows a numeric badge of incomplete tasks.

### 7.8 Sync & persistence (the practical gripe)

- **Now:** local JSON in Application Support (`tasks.json`), atomic writes, resilient decoding (old files without pin/recurrence/list still load). Solid single-device foundation.
- **Phase 1 priority:** **iCloud sync** so iPhone and Mac are always identical — this is a known competitor strength (Apple Reminders, Todoist) and a hard requirement for a multi-device personal tool. Approach: CloudKit private database, or a CloudKit-backed store, mirroring the existing model. Must preserve local-first/offline behavior (sync is a mirror, not a dependency).
- **Conflict policy:** last-writer-wins per task is acceptable for a single-user multi-device app; the model's per-task `id` + `createdAt` support this.
- **App-Group shared container (Phase 1 prerequisite):** move `tasks.json` into a shared App Group (`group.com.smarttdl`). This is the local substrate CloudKit mirrors **and** what unlocks widget / share-extension capture on iPhone — a hard Phase-1 prerequisite. See [`PRD-iphone.md`](PRD-iphone.md) §4.
- **Android is *not* covered by iCloud.** CloudKit is Apple-only; iCloud syncs **Mac ↔ iPhone only**. Android has a separate sync story (island first, then user-owned cloud) — [`PRD-android.md`](PRD-android.md) §0.3. Any public/marketing copy must scope the iCloud claim to Apple platforms.

### 7.9 Settings, API key & privacy

Built:
- **Settings** with API-key paste, stored in the **Keychain** (`com.smarttdl.SmartTDL`). A `smarttdl.hasAPIKey` UserDefaults flag gates Keychain reads so a no-key/fresh-install state produces **zero** system prompts and never blocks launch. Reads happen off the main thread. **Do not reintroduce a synchronous Keychain read in `init()`/`SettingsView`** (documented gotcha).
- **Appearance** toggle (System / Light / Dark via `smarttdl.appearance` + `.preferredColorScheme`).
- **Context field** (`smarttdl.context`) — a free-text "what I'm working on" that feeds the ranker today; it's the manual precursor to the connectors in §7.5.

Privacy posture: no analytics SDK, no account, no server. The only network call is the user's own key → Anthropic, sending only task titles + minimal context. State this plainly in Settings (trust is the moat).

### 7.10 Platform specifics

- **Keyboard-entry gotcha (Mac):** `handleKey` must bail (`return .ignored`) whenever a text field is active (`guard editingID == nil, focusedDay == nil, !searchFocused`); otherwise letters fire vim-style commands instead of typing. Do not regress.
- **Quiet controls** (Mac top-right): appearance, ⌘K (command bar), ⌘J (focus mode), settings, day-count toggle. Keep this the *only* chrome.
- **Build/run (dev):** `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme SmartTDL -destination 'platform=macOS' -configuration Debug -derivedDataPath build CODE_SIGNING_ALLOWED=NO build`, then `codesign --force --deep --sign - <app>; open <app>`. `screencapture -x -o /tmp/x.png` grabs the running UI.

---

## 8. Design language

Two named, already-chosen systems (do not re-litigate; extend within them):

- **"Settle"** (the foundation, chosen via a 20-agent research workflow over ~17 apps): warm-paper color tokens for light + dark in `Theme.swift` (`Color(light:dark:)`); a **terracotta accent used only on live interaction**; serif (bundled **Playfair Display**) day mastheads + SF body; ink-stroke completion; dimmed completed pool; natural-language capture; context-menu reschedule; ⌘Z undo; safe-moment re-rank.
- **"Gravity Field"** (the Mac week board): a **gravity gradient** where a day's tasks step down in type size + weight + ink **by rank index** (the `Gravity` enum, quantized by index not raw score, to avoid jitter); the AI's #1 is heaviest with a small "NOW" crown. **One** reserved terracotta accent (the live #1 + commit moment only). **No numbers, scores, or badges, ever.** The honest-confidence hedge flattens the ramp when scores cluster.

Design rule of thumb: *if a new idea needs a new color, a new control, or a number on screen, it probably violates the language — find the ambient version instead.*

---

## 9. Technical architecture

### 9.1 Current shape (built)

```
SmartTDLApp.swift     App entry, scene setup
ContentView.swift     Platform split (iPhone TaskListView / Mac WeekBoardView)
TaskStore.swift       @Observable single source of truth: model, persistence,
                      buffered ranking, safe-moment commit, undo, roll-forward
TodoItem.swift        Model: TodoItem + Recurrence (Codable, resilient decode)
Ranker.swift          Ranker protocol; HeuristicRanker; HaikuRanker; Keychain
DateParser.swift      Natural-language date extraction
TaskListView.swift    iPhone day list
TaskRowView.swift     Row rendering (complete, edit-in-place)
SettingsView.swift    API key, appearance, context
Theme.swift           Color(light:dark:) tokens, Gravity enum, type/accent
```

Key invariants to preserve:
- **`Ranker` is the only intelligence seam.** New signals/connectors feed the `context` string or the task set passed to `rank`; they never add UI.
- **Buffered/safe-moment commit** (`pendingScores`, `interacting`, `commitPendingRank`, `scheduleIdleCommit`) must remain — it's the trust mechanism.
- **Keychain reads stay gated** behind `hasKey` + off-main-thread (no launch prompts).
- **Resilient `Codable`** (decodeIfPresent everywhere) — never break old saved files.

### 9.2 Planned additions

- **`SyncStore` / CloudKit mirror** (Phase 1) behind `TaskStore`'s persistence boundary — `save()`/`load()` become a syncing store; the rest of the app is unchanged. *Apple platforms only — CloudKit cannot sync Android; the Android fork carries its own substrate ([`PRD-android.md`](PRD-android.md) §0.3).* The local substrate is the App-Group container `group.com.smarttdl`.
- **`TimeContextProvider`** (Phase 2) — EventKit reader producing the "free hours / next event" line appended to `context`. Pure input to the existing ranker.
- **`ContextConnector` protocol** (Phase 3) — Gmail/Calendar/other sources each emit context fragments; a `ContextAggregator` composes the `context` string. One output (auto-sort), many inputs.
- **`Notifier`** (Phase 2) — schedules the single daily local notification; enforces the "max one nudge, no badge" rule in one place.

### 9.3 Cost & performance

- Rank only the visible window (done), debounce 350ms (done), commit on idle (done) → typically a few Haiku calls per active session, pennies on the user's key.
- Long-list performance (a competitor weakness for TickTick/Notion): because we rank only the visible window and never render a 150-item flat wall (parking lots + roll-forward keep the active set small), we structurally avoid the lag. Verify with a 500-task stress fixture before Phase 1 ship.

---

## 10. Current state — what's built today

✅ **Built and working:**
- TeuxDeux-style day model with roll-forward, completed pool, recurrence, undated parking lots (Later/Misc/Reminders).
- iPhone day list + Mac week board ("Gravity Field") with 3/5/7 day-count toggle and trailing list lanes.
- Invisible ranking: `HeuristicRanker` (offline default) + `HaikuRanker` (Claude Haiku 4.5), behind the `Ranker` seam.
- Safe-moment buffered re-rank; honest-confidence hedge (`topScoresClustered`); pin-to-override.
- Natural-language date capture; ⌘N / ⌘K / ⌘J / ⌘Z; appearance toggle; end-of-day sweep; "all clear" line.
- Keychain-stored API key with zero-prompt gating; free-text context field feeding the ranker.
- Local JSON persistence with resilient decoding.

🚧 **Not yet built (the gaps this PRD prioritizes):**
- **Cross-device sync** (iCloud) — pain: sync problems.
- **Time-connection layer** (Calendar/EventKit → free-hours awareness) — pain #4, the biggest missing piece.
- **Context connectors** (Gmail, etc.) — the "connect everything" vision.
- **The daily ritual + single honest notification** — pain #7 retention.
- **System-wide & voice capture** (share sheet, widget, dictation) — deepening pain #2.

---

## 11. Roadmap & plan

Sequenced by leverage: first make the existing app trustworthy across devices (sync), then close the biggest research gap (time), then the retention ritual, then the long-term context vision. Each phase ships independently and leaves the app fully usable.

### Phase 0 — Hardening (foundation, ~now)
*Make the current build rock-solid before adding surface area.*
- [ ] 500-task stress fixture; confirm no lag and ranking stays cheap.
- [ ] Migrate `HaikuRanker` to structured/tool-use output (robustness), keep the fence-stripping fallback.
- [ ] Score caching by title hash to skip re-ranking unchanged tasks.
- [ ] Unit tests for `order`, `rollForward`, recurrence `nextDate`, safe-moment commit, `topScoresClustered`.
- **Exit criteria:** all invariants in §9.1 covered by tests; cold launch produces zero Keychain prompts; ranking cost ≤ a few calls/session.

### Phase 1 — Cross-device sync (the practical must-have)
- [ ] CloudKit private-DB mirror behind `TaskStore` persistence; local-first preserved (offline fully works).
- [ ] Last-writer-wins conflict policy keyed on `id` + `createdAt`.
- [ ] iPhone ↔ Mac parity verified (add on one, appears on the other within seconds).
- **Exit criteria:** a task added on iPhone appears on Mac (and vice versa) reliably; airplane-mode edits reconcile on reconnect; no data loss across 100 edit/sync cycles.

### Phase 2 — Time-connection + the daily ritual (close pain #4 and #7)
- [ ] `TimeContextProvider` (EventKit): free-hours-remaining + next-event line into `context`.
- [ ] Ambient over-commitment cue (quietest honest signal; no red, no numbers).
- [ ] `Notifier`: single daily "your day is ready" local notification at a user-set time; **no badge counts**, max one nudge/day enforced in code.
- [ ] Peak-end polish on the "all clear" moment.
- **Exit criteria:** ranking demonstrably shifts when the calendar is full; the app never schedules more than one notification/day; over-commitment is felt, not announced.

### Phase 3 — Capture everywhere + context connectors (the "connect everything" vision)
- [ ] Share Sheet extension + Home/Lock-Screen widget (one-tap add to Today/parking lot).
- [ ] Voice capture → `DateParser` → ranker (no separate AI surface).
- [ ] `ContextConnector` protocol + `ContextAggregator`; first connector = Gmail (opt-in, native OAuth; prototype context value via the session's Gmail/Calendar MCP first).
- [ ] Privacy: only derived/minimal context to the model; per-source opt-in + revoke.
- **Exit criteria:** a new task can be captured without opening the app; at least one external context source measurably improves ranking relevance (qualitative dogfood test); no raw email/event bodies ever leave the device.

### Phase 4 — Considered experiments (gated, opt-in, may never ship)
- [ ] Optional "block time for the top task" writing one calendar event (single deliberate gesture only).
- [ ] Hidden long-press "why is this first?" one-line rationale.
- [ ] "This rolled forward 5×: keep / park / drop?" gentle declutter prompt.
- **Exit criteria:** each must pass the principles in §4 — if it adds standing UI or a maintenance burden, it's cut.

### Cross-cutting: distribution
- App Store listing as a free (or low one-time) app; messaging centers on "calm + smart + no subscription, bring your own key." Onboarding: paste key (optional), grant Calendar (optional), see Today. Everything optional; the app is useful immediately with neither.
- **Marketing landing page** ([`PRD-landing-page.md`](PRD-landing-page.md)) — a static site (**not** a web app). Primary CTA is the App Store download (**gated on an actual listing existing**; until then the page is email-capture only); secondary is a launch / TestFlight email list.
- **Android is demand-gated.** The landing-page waitlist signal is the explicit green-light for starting Android work — **no Android build begins until that demand threshold is met** ([`PRD-android.md`](PRD-android.md) §0). This makes the page→waitlist→Android-go a real dependency chain, not a vague aspiration.

---

## 12. Success metrics

Because this is a personal-first tool, metrics are leading indicators of *genuine daily usefulness*, not vanity growth.

**North star:** **D7 / D30 "open-and-act" retention** — does the user open the app on day 7 and day 30 *and complete at least one task*? (Directly attacks the app-graveyard problem.)

**Supporting:**
- **Capture latency** — median time from app-open/widget-tap to task saved. Target < 3s.
- **Top-task acceptance** — of tasks completed, what fraction were the AI's #1 (or top-3) for their day? Rising = the ranker is earning trust. (Computed locally, privately.)
- **Reshuffle-under-hand incidents** — must be **zero** (the trust invariant; any occurrence is a P0 bug).
- **Daily-active ritual rate** — fraction of days the user opens within the window after the single notification.
- **Calm proxy** — sessions with zero settings/organizing actions / total sessions (high = the surface stays quiet; low = we accidentally built busywork).
- **Cost per active day** — Haiku spend on the user's key; must stay in single-digit cents.

**Guardrail (anti-metric):** if "time spent in app" rises *without* completions rising, that's organizing-isn't-doing creeping in — investigate and cut surface.

---

## 13. Risks & open questions

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| **Ranker feels wrong / users distrust the order** | Med | Honest-confidence hedge (built); pin-to-override; never reshuffle under hand; explainability as a hidden fallback |
| **BYO-key onboarding friction** (pasting a key is a big ask for non-technical users) | High | App is fully useful with heuristic-only and *no* key; key is a pure upgrade; consider a generous-but-capped optional proxy later (revisits non-goal — decide deliberately) |
| **iCloud sync conflicts / data loss** | Med | Local-first; atomic writes; LWW on id+createdAt; 100-cycle reconciliation test before ship |
| **Calendar context leaks privacy** | Med | EventKit on-device; only derived "free hours/next event" string to model; never raw event titles unless user opts in |
| **"Invisible AI" is invisible to the point of seeming dumb** | Med | The gravity ramp + crown make the ranking *legible without being loud*; the value must be felt within the first session |
| **Scope creep toward Notion/OmniFocus** | High | The non-goals (§4.1) are a hard contract; the "needs a new color/control/number → reject" heuristic |
| **Notification fatigue** | Low (by design) | Max one nudge/day enforced in code; no badge counts |

**Open questions (decide before the relevant phase):**
1. **Sync substrate** — CloudKit private DB vs. a SwiftData + CloudKit store? (Phase 1) — leaning CloudKit to keep the existing JSON model thin.
2. **Should a tiny, capped, app-funded AI tier exist** for users who won't paste a key, to widen appeal — or does that betray the BYO-key purity and reintroduce cost/subscription risk? (Pre-Phase 3 decision.)
3. **How loud is the over-commitment cue allowed to be** before it violates "ambient"? Needs dogfood tuning. (Phase 2)
4. **Voice capture** — on-device (Speech framework) vs. routed through the model? Privacy + cost trade. (Phase 3)
5. ~~**Is iPhone the week board too, eventually?**~~ **Resolved 2026-06-28** ([`PRD-iphone.md`](PRD-iphone.md) §9): iPhone stays a **vertical day list permanently**. The remaining live thread is whether **Android tablet/foldable** hosts a multi-day week board ([`PRD-android.md`](PRD-android.md)).
6. **Android go/no-go threshold** — what landing-page waitlist signal green-lights starting Android work? (Pre-everything; [`PRD-android.md`](PRD-android.md) §0.6.)

---

## 14. Appendix

### A. Glossary
- **Day-task** — `TodoItem` with `list == nil`; scheduled, rolls forward, ranked.
- **Parking-lot task** — `list ∈ {Later, Misc, Reminders}`; undated, never ranked, the someday valve.
- **Gravity ramp** — the Mac visual where rank index drives type size/weight/ink.
- **Safe moment** — a beat when no row is being touched/hovered/edited; the only time scores commit.
- **Honest-confidence hedge** — flattening the ramp when top scores cluster within 0.06 (AI-only).
- **BYO key** — user supplies their own Anthropic API key; funds intelligence; no subscription.

### B. Source research (verbatim themes this PRD answers)
- The seven tensions: guilt-not-help; capture-too-hard; everything-equal; no-time-connection; too-simple-or-complicated; organizing-isn't-doing; app-graveyard. Plus subscription fatigue, sync, notifications.
- Competitive teardown: Todoist, TickTick, Things 3, Microsoft To Do, Google Tasks, Apple Reminders, Notion, Trello, OmniFocus, Motion/Sunsama.
- The root mismatch: apps either add friction or stop short of the hard part (deciding + doing).

### C. Decisions locked (do not re-litigate without cause)
- ~~Apple-only, native, no backend we operate.~~ **Re-opened 2026-06-28:** Mac + iPhone ship now (native, no operated backend); **Android is a demand-gated conditional fork** with its own codebase + sync story; a **marketing landing page** is in scope. A web *app* / Windows app remain refused; **no operated backend by default** still holds. · No projects/tags/flags, ever. · Intelligence stays invisible. · BYO key, no subscription. · "Settle" + "Gravity Field" design languages. · Mac = week board only (list view retained in source, not presented). · **iPhone = vertical day list, permanently** (resolved 2026-06-28). · Never reshuffle under the user's hand.
