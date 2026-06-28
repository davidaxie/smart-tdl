# Smart TDL — Sync Implementation Plan (Phase 1)

**Status:** Plan · **Owner:** David Xie · **Date:** 2026-06-28 · **Companion to:** [`PRD.md`](PRD.md) §7.8/§9.2, [`PRD-mac.md`](PRD-mac.md) §12.1

> This doc makes every design decision sync needs, so the actual CloudKit code is mechanical once the container exists. It exists because real sync can't be built/tested under the ad-hoc dev loop (no iCloud entitlement / container). **The work is split:** the user does the one-time capability + container setup (§6); everything else (§3–§5) is implementable and unit-testable without an account, and §7 is the code that lands once §6 is done.

---

## 1. Goal & constraints (from the master PRD)

- **Mac ↔ iPhone are the same data.** A task added/edited/completed on one appears on the other within seconds. (Apple platforms only — Android is a separate story, [`PRD-android.md`](PRD-android.md) §0.3.)
- **Local-first.** The app is fully usable offline; sync is a **mirror, not a dependency**. The local JSON file (`tasks.json`) stays the source of truth the UI reads; sync reconciles it in the background.
- **No backend we operate.** Sync rides Apple's CloudKit private database (the user's own iCloud); we run no server and hold no user data.
- **Conflict policy:** last-writer-wins per task.
- **The trust invariant still holds (P5).** Remote changes must **never reorder/mutate a row under the user's hand** — they are applied at safe moments, exactly like buffered re-rank scores.

## 2. Architecture decision — `CKSyncEngine`

**Chosen: `CKSyncEngine`** (iOS 17 / macOS 14 — the app already targets these). Rejected alternatives:

| Option | Why not |
|---|---|
| `NSPersistentCloudKitContainer` | Forces a migration to Core Data/SwiftData. The app's model is a simple `Codable` array; a full ORM migration is a big, risky change for no benefit here. |
| Hand-rolled `CKDatabase` push/pull | Re-implements change tokens, retries, batching, account-state handling, and a server-change subscription by hand — exactly what `CKSyncEngine` exists to give us. |
| A BaaS (Firebase/Supabase) | Reintroduces a backend we operate — violates the non-goal, and adds an account system. |

`CKSyncEngine` keeps the `Codable` model, syncs at the record level (efficient — only changed tasks move), persists its own sync state, and surfaces a clean delegate for "here are the changes to send / here are the changes that arrived." It's the right-sized tool for a single-user, multi-device app.

## 3. Data model mapping

One CKRecord per task, in a single custom record zone in the **private database**.

- **Record type:** `Task`
- **Record zone:** `TasksZone` (a custom zone — required for `CKSyncEngine` and for delete tracking).
- **Record name (CKRecord.ID):** the task's `id.uuidString` (stable, so the same task is one record everywhere).
- **Fields:** `title` (String), `isCompleted` (Int64 0/1), `day` (Date), `sortIndex` (Double), `createdAt` (Date), `modifiedAt` (Date — see §4), `isPinned` (Int64), `recurrence` (String? — the `Recurrence` JSON), `list` (String?).
- **Deliberately NOT synced: `importance`.** It's local AI output — each device computes its own ranking from its own key/context. Syncing it would cause churn and cross-device disagreement. Importance stays device-local; only the *inputs* (the task content) sync, and each device ranks independently. This is consistent with "the ranker is the only output, context is the input."

`Recurrence` already encodes to JSON via `Codable`; store it as a JSON string field. `TodoItem ↔ CKRecord` is a pure, unit-testable mapping (write it as `TodoItem(record:)` / `record(from:)` and test round-tripping without any network).

## 4. Conflict resolution — last-writer-wins on `modifiedAt`

LWW needs a per-task **modification** timestamp. The model only has `createdAt` (creation), so Phase 1 adds **`modifiedAt: Date`** to `TodoItem`:

- Defaults to `createdAt` (Codable-resilient: old `tasks.json` files without the field decode fine and back-fill `modifiedAt = createdAt`).
- **Bumped to `Date()` on every user-meaningful content change** — add, rename, toggle-complete, move (day/list), pin, recurrence change, roll-forward, end-of-day sweep.
- **NOT bumped on importance/rank commits** (`commitPendingRank`) — importance is local-only and not synced.

Merge rule when a local task and an incoming remote record collide: **keep the one with the later `modifiedAt`.** Ties (same `modifiedAt`) break on `id` for determinism. Because completion is the most common "conflict" (done on phone, still open on Mac), LWW resolves to the later edit, which is acceptable for a single-user tool.

Deletes propagate as CKRecord deletions in the zone (tombstoned by `CKSyncEngine`), so a delete on one device removes the task on the other.

