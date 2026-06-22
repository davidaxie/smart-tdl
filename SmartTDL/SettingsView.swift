import SwiftUI

struct SettingsView: View {
    @Environment(TaskStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var key: String = Keychain.apiKey ?? ""
    @State private var context: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("sk-ant-…", text: $key)
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        #endif
                } header: {
                    Text("Claude API key")
                } footer: {
                    Text("Stored only in your device Keychain. Powers Haiku ranking, so your most important tasks rise to the top automatically. Without a key, a local heuristic is used instead.")
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
        Keychain.set(key)
        store.updateContext(context)
        store.refreshRanker()
        dismiss()
    }
}
