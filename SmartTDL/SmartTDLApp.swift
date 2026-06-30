import SwiftUI

@main
struct SmartTDLApp: App {
    @State private var store = TaskStore()
    @Environment(\.scenePhase) private var scenePhase

    init() { Typeface.register() }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .onAppear { store.drainCaptures() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { store.drainCaptures() }   // captured while backgrounded
                }
        }
        #if os(macOS)
        .defaultSize(width: 920, height: 820)
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        #endif
        .commands {
            CommandGroup(replacing: .undoRedo) {
                Button("Undo") { store.undo() }
                    .keyboardShortcut("z", modifiers: .command)
            }
            CommandGroup(after: .newItem) {
                Button("New Task") { store.requestNewTask() }
                    .keyboardShortcut("n", modifiers: .command)
                Button("Quick Capture…") { store.requestCommandBar() }
                    .keyboardShortcut("k", modifiers: .command)
                Button("Find") { store.requestFind() }
                    .keyboardShortcut("f", modifiers: .command)
                Divider()
                Button("Focus Now") { store.requestFocusMode() }
                    .keyboardShortcut("j", modifiers: .command)
                Button("Push Unfinished to Tomorrow") { store.pushAllToTomorrow() }
                    .keyboardShortcut("t", modifiers: [.command, .shift])
            }
        }

        #if os(macOS)
        MenuBarExtra("Smart TDL", systemImage: "checklist") {
            CaptureMenuView()
                .environment(store)
        }
        .menuBarExtraStyle(.window)

        // Native Settings scene → ⌘, opens it from the app menu (no in-window sheet).
        Settings {
            SettingsView()
                .environment(store)
        }
        #endif
    }
}
