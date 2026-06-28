# Smart TDL — Android PRD (platform companion)

**Status:** Draft v1 (strategic fork — decision required) · **Owner:** David Xie · **Date:** 2026-06-28
**Platform:** Android (phone primary; tablet/foldable noted) · **Companion to:** [`PRD.md`](./PRD.md) (master/overview, iPhone + Mac)
**Relationship to master:** This document is a deep, Android-specific companion. It does **not** restate the product thesis, the seven research pains, the ten principles, or the permanent non-goals in full — those live in [`PRD.md`](./PRD.md) §1–§8 and are binding here too. It goes deep on what is unique and hard about Android, and it opens with the strategic question the master PRD's "Decisions locked" section (`PRD.md` §14.C) explicitly closed off.

> **Read this first.** Android is **newly in scope as of 2026-06-28** and it *contradicts* a locked decision. The master PRD §4.1 and §14.C lock "**Apple-only, native, no backend we operate.**" An Android app breaks the first clause outright and puts pressure on the third. This PRD therefore opens with an honest **Strategic implications & decision required** section before any product spec, so the owner can make an informed call about *whether and when* to build Android at all. The product spec that follows is written as "if we proceed, here is the right way" — not as a foregone conclusion.

---

## 0. Strategic implications & decision required

### 0.1 What Android breaks

| Locked decision (`PRD.md` §14.C / §4.1) | What Android does to it | Severity |
|---|---|---|
| **Apple-only, native-quality** | Broken outright. SwiftUI cannot target Android; this is a **second native codebase** in a different language and UI toolkit. | High — this is the core fork. |
| **No backend we operate** | Pressured. CloudKit (the planned iOS/Mac sync substrate) is Apple-only and cannot sync to Android. Cross-platform sync forces one of: accept an island, adopt a BaaS/self-host (a backend we operate), or push sync onto user-owned storage. | High — see §0.3. |
| **BYO key, no subscription** | **Survives intact.** The Anthropic Messages API is plain HTTPS; an Android client calls it directly with the user's key, same as iOS. No change to the funding model. | None — this is the easy part (see §0.4). |
| **Invisible intelligence, minimal surface, the design languages** | **Survive in spirit but require translation.** "Settle" and "Gravity Field" are expressed in `Theme.swift` / SwiftUI primitives; they must be re-expressed in Compose without defaulting to generic Material 3 (see §0.5, §3). | Medium — design risk, not architecture risk. |

The honest summary: **Android multiplies maintenance and dilutes the native-Apple identity that is part of the product's calm.** Two of the three things that make Smart TDL defensible (no subscription; invisible intelligence) carry over cleanly. The third (native-Apple quality and zero operated backend) is exactly what Android taxes.

### 0.2 Recommended engineering stack — KMP for the brain, native Compose for the skin

The decision is **not** "Kotlin/Compose vs. Flutter vs. React Native." The product's whole thesis is native-grade calm, so a cross-platform *UI* runtime (Flutter/RN) is rejected on the same grounds the master PRD rejects cross-platform generally — it would compromise the surface the product is selling. The real choice is narrower: **how much of the existing Swift logic do we share with Android, and how?**

**Option A — Pure Kotlin + Jetpack Compose (duplicate the model + ranker).**
Re-implement `TodoItem`, `Recurrence`, the ordering rule, `DateParser`, `HeuristicRanker`, `HaikuRanker`, and the safe-moment buffering in Kotlin. iOS stays Swift; Android is independent Kotlin.
- **Pro:** simplest build; no new toolchain; each platform idiomatic; fastest to a first Android build.
- **Con:** the **brain is duplicated**. Every future ranker change, every new `context` signal, every tweak to the ordering rule (`completed sink → pinned → importance desc → sortIndex`) or the safe-moment commit must be written twice and kept behaviorally identical. The master PRD's most load-bearing invariants (P5 never-reorder-under-hand, P6 honest-confidence hedge at the 0.06 threshold) are exactly the kind of subtle logic that **drifts** when duplicated. A drift here is a P0 trust bug on one platform only — the worst kind to catch.

**Option B — Kotlin Multiplatform (KMP), share the brain, native UI per platform. ← RECOMMENDED**
Extract the platform-agnostic core into a KMP shared module: `TodoItem` + `Recurrence` (with the resilient `decodeIfPresent`-equivalent), the `order` rule, `DateParser`, the `Ranker` protocol + `HeuristicRanker` + `HaikuRanker`, and the safe-moment buffering state machine (`scheduleRank` → `pendingScores` → `scheduleIdleCommit` → `commitPendingRank`, the `interacting` set, `topScoresClustered`). UI stays **native**: SwiftUI on Apple, Compose on Android. iOS consumes the shared module as a framework; Android consumes it as a normal Kotlin dependency.
- **Pro:** the brain — and the trust-critical invariants — live in **one** place, tested once, behaviorally identical across all three surfaces. New `context` signals (calendar, Gmail) feed one ranker. This is the architectural match to the master PRD's central claim that "the `context` string is the one universal seam and the auto-sort is the only output" (`PRD.md` §7.3, §9.1) — a single shared seam is the cleanest possible expression of that.
- **Con:** real cost. (1) **It requires migrating the existing Swift core to Kotlin** — the iOS app today is Swift, so KMP isn't free adoption; it's a rewrite-the-core-in-Kotlin project that then *re-exposes* to Swift. (2) Build complexity: Gradle + Xcode interop, a shared-module CI, KMP-version churn. (3) The team is currently a SwiftUI shop; KMP adds a Kotlin competency.

