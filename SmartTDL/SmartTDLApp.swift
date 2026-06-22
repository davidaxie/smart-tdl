import SwiftUI

@main
struct SmartTDLApp: App {
    @State private var store = TaskStore()

    init() { Typeface.register() }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
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
        #endif
    }
}
