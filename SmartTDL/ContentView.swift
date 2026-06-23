import SwiftUI

struct ContentView: View {
    @Environment(TaskStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @State private var showSettings = false
    @AppStorage("smarttdl.appearance") private var appearance = Appearance.system.rawValue
    #if os(macOS)
    @State private var showCommandBar = false
    @State private var showFocusMode = false
    #endif

    var body: some View {
        shell
            .tint(.accentInk)
            .preferredColorScheme(Appearance(rawValue: appearance)?.colorScheme)
            .sheet(isPresented: $showSettings) {
                SettingsView().environment(store)
            }
            .onChange(of: showSettings) { _, shown in
                if !shown { store.requestListRefocus() }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { store.commitPendingRank() }
            }
    }

    @ViewBuilder
    private var shell: some View {
        #if os(macOS)
        ZStack {
            Color.bgCanvas.ignoresSafeArea()
            WeekBoardView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .overlay(alignment: .topTrailing) {
            QuietControls(onCapture: { showCommandBar = true },
                          onFocus: { showFocusMode = true },
                          onSettings: { showSettings = true })
        }
        .overlay {
            if showCommandBar {
                CommandBarView(isPresented: $showCommandBar).environment(store)
            }
        }
        .overlay {
            if showFocusMode {
                FocusModeView(isPresented: $showFocusMode).environment(store)
            }
        }
        .onChange(of: store.commandToken) { _, _ in showCommandBar = true }
        .onChange(of: store.focusToken) { _, _ in showFocusMode = true }
        #else
        NavigationStack {
            ZStack {
                Color.bgCanvas.ignoresSafeArea()
                TaskListView()
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
        }
        #endif
    }
}

#Preview {
    ContentView().environment(TaskStore())
}