**Recommendation: Option B (KMP), but *gated* — see §0.6.** The brain is the product; duplicating it (Option A) puts the master PRD's two hardest invariants (P5, P6) at permanent risk of silent cross-platform drift, which is unacceptable for a product whose moat is trust. KMP pays a one-time migration cost to make drift structurally impossible. **However**, that migration cost is only justified *after* the iOS/Mac brain has stabilized — porting a moving target to Kotlin twice is worse than either option. So: finish and freeze the iOS ranker + sync first (master PRD Phase 0–1), *then* extract to KMP as the first Android workstream. If the team cannot take on Kotlin competency at all, Option A is the fallback, with a **mandatory shared behavioral test vector** (a fixture of task-sets → expected score-order + commit-timing) run against both implementations in CI to catch drift.

### 0.3 Sync is the hard problem

CloudKit is Apple-only. The master PRD's Phase 1 (`PRD.md` §11) is "CloudKit private-DB mirror." That substrate **cannot** reach Android. The options, with honest trade-offs:

| Option | What it is | Honoring "no backend we operate" | Privacy surface | Cost | Recommendation |
|---|---|---|---|---|---|
| **(a) Island** | Android is a separate device family with **no cross-platform sync** initially. Each platform local-first; iOS/Mac sync via CloudKit, Android local-only (or Android-to-Android later). | ✅ Fully — no new backend. | ✅ None added. | ✅ ~zero. | **Ship Android on this first.** Honest to users ("Android does not yet sync with your iPhone"). De-risks the launch; lets demand validate before we pay the sync tax. |
| **(b) Cross-platform sync substrate (BaaS or thin self-host)** | A Firebase/Supabase backend, or a thin self-hostable sync service, holds the canonical task store; all three platforms sync through it. | ❌ Reintroduces **a backend the team operates** — the exact non-goal §4.1 refuses. | ⚠️ User task data now transits/rests on a server we run or rent. Must be stated plainly; encryption-at-rest + minimal schema required. | 💲 Ongoing hosting + ops + an account system (or anonymous device-keyed records). | **Only if demand proves it.** This is the real cost of true cross-platform parity. Treat as a deliberate, separately-decided phase, not a default. |
| **(c) User-owned sync** | Sync rides a file the **user** controls — their own cloud-storage file (e.g. a `tasks.json` in a user-chosen Drive/Dropbox/WebDAV folder), or an export/import handoff. The team operates no server. | ✅ Mostly — no backend we operate; we use the user's storage, the same philosophy as BYO-key. | ✅ Data rests in the user's own account. | ✅ Low (client integration only). | **The principled middle path.** Slower/clunkier than (b), but it preserves the constitution. Strong fit with the BYO-key ethos ("you bring your own key; you bring your own sync"). Conflict policy is last-writer-wins on `id`+`createdAt`, same as the master PRD's CloudKit plan (`PRD.md` §7.8). |

**Recommended sequencing:** **(a) island → (c) user-owned sync → (b) operated backend only if (c) proves insufficient and demand is real.** This keeps the constitution intact as long as possible and never pays the operated-backend cost speculatively. Crucially, the shared model is JSON-first already (`tasks.json`, atomic writes, resilient decode) — option (c) is a natural extension of the existing persistence boundary, and the KMP shared module can own the serialization so all platforms read/write a byte-compatible file.

### 0.4 BYO key on Android (the easy part — keep it identical)

The funding model is untouched. The Android client makes the **same raw HTTPS call** the iOS `HaikuRanker` makes:

- **Endpoint:** `POST https://api.anthropic.com/v1/messages`
- **Headers:** `x-api-key: <user key>`, `anthropic-version: 2023-06-01`, `content-type: application/json`
- **Model:** `claude-haiku-4-5` (same id; do not change without master-PRD alignment)
- **Body:** the same task list + `context` string the shared ranker assembles. No Swift SDK on iOS → **no Kotlin SDK on Android either**; a hand-rolled HTTP call (Ktor or OkHttp) keeps both platforms on the identical wire shape, which the KMP shared module can own end-to-end (Ktor client in `commonMain`).

