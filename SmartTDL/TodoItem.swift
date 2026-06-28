import Foundation
import CloudKit

/// How a task repeats. On completion the task regenerates on its next date.
enum Recurrence: Codable, Hashable {
    case daily
    case weekdays
    case weekly(Int)   // Calendar weekday 1...7
    case monthly

    var label: String {
        switch self {
        case .daily: "every day"
        case .weekdays: "every weekday"
        case .weekly: "weekly"
        case .monthly: "every month"
        }
    }

    /// The next occurrence strictly after `day`.
    func nextDate(after day: Date, calendar: Calendar = .current) -> Date {
        let start = calendar.startOfDay(for: day)
        switch self {
        case .daily:
            return calendar.date(byAdding: .day, value: 1, to: start) ?? start
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: start) ?? start
        case .weekdays:
            var d = calendar.date(byAdding: .day, value: 1, to: start) ?? start
            for _ in 0..<7 {
                let wd = calendar.component(.weekday, from: d)
                if wd != 1 && wd != 7 { return d }
                d = calendar.date(byAdding: .day, value: 1, to: d) ?? d
            }
            return d
        case .weekly(let target):
            var d = calendar.date(byAdding: .day, value: 1, to: start) ?? start
            for _ in 0..<7 {
                if calendar.component(.weekday, from: d) == target { return d }
                d = calendar.date(byAdding: .day, value: 1, to: d) ?? d
            }
            return calendar.date(byAdding: .day, value: 7, to: start) ?? start
        }
    }

    /// The first occurrence on or after `day`.
    func firstOccurrence(onOrAfter day: Date, calendar: Calendar = .current) -> Date {
        let start = calendar.startOfDay(for: day)
        switch self {
        case .daily, .monthly:
            return start
        case .weekdays:
            let wd = calendar.component(.weekday, from: start)
            return (wd != 1 && wd != 7) ? start : nextDate(after: start, calendar: calendar)
        case .weekly(let target):
            return calendar.component(.weekday, from: start) == target ? start : nextDate(after: start, calendar: calendar)
        }
    }
}

/// A single to-do, scheduled on a given day (TeuxDeux-style). Named `TodoItem`
/// (not `Task`) to avoid clashing with Swift Concurrency's `Task`.
struct TodoItem: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    var isCompleted: Bool = false
    var day: Date
    var sortIndex: Double
    var createdAt: Date = Date()
    /// Bumped on every user-meaningful content change (title, day, completion,
    /// pin, list, recurrence) — but NOT on importance/rank commits, which are
    /// local-only. Drives last-writer-wins sync. Defaults to `createdAt`.
    var modifiedAt: Date = Date()
    var importance: Double? = nil
    var isPinned: Bool = false
    var recurrence: Recurrence? = nil
    /// `nil` = a day-based task (scheduled, rolls forward, AI-ranked). A name =
    /// the task lives in an undated parking-lot list (Later/Misc/…) and `day` is
    /// ignored: it never rolls forward and isn't gravity-ranked.
    var list: String? = nil

    init(title: String, day: Date, sortIndex: Double, isCompleted: Bool = false,
         recurrence: Recurrence? = nil, list: String? = nil) {
        self.title = title
        self.day = Calendar.current.startOfDay(for: day)
        self.sortIndex = sortIndex
        self.isCompleted = isCompleted
        self.recurrence = recurrence
        self.list = list
        self.modifiedAt = self.createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id, title, isCompleted, day, sortIndex, createdAt, modifiedAt, importance, isPinned, recurrence, list
    }

    // Resilient decoding so older saved files (without pin/recurrence/list) still load.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try c.decode(String.self, forKey: .title)
        isCompleted = try c.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
        day = try c.decode(Date.self, forKey: .day)
        sortIndex = try c.decodeIfPresent(Double.self, forKey: .sortIndex) ?? 0
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        modifiedAt = try c.decodeIfPresent(Date.self, forKey: .modifiedAt) ?? createdAt
        importance = try c.decodeIfPresent(Double.self, forKey: .importance)
        isPinned = try c.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        recurrence = try c.decodeIfPresent(Recurrence.self, forKey: .recurrence)
        list = try c.decodeIfPresent(String.self, forKey: .list)
    }
}

