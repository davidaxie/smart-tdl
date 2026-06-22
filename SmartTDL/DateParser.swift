import Foundation

/// Lightweight natural-language day capture. Typing "call Sam friday" routes the
/// task to Friday and strips the token from the title. Predictable, hand-rolled
/// weekday map (no surprises), so the task visibly lands in its day.
enum DateParser {
    /// Returns the cleaned title and an optional target day.
    static func parse(_ raw: String, reference: Date, calendar: Calendar = .current) -> (title: String, day: Date?) {
        let today = calendar.startOfDay(for: Date())
        let tokens = raw.split(separator: " ").map(String.init)
        guard !tokens.isEmpty else { return (raw, nil) }

        // "… in N days"
        if tokens.count >= 4 {
            let tail = tokens.suffix(3).map { $0.lowercased() }
            if tail[0] == "in", tail[2].hasPrefix("day"), let n = Int(tail[1]), n >= 0, n <= 60 {
                let title = tokens.dropLast(3).joined(separator: " ")
                if !title.isEmpty {
                    return (title, calendar.date(byAdding: .day, value: n, to: today))
                }
            }
        }

        // "… next <weekday>"
        if tokens.count >= 3 {
            let tail = tokens.suffix(2).map { $0.lowercased() }
            if tail[0] == "next", let wd = weekday(tail[1]) {
                let title = tokens.dropLast(2).joined(separator: " ")
                if !title.isEmpty {
                    return (title, nextWeekday(wd, after: today, calendar: calendar))
                }
            }
        }

        // "… <today|tonight|tomorrow|weekday>"
        if tokens.count >= 2, let day = resolveSingle(tokens[tokens.count - 1].lowercased(), today: today, calendar: calendar) {
            let title = tokens.dropLast().joined(separator: " ")
            if !title.isEmpty { return (title, day) }
        }

        return (raw, nil)
    }

    /// Detects "every …" recurrence. Returns the cleaned title, the recurrence,
    /// and the first day it should appear on.
    static func parseRecurrence(_ raw: String, calendar: Calendar = .current) -> (title: String, recurrence: Recurrence?, day: Date?) {
        let today = calendar.startOfDay(for: Date())
        var tokens = raw.split(separator: " ").map(String.init)
        guard let idx = tokens.firstIndex(where: { $0.lowercased() == "every" }), idx + 1 < tokens.count else {
            return (raw, nil, nil)
        }
        let kw = tokens[idx + 1].lowercased()
        var rec: Recurrence?
        switch kw {
        case "day", "daily":
            rec = .daily
        case "weekday", "weekdays":
            rec = .weekdays
        case "week", "weekly":
            rec = .weekly(calendar.component(.weekday, from: today))
        case "month", "monthly":
            rec = .monthly
        default:
            if let wd = weekday(kw) { rec = .weekly(wd) }
        }
        guard let rec else { return (raw, nil, nil) }
        tokens.removeSubrange(idx...(idx + 1))
        let title = tokens.joined(separator: " ").trimmingCharacters(in: .whitespaces)
        return (title.isEmpty ? raw : title, rec, rec.firstOccurrence(onOrAfter: today, calendar: calendar))
    }

    private static func resolveSingle(_ token: String, today: Date, calendar: Calendar) -> Date? {
        switch token {
        case "today", "tonight":
            return today
        case "tomorrow", "tmrw", "tmr":
            return calendar.date(byAdding: .day, value: 1, to: today)
        default:
            if let wd = weekday(token) { return nextWeekday(wd, after: today, calendar: calendar) }
            return nil
        }
    }

    private static func weekday(_ s: String) -> Int? {
        // Calendar weekday: 1 = Sunday … 7 = Saturday
        [
            "sunday": 1, "sun": 1,
            "monday": 2, "mon": 2,
            "tuesday": 3, "tue": 3, "tues": 3,
            "wednesday": 4, "wed": 4,
            "thursday": 5, "thu": 5, "thur": 5, "thurs": 5,
            "friday": 6, "fri": 6,
            "saturday": 7, "sat": 7,
        ][s]
    }

    private static func nextWeekday(_ target: Int, after start: Date, calendar: Calendar) -> Date {
        var d = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        for _ in 0..<7 {
            if calendar.component(.weekday, from: d) == target { return d }
            d = calendar.date(byAdding: .day, value: 1, to: d) ?? d
        }
        return start
    }
}
