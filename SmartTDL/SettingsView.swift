import SwiftUI

struct SettingsView: View {
    @Environment(TaskStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    // Never pre-read the Keychain (that can trigger a system prompt). Start
    // empty; an empty field on save means "keep the existing key".
    @State private var key: String = ""
    @State private var context: String = ""
    @State private var hasKey: Bool = Keychain.hasKey

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField(hasKey ? "Enter a new key to replace" : "sk-ant-…", text: $key)
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        #endif
                    if hasKey {
                        Button("Remove key", role: .destructive) {
                            Keychain.set(nil)
                            key = ""
                            hasKey = false
                            store.refreshRanker()
                        }
                    }
                } header: {
                    Text("Claude API key")
                } footer: {
                    Text(hasKey
                         ? "A key is saved in your device Keychain — Haiku is ranking your tasks. Leave the field blank to keep it, or enter a new key to replace it."
                         : "Stored only in your device Keychain. Powers Haiku ranking, so your most important tasks rise to the top automatically. Without a key, a local heuristic is used instead.")
                }

                Section {
                    TextField("What are you working on?", text: $context, axis: .vertical)
                        .lineLimit(2...5)
                } header: {
                    Text("Context")
                } footer: {
                    Text("A short note about your current focus. The ranking uses it to understand what matters right now.")
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .onAppear { context = store.context }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: saveAndDismiss)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 440, minHeight: 380)
        #endif
    }

    private func saveAndDismiss() {
        // Only write when the user actually entered a key; an empty field keeps
        // any existing key rather than clearing it (use "Remove key" to clear).
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { Keychain.set(trimmed) }
        store.updateContext(context)
        store.refreshRanker()
        dismiss()
    }
}
