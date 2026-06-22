# Smart TDL

A smart to-do list app for **iPhone** and **Mac**, built as a single SwiftUI
multiplatform project. Add tasks, set priorities and due dates, and let the app
surface what matters with an intelligent sort order.

<p align="center"><em>One codebase → iOS app + native Mac app.</em></p>

## Features

- ✅ **Add / edit / complete / delete** tasks (tap a row to edit, swipe to delete)
- 🎯 **Priorities** — Low / Medium / High, color-coded
- 📅 **Due dates** — optional, with **Today** and **overdue** highlighting
- 🧠 **Smart ordering** — open tasks first, then overdue, then by priority,
  then by soonest due date
- 🔍 **Search** and **filter** (All / Active / Done)
- 💾 **Local persistence** — tasks are saved to a JSON file in Application Support
- 🍎 **Native on both platforms** — iPhone, iPad, and Mac from one target

## Requirements

- **Xcode 16 or newer** (developed and verified on Xcode 26)
- **iOS 17+** / **macOS 14+** deployment targets

## Getting started

```bash
open SmartTDL.xcodeproj
```

Then pick a destination in the toolbar:

- **My Mac** → runs the native Mac app
- **Any iPhone simulator** → runs the iOS app

Press **⌘R** to build and run.

### Build from the command line

```bash
# Mac app
xcodebuild -scheme SmartTDL -destination 'platform=macOS' build

# iPhone simulator
xcodebuild -scheme SmartTDL -destination 'generic/platform=iOS Simulator' build
```

> If `xcodebuild` isn't found, your `xcode-select` may point at the Command Line
> Tools. Prefix commands with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`
> or run `sudo xcode-select -s /Applications/Xcode.app`.

## Project structure

```
SmartTDL/
├── SmartTDL.xcodeproj          # Xcode project (single multiplatform target)
└── SmartTDL/
    ├── SmartTDLApp.swift       # @main App entry point
    ├── ContentView.swift       # Root screen: filter, search, summary bar
    ├── TaskListView.swift      # The task list + empty states
    ├── TaskRowView.swift       # A single task row + priority badge
    ├── AddTaskView.swift       # Create / edit form (sheet)
    ├── TaskStore.swift         # @Observable store: CRUD, smart sort, persistence
    ├── TodoItem.swift          # The task model + Priority enum
    ├── Theme.swift             # SwiftUI color theming for priorities
    └── Assets.xcassets         # App icon slots + accent color
```

## Architecture

- **`TaskStore`** is the single source of truth. It's an `@Observable` class
  injected into the SwiftUI environment, so any view can read or mutate tasks and
  the UI stays in sync automatically.
- **Persistence** is plain `Codable` → JSON, written atomically to
  `~/Library/Application Support/SmartTDL/tasks.json` (and the platform
  equivalent on iOS). No external dependencies.
- **The model layer** (`TodoItem`, `Priority`) imports only Foundation; UI
  concerns like colors live in `Theme.swift`.

## Ideas for next steps

- Tags / projects to group tasks
- Notifications/reminders for due dates
- iCloud sync via SwiftData or CloudKit
- Recurring tasks
