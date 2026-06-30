import Foundation

/// The hand-off between a capture surface (the Share Extension today; a widget or
/// Shortcuts action later) and the app. An extension runs in its own process and can't
/// touch the app's store, so it appends raw captured strings to a small shared queue;
/// the app drains that queue into real tasks the next time it activates. This keeps
/// capture instant and the app the single writer of `tasks.json`.
///
/// Storage is the App Group `group.com.smarttdl` when it's provisioned (so the extension
/// and the app genuinely share it). It falls back to standard `UserDefaults` when the
/// group isn't set up yet — which keeps the drain logic fully testable today, before the
/// App Group capability (account-gated) exists. Injecting a throwaway suite makes each
/// test hermetic.
struct CaptureInbox {
    static let appGroup = "group.com.smarttdl"
    private static let key = "smarttdl.captureQueue"

    let defaults: UserDefaults

    /// Uses the shared App Group container when available, else standard defaults.
    init(defaults: UserDefaults? = nil) {
        self.defaults = defaults ?? UserDefaults(suiteName: Self.appGroup) ?? .standard
    }

    /// Append one captured string (called from the extension). Trimmed; blanks ignored.
    func enqueue(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var queue = defaults.stringArray(forKey: Self.key) ?? []
        queue.append(trimmed)
        defaults.set(queue, forKey: Self.key)
    }

    /// Remove and return everything queued (called by the app when it activates). Order
    /// preserved, so captures land in the order they were made.
    func drain() -> [String] {
        let queue = defaults.stringArray(forKey: Self.key) ?? []
        if !queue.isEmpty { defaults.removeObject(forKey: Self.key) }
        return queue
    }

    /// How many captures are waiting (without draining) — for a badge-free menu hint.
    var pendingCount: Int { (defaults.stringArray(forKey: Self.key) ?? []).count }
}
