# Smart TDL — iPhone PRD (the capture-and-glance surface)

**Status:** Draft v1 · **Owner:** David Xie · **Last updated:** 2026-06-28
**Platform:** iPhone (iOS 17+, SwiftUI) · **Companion to:** [`PRD.md`](./PRD.md) (master/overview) · **Repo:** `github.com/davidaxie/smart-tdl`

> This is the **platform-specific PRD for iPhone**. It assumes — and does not re-derive — the shared product thesis, the seven research pains, the ten principles (P1–P10), the permanent non-goals, the data model, the ranking seam, and the two design languages. All of those live in the master [`PRD.md`](./PRD.md); see especially §4 (principles), §4.1 (non-goals), §7.3 (ranking engine), §7.8 (sync), §8 (design languages), §9 (architecture). Where this doc restates a shared fact, it does so only enough to stand alone.
>
> **Why a separate iPhone doc.** The phone is not a smaller Mac. It is a *different job*. The Mac is the planning surface, used at a desk, keyboard-first, with a week board (`WeekBoardView`). **The iPhone is the capture-and-glance surface, used in motion** — one thumb, three seconds, often before the app even opens. The pains the phone owns are **#2 (capture is too much work)** and **#7 (the app graveyard / retention)**; it shares **#1 (guilt)**, **#3 (everything equal)**, and **#5 (simple-but-smart)**. This doc goes deep on the parts that are *only* true on a phone: ergonomics in motion, capture everywhere (widgets / Share Sheet / Siri & App Intents), the daily ritual + single honest notification, legible invisible ranking on a small screen, safe-moment re-rank under a literal finger, iCloud parity, and the open question of whether the phone ever becomes a week board.

---

## 1. iPhone in one paragraph

On iPhone, Smart TDL is a single vertical scroll of days — **Today first**, then the next six — rendered by `TaskListView`. Each day has a serif Playfair masthead, the day's open tasks (the most important already floated to the top, no number or badge says so), an always-present inline add row, and a dimmed pool of what you've completed. You add a task in one gesture and natural-language dates (`DateParser`) file it silently. You complete a task with a tap or a left-swipe and feel a single success haptic. You reschedule with a swipe or a long-press menu. The intelligence — local `HeuristicRanker` with no key, Claude Haiku 4.5 (`HaikuRanker`) when you've pasted your own Anthropic key — never shows itself: it only ever **reorders, rolls forward, and (later) connects context**. The phone's defining promises are *capture latency ≈ zero from anywhere on the device* and *one calm daily ritual that brings you back tomorrow* — never a notification stream, never a count badge.

---

## 2. Scope & the iPhone job-to-be-done

### 2.1 What the iPhone surface is for

| Job (from master §5) | iPhone expression |
|---|---|
| Capture a fleeting thought in one gesture | Inline add per day; **plus**, from outside the app: Lock/Home-Screen widget, Share Sheet, Siri/Shortcuts, voice dictation — all routed through the same `DateParser` + `TaskStore.add`. |
| Open and be told what's next, without deciding | Today's `focusTaskID` floats to the top via the invisible ranker; legible by position + a single accent dot, never a score. |
| Get a quiet sense of closure | Tap-to-complete ink-stroke + success haptic; the **"all clear"** peak-end moment when Today's open list empties. |
| Reconcile tasks with the real day (Phase 2) | Ambient over-commitment cue fed from EventKit free-hours into the ranker's `context` — felt, not announced. |

### 2.2 In scope for iPhone (this doc)

- The vertical day list (`TaskListView`) and its in-motion ergonomics.
- Capture-everywhere surfaces: **WidgetKit** (Home/Lock Screen, interactive), **Share Sheet** extension, **App Intents / Siri / Shortcuts**, voice dictation.
- The **daily ritual**: one local notification/day, peak-end "all clear", a `Notifier` component enforcing "max one nudge, never a badge."
- Invisible ranking made legible on a 390pt-wide screen; pin-to-override by long-press; the safe-moment rule under a literal finger (touch / scroll / edit → `setInteracting`).
- iCloud sync parity with Mac; background refresh for roll-forward + ranking.

### 2.3 Out of scope (inherits master §4.1 non-goals — restated for the phone)

No tags/projects/labels/folders/sub-tasks. No manual priority flags or color-coding. **No visible AI surface** — no chat box, no "AI suggestions" sheet, no scores, no count badge (the app icon badge is *banned*, see §6.3). No team/shared lists. No gamification (no points, no streak-as-points, no confetti spam). No backend we operate — sync rides CloudKit, intelligence rides the user's own key. The one sanctioned manual override is **pin** (one-tap intent, not a system to maintain).

---

## 3. The vertical day list — ergonomics in motion

The phone is operated with one thumb, often while walking, in a queue, between meetings. Every interaction is designed for **reachability, forgiveness, and a calm surface** under those conditions. The current `TaskListView` is the foundation; this section specs what exists and what must be added.

### 3.1 Layout & thumb reach