// MARK: - CloudKit record mapping (sync — see docs/sync-plan.md §3)

/// One `Task` CKRecord per task, keyed by the task's `id`. `importance` is
/// intentionally NOT synced — it's local AI output computed per device. These are
/// pure, offline functions (a CKRecord is in-memory), so they're unit-testable
/// without an iCloud account; the `CKSyncEngine` that drives them is added once the
/// container exists. Co-located here (vs. a new file) to avoid a project-file change.
extension TodoItem {
    enum Sync {
        static let recordType = "Task"
        static let zoneName = "TasksZone"
        enum Key {
            static let title = "title"
            static let isCompleted = "isCompleted"
            static let day = "day"
            static let sortIndex = "sortIndex"
            static let createdAt = "createdAt"
            static let modifiedAt = "modifiedAt"
            static let isPinned = "isPinned"
            static let recurrence = "recurrence"   // Recurrence encoded as JSON
            static let list = "list"
        }
    }

    /// The stable record ID for this task in the given zone.
    func recordID(in zoneID: CKRecordZone.ID) -> CKRecord.ID {
        CKRecord.ID(recordName: id.uuidString, zoneID: zoneID)
    }

    /// Write this task's synced fields onto a record (a fresh one when creating, or
    /// the server's existing record when updating so its change tag is preserved).
    @discardableResult
    func populate(_ record: CKRecord) -> CKRecord {
        record[Sync.Key.title] = title
        record[Sync.Key.isCompleted] = Int64(isCompleted ? 1 : 0)
        record[Sync.Key.day] = day
        record[Sync.Key.sortIndex] = sortIndex
        record[Sync.Key.createdAt] = createdAt
        record[Sync.Key.modifiedAt] = modifiedAt
        record[Sync.Key.isPinned] = Int64(isPinned ? 1 : 0)
        if let r = Self.encodeRecurrence(recurrence) { record[Sync.Key.recurrence] = r }
        else { record[Sync.Key.recurrence] = nil }
        if let l = list { record[Sync.Key.list] = l } else { record[Sync.Key.list] = nil }
        // importance is deliberately omitted — local-only (sync-plan §3).
        return record
    }

    /// A new record for this task in the given zone.
    func makeRecord(in zoneID: CKRecordZone.ID) -> CKRecord {
        populate(CKRecord(recordType: Sync.recordType, recordID: recordID(in: zoneID)))
    }

    /// Reconstruct a task from a record. Returns nil for a wrong type or a record
    /// name that isn't a UUID. `importance` comes back nil (not synced).
    init?(record: CKRecord) {
        guard record.recordType == Sync.recordType,
              let uuid = UUID(uuidString: record.recordID.recordName) else { return nil }
        self.init(
            title: (record[Sync.Key.title] as? String) ?? "",
            day: (record[Sync.Key.day] as? Date) ?? Date(),
            sortIndex: (record[Sync.Key.sortIndex] as? Double) ?? 0,
            isCompleted: ((record[Sync.Key.isCompleted] as? Int64) ?? 0) != 0,
            recurrence: Self.decodeRecurrence(record[Sync.Key.recurrence] as? String),
            list: record[Sync.Key.list] as? String
        )
        self.id = uuid
        self.isPinned = ((record[Sync.Key.isPinned] as? Int64) ?? 0) != 0
        if let c = record[Sync.Key.createdAt] as? Date { self.createdAt = c }
        self.modifiedAt = (record[Sync.Key.modifiedAt] as? Date) ?? self.createdAt
    }

    static func encodeRecurrence(_ r: Recurrence?) -> String? {
        guard let r, let data = try? JSONEncoder().encode(r) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func decodeRecurrence(_ s: String?) -> Recurrence? {
        guard let s, let data = s.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(Recurrence.self, from: data)
    }
}
