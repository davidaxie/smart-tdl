# Smart TDL — macOS Platform PRD (the Planning Surface)

**Status:** Draft v1 · **Owner:** David Xie · **Date:** 2026-06-28
**Platform:** macOS app (SwiftUI multiplatform target) · **Companion to:** [`PRD.md`](./PRD.md) (master/overview)
**Repo:** `github.com/davidaxie/smart-tdl` · Xcode project at root, branch `main`

> This is the **deep, Mac-specific** companion to the master PRD. The master defines *what Smart TDL is* across platforms — the thesis, the seven research pains, the ten principles, the permanent non-goals, the shared model, and the cross-platform roadmap. **Read it for the shared facts; read this for the Mac.** Where this doc cites a principle (P1–P10) or a research pain (#1–#7), the definition lives in `PRD.md §4` and `§2`. Everything below is true of the Mac surface specifically and is grounded in the live source (`ContentView.swift`, `TaskListView.swift`, `TaskStore.swift`, `Ranker.swift`, `Theme.swift`, `SmartTDLApp.swift`).

---

## 1. What the Mac is *for* (and what it is not)

The Mac is the **planning surface** — used at a desk, with a keyboard under your hands and a wide screen in front of you. Where the iPhone is the **capture-and-glance** surface used in motion (a single vertical day list, `TaskListView`), the Mac is where you **see the shape of your week and decide nothing**, because the intelligence already decided.

The Mac's one job: **render the whole field of attention at once — Today plus the days ahead, side by side — so the right task in each day is pre-attentively obvious, and let a power user operate the entire app without lifting their hands to the mouse.** It is *calm to look at* and *fast to operate*. Those two properties are in tension in most pro apps (calm apps are slow; fast apps are busy); resolving that tension is the Mac product (see §11, "Calm but fast").

**The Mac is exactly one screen.** As of the current direction there is **no list/week toggle** — the **`WeekBoardView` week board is the primary and only presented Mac surface** (`ContentView.shell`, macOS branch). The older vertical "Gravity Field" list (`MacListView` / `MacRow` / `SideRail`, crowned Playfair "NOW" hero) **remains in source but is not presented**; it is a parked alternative layout (see §8). Do not delete it.

### Pains this surface answers (master `PRD.md §2`)
- **#3 Everything looks equally important** — the gravity ramp makes each day's #1 the heaviest thing in its lane, pre-attentively. This is the Mac's signature.
- **#1 Guilt, not help** — roll-forward, the dimmed completed tray, and the trailing parking-lot lanes keep every day-lane small even on a 27" display where there's *room* to dump a guilt-wall. The wide screen is the temptation; the small daily field is the discipline.
- **#5 Too simple OR too complicated** — a desk app is where "too complicated" usually wins (toolbars, inspectors, sidebars). The Mac proves the "simple + smart" quadrant holds even on a power surface: one screen, one strip of quiet chrome, a keyboard layer with zero visible affordances.
- **#4 No connection to time** — the week board *is* a time view (days as columns); Phase 2 calendar awareness (master `§7.4`) feeds the same ranker that draws the ramp.

### Non-goals re-affirmed for the Mac (master `PRD.md §4.1`)
No projects/tags/folders/sub-tasks. No manual priority flags or color-coding. **No visible AI surface** — no chat box, no scores, no badges, no "AI suggestions" inspector. No Kanban-style manual columns of *status* (the lanes are **days**, not "To Do / Doing / Done"). No multi-pane inspector. No team/shared boards. The Mac's wide canvas makes all of these *tempting*; §10 names each temptation and its ambient alternative.

---

## 2. The week board (`WeekBoardView`) — the whole Mac in one view

`WeekBoardView` is a single horizontally-scrolling row of **full-height lanes**. The first N lanes are **days** (`DayColumn`); the trailing lanes are the three **undated parking lots** (`ListLane`: Later / Misc / Reminders). One `GeometryReader` sizes everything to fill the viewport.

### 2.1 Layout & lane sizing (the math, from source)

```
availForDays = viewportWidth − margin*2 − gap*(dayCount−1)      // margin = Space.section (36), gap = Space.m (12)
laneW        = clamp(availForDays / dayCount, min: 168, max: 300)
laneH        = viewportHeight − 56 − Space.xl
```

- The **chosen day-count fills the viewport** (lanes grow to use the width), but never narrower than 168pt (legibility floor) or wider than 300pt (a day-lane wider than ~300 reads as a document, not a list). When days + clamp don't consume the full width, the parking-lot lanes pick up the remainder to the right.
- **Parking-lot lanes always trail the day lanes** and are reached by **scrolling right** — they are out of the default field of view by construction (P7, anti-guilt). They are never ranked and never roll forward.
- Each lane is a `RoundedRectangle(cornerRadius: 12)` filled with `Color.surfacePool`. **Today's lane is warmer** (`opacity 0.6` vs `0.3` for every other lane and all parking lots) — the single most-important *spatial* cue on the board. Today owns the screen by tone, not by a border or a badge.

### 2.2 The day-count toggle (`smarttdl.weekDays`: 3 / 5 / 7)

Lives in `QuietControls` top-right as a tiny capsule segment (`DayCountToggle`). It is **the only layout control on the Mac** and replaces the retired list/week toggle.

| Setting | Feel | Use |
|---|---|---|
| **3** | Near-focus. Today + 2; lanes go wide (toward the 300 cap). | "What's my next three days." Deep work cadence. |
| **5** | Work week. | The default planning horizon for most desk sessions. |
| **7** (default) | Full visible window. | "Show me everything I'm holding." Matches `store.visibleDays` (today + next 6). |

The toggle is persisted in `@AppStorage("smarttdl.weekDays")` and animates lane resize with `Motion.press`. **It never changes which tasks exist or how they rank** — it only changes how many day-lanes are drawn. The model's window is always 7 days (`TaskStore.visibleDays`); the toggle is a viewport choice, not a data filter.

### 2.3 Inside a day lane (`DayColumn`)

Top to bottom:
1. **`ColumnMasthead`** — compact header: an **accent dot** for Today only, the serif (`display`) day label (`Today` / `Tomorrow` / weekday), a small `MMM d` sub-label. No counts, no progress %, no badge.
2. A small **`"NOW"` eyebrow** in terracotta (`Color.accentInk`) — shown only on Today, only when Today has open tasks. This is the lane's one accent moment.
3. The **open tasks**, in rank order, each drawn through the gravity ramp (`Gravity.column(rank:)`, §3).
4. **`AddRow`** — inline capture for that day (always present, never a modal).
5. The **completed tray** (`CompletedTrayHeader` "Done today · N" + dimmed rows) when the day has completions — present for satisfaction, receded out of the active field (P7).
6. **`"A clear day."`** serif line when Today is empty (the calm empty state).

Each lane independently scrolls vertically, so a heavy day never pushes a light day's content off-screen. The lane is a `dropDestination` (§5.4) — drag a task onto any lane to reschedule it to that day.

### Acceptance criteria — week board
- AC-WB-1: On launch the board shows `weekDays` day-lanes followed by the three parking-lot lanes; Today is leftmost and visibly warmer.
- AC-WB-2: Switching 3↔5↔7 resizes lanes to fill the viewport within the 168–300pt clamp and animates with no content reflow jump; task membership and rank are unchanged.
- AC-WB-3: A day with 30 open tasks scrolls within its own lane; adjacent lanes are unaffected.
- AC-WB-4: Parking-lot lanes are never reachable without scrolling right past all day lanes; their tasks carry no `importance` and never appear in a day.

---

## 3. The "Gravity Field" design language on the Mac (full spec)

The master design section (`PRD.md §8`) names two systems: **"Settle"** (warm-paper foundation — `Theme.swift` color tokens, Playfair mastheads, ink-stroke completion, terracotta-on-live-interaction-only) and **"Gravity Field"** (the week-board ramp). The Mac is where Gravity Field is fully expressed. Do not re-invent it; extend within it.

### 3.1 The gravity ramp — rank index → type, in one pre-attentive channel

The ramp is the entire visible output of the ranker. A day's tasks **step down in size + weight + ink by rank index** so the AI's #1 is unmistakably the heaviest object in its lane. From `Gravity.column(rank:)`:

| Rank in day | Size | Weight | Ink |
|---|---|---|---|
| **0 (the #1)** | 20 | semibold | `inkPrimary` (full strength) |
| 1 | 16 | medium | `inkBody` |
| 2 | 14.5 | regular | `inkBody` |
| 3 | 13.5 | regular | `inkSecondary` |
| 4+ | 13 | regular | `inkSecondary` (floor — still clears 4.5:1 contrast) |

**Quantized by rank *index*, never by raw score.** This is load-bearing: scores from Haiku jitter slightly between calls; if type size tracked raw score the column would shimmer on every re-rank. Snapping to a small set of index steps means a re-rank only changes type when an item actually changes *position* — and that only happens at a safe moment (§4). The ramp is the honest visualization of *order*, not of *magnitude*.

### 3.2 The "NOW" crown

Each day's #1 is crowned. On the week board the crown is the **`"NOW"` eyebrow** (10pt semibold, tracked, terracotta) sitting above the open tasks, plus the heaviest type on the row beneath it. There is no number, no star, no "#1" — the crown *is* the type weight plus the one-word label. The parked vertical layout (§8) crowns more dramatically (a serif hero card); the week board's crown is deliberately quieter because a board shows seven crowns at once and seven hero cards would be loud.

### 3.3 The single reserved terracotta accent

Terracotta (`Color.accentInk`, `#B5733F` light / `#D08A52` dark) is **rationed**. On the Mac it appears only on:
- the Today **accent dot** in the masthead,
- the **`"NOW"` crown** eyebrow,
- the **completion meander** fill (the hairline that fills as a day clears, parked-layout masthead),
- **live interaction** — the focused/selected hero border, the command-bar plus glyph, the focus-mode "NOW" label and complete button.

That's it. Terracotta means **"the system is alive right here, right now."** It is never decorative and never used to mark a category (there are no categories). If a new feature wants terracotta to mean a *second* thing, that's a design smell (P1).

### 3.4 Honest-confidence flattening (`topScoresClustered`, AI-only)

When the ranker can't confidently separate a day's top two tasks, the UI **must not crown a near-tie** (P6). `TaskStore.topScoresClustered(on:)` returns true when `usingAI` and the top two open tasks' `importance` differ by **< 0.06**. When true, the day's ramp **flattens**:
- In the parked vertical layout this is wired today: the hero shrinks (27→22) and its label changes from `"NOW"` to `"A FEW THINGS MATTER"`; the body ramp compresses (`Gravity.today(rank:flattened:)` collapses to two steps).
- **Gap to close on the week board:** `DayColumn` currently draws `Gravity.column(rank:)` without consulting `topScoresClustered`. The flatten must be ported to the board so the gravity gradient and the crown soften when scores cluster (see §9 roadmap, Phase 0). The honest-confidence hedge is a principle, not an optional polish — an over-confident crown on a true tie is a trust bug.

**Gated on real AI** (`usingAI`): the `HeuristicRanker` ties constantly (its scores are coarse word-counts), so flattening on heuristic ties would flatten the ramp almost always and make the board mush. The hedge only engages when a genuine model produced genuinely-close scores.

### 3.5 No numbers, no scores, no badges — ever

There is no place on the Mac that shows a number of incomplete tasks, a score, a percentage, a streak count, or a priority label. The closest things to "data viz" are deliberately **wordless**: the `Sparkline` ("shape of the day," one stroke per task, height by rank) and the `Meander` (a hairline that fills terracotta as a day clears) in the parked masthead — both encode *shape*, never a figure. This is non-negotiable (master `PRD.md §8`).

### Acceptance criteria — Gravity Field
- AC-GF-1: In any day lane with ≥2 open tasks, the rank-0 task renders strictly heavier (larger size and/or stronger weight and/or darker ink) than rank-1, and the ramp is monotonic.
- AC-GF-2: Type size for a row changes **only** when the row's rank index changes — never on a re-rank that leaves order unchanged. (Verify by ranking the same set twice with slightly different raw scores; no visual change.)
- AC-GF-3: With a real key, when two top scores are within 0.06, the crown/ramp visibly softens (board parity with the parked layout's flatten). With no key (`usingAI == false`), flattening never engages.
- AC-GF-4: Terracotta appears nowhere except the four live-interaction sites in §3.3. A grep for accent usage outside those sites is a review failure.

---

## 4. The trust invariant on the Mac: never reorder under the hand (P5)

This is the single most important behavioral contract on the planning surface, because a desk user **dwells** — the cursor hovers, a row is half-edited, the eye is tracking a specific line. If the board reshuffled under that, the calm is destroyed and trust with it. **Any reshuffle-under-hand is a P0 trust bug** (master `PRD.md §12`).

The mechanism (`TaskStore`, unchanged across platforms but felt most on Mac):
1. A re-rank is **debounced ~350ms** (`scheduleRank` → `rerank`), ranks only the **visible open day-tasks**, and writes scores into **`pendingScores`** — *not* into the items.
2. `pendingScores` are only applied by **`commitPendingRank()`**, which **bails unless `interacting` is empty**.
3. The **`interacting` set** is populated by **`setInteracting(id, active)`**, called from **every `MacRow`'s `.onHover`** (`store.setInteracting(item.id, h)`). So while the cursor is over *any* row, the board is frozen. When the last hover ends, `commitPendingRank()` fires automatically.
4. A separate **`scheduleIdleCommit` (~1s)** commits after the model returns even if the user simply went still.
5. **`scenePhase == .active`** also triggers a commit (`ContentView`), so scores settle when you return to the window — never while you're mid-gesture.

**Mac-specific consequences and rules:**
- **Hover is a first-class freeze signal on Mac** (the iPhone has no hover). The `.onHover → setInteracting` wiring in `MacRow` is the desktop's primary safe-moment guard and **must not regress**. If a future row view forgets to report hover, the board can reshuffle under the cursor.
- **Editing freezes too:** an in-progress edit (`editingID` set, field focused) keeps that row's identity stable; the commit waits.
- The re-rank, when it *does* land, animates with **`Motion.ambient`** (response 0.62, damping 0.90, zero overshoot) — slow and certain, so a re-sort reads as the system *reasoning out loud*, never as a glitch.

### Acceptance criteria — trust
- AC-T-1: With the cursor held over any row, no row in any lane changes position, size, or order for the duration of the hover, regardless of re-ranks completing in the background.
- AC-T-2: Releasing hover (or going idle ~1s) commits buffered scores with the `Motion.ambient` settle.
- AC-T-3: Editing a row never causes that row or its neighbors to move until the edit commits and the user is idle.
- AC-T-4 (regression test): a unit test asserts `commitPendingRank()` is a no-op while `interacting` is non-empty.

---

## 5. Keyboard-first power without visible complexity

The Mac's "fast" half. **Every operation has a keystroke; none of them appears on screen.** A new user sees a calm board; a power user never touches the trackpad. This is how the Mac is OmniFocus-fast with a Things-calm surface.

### 5.1 Global commands (menu + shortcut, from `SmartTDLApp.commands`)

| Shortcut | Command | Action |
|---|---|---|
| **⌘N** | New Task | `requestNewTask()` → focuses Today's add row (`newTaskToken`) |
| **⌘K** | Quick Capture… | `requestCommandBar()` → the Spotlight-style command bar (`commandToken`) |
| **⌘F** | Find | `requestFind()` → in-list search (parked-layout `findToken`; board search is a gap, §9) |
| **⌘J** | Focus Now | `requestFocusMode()` → full-screen single-task mode (`focusToken`) |
| **⌘Z** | Undo | `undo()` — 50-step stack over toggle / delete / move (`CommandGroup(replacing: .undoRedo)`) |
| **⌘⇧T** | Push Unfinished to Tomorrow | `pushAllToTomorrow()` — the end-of-day sweep |

These are real `NSMenu` items under the standard menu bar (File / Edit groups), so they're discoverable via the menu and the `⌘?` Help search, satisfying macOS HIG **without adding any in-window chrome**. The command tokens (`newTaskToken`, `commandToken`, `focusToken`, `findToken`, `refocusToken`) are integer counters the views observe via `.onChange` — a deliberate, decoupled signalling seam so a global menu command can drive a deeply-nested view without a binding spaghetti.

### 5.2 In-list vim-style navigation (the hidden power layer)

The parked vertical layout (`MacListView`) implements the full keyboard model in `handleKey`. **This model is the spec for the week board too** — porting it to `DayColumn`/`WeekBoardView` is the top keyboard gap (§9). The grammar:

| Key(s) | Action |
|---|---|
| `j` / `↓`, `k` / `↑` | Move selection down / up through the flattened nav order |
| `return` / `e` | Edit the selected row in place |
| `space` / `x` | Complete the selected task (cursor marches to the next open task) |
| `delete` / `#` | Delete (cursor lands on the next sensible row) |
| `p` | Pin / unpin (the one sanctioned manual override, P-pin) |
| `o` / `a` | Open the add row for the selected day |
| `t` | Defer selected to **Today** |
| `m` | Defer selected to to**m**orrow |
| `1`–`7` | Defer selected to the Nth visible day |
| `]` / `[` (or `⌘]` / `⌘[`) | Nudge selected one day later / earlier (never before today) |
| `esc` | Clear selection (or close search) |

The completion key is intentionally clever: `complete()` computes the *next* open task **before** the toggle reshuffles the current one into the completed pool, then moves the cursor there — so holding `space`/`x` sweeps a day clear without the cursor ever stranding.

### 5.3 The `handleKey` "bail when editing" invariant (must not regress)

> `guard editingID == nil, focusedDay == nil, !searchFocused else { return .ignored }`

This single line is a documented landmine (master `PRD.md §7.10`). If `handleKey` does **not** bail while any text field is active — a row being edited, the add field focused, or search focused — then typing a literal `t`, `m`, `e`, `p`, `x`, or a digit **fires the vim command instead of inserting the character**, and task entry feels broken. **Any new text-entry context on the Mac (a renamed lane, a tag-free quick filter, anything focusable) must extend this guard.** This is a hard regression gate for any keyboard work.

### 5.4 Drag-to-reschedule + context menu

- **Drag:** every `MacRow` is `.draggable(item.id.uuidString)`; every `DayColumn` (and the parked `TodayMasthead`) is a `.dropDestination(for: String.self)` that calls `store.move(it, to: day)`. Drag a task from any lane onto any day lane to reschedule. Dropping onto a day **un-files** a parked task (`move` sets `list = nil`) — the natural "promote this someday item to a real day" gesture.
- **Context menu:** right-click a row for reschedule targets (the `moveTargets: store.visibleDays`), pin, and delete — the mouse-driven equivalent of the keyboard defers, for users who reach for the trackpad.

### Acceptance criteria — keyboard
- AC-KB-1: Every action in §5.2 is reachable by keyboard with no visible toolbar; the board has no on-screen buttons for them.
- AC-KB-2: With a row in edit mode, typing `t m e p x 1` inserts those literal characters; the vim commands do not fire (the bail guard holds).
- AC-KB-3: ⌘N / ⌘K / ⌘J / ⌘Z / ⌘⇧T work from the board with the window focused, driven through the command tokens.
- AC-KB-4: Holding `x` (or `space`) clears a day's open tasks one by one without the selection cursor stranding.

---

## 6. Mac-native surface area — in/out decisions

Each native Mac affordance is decided **against the principles**, not by default platform expectation. "macOS apps usually have X" is never a reason; "X stays ambient and adds no maintenance" is.

| Surface | Decision | Rationale |
|---|---|---|
| **Standard menu bar** (File/Edit groups) | **IN — built** | Houses the global commands (§5.1). Native, discoverable, zero in-window chrome. The *right* place for power, off the calm canvas. |
| **Menu-bar extra** (status item, `MenuBarExtra` + `CaptureMenuView`) | **IN — built** | One-keystroke capture from anywhere without raising the main window. Type a task (with NL dates / recurrence), `↩`, done. This is the Mac's answer to "capture is too much work" (#2) at the OS level — the equivalent of the iPhone share-sheet/widget. `menuBarExtraStyle(.window)`. |
| **Global system-wide hotkey** (capture from any app, app unfocused) | **IN — planned (P2/P3)** | The menu-bar extra requires a click on the status item; a true registered global hotkey (e.g. `⌃⌥Space`) opening `CaptureMenuView` is the frictionless ideal. Out today only because it needs a global event monitor / login-item consideration; honors P2. Must remain a *single* capture field — never a launcher. |
| **`⌘K` command bar** (`CommandBarView`) | **IN — built** | Spotlight-style centered capture overlay: NL-parsed multi-line add (one task per line), `↩` adds + stays open (batch capture), `esc` closes, a quiet "N added" confirmation. It is **capture-only**, not a fuzzy command palette — adding "commands" to it would smuggle a control surface in (P1). See §6.1. |
| **Focus mode** (`⌘J`, `FocusModeView`) | **IN — built** | Full-window single-task "NOW": the top task large and centered, a Complete button, `return` done / `→` defer / `esc` exit, and a wordless "N left" line. The doing surface — the planning board collapsed to the one thing. |
| **`.hiddenTitleBar` window** | **IN — built** | `windowStyle(.hiddenTitleBar)`, default 920×820, `contentMinSize` resizable. The chromeless frame is the calm; the board *is* the window. |
| **Settings window** | **IN — built** (currently a sheet, `SettingsView`) | API key, appearance, context field. **Should migrate to a real `Settings { }` scene** so `⌘,` opens it natively (§9). Keep it a single short pane — it is the *only* configuration screen and must stay that way (no tabs sprawl). |
| **Multi-window** | **DEFERRED — single window** | The product is *one calm screen*; multiple week-board windows invite a "windows to maintain" tax and a sync-within-app coherence question. `WindowGroup` technically permits it, but we don't design for or encourage it. Revisit only if a real workflow demands it. |
| **Full-screen** | **ALLOWED — passive** | Standard macOS full-screen works (it's just the board, bigger). The board already fills the viewport, so full-screen is a free win with no special design. |
| **Dock badge / count** | **OUT — forbidden** | A Dock badge of incomplete tasks is the guilt machine (master `PRD.md §7.7`). **Never** set `NSApp.dockTile` to a count. The Dock icon stays a plain icon. |
| **Notification Center** | **IN — planned (P2)** | Exactly **one** "your day is ready" local notification/day, opening to Today. Enforced max-one-nudge, **no badge** (master `PRD.md §7.7`). |
| **Hover affordances** | **IN — built, rationed** | `QuietControls` fades from 0.28→1.0 opacity on hover; the parked hero reveals a one-line "why first" whisper on hover. Hover *reveals*, never *adds standing UI*. (And hover doubles as the trust-freeze signal, §4.) |
| **Spotlight / Quick Look / Services / sharing** | **OUT (for now)** | Indexing tasks into system Spotlight is a privacy + scope question (P9) not worth Phase-0–3 surface. |

### 6.1 `⌘K` command bar vs. menu-bar extra — why both, and the boundary

Both are capture; they differ by context:
- **`⌘K` command bar** = capture *while the main window is focused and you're planning*. Centered over the board, supports **batch** entry (paste five lines, each becomes a task), confirms inline. It's the desk-session bulk-add.
- **Menu-bar extra** = capture *while you're in another app entirely*. A small popover, single field, fire-and-forget.

The boundary that keeps both honest: **neither runs commands.** They parse text → `DateParser` → `store.add`. The moment either gains a "/" command menu or fuzzy actions, it has become a control surface and violates P1. If we ever want "search from `⌘K`," that's a separate, clearly-labeled find — not a mode of capture.

---

## 7. Capture & the model on the Mac

Capture (P2, pain #2) has four entry points on the Mac, all funneling through the **same** silent `DateParser` + `store.add`:
1. **Inline `AddRow`** in any day lane — tap/`o`/`a`, type, `return`.
2. **`⌘N`** — focuses Today's add row.
3. **`⌘K` command bar** — batch, centered.
4. **Menu-bar extra** — from any app.

All four run `DateParser.parseRecurrence` then `DateParser.parse`: "call Sam friday" files on Friday with the date token stripped; "standup every weekday" creates a weekday `Recurrence`. No date picker, no required fields, no recurrence UI — the language *is* the UI.

**The shared model (master `PRD.md §7.1`), as it manifests on the board:**
- A **day-task** (`list == nil`) lives in a `DayColumn`, rolls forward, and is gravity-ranked.
- A **parking-lot task** (`list ∈ {Later, Misc, Reminders}`) lives in a trailing `ListLane`, is undated, **never ranked, never rolled forward** — the someday/maybe pressure valve. Moving it onto a day lane (drag, or `move`) un-files it and it joins the ranked field.
- **Pin** (`p` / context menu) is the **one** sanctioned manual override (master `PRD.md §7.3`): pinned tasks sort first regardless of AI score. It's a one-tap *intent*, not a priority system to maintain — which is exactly why it's allowed where a "P1/P2/P3" flag is forbidden.

---

## 8. The parked alternative layout (`MacListView` / `MacRow` / `SideRail`) — keep, don't delete

Before the week board became the only surface, the Mac shipped a **vertical "Gravity Field" list**: a single centered column of days flowing top-to-bottom, the right rail (`SideRail`) holding the parking lots, and — the signature — a **crowned Playfair "NOW" hero**: Today's #1 rendered as a large serif task on a warm **elevated card** (`Color.cardElevated`, lifted by light not shadow), with a `"NOW"` eyebrow and an on-hover "why first" whisper. The full honest-confidence flatten is wired here (hero 27→22, label → `"A FEW THINGS MATTER"`).

**Status: retained in source, not presented** (`ContentView` macOS branch instantiates `WeekBoardView` only). **Do not delete `MacListView`, `MacRow`, `SideRail`, `SideList`, `TodayMasthead`, `Sparkline`, `Meander`.** The user may want it back.

**Why it might return (the conditions):**
- **Single-day deep focus.** The vertical list with the big serif hero is more *editorial* and more emotionally satisfying for a "just today" mood than a 7-lane board. A future "Today" view, or the `3`-day board feeling too sparse, could revive it.
- **Narrow windows / laptops.** The board needs width to breathe (168pt lane floor); below ~860pt the parked layout's single column + collapsing rail (`showRail = width >= 860`) degrades more gracefully. A width-adaptive `ContentView` could present the list under a threshold and the board above it.
- **The hero crown is the strongest expression of the design language.** If user research says the board's quiet eyebrow-crown under-sells the intelligence ("invisible to the point of seeming dumb," master risk `§13`), the serif hero is the louder-but-still-calm answer, ready to swap in.

Because both layouts already share `MacRow`, `Gravity`, `AddRow`, `DateParser`, and the `TaskStore` safe-moment machinery, swapping or width-gating between them is a `ContentView` change, not a rewrite. That is the value of keeping it parked.

---

## 9. Mac-specific roadmap

Sequenced by leverage. Phase numbers align with the master roadmap (`PRD.md §11`) where they share work (sync, time, ritual); Mac-only items are called out. Each item has an explicit done criterion.

### Phase 0 — Board parity & hardening (now)
*Make the only-presented surface as complete as the parked one, and lock the invariants.*
- [ ] **Port the keyboard model** (§5.2) from `MacListView.handleKey` into `WeekBoardView`/`DayColumn`: selection cursor, j/k nav across lanes, `space`/`x` complete with cursor-march, `e`/`return` edit, `p` pin, `t`/`m`/`1–7`/`[`/`]` defer, `esc`. **Done:** every keystroke in §5.2 works on the board; AC-KB-1..4 pass.
- [ ] **Port honest-confidence flatten to the board** (§3.4): `DayColumn` consults `store.topScoresClustered(on:)` and softens the crown + ramp. **Done:** AC-GF-3 passes on the board, not just the parked list.
- [ ] **Re-affirm the `handleKey` bail guard** on the board's new key handler (§5.3) and add the regression test. **Done:** AC-KB-2 passes; a unit test fails if the guard is removed.
- [ ] **Board search** to replace the parked `⌘F` in-list search (a quiet overlay filter, not a new lane). **Done:** `⌘F` filters visible lanes; `esc` clears.
- [ ] **Trust test:** unit test that `commitPendingRank()` is a no-op while `interacting` is non-empty (AC-T-4); and a UI test that hover freezes order (AC-T-1).
- [ ] **500-task stress fixture** (shared with master Phase 0): board stays smooth; per-lane vertical scroll only; ranking still ranks only the visible window. **Done:** no dropped frames scrolling a 500-task fixture; Haiku calls/session unchanged.
- **Exit criteria:** the week board has full keyboard + flatten + search parity with the parked layout; all trust ACs covered by tests; no regressions in the bail guard.

### Phase 1 — Settings as a real scene + sync parity
- [ ] **Migrate `SettingsView` from a sheet to a `Settings { }` scene** so `⌘,` opens it natively and it lives in the app menu. Keep it one short pane. **Done:** `⌘,` opens Settings; sheet path removed from `ContentView`.
- [ ] **iCloud/CloudKit sync** (shared with master Phase 1) behind `TaskStore` persistence; **Mac↔iPhone parity** verified (add on Mac → appears on iPhone within seconds and vice versa); local-first preserved (offline edits reconcile). **Done:** master AC for sync + a Mac-specific check that a board edit propagates to the phone day list.
- **Exit criteria:** native `⌘,` Settings; a task added on the board appears on iPhone reliably across 100 edit/sync cycles with no loss.

### Phase 2 — Time awareness + the single daily nudge (Mac side)
- [ ] **`TimeContextProvider` (EventKit)** appends "free hours / next event" to `context` (shared with master Phase 2). On the board this should produce an **ambient over-commitment cue** — the *quietest* honest signal (e.g. a faint hairline under a day whose load exceeds free hours, or lower-ranked rows dimming toward "tomorrow" weight). **No red, no number** (P6, master `§7.4`). **Done:** ranking demonstrably shifts when the day's calendar is full; the cue is felt, not announced.
- [ ] **`Notifier`** schedules the single "your day is ready" local notification; opens the Mac to Today. **Max one/day, no Dock badge ever** (§6, master `§7.7`). **Done:** the app can never schedule >1 nudge/day; the Dock icon never shows a count.
- **Exit criteria:** time signal visibly influences the board's order; notification cap enforced in code; Dock stays badge-free.

### Phase 3 — Global capture & context connectors (Mac side)
- [ ] **Global system-wide hotkey** opening `CaptureMenuView` from any app (§6) — registered event monitor, login-item aware. **Done:** capture works with Smart TDL unfocused; still a single capture field, no launcher behavior.
- [ ] **Context connectors** (Calendar already in P2; Gmail next) feed the **same `context` string** — no new Mac UI; connectors are inputs, the board's auto-sort is the only output (master `§7.5`). **Done:** at least one external source measurably improves board ranking in dogfood; only derived/minimal context leaves the device; per-source opt-in + revoke.
- **Exit criteria:** capture from anywhere on the Mac without raising the window; a connector improves ranking with zero new on-board UI.

### Phase 4 — Considered Mac experiments (gated, may never ship)
- [ ] **Width-adaptive layout swap:** present the parked vertical hero list below a width threshold, the board above it (§8). **Gate:** must not double maintenance or confuse the user with two "modes."
- [ ] **Hidden "why is this first?"** one-line rationale on the board hero (already present in the parked hero on hover). **Gate:** stays hover-revealed, never standing UI (P1).
- [ ] **Optional "block time for the top task"** writing one Calendar event from focus mode (master `§7.4` Phase-3 experiment). **Gate:** single deliberate gesture only; never auto-schedules.
- **Exit criteria:** each passes the principles in master `§4`; anything that adds standing UI or a maintenance burden is cut.

---

## 10. Temptations the wide screen invites — and the ambient alternative

A desk surface with a 27" canvas is where the non-goals (master `§4.1`) come under the most pressure. Naming each (P-naming discipline):

| Temptation (because there's room) | Why it violates the constitution | The ambient alternative we ship instead |
|---|---|---|
| A **left sidebar of projects/tags** | Re-introduces organizing-isn't-doing (#6) and the maintenance tax | No sidebar. Days are the only "containers"; the AI does the grouping by ranking. |
| **Status columns** (To Do / Doing / Done) — it *looks* like a board already | Manual status-dragging is productivity theater (#6); status is a thing to maintain | The lanes are **days**, not statuses. "Done" is the dimmed tray, not a column you drag into. |
| A **priority/inspector panel** on the right | Manual P1–P4 is exactly the busywork we removed (#3, P1) | The gravity ramp *is* the priority view, drawn by the AI; pin is the only manual lever. |
| **Numbers everywhere** (counts per lane, % complete, score tooltips) | Numbers are the guilt/score machine (master `§8`, P1) | Wordless shape: the ramp, the `Sparkline`, the `Meander`. No figures. |
| A **Dock badge** of incomplete tasks | The single most guilt-inducing macOS affordance (#1, master `§7.7`) | Plain Dock icon, forever. At most one honest notification/day. |
| **Multi-window / detached day windows** | "Windows to maintain" tax; coherence questions | One calm window. Focus mode (`⌘J`) is the "one thing" view, not a second window. |
| A **fuzzy command palette** on `⌘K` | Smuggles a control surface into capture (P1) | `⌘K` is capture-only; commands live in the native menu bar where they belong. |
| A **settings page with tabs** (themes, integrations, rules) | Configuration sprawl = the Notion disease (#5) | One short Settings pane: key, appearance, context. Connectors are opt-in toggles, not a control room. |

The rule of thumb from the master holds on the Mac with extra force: **if a new idea needs a new color, a new control, or a number on screen, find the ambient version or drop it.**

---

## 11. "Calm but fast" — the Mac's defining property

The two halves, and how they coexist:

**Calm to look at**
- One window, chromeless (`.hiddenTitleBar`), warm paper (`Color.bgCanvas`), serif mastheads.
- The **only** standing chrome is `QuietControls` top-right, and it sits at **0.28 opacity until hovered** — present but nearly invisible.
- No badges, no counts, no toolbars, no sidebars, no inspectors.
- Re-ranks land slowly (`Motion.ambient`) and only at safe moments — the board never twitches.

**Fast to operate**
- Every action has a keystroke (§5); the trackpad is optional.
- Capture from four places, all NL-parsed, all zero-field.
- `space`/`x` sweeps a day clear; `t`/`m`/`1–7` defers without a date picker; `⌘K` batch-adds.
- The menu-bar extra (and planned global hotkey) capture without even raising the window.

The synthesis: **the speed lives in muscle memory and the menu bar, not in on-screen controls.** A novice sees only the calm board and uses the mouse; an expert never sees more chrome but flies by keyboard. The same pixels serve both. That is the "simple + smart" quadrant (master `§3.2`) made literal on the desktop — and the explicit guardrail against it failing is the master's anti-metric (master `§12`): if time-in-app rises without completions rising, we accidentally built busywork and must cut surface.

---

## 12. Sync, Keychain, and the dev loop (Mac specifics)

### 12.1 Sync parity
Persistence today is local JSON at `~/Library/Application Support/SmartTDL/tasks.json` (atomic writes, resilient `decodeIfPresent` decoding — **never break old-file loading**). **Phase 1 iCloud/CloudKit sync** (master `§7.8`, `§11`) must give the Mac board and the iPhone day list an **identical model**: a task added to a lane on the Mac appears in the right day on the phone and vice versa, with last-writer-wins on `id`+`createdAt`. Sync is a **mirror, not a dependency** — the Mac stays fully usable offline (local-first, P9).

### 12.2 The Keychain re-prompt-on-resign dev gotcha (Mac-only pain)
The user's Anthropic key lives in the Keychain (`service com.smarttdl.SmartTDL`, account `anthropic-api-key`). **macOS ties Keychain item access to the app's code signature, and an ad-hoc dev build's signature changes on every rebuild** — so macOS re-prompts for Keychain access (or denies it) far more often in development than iOS ever does. Mitigations already in code and to preserve:
- `Keychain.hasKey` reads a **`UserDefaults` flag** (`smarttdl.hasAPIKey`), never the Keychain — so a no-key/fresh install produces **zero** system prompts and launch never blocks.
- The real `Keychain.apiKey` read runs **off the main thread** in `refreshRanker()` (`Task.detached`), defaulting to `HeuristicRanker` until it resolves — the first frame never waits on the Keychain.
- **Never reintroduce a synchronous Keychain read in `init()` or `SettingsView`** (master `§7.9`). This is a hard rule; it's the difference between a clean launch and a password-prompt-on-every-build dev experience.

### 12.3 Build / run / observe loop
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -scheme SmartTDL -destination 'platform=macOS' \
  -configuration Debug -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
codesign --force --deep --sign - <built .app>     # ad-hoc sign so it runs
open <built .app>
screencapture -x -o /tmp/x.png                    # grab the running board to verify UI
```
(Per master `§7.10`. The repo `README.md` is stale — it still describes an older priorities/`AddTaskView` design — trust the source and this PRD, not the README, until the README is refreshed.)

---

## 13. Cross-document dependencies (keep consistent)

- **Shared model & invariants** with the master and the iPhone PRD: `TodoItem` (`list==nil` ⇒ ranked day-task; `list` set ⇒ unranked parking lot), `Recurrence`, `TaskStore.order`, the **safe-moment buffered re-rank** (`pendingScores`/`interacting`/`commitPendingRank`), and the **`Ranker` seam** (`context` is the universal input; auto-sort is the only output). Any change here is a cross-platform change — coordinate with master `§9.1`.
- **Sync policy** (last-writer-wins on `id`+`createdAt`, local-first mirror) must match the iPhone PRD and master `§7.8` exactly — the Mac board and iPhone list are the same data.
- **The intelligence never adds UI** (P1) is a *shared* contract; the Mac's gravity ramp/crown is the agreed visualization and must not drift into scores/badges that would contradict the iPhone or master.
- **Design languages** ("Settle" + "Gravity Field") are shared and already chosen (master `§8`); the Mac extends them, it does not fork them.
- **Notification & Dock policy** (max one nudge/day, no count badge) is shared with master `§7.7`; the Mac additionally forbids a Dock badge.

---

## 14. Open questions (Mac-specific)

1. **Board hero loudness.** Is the board's quiet eyebrow-crown enough to make the intelligence *felt* in the first session (master risk: "invisible to the point of seeming dumb"), or do we need the parked serif hero (§8) — perhaps width-gated? Needs dogfood.
2. **Width-adaptive swap.** Should `ContentView` present the parked vertical hero list below a width threshold and the board above it (§8 / Phase 4), or is "two layouts" itself a complexity smell to avoid?
3. **Global hotkey vs. menu-bar extra overlap.** Once a global hotkey exists, does the menu-bar status item still earn its place, or does it become redundant chrome?
4. **Settings scope creep as connectors arrive.** When Calendar/Gmail connectors land (Phase 3), how do per-source opt-in toggles live in a one-pane Settings without becoming a "control room"? (Likely: a single short "Connections" list, each a plain on/off + revoke — no per-connector configuration screens.)
5. **Over-commitment cue loudness (Mac).** What is the quietest board treatment that still honestly says "this day is full" without a number or a red mark? (Shared with master open question, but the board's lane geometry gives it a Mac-specific answer space — e.g. lane-fill tone vs. a hairline.)
6. **Spotlight indexing.** Worth exposing tasks to system Spotlight later for OS-level find, or does that violate local-first/private-by-default (P9)?