- **Today is always first and always at the top of scroll.** The single most valuable glance — "what's next" — must land in the bottom two-thirds of the screen (the thumb-reachable zone) without scrolling. On launch, `TaskListView` scrolls to top; the Today masthead + the floated #1 are immediately visible.
- **Primary add is bottom-anchored.** The existing iOS `.toolbar { ToolbarItem(placement: .bottomBar) }` "+" focuses Today's inline field (`focusedDay = today`). The bottom bar is correct: the most frequent action sits under the thumb, not in a top-right corner. Keep it there.
- **Settings is top-right and recessive** (`slider.horizontal.3`), reached rarely. This is the *only* chrome besides the add button — matching the Mac's "QuietControls" restraint.
- **Inline add row per day** (`AddRow`) stays at the bottom of each day's section so you can append to any day without a modal. Tapping a day masthead activates that day's field (`onActivate`).

### 3.2 Swipe actions (the in-motion verbs)

The row (`TaskRowView`) already carries the swipe grammar; this is the canonical spec.

| Gesture | Action | Rationale |
|---|---|---|
| **Leading swipe (full-swipe)** | Complete / reopen — `onToggle`, tinted `accentInk` | Completion is the happy path; full-swipe makes it a flick. |
| **Trailing swipe → Pin** | `onPin` — pin/unpin to top | The one sanctioned override, reachable without a menu. |
| **Trailing swipe → Delete (destructive, full-swipe)** | `onDelete` | Destructive is trailing + red, per platform convention. |
| **Long-press → context menu** | Pin, **Move to…** (any visible day), Delete | Reschedule lives here (`onMove`, `moveTargets = visibleDays`). |
| **Tap row text** | Edit in place | No detail screen; edit is inline (`TextField`, `.submitLabel(.done)`). |
| **Tap toggle** | Complete with `PressScaleStyle` bounce | User-initiated bounce is allowed (Motion.complete). |

**Gap to close (Phase 2): a "Park" swipe.** Today, parking a day-task into a list (Later/Misc/Reminders) is a Mac-only drag onto the right rail (`SideRail` / `moveToList`). On the phone there is **no one-gesture park**. Add a trailing-swipe **"Park"** action (or a context-menu "Park to…" submenu) that calls `store.moveToList(item, list:)`. This is the phone's pressure-valve for "not today, not deletable" and directly serves pain #1 (no wall of guilt). Acceptance: a task can be moved from Today to a parking lot in ≤2 taps without leaving the list.

**Reaching the lists — navigation (must mirror Android).** Parking lots are **not** a separate tab. They live **below the day list as the same vertical scroll** — scroll past the last day to reach Later / Misc / Reminders — keeping them out of the daily field of attention without hiding them behind chrome. This is the phone counterpart to the Mac's trailing lanes and is **identical to Android** ([`PRD-android.md`](PRD-android.md) §2); the master records the mirror in [`PRD.md`](PRD.md) §7.1. No bottom tab bar (UIKit/Material clutter we refuse). Acceptance: Later/Misc/Reminders are reachable in one continuous scroll from Today, with no tab or separate screen.

### 3.3 Scroll, pull-to-add, and "never reshuffle under the finger"

