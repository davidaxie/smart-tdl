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
