import Foundation
import Security

/// Assigns an importance score (0...1) to each task. Implementations are
/// interchangeable: a local heuristic, or Claude Haiku over the network.
protocol Ranker: Sendable {
    func rank(_ tasks: [TodoItem], context: String) async throws -> [UUID: Double]
}

// MARK: - Local heuristic (always available, no network, no key)

struct HeuristicRanker: Ranker {
    private static let urgentWords = [
        "urgent", "asap", "today", "now", "deadline", "due", "pay", "call",
        "email", "send", "submit", "fix", "important", "review", "respond",
        "reply", "ship", "finish", "book", "schedule", "tax", "rent", "bill"
    ]

    func rank(_ tasks: [TodoItem], context: String) async throws -> [UUID: Double] {
        let today = Calendar.current.startOfDay(for: Date())
        var scores: [UUID: Double] = [:]
        for t in tasks {
            var s = 0.5
            let lower = t.title.lowercased()
            for word in Self.urgentWords where lower.contains(word) { s += 0.07 }
            // Sooner days matter more.
            let days = Calendar.current.dateComponents([.day], from: today, to: t.day).day ?? 0
            s += max(0, 0.2 - Double(days) * 0.03)
            scores[t.id] = min(1, max(0, s))
        }
        return scores
    }
}

// MARK: - Claude Haiku 4.5 ranker (raw Messages API; no Swift SDK exists)

struct HaikuRanker: Ranker {
    let apiKey: String
    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    func rank(_ tasks: [TodoItem], context: String) async throws -> [UUID: Double] {
        let list = tasks.enumerated()
            .map { "\($0.offset): \($0.element.title)" }
            .joined(separator: "\n")
        let contextBlock = context.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? ""
            : "\nWhat the user is currently working on:\n\(context)\n"

        let prompt = """
        You rank a person's to-do items by how important they are to do next.
        \(contextBlock)
        Tasks (one per line as `index: text`):
        \(list)

        Return ONLY a JSON object mapping each index (as a string key) to an \
        importance score between 0.0 (low) and 1.0 (high). No prose, no code \
        fences. Example: {"0": 0.9, "1": 0.3}
        """

        let body: [String: Any] = [
            "model": "claude-haiku-4-5",
            "max_tokens": 512,
            "messages": [["role": "user", "content": prompt]]
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw RankerError.http(String(data: data, encoding: .utf8) ?? "unknown error")
        }

        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let content = json["content"] as? [[String: Any]],
            let text = content.first(where: { ($0["type"] as? String) == "text" })?["text"] as? String
        else { throw RankerError.badResponse }

        let cleaned = Self.stripCodeFences(text)
        guard
            let scoreData = cleaned.data(using: .utf8),
            let raw = try? JSONSerialization.jsonObject(with: scoreData) as? [String: Any]
        else { throw RankerError.badResponse }

        var out: [UUID: Double] = [:]
        for t in tasks.enumerated() {
            if let n = raw[String(t.offset)] as? NSNumber {
                out[t.element.id] = min(1, max(0, n.doubleValue))
            }
        }
        return out
    }

    private static func stripCodeFences(_ s: String) -> String {
        var t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.hasPrefix("```") {
            t = t.replacingOccurrences(of: "```json", with: "")
                 .replacingOccurrences(of: "```", with: "")
                 .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return t
    }

    enum RankerError: Error { case http(String), badResponse }
}

// MARK: - Keychain (stores the user's Anthropic API key locally)

enum Keychain {
    private static let service = "com.smarttdl.SmartTDL"
    private static let account = "anthropic-api-key"
    private static let flagKey = "smarttdl.hasAPIKey"

    /// Cheap, prompt-free check for whether the user has saved a key. Reading the
    /// actual Keychain item can surface a system password prompt (especially when
    /// the app's signature changes between builds), so callers gate on this first
    /// and only touch the Keychain when a key is genuinely expected.
    static var hasKey: Bool { UserDefaults.standard.bool(forKey: flagKey) }

    /// The stored key. May prompt — only call when `hasKey` is true.
    static var apiKey: String? { read() }