## 5. Integration points in the app (testable now, wired on §6 completion)

1. **`modifiedAt` field + bumping** — model change, fully testable now (this branch implements it). 
2. **`TodoItem ↔ CKRecord` mapping** — pure functions, unit-testable now.
3. **A `SyncCoordinator`** (added when the container exists) owns the `CKSyncEngine`, holds its serialized state, and:
   - **On local mutation:** `TaskStore` notifies it; it enqueues the changed record IDs to send. (A light hook at the same points that bump `modifiedAt`.)
   - **On remote changes arriving:** it merges them into `items` by the LWW rule — **buffered and committed at safe moments**, reusing the existing `pendingScores`/`interacting`/`commitPendingRank` machinery so a remote edit never reshuffles a row under the cursor/finger (P5). This is the key tie-in: *sync changes are treated exactly like re-rank changes.*
4. **`TaskStore.save()/load()` stay** as the local cache; `SyncCoordinator` is additive, not a replacement. Offline edits queue in `CKSyncEngine`'s pending state and flush on reconnect.
5. **Account-state handling:** if the user isn't signed into iCloud, the app runs exactly as today (local-only) — no errors, no nags. Sync simply isn't active.

## 6. Prerequisites — the one-time setup the user does (in Xcode + portal)

These are **account-gated** and can't be done under ad-hoc signing:

1. **Sign the target with your Apple Developer team** (Signing & Capabilities → Team), so entitlements can be provisioned.
2. **Add the iCloud capability** → check **CloudKit**. Xcode adds the entitlement `com.apple.developer.icloud-services = [CloudKit]` and `com.apple.developer.icloud-container-identifiers`.
3. **Create the CloudKit container** `iCloud.com.smarttdl.SmartTDL` (Xcode can create it, or do it in the Apple Developer portal / CloudKit Console).
4. **(Optional, for widgets/extensions later) App Group** `group.com.smarttdl` — the shared local substrate for `tasks.json` ([`PRD-iphone.md`](PRD-iphone.md) §4). Not required for sync itself.
5. Confirm the same iCloud account is signed in on both the Mac and the iPhone used for testing.

Until step 1–3 exist, the `SyncCoordinator` code (§7) won't run; everything in §3–§5 (mapping, `modifiedAt`, the buffered-merge design) is built and tested without them.

## 7. The code that lands after §6

- `SyncCoordinator` (owns `CKSyncEngine`, conforms to `CKSyncEngineDelegate`): handle `fetchedDatabaseChanges` / `sentDatabaseChanges` / `fetchedRecordZoneChanges` / `sentRecordZoneChanges` / `stateUpdate`; serialize the engine state to disk.
- `TodoItem(record:)` + `record(from:)` mapping (built now).
- `TaskStore` hooks: a `syncDidMutate(ids:)` notification at the bump sites; a `applyRemote(_:)` that funnels remote merges through the safe-moment buffer.
- Wire `SyncCoordinator` into `SmartTDLApp` lifecycle (start on launch if an iCloud account is available; respond to account changes).

## 8. Verification plan (when unblocked)

- **Two-device parity:** add on Mac → appears on iPhone within seconds, and vice versa (master AC).
- **Offline reconcile:** edit on each device while offline → reconnect → both converge with no loss.
- **Trust under sync:** trigger a remote change while hovering/editing a row on the other device → the row must not move until a safe moment (P5 regression check).
- **100 edit/sync cycles:** no data loss, no duplicate tasks (LWW + stable record IDs guarantee this).
- **No-account path:** sign out of iCloud → app works exactly as local-only, no errors.

## 9. Risks & notes

- **Roll-forward churn:** `rollForward` bumps `modifiedAt` on launch, so an unfinished task moved to "today" syncs. If two devices launch on different days they may both roll a task forward to their own "today" — LWW on `modifiedAt` resolves it to the later launch. Acceptable; revisit if it proves annoying (could make roll-forward not bump `modifiedAt` and instead derive "today" per-device at read time).
- **Importance is intentionally local** (§3) — expect each device to show its own ranking until both have ranked; this is by design, not a sync bug.
- **CloudKit eventual consistency:** "within seconds" is typical but not guaranteed; the UI must never block on sync (it doesn't — local-first).
- **Schema in CloudKit** is created on first record save in the Development environment; promote to Production before App Store release.

---

### Decisions locked by this doc
CKSyncEngine (not Core Data, not a BaaS) · one `Task` record per task in a custom `TasksZone` of the private DB, keyed by `id` · sync task **content** but **not `importance`** (local AI) · LWW on a new **`modifiedAt`** field · remote merges go through the **safe-moment buffer** so sync honors P5 · local JSON stays the source of truth the UI reads.