- **Scroll dismisses the keyboard interactively** (`.scrollDismissesKeyboard(.interactively)`) — already set. Drag down to type-then-scroll feels native.
- **Pull-to-add (Phase 2).** A short pull-down at the top of Today reveals/auto-focuses the Today add field (a calmer alternative to reaching the bottom bar one-handed). It must not be a full "refresh" spinner — it's a capture affordance, not a sync gesture. If it competes with the system pull-to-refresh, prefer the bottom-bar "+" and ship pull-to-add behind a feel test.
- **The re-rank glide is the only signal.** A single shared `.animation(Motion.settle, value: store.items)` animates every reflow; that glide is the *entire* visible vocabulary of the ranker. There is no spinner, no "thinking" indicator (P1).
- **The list must never reshuffle under a finger.** See §7 — this is the trust invariant and the phone has a specific gap (touch/scroll don't currently mark interaction) that this PRD requires closing.

### 3.4 The "Settle" aesthetic on a phone

The phone inherits the "Settle" design language (master §8) verbatim; the phone-specific notes:

- **Warm paper canvas** (`bgCanvas` `#FBF8F2` light / `#16140F` dark) edge-to-edge under the list (`.scrollContentBackground(.hidden)`), with optional `PaperGrain` for depth. No white cards in the day list (cards are a Mac-hero device).
- **Terracotta (`accentInk`) only on live interaction** — the Today accent dot, the active add "+", the completion fill/checkmark, the active swipe button, the day-completion meander. Never as decoration. On a small screen this restraint is what keeps the surface calm under motion.
- **Playfair Display mastheads** at `largeTitle`/34pt on iPhone (`DayMasthead`), SF body for tasks. The serif day headers are the editorial spine; everything else recedes.
- **Ink-stroke completion** (`CompletionToggle`): the terracotta circle fills and a stroked checkmark draws in <150ms — the satisfying micro-moment of the whole app, and the anchor of the peak-end design (§6).

### 3.5 Haptics (peak-end, on the phone where they matter)

- **Completion = one success haptic.** `TaskRowView` already has `.sensoryFeedback(.success, trigger: item.isCompleted)`. This is the single most important tactile moment — it *is* the reward, and it must stay a quiet `.success`, never escalating, never celebratory-spammy (no gamification, master §4.1).
- **Pin = a light `.impact`** (selection-class) so the override registers physically without ceremony.
- **"All clear" = one gentle `.success`** when Today's open list empties (paired with the visual line, §6.2). This is the peak-end haptic; it fires at most once per day per clearing.
- **No haptic on add, on scroll, or on re-rank.** The ranker is silent in every channel including touch (P1). Honor `UIAccessibility`/Reduce-Motion + the system haptic setting.

### 3.6 Accessibility — first-class, not retrofitted

- **Dynamic Type.** Playfair mastheads use `.custom(name, size:, relativeTo:)` and body uses `.system(.body)`, so both scale. **Acceptance:** the day list is fully usable and non-truncating-of-meaning at the largest accessibility text sizes; the floated #1 must remain identifiable at all sizes (position carries the signal, not size — so large type does not erase the ranking, unlike the Mac gravity ramp which leans on size).
- **VoiceOver.** Every row reads `title` + completion state; the toggle has `.accessibilityLabel` ("Mark as done" / "Mark as not done") — already present. **Add:** swipe actions exposed as VoiceOver custom actions (Complete, Pin, Park, Delete, Move to…), and the Today #1 announced as "top task" (a position label, not a score — stays honest, P6). The "+" reads "Add task to Today" (already set).
- **Reduce Motion.** The settle animation is gated: `.animation(reduceMotion ? nil : Motion.settle, value:)` — already present in `TaskListView`. With Reduce Motion on, re-ranks apply instantly at safe moments (no glide) and the completion bounce becomes a cross-fade. **Acceptance:** with Reduce Motion on, no element springs/overshoots; the list still re-sorts only at safe moments.
- **Contrast.** Ink tones are tuned to clear 4.5:1 even at the gravity "floor" on Mac; on the phone the day list does not dim tasks by rank (only the Mac does), so all open tasks render at body ink — better for low-vision users. Keep it that way: **the phone does not encode rank in opacity/size** (see §5).
- **Reachability & one-handed.** All destructive/irreversible actions are undoable (`undo`, 50-step stack) and reachable without two hands. Honor the system's Reachability pull-down.

---

## 4. Capture everywhere — the phone's signature deepening of pain #2

This is the part of the product that is *most* a phone story. Master §7.2 lists share-sheet/widget/voice as "planned"; this section specifies each surface, its UI, and **its exact data path back into `TaskStore`**. The architectural rule (P1, master §9.1): **every capture path resolves to the same `DateParser` → `TaskStore.add(...)`; none of them adds a new ranking pathway or a visible AI surface.**

### 4.1 The shared capture pipeline (the contract every surface obeys)

```
raw text  →  DateParser.parseRecurrence(raw)   // "standup every weekday"
          ↘  DateParser.parse(raw, reference:) // "call Sam friday"
          →  TaskStore.add(title, to: day [, recurrence:])   // day-task
          or  TaskStore.add(title, toList: name)             // parking-lot task
          →  save() (atomic JSON now → CloudKit mirror, Phase 1)
          →  scheduleRank()  // 350ms debounce → ranker → buffered → safe-moment commit
```

Every external surface MUST funnel through this exact pipeline. No surface parses dates itself, ranks itself, or writes JSON itself. This keeps the "intelligence is one seam" invariant true across the whole device.

**App Group requirement.** Widgets, the Share Sheet extension, and App Intents run in **separate processes** from the main app. They cannot reach the current `TaskStore`'s `Application Support/SmartTDL/tasks.json` (that path is per-app-container, not shared). **Phase-1 prerequisite for capture-everywhere:** migrate persistence to a **shared App Group container** (`group.com.smarttdl`) so all extensions read/write the same store, and have the main app reconcile on next foreground. This is a concrete dependency that gates §4.2–§4.4 and must land alongside or before iCloud sync (§8).

### 4.2 Home & Lock Screen widgets (WidgetKit)

Three widget families, all glance-or-one-tap, none showing a count badge:

1. **"Now" widget (small / Lock-Screen rectangular).** Shows Today's #1 open task (`nextFocusTask()`), in serif, with the terracotta accent dot. No number, no "1 of 7." If Today is clear, it shows the "All clear" line. Tapping opens the app to Today. This is the *glance* surface — the ranker's only job, surfaced where you'll see it on a locked phone.
   - **Refresh:** WidgetKit timeline reloaded on app foreground/background, on every mutation via `WidgetCenter.shared.reloadAllTimelines()`, and at the daily-ritual time. Roll-forward must run in the widget's read path so a stale "yesterday's #1" never shows.
2. **"Add to Today" widget (small, interactive — iOS 17 App Intents).** A one-tap "+" tile that launches an **interactive add**: either a Lock-Screen quick field or, if interactive text entry isn't available in-widget, a deep link to the app's add-Today field (`requestNewTask` token). The button is an `AppIntent` (`AddToTodayIntent`, §4.4) so the common case ("capture now, file later") is one tap from a locked phone.
3. **Lock-Screen inline/circular accessory (iOS 16+).** Inline accessory = the #1 task title truncated; circular = a tiny completion meander (fraction of Today done, mirroring the Mac `Meander`). **Never** a number-of-remaining badge — that's the guilt machine (master §7.7).

**Data path:** widgets read the shared App-Group store (read-only render) and trigger captures via App Intents that call `TaskStore.add(...)` (or stage into the shared store for the app to reconcile). Widgets never rank.

### 4.3 Share Sheet extension

A `ShareViewController` (Action/Share extension) that accepts **text, URLs, and selections** from any app (a link from Safari, a line from Mail, a paragraph from Notes).

- **UI:** a minimal "Settle"-styled sheet — the shared text pre-filled in a field, a destination toggle: **Today** (default) or a **parking lot** (Later / Misc / Reminders). One serif title, one field, one segmented destination, "Add." No projects, no tags (non-goals hold inside the extension too).
- **Default behavior:** plain text → `DateParser.parse` → Today (or the parsed day). A shared **URL** → the title becomes the page title (or the raw URL) and the URL is appended to the task title (we have no separate "notes" field — and we will not add one; the link rides in the title). Ambiguous "someday" content can be sent to **Later** with one tap.
- **Data path:** writes through the shared App-Group store via the same `TaskStore.add(...)`; the main app picks it up on next foreground and ranks it. Acceptance: selecting text in Safari → Share → Smart TDL → "Add" creates a Today task in <5s without opening the app.

### 4.4 Siri, App Intents & Shortcuts (voice as a first-class capture, not an AI surface)

This is the subtle one: **voice capture must not become a second "AI" surface.** Todoist has an AI voice assistant; we deliberately do *not*. Our voice path is dumb dictation → the *same* `DateParser` → the *same* ranker. The intelligence is still only the invisible re-sort.

- **`AddTaskIntent` (App Intent).** Parameters: `text` (the spoken/typed task), optional `destination` (Today | Later | Misc | Reminders). Siri phrase: *"Add 'call Sam Friday' to Smart TDL."* The intent calls `DateParser` then `TaskStore.add` — "Friday" is parsed by the same hand-rolled weekday map, so voice and typing land identically and predictably.
- **`AddToTodayIntent`.** Zero-parameter convenience for the interactive widget and a Lock-Screen/Action-Button binding: prompts for one line, files it to Today.
- **`ShowTopTaskIntent` (read).** *"What's my top task?"* → speaks `nextFocusTask()?.title`. Honest phrasing: "Your top task is X" (a position claim), never "the most important by score" (no number leaks — P6).
- **`CompleteTopTaskIntent` (optional, Phase 3).** *"Mark my top task done."* → `toggle(nextFocusTask())`. Gated behind a confirmation since it mutates.
- **Shortcuts / Action Button / Back Tap:** all of the above are exposed as App Shortcuts so a user can bind "Add to Smart TDL" to the Action Button or a Back-Tap. **Dictation** is just the keyboard mic into any of these — no custom speech stack in Phase 2/3 (privacy + cost; see master open-Q #4). On-device `Speech` framework is a Phase-4 consideration only if dictation proves insufficient.
- **Data path:** identical pipeline (§4.1). No intent talks to Anthropic; ranking remains a background effect of `scheduleRank()`.

### 4.5 Capture surface summary

| Surface | Trigger | Entry UI | Data path | Phase |
|---|---|---|---|---|
| Inline add | Tap day field / bottom "+" | `AddRow` TextField | `DateParser`→`add` | **Built** |
| Home widget "Now" | Glance | read-only | `nextFocusTask()` render | 3 |
| Interactive "Add to Today" widget | One tap | App Intent | `AddToTodayIntent`→`add` | 3 |
| Lock-Screen accessory | Glance | read-only | `nextFocusTask()` / meander | 3 |
| Share Sheet | Share from any app | minimal sheet | shared store→`add` | 3 |
| Siri / Shortcuts / Action Button | Voice / button | system | `AddTaskIntent`→`DateParser`→`add` | 3 |
| Dictation | Keyboard mic | any field | same as typing | **Built** (keyboard) |

**Prerequisite for rows 2–6:** the App-Group shared store (§4.1) — a Phase-1/early-Phase-3 enabler.

---

## 5. The invisible ranking, legible on a small screen

The Mac encodes rank with the **gravity ramp** (type size + weight + ink step down by rank index — master §8, `Gravity` enum). **The phone deliberately does not.** On a 390pt-wide column, shrinking and graying lower tasks would (a) fight Dynamic Type, (b) hurt low-vision users, and (c) read as visual noise while walking. So the phone uses a **calmer, single-channel signal**:

- **Position is the signal.** The #1 open task is simply *first* under the Today masthead (`openTasks(on:)` already returns importance-sorted order). On a phone, "top of the list" is the most legible possible ranking cue and needs no decoration.
- **One accent touch for the focus task.** Today's `focusTaskID` (the top open task) is the only row that may carry the terracotta accent dot / slightly heavier treatment — the phone's equivalent of the Mac "NOW" crown, but whisper-quiet. `TaskRowView` already takes an `isFocus` flag (currently it bumps to `.title2`); on iPhone keep this **subtle** — a small accent dot and `inkPrimary` ink, not a giant serif hero. The hero card is a Mac device; the phone's hero is just "first, with a dot."
- **No numbers, no badges, ever.** No score, no "P1," no "1/7." (P1, master §8.)
- **Honest-confidence hedge.** `topScoresClustered(on:)` (AI-only, top-two within 0.06) already exists. On the phone, when it's true, the focus row **drops its accent emphasis** — i.e., the phone *removes the crown* rather than crowning a near-tie. No "a few things matter" label is needed on the phone (that's a Mac affordance); the honest signal is simply the absence of a singled-out #1. This is the phone-native expression of P6.

**Pin-to-override on the phone = one gesture.** Master calls pin "the one sanctioned manual lever." On iPhone it must be a single deliberate action, not a buried setting:
- **Long-press → "Pin to top"** (context menu, present in `TaskRowView.contextMenu`), and
- **Trailing-swipe → Pin** (present), both calling `togglePin`.
- A pinned task shows the quiet rotated `pin.fill` mark (present in `marks`) — a *state indication*, not a badge or a count. Pin sorts first via `TaskStore.order` (pinned → importance → sortIndex). This is the user's "I decide this one" lever; everything else stays the ranker's job.

---

## 6. The daily ritual & retention — the phone is where this lives

Pain #7 (the app graveyard) is *won or lost on the phone*, because the phone is where a notification arrives and where the morning glance happens. Master §7.7 sets the policy; this section makes it concrete for iOS.

### 6.1 The single daily notification (`Notifier`)

- **Exactly one scheduled local notification per day**, at a user-set time (default morning). Copy: *"Your day is ready."* — an invitation to a calm screen, not a tally. Tapping opens the app to Today with the #1 already on top (`nextFocusTask()`).
- **Enforced in code, in one place.** A `Notifier` component is the *only* code allowed to schedule a `UNNotificationRequest`. It cancels-and-reschedules so there is structurally **never** more than one pending Smart-TDL notification. **Acceptance (must be a unit test):** for any sequence of app events, `UNUserNotificationCenter.pendingNotificationRequests` for Smart TDL never exceeds 1.
- **No app-icon badge — ever.** `UNNotificationContent.badge` is never set; the app never calls `setBadgeCount`. A number on the icon is the guilt machine we explicitly reject (master §7.7). This is a hard ban, asserted in code review and ideally a lint/test.
- **Re-engagement is honest and rare.** If the user is absent for a long stretch, at most a single gentle "still here when you need it," then silence. No nag escalation, no streak-loss threats (no gamification, master §4.1).
- **Permission ask is deferred and contextual.** Do not request notification permission on first launch. Ask only after the user has completed a first task or explicitly sets a ritual time — so the prompt arrives once the value is felt. With permission denied, the app is fully usable; the ritual simply becomes a passive widget glance.

### 6.2 The peak-end "all clear" moment

- When Today's open list empties, show the **`AllClearLine`** ("All clear for today.") with one gentle success haptic. This is the engineered *end* — the peak-end rule says people remember the peak and the end, so we give the day a good end and earn tomorrow's return.
- **Bug to fix (Phase 0):** `AllClearLine` currently renders **only in the Mac `MacListView.section`** (it's wired there but **not** in the iPhone `TaskListView.daySection`, which falls back to the generic `EmptyLine`). **Acceptance:** on iPhone, when Today has completed tasks but no open tasks, `AllClearLine` (not `EmptyLine`) appears, with its haptic, exactly once per clearing. This is the phone's most important retention detail and it's currently missing — high priority.
- **No confetti, no points, no streak counter on screen.** A quiet private streak may be tracked for the user's own continuity (master §7.7) but is never gamified or surfaced as a score.

### 6.3 Anti-patterns explicitly banned on iPhone

| Tempting iOS affordance | Why it's banned | The ambient alternative |
|---|---|---|
| App-icon badge with # of incomplete tasks | The guilt machine; turns the home screen into a debt ledger (pain #1, #7) | The "Now" widget showing the *one* next task |
| Multiple/нagging reminders | Notification fatigue, the #1 reason apps get muted | One honest nudge/day via `Notifier` |
| "You broke your streak!" push | Gamification dark pattern (non-goal) | Silent re-engagement, single gentle note |
| A "AI is thinking…" spinner during re-rank | Violates P1 (ambient intelligence adds no UI) | The `Motion.settle` glide is the only signal |

---

## 7. The safe-moment rule under a literal finger (the trust invariant on touch)

Principle **P5** — *never reorder under the user's hand* — is the load-bearing trust mechanism (master §4, §7.3). The store implements it correctly: scores buffer in `pendingScores`, and `commitPendingRank()` only applies them when the `interacting` set is empty, after an idle beat (`scheduleIdleCommit`, ~1s). A row marks itself via `setInteracting(id, active)`.

**The iPhone has a real, specific gap here.** Today, `TaskRowView` only calls `onInteract` on **focus** (when the field is being edited):

```swift
// TaskRowView, iOS path:
.onChange(of: focused) { _, isFocused in
    onInteract(isFocused)   // ← only editing marks interaction on iOS
    ...
}
```

On the Mac, `onHover` also marks interaction — but **a phone has no hover.** That means on iPhone, a re-rank can currently commit while the user is **touching, dragging, or mid-swipe** on a row that isn't being *edited*. That is a P0 trust bug waiting to happen (master §12: reshuffle-under-hand incidents must be **zero**).

**Required (Phase 0/1):** mark interaction on the phone for the gestures that actually occur on a phone:
- **Touch-down / press on a row** → `setInteracting(id, true)`; touch-up/cancel → `false` (a `DragGesture(minimumDistance: 0)` or `.onLongPressGesture`-style press tracker on the row).
- **Active swipe** on a row → that row is interacting until the swipe settles.
- **Active scroll** of the list → suppress commits for the duration. A pragmatic implementation: treat scroll-in-progress as a global "interacting" gate (e.g., a `store.setScrolling(true/false)` that `commitPendingRank` also checks), since the user can't precisely point at one row while flicking.
- **Edit in place** → already covered by `focused` → `onInteract`.

**Acceptance (must be testable):**
1. While a finger is pressing or dragging any row, no row's position changes.
2. While the list is actively scrolling, no re-rank commits; commits resume only after scroll settles + the idle beat.
3. `scenePhase == .active` still triggers a `commitPendingRank()` (already wired in `ContentView`) so a backgrounded re-rank lands cleanly on return — but only because at that instant nothing is being touched.
4. Reshuffle-under-finger incidents in a manual "scroll-and-watch for 60s during active ranking" test = **zero**.

This is the single most important iPhone-specific engineering requirement in this doc.

---

## 8. iCloud sync, persistence & background work

Master §7.8 / §9.2 set the sync policy (CloudKit private DB, local-first, last-writer-wins on `id` + `createdAt`). The phone-specific concerns:

- **Parity with Mac, same model.** The phone and Mac share `TodoItem` and `TaskStore`; sync must make "add on iPhone → appears on Mac within seconds" true and vice-versa. The resilient `Codable` (`decodeIfPresent` everywhere) means schema can evolve without breaking either platform's stored data — never regress that.
- **Local-first is non-negotiable on a phone.** A phone is offline constantly (elevators, planes, tunnels). The phone must be **fully functional with no network and no iCloud** — add, complete, reschedule, roll-forward, heuristic-rank all work offline; sync is a mirror that reconciles on reconnect, never a dependency (P9/P10).
- **Conflict policy on the phone.** Last-writer-wins per task keyed on `id` + a monotonic edit marker. The most common phone conflict is "completed on phone, still open on Mac" — LWW resolves to the later edit; because completion is rarely contentious, this is acceptable for a single-user multi-device tool (master §13, risk row).
- **App-Group + CloudKit interplay.** The shared App-Group store (§4.1) is the *local* substrate the widgets/extensions write to; CloudKit mirrors that store across devices. Order of operations: extension writes → App-Group store → main app reconciles on foreground → CloudKit pushes. Both must preserve atomic writes (current `save()` uses `.atomic`).
- **Background refresh.** Use `BGAppRefreshTask` to (a) run `rollForward()` so a phone opened cold at 9am already shows yesterday's unfinished work on Today, (b) refresh the widget timeline, and (c) optionally pre-warm a Haiku rank so the morning glance is already sorted. Background ranking still obeys safe-moment commit (the app isn't foreground, so `interacting` is trivially empty, but commits still apply on next `scenePhase == .active`). Keep background Anthropic calls rare and cheap (debounce + visible-window-only ranking already keep cost in pennies — master §9.3).

**Acceptance:** a task added on iPhone appears on Mac within seconds online; airplane-mode edits on the phone reconcile on reconnect with no data loss across 100 edit/sync cycles; cold-launch at 9am shows correctly rolled-forward Today without the user touching anything.

---

## 9. The open product question: does iPhone ever become a week board?

Master §13 open-Q #5 asks it directly: *"Is iPhone the week board too, eventually, or does the day-list stay the phone's identity?"*

**Position: the vertical day list is the phone's permanent identity. The phone does NOT become a week board.** Reasoning, grounded in the phone's job:

1. **The phone's job is capture-and-glance, not planning.** A week board is a *planning* surface — you survey seven lanes, drag across days, balance the week. That is a desk activity with a pointer and screen width. The Mac already owns it (`WeekBoardView`, 3/5/7 lanes). Duplicating it on a 390pt screen means shrinking each lane to ~50pt — illegible, un-thumbable, and a magnet for the exact fiddly cross-day reorganizing we call "organizing-isn't-doing" (pain #6).
2. **A horizontal multi-lane board fights one-thumb, in-motion use.** Swiping between day columns competes with the row swipe-to-complete grammar (§3.2) and the vertical scroll. The phone's gestures are already fully allocated to the verbs that matter (complete, pin, park, reschedule, scroll).
3. **The vertical day list already shows the week.** `TaskListView` renders `visibleDays` = Today + 6 as a scroll. The user *can* see the whole week — by scrolling down — without a board's spatial overhead. Glanceability beats survey-ability on a phone.
4. **It keeps the platforms honestly differentiated.** Mac = plan the week at a desk; phone = capture anywhere + glance at "what's next." Each surface is the best tool for its moment, which is more valuable than feature-parity for its own sake.

**The one concession we will consider (not a board):** a **horizontal-swipe between *days*** as an *optional* navigation accelerant (swipe left on the Today masthead to peek Tomorrow), if usability testing shows scrolling to a far day is too slow one-handed. Even then it stays a single-day view at a time — never a multi-lane board. If we ship it, it must not break the vertical scroll or the row-swipe verbs. Default remains the vertical scroll.

**Decision to lock:** iPhone = vertical day list, permanently. Revisit only if dogfooding produces a concrete capture-or-glance failure that a board (and nothing simpler) would fix.

---

## 10. iPhone roadmap (phased, with done-criteria)

Sequenced to (a) fix the trust + retention gaps that already exist on the phone, then (b) light up capture-everywhere, then (c) the time layer. Each phase leaves the phone fully usable. Aligns with master §11 phases but scoped to iPhone deliverables.

### Phase 0 — iPhone hardening (the gaps that exist *today*)
*Make the current iPhone build trustworthy before adding surface area.*
- [ ] **Safe-moment-on-touch (§7):** mark `setInteracting` on row press/drag/swipe and suppress commits during active scroll. **Done:** reshuffle-under-finger incidents = 0 in the 60s scroll-during-rank test; unit test asserts no commit while `interacting` non-empty or scrolling.
- [ ] **Wire `AllClearLine` into `TaskListView` (§6.2):** show it (not `EmptyLine`) when Today has done-but-no-open tasks, with one success haptic. **Done:** UI test confirms the line + single haptic appear exactly once per clearing on iPhone.
- [ ] **Dynamic Type & VoiceOver pass (§3.6):** day list non-truncating-of-meaning at largest sizes; swipe actions exposed as VoiceOver custom actions; #1 announced as "top task." **Done:** accessibility audit checklist green.
- [ ] **Reduce-Motion verified:** no spring/overshoot anywhere with the setting on; re-rank applies as instant cross-fade at safe moments.
- **Exit criteria:** the three trust/retention/accessibility invariants above hold; zero Keychain prompts on cold launch (already true — never regress, master §7.9).

### Phase 1 — Sync parity + the shared store enabler
- [ ] **App-Group shared persistence (§4.1):** move `tasks.json` to `group.com.smarttdl`; main app reconciles extension writes on foreground. **Done:** a write from a test extension target is visible in the app after foreground.
- [ ] **CloudKit mirror (master §9.2)** behind `TaskStore` persistence; local-first preserved. **Done:** iPhone↔Mac add appears within seconds online; airplane-mode edits reconcile on reconnect; no loss across 100 cycles.
- [ ] **`BGAppRefreshTask`:** background roll-forward + widget reload. **Done:** cold 9am launch shows correctly rolled-forward Today.

### Phase 2 — Capture everywhere + the daily ritual
- [ ] **`Notifier` (§6.1):** single daily local notification at a user-set time; **no badge**; max-one-pending enforced. **Done:** unit test — pending Smart-TDL notifications ≤ 1 for any event sequence; `badge` never set.
- [ ] **WidgetKit suite (§4.2):** "Now" glance widget, interactive "Add to Today," Lock-Screen accessory. **Done:** widget shows correct #1 (post-roll-forward); one-tap add lands a Today task; no count anywhere.
- [ ] **App Intents / Siri / Shortcuts (§4.4):** `AddTaskIntent`, `AddToTodayIntent`, `ShowTopTaskIntent`. **Done:** "Add 'call Sam friday'" files identically to typing it; "what's my top task" speaks `nextFocusTask().title`.
- [ ] **"Park" swipe (§3.2):** trailing-swipe / menu to `moveToList`. **Done:** Today→Later in ≤2 taps without leaving the list.
- [ ] **Time-layer ambient cue (master §7.4):** EventKit free-hours into `context`; quietest over-commitment signal on Today. **Done:** ranking shifts when the calendar is full; cue is felt, not announced (no number, no red).
- **Exit criteria:** a task can be captured from a locked phone without opening the app; the app never schedules >1 notification/day and never shows a badge.

### Phase 3 — Share Sheet + voice polish + context connectors (phone side)
- [ ] **Share Sheet extension (§4.3):** text/URL/selection → Today or a parking lot. **Done:** Safari selection → Share → "Add" creates a Today task in <5s.
- [ ] **Dictation-to-task** end-to-end via the keyboard mic through `AddTaskIntent`/inline. **Done:** spoken "milk tomorrow" files to Tomorrow.
- [ ] **`CompleteTopTaskIntent`** (confirmation-gated) + Action-Button/Back-Tap bindings.
- [ ] First **context connector** value validated on the phone (Calendar already in; Gmail opt-in per master §7.5) — connectors feed `context`, never add UI.
- **Exit criteria:** capture works from every surface in §4.5; no raw email/event bodies leave the device; no new visible AI surface introduced anywhere.

### Phase 4 — Considered experiments (gated; may never ship)
- [ ] Optional horizontal day-peek navigation (§9) — only if one-handed reach to far days proves too slow; never a board.
- [ ] Pull-to-add gesture (§3.3) if it tests calmer than the bottom "+".
- [ ] Hidden long-press "why is this first?" honest one-liner (reusing the Mac `heroWhy` logic), invisible by default (master §4 P1).
- **Exit criteria:** each passes the principles — if it adds standing UI, a number, or a maintenance burden, it's cut.

---

## 11. iPhone success metrics (subset of master §12, phone-weighted)

- **North star:** D7/D30 open-and-act retention — opens the phone on day 7/30 *and* completes ≥1 task. (The phone is where the ritual + notification land, so this is primarily a phone metric.)
- **Capture latency from any surface** — median time from widget-tap / Share / Siri / inline to task saved. Target < 3s (widget/Siri should be ~1–2s).
- **Ritual-open rate** — fraction of days the user opens within the window after the single daily notification.
- **Reshuffle-under-finger incidents** — must be **0** (the §7 trust invariant; any occurrence is a P0).
- **Badge-shown count** — must be **0** by construction (the icon never badges).
- **Calm proxy** — sessions with zero settings/organizing actions / total sessions; high = the phone surface stayed quiet.
- **Guardrail (anti-metric):** if phone "time in app" rises without completions rising, organizing-isn't-doing is creeping in (e.g., a capture surface became a fiddly form) — investigate and cut surface.

---

## 12. iPhone-specific risks & open questions

| Risk | Likelihood | Mitigation |
|---|---|---|
| **Reshuffle-under-finger** (no hover on iOS to mark interaction) | High if unaddressed | §7 press/scroll interaction gating — Phase 0, the top priority |
| Extension/widget can't see the store (separate process) | Certain without fix | App-Group shared container (§4.1), Phase 1 prerequisite |
| `AllClearLine` missing on iPhone weakens the peak-end → retention | Med | Wire it in Phase 0 (§6.2) |
| Notification feels like a nag despite "one/day" | Low (by design) | `Notifier` single-pending enforcement + honest copy + deferred ask |
| Voice capture drifts toward a second "AI surface" | Med | Voice routes through `DateParser`+ranker only; no model call in any intent (§4.4) |
| Dynamic Type breaks the day-list legibility / floated-#1 cue | Med | Position (not size) carries rank on iPhone (§5); accessibility pass Phase 0 |
| iCloud conflicts (completed-on-phone vs open-on-Mac) | Med | LWW on `id`+edit marker; 100-cycle test (§8) |

**Open questions (decide before the relevant phase):**
1. **Pull-to-add vs. bottom "+":** does a top pull-down to capture beat the bottom-bar button one-handed, or does it collide with system gestures? (Phase 4 feel test.)
2. **Interactive widget text entry:** can we capture *text* directly in a Lock-Screen widget on the target iOS version, or must "Add to Today" deep-link into the app for the keyboard? (Phase 2 implementation detail.)
3. **Horizontal day-peek navigation:** ship it as an accelerant or hold the line at pure vertical scroll? (Phase 4 — default is hold.)
4. **Background pre-warm ranking:** is a `BGAppRefreshTask` Haiku call worth the pennies to make the 9am glance pre-sorted, or is heuristic-sorted-then-refine-on-open enough? (Phase 2 tuning.)
5. **Default ritual time:** fixed morning default vs. inferring from the user's first-open pattern (kept simple — a user-set time, no behavioral inference, to avoid a hidden "AI schedules your day" surface). Leaning fixed/user-set.

---

## 13. Appendix — iPhone implementation map (where each thing lives today)

| Concern | Current code | iPhone change needed |
|---|---|---|
| Day list surface | `TaskListView.swift` (iOS path) | + Park swipe, + `AllClearLine` wiring, + horizontal peek (P4) |
| Row + swipes + haptics | `TaskRowView.swift` (`.swipeActions`, `.sensoryFeedback`, `.contextMenu`) | + press/drag → `setInteracting` (§7) |
| Add + NL dates | `AddRow` (in `TaskListView`), `DateParser.swift` | reused verbatim by every capture surface |
| Store / safe-moment commit | `TaskStore.swift` (`pendingScores`, `interacting`, `commitPendingRank`, `scheduleIdleCommit`) | + `setScrolling` gate; + App-Group path; + CloudKit mirror |
| Ranking seam | `Ranker.swift` (`HeuristicRanker`, `HaikuRanker`) | unchanged; connectors feed `context` only |
| Key handling | `Keychain` (gated `hasKey`, off-main read) | unchanged; never reintroduce a sync read at launch |
| Theme / motion / haptic tone | `Theme.swift` (`Color(light:dark:)`, `Motion`, `Gravity`) | phone uses position not `Gravity` for rank (§5) |
| App entry / scene | `SmartTDLApp.swift`, `ContentView.swift` (`#else` iOS branch) | + Widget extension target, Share extension target, App Intents, `Notifier` |

**Invariants this PRD must never break** (from master §9.1, restated for iPhone): the `Ranker` is the only intelligence seam (capture surfaces feed `context`/tasks, never add UI); buffered safe-moment commit stays and is *extended* to touch/scroll on the phone; Keychain reads stay gated + off-main; resilient `Codable` keeps old saved files (and now cross-device files) loading; **no count badge, ever.**