    static func set(_ value: String?) {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmed, !trimmed.isEmpty {
            write(trimmed)
            UserDefaults.standard.set(true, forKey: flagKey)
        } else {
            remove()
            UserDefaults.standard.set(false, forKey: flagKey)
        }
    }

    private static func read() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8) else { return nil }
        return value
    }

    private static func write(_ value: String) {
        remove()
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
            kSecValueData as String: Data(value.utf8)
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    private static func remove() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Context connectors ("connect everything" — PRD §7.5)

/// A source of ambient context for the ranker. Connectors are INPUTS (calendar,
/// later Gmail, etc.); the auto-sort is the only OUTPUT — they never add UI. Each
/// returns a short prose fragment, or nil when it has nothing to say (or no access).
protocol ContextConnector {
    func fragment() async -> String?
}

/// Composes the ranker's effective context: the user's own note first, then every
/// connector's fragment. Pure string composition (blank fragments dropped) — this is
/// the single seam that absorbs unlimited context without touching the ranking path.
struct ContextAggregator {
    let connectors: [ContextConnector]

    func compose(userContext: String) async -> String {
        var parts: [String] = []
        let user = userContext.trimmingCharacters(in: .whitespacesAndNewlines)
        if !user.isEmpty { parts.append(user) }
        for connector in connectors {
            if let raw = await connector.fragment() {
                let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { parts.append(trimmed) }
            }
        }
        return parts.joined(separator: "\n")
    }
}

// MARK: - Gmail connector (PRD §7.5 — email as a context input)

/// A minimal, provider-agnostic view of what the inbox contributes to ranking context.
/// Deliberately tiny: connectors are *inputs* to the sort, never inbox UI, so we only
/// surface the couple of signals that change what matters next.
struct InboxSnapshot: Sendable, Equatable {
    /// Roughly how many messages look like they're waiting on the user to reply.
    var awaitingReply: Int
    /// A salient sender/subject worth naming, if any (e.g. "Dana about the contract").
    var highlight: String?
}

/// Anything that can read an `InboxSnapshot`. Returns nil when unavailable — no account,
/// no access, or offline — so the connector simply stays quiet.
protocol InboxReading: Sendable {
    func snapshot() async -> InboxSnapshot?
}

/// Turns inbox state into one quiet prose line for the ranker. The reader is injected so
/// the prose composition is unit-testable today; the production reader (`GmailInbox`) is
/// inert until OAuth is configured, so this connector contributes nothing until then —
/// exactly like the calendar connector before access is granted.
struct GmailConnector: ContextConnector {
    let reader: InboxReading

    func fragment() async -> String? {
        guard let snapshot = await reader.snapshot() else { return nil }
        return Self.line(for: snapshot)
    }

    /// Pure prose composition — nil when there's nothing worth saying. No raw inbox
    /// counts as pressure beyond the gentle "waiting on a reply" framing.
    static func line(for snapshot: InboxSnapshot) -> String? {
        guard snapshot.awaitingReply > 0 || snapshot.highlight != nil else { return nil }
        var parts: [String] = []
        switch snapshot.awaitingReply {
        case 0:        break
        case 1:        parts.append("One email is waiting on a reply")
        case let n:    parts.append("\(n) emails are waiting on a reply")
        }
        if let highlight = snapshot.highlight {
            parts.append(parts.isEmpty ? "An email about \(highlight) may need attention"
                                       : "including \(highlight)")
        }
        return parts.joined(separator: ", ") + "."
    }
}

/// The production inbox source. INACTIVE until Gmail OAuth is configured: it returns nil,
/// so `GmailConnector` says nothing and the app is unaffected. To activate, supply a
/// Google Cloud OAuth client (id + secret + redirect), authenticate, and replace the
/// body with a Gmail API read that maps inbox threads → `InboxSnapshot`.
struct GmailInbox: InboxReading {
    func snapshot() async -> InboxSnapshot? {
        // TODO(oauth): authenticate via Google OAuth; query the Gmail API for inbox
        // threads awaiting reply; map to InboxSnapshot. Silent until then.
        nil
    }
}
