# Smart TDL

A calm day planner for iPhone and Mac that decides what matters next, without showing you a single priority flag.

## What it does

Smart TDL is a minimal, TeuxDeux-style list of days: Today first, then the next six. There are no projects, tags or priority pickers. Instead, a ranking engine scores the open tasks in the background and quietly floats the most important one to the top.

- **Fast capture.** Type `call Sam friday` and the task lands on Friday with the date words removed. Also understands `tomorrow`, `next tue` and `in 3 days`, plus recurrence like `every weekday` or `every monday`.
- **Invisible ranking.** A local heuristic works offline with no setup. Paste your own Anthropic API key and Claude Haiku 4.5 ranks instead, optionally guided by a one-line "what are you working on?" note.
- **Never reorders under your hand.** New scores are buffered and applied only at a "safe moment", when no row is being touched, hovered or edited.
- **Honest confidence.** When the AI's top two scores are within 0.06 of each other, the UI stops presenting a single #1 and gives the top tasks equal weight.
- **Rolls forward.** Unfinished tasks move to today, and one shortcut pushes everything left today to tomorrow.
- **Mac week board.** A column per day (3, 5 or 7 days) with a "gravity" type ramp, so rank shows up as size and weight. Undated Later / Misc / Reminders lanes sit to the right, and tasks drag between days and lanes.
- **Keyboard first on Mac.** Cmd+N new task, Cmd+K quick capture, Cmd+J focus mode (one task, full screen), Cmd+Shift+T push to tomorrow, Cmd+Z undo, plus a menu bar capture item.
- **iPhone.** Swipe to complete, pin or delete, a long-press menu to move a task, and a success haptic when you check one off.

## How it works

- **`TaskStore`** (`@Observable`, main actor) is the single source of truth. It persists to JSON in Application Support, and the decoder tolerates older files that lack newer fields.
- **`Ranker` protocol.** `HeuristicRanker` (keyword and due-date scoring) and `HaikuRanker` (raw Messages API over `URLSession`, since there is no Swift SDK) can be swapped freely. The API key lives in the Keychain, behind a `UserDefaults` flag so launch never triggers a Keychain prompt.
- **Context connectors.** A `ContextAggregator` combines the user's note with one-line fragments from pluggable connectors before each rank. `TimeContextProvider` turns today's remaining calendar events (EventKit) into "about N free hours left", using merged, window-clamped interval math. A Gmail connector is stubbed behind an `InboxReading` protocol.
- **Sync, built ahead of activation.** `TodoItem` maps to and from a `CKRecord` as pure, offline-testable functions. `SyncCoordinator` wraps `CKSyncEngine` with last-writer-wins on `modifiedAt`. AI scores are deliberately left out of sync, because each device computes its own. Remote changes are buffered behind the same safe-moment gate as local re-ranks, and local saves are diffed so only changed IDs go upstream.
- **Capture inbox.** A Share Extension appends text to an App Group queue (`CaptureInbox`), and the app drains it into Today whenever it becomes active, so the app remains the only writer of `tasks.json`.
- **One calm daily nudge.** `DailyRitual` schedules a single repeating notification under a stable identifier, so rescheduling replaces it instead of stacking. The copy leads with the day's top task and never shows a bare count.
- **Tests.** 67 XCTest cases cover ordering, recurrence math, legacy decoding, the safe-moment commit, CKRecord round-trips, LWW merges, sync echo suppression, free-time math, notification scheduling, connector prose and the capture queue.

## Tech stack

Swift 5, SwiftUI (one multiplatform target, iOS 17+ and macOS 14+), Observation, CloudKit (`CKSyncEngine`), EventKit, UserNotifications, Keychain Services, XCTest. No third-party dependencies. Display type is Playfair Display (SIL OFL).

## Running locally

Requires Xcode 16 or newer.

```bash
open SmartTDL.xcodeproj
```

Pick **My Mac** or an iPhone simulator and press Cmd+R. From the command line:

```bash
# Mac app
xcodebuild -scheme SmartTDL -destination 'platform=macOS' build

# iPhone simulator
xcodebuild -scheme SmartTDL -destination 'generic/platform=iOS Simulator' build

# Unit tests
xcodebuild test -scheme SmartTDL -destination 'platform=macOS'
```

To use AI ranking, open Settings (Cmd+, on Mac) and paste an Anthropic API key. Without one, the app uses the local heuristic.

## Status / roadmap

The core app works locally on iPhone and Mac. The following are implemented and unit-tested but not yet switched on, because each needs Apple Developer signing or an OAuth client:

- iCloud sync between Mac and iPhone (`SyncCoordinator.swift`, setup steps in [`docs/sync-plan.md`](docs/sync-plan.md))
- An in-app opt-in for the calendar free-time signal
- The daily notification
- The Share Extension target ([`ShareExtension/README.md`](ShareExtension/README.md))
- A live Gmail connector

The product thinking lives in [`docs/PRD.md`](docs/PRD.md), with platform companions for [Mac](docs/PRD-mac.md), [iPhone](docs/PRD-iphone.md), [Android](docs/PRD-android.md) and a [landing page](docs/PRD-landing-page.md).