**Key storage — the Android analog of the iOS Keychain zero-prompt gating:**

| iOS (master PRD §7.9) | Android equivalent |
|---|---|
| Keychain, service `com.smarttdl.SmartTDL`, account `anthropic-api-key` | **Android Keystore-backed `EncryptedSharedPreferences`** (Jetpack Security), or a `MasterKey`-wrapped DataStore. The Keystore holds the symmetric key; the encrypted blob holds the API key. |
| `smarttdl.hasAPIKey` UserDefaults flag gates Keychain reads → zero system prompts on a fresh/no-key install; reads off the main thread | A plain `SharedPreferences`/DataStore boolean `smarttdl.hasAPIKey` gates the `EncryptedSharedPreferences` read. Android Keystore reads do **not** prompt the user (unlike macOS re-prompting on signature change), so the zero-prompt property is *easier* on Android — but still **never read the encrypted store on the main thread** (do it on `Dispatchers.IO`), and **never block launch** on it. Degrade to `HeuristicRanker` if absent. |

Non-negotiable parity rules (mirroring `PRD.md` §7.9 gotchas): a no-key/fresh install produces **zero** prompts and never blocks launch; the local `HeuristicRanker` works offline with no key (P10); only task titles + minimal `context` ever leave the device (P9).

### 0.5 Brand tension — honoring "Settle"/"Gravity Field" without defaulting to Material 3

The risk: Android developers reach for Material 3 components, dynamic color (Material You), and the system font, and the bespoke calm of "Settle" dissolves into a generic Google app. This must be actively resisted. The design languages are chosen and binding (`PRD.md` §8) — Android *extends within them*, it does not re-invent. See §3 for the full translation table; the headline decisions:

- **Opt out of Material You dynamic color.** Smart TDL's palette is intentional warm-paper, not the user's wallpaper. Use a **fixed custom color scheme** in Compose (`MaterialTheme` with explicit `ColorScheme`, dynamic color disabled), porting `Theme.swift`'s `Color(light:dark:)` tokens verbatim as Compose `Color` pairs selected by `isSystemInDarkTheme()`.
- **Terracotta accent only on live interaction** — same rule as iOS. Not a global Material accent; applied only to the live #1 and the commit moment.
- **Bundle Playfair Display** as a Compose `FontFamily` for day mastheads; system font (Roboto, the SF analog) for body. Same serif-masthead / system-body split as iOS.
- **Ink-stroke completion** re-implemented as a Compose draw/animation, not the Material checkbox.
- **Respect Android idioms where they don't fight the brand:** edge-to-edge layout, the **predictive back gesture**, and gesture navigation are *platform-native calm* and should be embraced — they don't conflict with "Settle," they reinforce it. The line to hold: adopt Android's *interaction* idioms, reject Android's *visual* defaults.

### 0.6 The sharp recommendation — whether and when

**Do not build Android yet. Build it after iOS/Mac + sync are solid, and gate the start on a real demand signal.** Specifically:

1. **Prerequisite (hard gate):** the iOS/Mac brain is frozen — master PRD **Phase 0 (hardening)** and **Phase 1 (CloudKit sync)** are complete and stable. Porting a moving ranker to Kotlin is the worst-case sequencing; freeze first.
2. **Demand gate:** a concrete signal that Android is worth the maintenance multiplier — e.g. a marketing landing page (also newly in scope as of 2026-06-28) capturing Android waitlist sign-ups above an agreed threshold, or repeated direct requests. Build the landing page first; let it measure demand cheaply before any Android code.
3. **Sequencing once green-lit:** KMP-extract the frozen brain (§0.2 Option B) → Android phone app on the island sync model (§0.3 option a) → user-owned sync (§0.3 option c) → operated backend (§0.3 option b) only if proven necessary.

**Be honest about the cost:** Android roughly **doubles ongoing maintenance** (second UI codebase, second store listing, second QA matrix, fragmentation across OEM skins and OS versions) and **dilutes the native-Apple identity** that is part of why the product feels calm. It is justified *only* if the addressable calm-seeking, BYO-key-comfortable Android audience is large enough to repay that — which the landing page exists to find out. The recommended posture is **patient**: prove the product and the sync story on Apple, prove demand on a landing page, then extend.

---

## 1. Scope, audience, and what carries over

**In scope (this doc):** Android **phone** app as the primary surface; **tablet/foldable** as a noted secondary (§5.4). **Out of scope:** **Wear OS** (explicitly deferred — §6.6), Android Auto, TV, and any operated backend beyond what §0.3 sequences.

