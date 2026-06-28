import Foundation

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