**Target user (Android-specific slice of `PRD.md` §5):** the same two personas — "the overwhelmed competent" and "the calm seeker" — who happen to be on Android. The BYO-key requirement self-selects for a slightly more technical user, which is fine (it's the same self-selection iOS accepts). Anti-persona unchanged: the system tinkerer is still sent to a power app.

**Pains this platform answers (from the seven; `PRD.md` §2, §6):** all seven apply identically — the model and ranker are shared. Android-specific *amplifiers*:
- **Pain #2 (capture too hard)** is where Android can actually *exceed* iOS: a system **share-target Intent**, a **Quick Settings tile**, **Glance home-screen widgets**, and **App Actions / Assistant** give more one-gesture capture entry points than iOS offers (§6). This is the strongest Android-native upside.
- **Pain #7 (retention / notifications)** must honor the same "max one honest nudge/day, never a count badge" rule (`PRD.md` §7.7) — and Android makes the no-badge promise easy because notification dot/badge behavior is opt-in per channel (§6.4).

**What is shared vs. native:**

| Layer | Shared (KMP `commonMain`) | Native (Android) |
|---|---|---|
| Model (`TodoItem`, `Recurrence`), ordering rule, resilient (de)serialization | ✅ | — |
| `DateParser`, `Ranker` seam, `HeuristicRanker`, `HaikuRanker` (Ktor HTTP), safe-moment buffering, honest-confidence hedge | ✅ | — |
| Persistence boundary (`tasks.json` read/write), key handling abstraction | ✅ logic | Android Keystore / `EncryptedSharedPreferences` impl |
| UI: day list, rows, completion, gravity ramp, settings | — | ✅ Jetpack Compose |
| OS surfaces: widgets, share-target, QS tile, notification, App Actions | — | ✅ Android |

---

## 2. Information architecture (Android phone)

**One model, native surface.** Android phone mirrors the **iPhone** identity, not the Mac one: a **vertical, scrollable day list** (the analog of `TaskListView` / `TaskRowView`), not the Mac week board. Rationale: the phone is the capture-and-glance surface used in motion (`PRD.md` §7.1); the week board is a desk/planning surface. Tablet/foldable may host a week-board-style multi-day layout (§5.4), but that is secondary.

- **Today + the 7-day window** (`visibleDays` = today + next 6), exactly as the shared model defines it.
- **Day-tasks** (`list == nil`) — scheduled, roll forward if unfinished, AI-ranked. **Parking-lot tasks** (`list ∈ {Later, Misc, Reminders}`) — undated, never roll forward, never ranked; the someday/maybe pressure valve. (Definitions binding from `PRD.md` §7.1; not re-derived here.)
- **Open vs. completed** per day; completed sink into a **dimmed completed pool**.
- **Parking lots** are reachable but kept out of the daily field of attention — a **vertical-scroll target *below* the day list** (scroll past the last day to reach Later / Misc / Reminders), **not** a trailing-lane like the Mac and **not** a tab bar (§2 forbids bottom tabs). This is the **same mechanism as iPhone** ([`PRD-iphone.md`](PRD-iphone.md) §3), so the two phones stay mirror-images. They must never become a wall of guilt (P7).

**Navigation chrome — minimal, Android-idiomatic:** a single quiet top area (the day masthead in Playfair) and the smallest possible control set: appearance toggle, find, settings. No bottom navigation bar full of tabs (that would be Material clutter the master PRD's minimalism forbids). The **predictive back gesture** handles "out of search / out of edit" naturally.

---

## 3. Design language on Android — the "Settle"/"Gravity Field" translation

The two named systems (`PRD.md` §8) are binding. This table is how each iOS/Theme.swift element maps to Compose **without** reverting to Material 3 defaults. The governing rule from the master PRD applies unchanged: *if a new idea needs a new color, a new control, or a number on screen, it probably violates the language — find the ambient version instead.*

| "Settle" / "Gravity Field" element (iOS) | Android (Compose) translation | Anti-pattern to avoid |
|---|---|---|
| Warm-paper tokens via `Color(light:dark:)` | A **fixed custom `ColorScheme`** (light + dark), tokens ported verbatim; selected by `isSystemInDarkTheme()`. **Dynamic color OFF.** | Material You dynamic color (wallpaper-derived) — kills the intentional palette. |
| Terracotta accent **only on live interaction** | A single reserved accent `Color`, applied only to the live #1 row and the commit moment. | Setting it as the global `primary` and letting Material splash it on every button/FAB. |
| Serif (Playfair Display) day mastheads + system body | Bundle Playfair as a `FontFamily` in `res/font`; masthead `Text` uses it; body uses the system family. | Using the Material `Typography` defaults throughout (loses the serif/system contrast). |
| Ink-stroke completion (strikethrough animation) | Custom `Canvas`/`drawBehind` stroke animation on tap-to-complete. | The Material `Checkbox` / filled-tonal check — wrong texture entirely. |
| Dimmed completed pool | Reduced-alpha rows in a collapsed section. | A separate "Completed" screen (adds navigation surface). |
| **Gravity ramp** (type SIZE + WEIGHT + INK step down **by rank index**, quantized, never raw score) | Map the shared ranker's quantized rank index to a Compose `TextStyle` ladder (font size + weight + alpha). Index-quantized to avoid jitter — identical rule to iOS. | Animating size/weight off the raw 0…1 score → visible jitter; binding it to anything Material-component-shaped. |
| #1 "NOW" crown | A small, quiet crown glyph on the live #1 only. | A badge/chip (Material `Badge`) — reads as a notification count, forbidden. |
| Honest-confidence hedge (flatten ramp when top-two within 0.06, AI-only) | Same shared signal (`topScoresClustered`) flattens the Compose `TextStyle` ladder. | Re-deriving the threshold on Android — it lives in the shared module (one source of truth). |
| **No numbers / scores / badges, ever** | No `Badge`, no count chips, no numeric priority anywhere. | Material's notification badge dots on the launcher icon (disable at channel level — §6.4). |

**Android interaction idioms to *embrace* (these reinforce calm, they don't fight it):** edge-to-edge content, gesture navigation, the **predictive back gesture** (Android 13+ / 14 polish), smooth scroll physics, and per-app dark/light following the system. These are platform-native calm and should be first-class.

---

## 4. The shared brain on Android (invisible ranking) — what must not regress

Everything in this section is *shared logic* (KMP), but the invariants are restated because they are the product's trust core and a P0 if they regress on Android specifically.

- **`Ranker` seam (shared):** `rank(tasks, context) -> Map<UUID, Double>` returning importance 0…1. `HeuristicRanker` always-on/offline (urgent-word scoring + day-proximity). `HaikuRanker` activates when a key is present, raw Ktor `POST` to the Messages API (`claude-haiku-4-5`). **The `context` string is the one seam for all future signals** (calendar free-hours, Gmail, …); connectors are *inputs*, the auto-sort is the only *output*. No new UI is ever added by intelligence (P1).
- **Safe-moment commit (P5 — the trust mechanism):** `scheduleRank` debounce (~350ms) → `rerank()` over the visible open day-tasks → scores buffered in `pendingScores` → `scheduleIdleCommit` (~1s) → `commitPendingRank` applies **only** when nothing is being touched (the `interacting` set is empty). On Android, "interacting" means: a row is pressed/dragged, a `TextField` is focused (editing), or a scroll/fling is in flight. **Any reshuffle under the user's finger is a P0 trust bug** — the same bar as iOS. Compose makes this clean: gate the commit on `interactionSource`/focus/scroll state.
- **Honest-confidence hedge (P6, AI-only):** `topScoresClustered` — top two importances within 0.06 → flatten the gravity ramp instead of crowning a near-tie. Gated on real AI (`usingAI`) because heuristic ties too often. Shared; Android just renders the flattened ladder.
- **Ordering rule (shared):** `completed sink → pinned first → importance desc (unranked = -1, last) → manual sortIndex`. **Pin is the one sanctioned manual override** (one-tap intent, not a system to maintain) — on Android a long-press or a swipe action, never a priority picker.
- **Roll-forward & sweep (shared):** `rollForward()` on launch moves past unfinished day-tasks to today; `pushAllToTomorrow()` is the end-of-day clean-slate sweep. Recurrence (daily/weekdays/weekly/monthly) spawns the next occurrence on completion.
- **Cost/perf (shared):** rank only the visible window, debounce 350ms, commit on idle → a few Haiku calls/session, pennies on the user's key. Verify with a 500-task stress fixture before any Android ship (mirrors `PRD.md` §9.3).
- **Resilient (de)serialization:** the Kotlin model must keep loading **old `tasks.json` files** that lack newer fields (the Kotlin analog of `decodeIfPresent` — kotlinx-serialization with optional/default fields and `ignoreUnknownKeys = true`). Never break old files. This is also what makes user-owned sync (§0.3c) byte-compatible across platforms.

---

## 5. Capture & core interactions (Android phone)

### 5.1 In-app capture (P2 — one gesture)
- **Inline add per day** — tap into a day, type, done. No modal, no required fields (mirrors iOS).
- **Natural-language dates** via the **shared `DateParser`** — "call Sam friday" files on Friday and strips the token. Silent; no date picker required.
- Capture defaults to **Today** unless a date is parsed; ambiguous "someday" phrasing can be nudged to a parking lot by the ranker without interrupting the user.
- **Acceptance:** a new user adds five tasks in under 15 seconds without opening a menu (same bar as `PRD.md` §7.2).

### 5.2 Completion & anti-guilt (P7)
- Tap-to-complete with **ink-stroke** strikethrough; completed dim into the pool.
- **Roll-forward** so the past never accumulates as guilt; **end-of-day sweep** for a deliberate clean slate.
- **Undo:** the shared 50-step undo stack over toggle/delete/move. On Android, surface via a **Snackbar "Undo"** (the idiomatic, calm undo affordance) and/or a gesture — never a destructive action without an undo path.

### 5.3 Reschedule / pin
- **Reschedule:** long-press → quiet menu (the Android analog of the iOS context-menu reschedule), or drag between days. No date-picker wall unless the user wants one.
- **Pin:** the single sanctioned override — a one-tap/long-press intent, surfaced minimally. Never a P1–P4 picker (non-goal).

### 5.4 Tablet / foldable (secondary)
- Larger screens **may** host a multi-day, week-board-style layout (closer to the Mac `WeekBoardView` spirit) — a multi-column day view that uses the extra width. This is a **responsive enhancement**, not a separate app: same shared brain, same tokens, same gravity ramp; the columns are just a wider expression of the day list.
- Foldable: respect fold/unfold and posture (table-top); the layout adapts via window-size classes. **Do not** introduce week-board-only features that would create model divergence — the master PRD keeps the week board presentation-only and additive (`PRD.md` §7.1).

---

## 6. Android-native surfaces (the platform's real upside)

These are where Android can *deepen* pain-#2 capture and the pain-#7 ritual beyond iOS — while honoring P1 (intelligence never adds UI) and the "max one honest nudge/day, no badge" rule.

| Surface | What it does | Brand/principle guardrail |
|---|---|---|
| **Share-target Intent** | Register an `intent-filter` (`ACTION_SEND`, text) so any app can "Share → Smart TDL" a selection/link straight into Today or a parking lot. Parsed through the shared `DateParser`. | One-gesture capture (P2). No required fields. Lands quietly; no confirmation wall. |
| **Glance home-screen widget** | A Jetpack **Glance** widget showing Today with the #1 already on top, plus a one-tap "add to Today." | Render with the "Settle" tokens, not Material widget defaults. Gravity ramp may appear in miniature; **no badges/numbers** in the widget. |
| **Quick Settings tile** | A QS tile that opens straight into one-tap capture (or "show Today"). | Pure capture/glance shortcut — adds no new intelligence UI (P1). |
| **Single daily notification** | At most **one** local notification/day (user-set time, default morning): "Your day is ready" → opens Today with #1 on top. Scheduled via `AlarmManager`/`WorkManager`. | **No count badge** (P7). It's an *invitation to a calm screen*, not an overdue tally. Enforced in one `Notifier` place: max one scheduled/day, by design. |
| **Notification channel config** | Create the channel with **badge/dot disabled** (`setShowBadge(false)`) and low-importance, non-buzzy defaults. | Makes the no-badge guilt-machine promise structural, not just a convention. |
| **App Actions / Assistant** | Optional: a `shortcuts.xml` capability so "add a task to Smart TDL" via Assistant routes to capture. | Capture only; no conversational AI surface (P1). Lowest priority. |
| **Wear OS** | **Explicitly out of scope for now** (§6.6). | — |

### 6.4 The notification & badge contract (binding)
The system can **never** produce more than one scheduled nudge per day by design, and **never** shows a numeric badge of incomplete tasks. On Android this is *easier* to guarantee than iOS: disable the badge at the channel level (`setShowBadge(false)`), use a single `WorkManager` daily job, and never call any "badge count" API. Re-engagement, if any, is a single gentle "still here when you need it" after a long absence — then silence (mirrors `PRD.md` §7.7).

### 6.6 Wear OS — explicitly deferred
Not in scope. A watch surface would be a third UI codebase for marginal capture value over the phone widget + QS tile, and it risks the notification minimalism. Revisit only if Android itself proves out and watch demand is concrete.

---

## 7. Privacy, key handling & data (Android specifics)

- **Key storage:** Android Keystore-backed `EncryptedSharedPreferences` (or `MasterKey`-wrapped DataStore). `smarttdl.hasAPIKey` boolean gates the encrypted read; reads on `Dispatchers.IO`; launch never blocks; zero prompts on a fresh/no-key install. Degrade to `HeuristicRanker` if absent (P10). (Full mapping in §0.4.)
- **Network:** the only outbound call is the user's key → `api.anthropic.com`, sending **only task titles + minimal `context`** (P9). No analytics SDK, no account, no server (in the island/user-owned-sync models). State this plainly in Settings, same as iOS.
- **Permissions posture:** request the **minimum**. `INTERNET` only (for the user's own key call). **Calendar** (`READ_CALENDAR`) is requested *only* if/when the time-connection layer ships (`PRD.md` §7.4), and only to derive a "free hours / next event" `context` line — never raw event titles unless the user opts in. **Notifications** (`POST_NOTIFICATIONS`, Android 13+) requested only when the daily-ritual notification is enabled — and the app is fully usable if the user declines.
- **Sync data surface:** in the island model (§0.3a) there is none. In user-owned sync (§0.3c) the data rests in the user's chosen cloud account. Only an operated-backend model (§0.3b) introduces a server-side privacy surface — which is precisely why it's gated and last.

---

## 8. Roadmap & acceptance criteria (Android)

Phased and gated. **No Android code begins until the master-PRD prerequisites in §0.6 are met** (iOS/Mac brain frozen via master Phase 0–1, and a demand gate via the landing page). Phases A–E below assume that green light.

### Phase A — KMP core extraction (the brain, once)
*Make the shared brain real before any Android UI.*
- [ ] Extract `TodoItem` + `Recurrence`, the `order` rule, `DateParser`, the `Ranker` seam + `HeuristicRanker` + `HaikuRanker` (Ktor), and the full safe-moment buffering state machine into a KMP `commonMain` module.
- [ ] iOS consumes the shared module (replacing the Swift core) with **zero behavioral change** — verified by the existing iOS test suite plus a new **shared behavioral test vector** (task-sets → expected score-order + commit-timing) run in `commonTest`.
- [ ] Resilient deserialization confirmed against real old `tasks.json` files.
- **Exit:** the shared module passes the behavioral vector; iOS app runs on it identically; cold-path Keychain/Keystore gating still produces zero prompts.

### Phase B — Android phone MVP (island, BYO key)
- [ ] Compose day list (`TaskListView` analog) with "Settle" tokens (dynamic color OFF), Playfair mastheads, ink-stroke completion, dimmed completed pool.
- [ ] Gravity ramp rendered from the shared quantized rank index; honest-confidence hedge flattens it (AI-only).
- [ ] Inline add + shared `DateParser`; tap-complete; long-press reschedule; pin; roll-forward; end-of-day sweep; Snackbar undo.
- [ ] Settings: paste key → `EncryptedSharedPreferences`; appearance toggle (System/Light/Dark); free-text `context` field; plain-language privacy statement.
- [ ] `HeuristicRanker` works with no key; `HaikuRanker` activates with a key; safe-moment commit verified (no reshuffle under finger).
- [ ] 500-task stress fixture: no lag, ranking stays cheap.
- **Exit (acceptance):**
  - Five tasks captured in < 15s with no menu.
  - **Zero** reshuffle-under-hand incidents across a scripted interaction test (the P5 invariant — any occurrence is a P0).
  - Fresh/no-key install: zero system prompts, launch never blocks, app fully usable offline on heuristic ranking.
  - No badges/numbers/scores anywhere on screen.

### Phase C — Android-native capture & ritual
- [ ] Share-target Intent → Today/parking lot via `DateParser`.
- [ ] Glance home-screen widget (Today + #1 + one-tap add), branded tokens, no badges.
- [ ] Quick Settings tile (one-tap capture / show Today).
- [ ] Single daily notification via `WorkManager`; channel created with `setShowBadge(false)`; max one nudge/day enforced in a single `Notifier`.
- **Exit (acceptance):** capture works without opening the app (share-target, widget, tile); the system can never schedule >1 notification/day and never shows a numeric badge — verified by test.

### Phase D — Cross-platform sync (sequenced per §0.3)
- [ ] **(c) User-owned sync** first: a user-chosen cloud file holding `tasks.json`; last-writer-wins on `id`+`createdAt`; local-first preserved (offline fully works); byte-compatible with iOS/Mac via the shared serialization.
- [ ] Honest in-product messaging about what does/doesn't sync at each stage (the island stage must say so plainly).
- [ ] **(b) Operated backend** only if (c) proves insufficient *and* demand is real — separately decided, with its own privacy/cost review (it reintroduces a non-goal).
- **Exit (acceptance for c):** a task added on Android appears on iPhone/Mac (and vice versa) after a sync cycle; airplane-mode edits reconcile on reconnect; no data loss across 100 edit/sync cycles; no backend operated by the team.

### Phase E — Time/context parity (mirrors master Phase 2–3)
- [ ] `TimeContextProvider` (Android Calendar Provider) → "free hours / next event" line into the shared `context`; ambient over-commitment cue (quietest honest signal; no red, no numbers).
- [ ] First context connector (Gmail) feeding `context` — opt-in, native OAuth, only derived/minimal context to the model.
- **Exit:** ranking demonstrably shifts when the calendar is full; no raw event/email bodies leave the device; no new standing UI added (P1).

---

## 9. Success metrics (Android-specific reads of the master set)

Same north star as `PRD.md` §12 — **D7/D30 "open-and-act" retention** — plus Android reads:
- **Capture latency** (open/widget-tap/share-target → saved): target < 3s; the share-target path should beat in-app.
- **Reshuffle-under-hand incidents:** **zero** (P5 trust invariant; any occurrence is P0).
- **Calm proxy:** sessions with zero settings/organizing actions ÷ total — high means the surface stayed quiet (no accidental Material clutter crept in).
- **Cross-platform drift incidents:** **zero** behavioral divergences between the Android and iOS ranker/commit — directly measured by the shared behavioral vector. (This metric only exists because of the KMP decision; under Option A it would be a manual, error-prone audit instead.)
- **Cost per active day:** Haiku spend on the user's key in single-digit cents.

**Guardrail (anti-metric):** if time-in-app rises without completions rising, organizing-isn't-doing is creeping in — investigate and cut surface (same as master §12).

---

## 10. Risks & open questions (Android)

| Risk | Likelihood | Mitigation |
|---|---|---|
| **Maintenance multiplier** — two UI codebases, store, QA, OEM/OS fragmentation | High | KMP shares the brain (the expensive, trust-critical part); gate the start on demand; keep the Android surface intentionally minimal. |
| **Cross-platform ranker drift** (esp. P5/P6) | Med (High under Option A) | KMP single source of truth + shared behavioral test vector in CI. If forced to Option A, the vector is mandatory and run against both. |
| **Material 3 / dynamic-color creep dilutes "Settle"** | High | Dynamic color OFF; fixed ported `ColorScheme`; custom completion/ramp; design-review gate against the §3 table. |
| **Sync reintroduces an operated backend** (non-goal) | Med | Sequence island → user-owned → operated; only pay the operated cost if proven; separate decision + privacy review. |
| **Identity dilution** — Android weakens the native-Apple calm story | Med | Patient sequencing; landing page validates demand before commitment; Android held to the same calm bar, not "good enough for Android." |
| **Background work limits / OEM battery killers** breaking the daily notification | Med | Use `WorkManager` (respects Doze); accept that the nudge is best-effort and *honest* (one/day, skippable) — never escalate or nag to compensate. |
| **Permission friction** (notifications on 13+, calendar) | Low | All optional; app fully useful with none granted (P10). |

**Open questions (decide before the relevant phase):**
1. **KMP now vs. Option A fallback** — does the team take on Kotlin core competency, or accept Option A + mandatory behavioral vector? (Pre-Phase A.)
2. **Sync substrate end-state** — is user-owned sync (§0.3c) acceptable as the *permanent* answer, preserving the no-operated-backend constitution, or is true real-time parity (§0.3b) eventually required? (Pre-Phase D.)
3. **Tablet/foldable week board** — does the larger-screen multi-day layout ship in Phase B or wait? (Product taste call; mirrors the open iPhone-week-board question in `PRD.md` §13.5.)
4. **Landing-page demand threshold** — what Android waitlist number actually green-lights Phase A? (Pre-everything; this is the gate.)
5. **The capped-app-funded-AI-tier question** (`PRD.md` §13.2) is *more* tempting on Android (where pasting a key is a bigger ask for a broader audience) — but answering it "yes" reintroduces cost/subscription risk and an operated billing surface. Decide deliberately, aligned with the master PRD, not as an Android expedient.

---

## 11. Appendix — Android ↔ iOS mapping (quick reference)

| Concept | iOS (master PRD) | Android |
|---|---|---|
| Phone day list | `TaskListView` / `TaskRowView` (SwiftUI) | Compose day list (native) |
| Theme tokens | `Theme.swift` `Color(light:dark:)` | fixed `ColorScheme`, dynamic color OFF |
| Key store | Keychain (`com.smarttdl.SmartTDL` / `anthropic-api-key`) | Keystore-backed `EncryptedSharedPreferences` |
| Key gate flag | `smarttdl.hasAPIKey` (UserDefaults) | `smarttdl.hasAPIKey` (DataStore/SharedPreferences) |
| Ranker HTTP | raw `URLSession` POST, no Swift SDK | raw Ktor/OkHttp POST, no Kotlin SDK |
| Model id | `claude-haiku-4-5` | `claude-haiku-4-5` (identical) |
| Reschedule | context-menu | long-press menu / drag |
| Undo | `⌘Z`, 50-step stack | Snackbar undo, same shared 50-step stack |
| Capture-everywhere | share sheet, widget (planned) | share-target Intent, Glance widget, QS tile |
| Daily nudge | one local notification, no badge | one `WorkManager` notification, channel badge OFF |
| Sync (planned) | CloudKit private DB (Apple-only) | user-owned file → (operated backend only if proven) |
| Shared brain | (origin) Swift core | KMP `commonMain` (post-extraction) |

*Binding cross-references to the master:* product thesis & positioning (`PRD.md` §1–§3), the ten principles (`PRD.md` §4), non-goals (`PRD.md` §4.1 — note Android now amends the "Apple-only / no-backend" clauses, see §0), personas (§5), pain→principle→feature spine (§6), product spec (§7), design languages (§8), architecture & invariants (§9), roadmap (§11), metrics (§12), risks (§13).
