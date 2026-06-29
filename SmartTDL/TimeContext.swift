import Foundation
import EventKit

/// The time-connection layer (pain #4): how much of today is actually free, fed as
/// a quiet line into the ranker's `context` so importance reflects the time the user
/// really has — never a loud time-block grid (PRD §7.4). The interval math here is
/// pure and unit-tested; the EventKit read is gated behind calendar authorization
/// and stays inert (the app behaves exactly as today) until the user grants access.
enum TimeContext {

    /// Free (unbusy) seconds within `window`, given busy intervals. Each busy
    /// interval is clamped to the window and overlaps are merged, so overlapping or
    /// out-of-window events never double-count.
    static func freeSeconds(in window: DateInterval, busy: [DateInterval]) -> TimeInterval {
        guard window.duration > 0 else { return 0 }
        let clamped: [DateInterval] = busy.compactMap { b in
            let s = max(b.start, window.start)
            let e = min(b.end, window.end)
            return e > s ? DateInterval(start: s, end: e) : nil
        }.sorted { $0.start < $1.start }

        var merged: [DateInterval] = []
        for iv in clamped {
            if let last = merged.last, iv.start <= last.end {
                merged[merged.count - 1] = DateInterval(start: last.start, end: max(last.end, iv.end))
            } else {
                merged.append(iv)
            }
        }
        let busyTotal = merged.reduce(0) { $0 + $1.duration }
        return max(0, window.duration - busyTotal)
    }

    /// The start of the next event strictly after `now`.
    static func nextEventStart(after now: Date, in events: [DateInterval]) -> Date? {
        events.map(\.start).filter { $0 > now }.min()
    }

    /// A quiet line for the ranker's `context`, or nil if there's nothing useful to
    /// say. Phrased as plain prose (no numbers on screen — this only ever reaches
    /// the model, never the UI).
    static func contextLine(freeSeconds: TimeInterval, nextEvent: Date?, calendar: Calendar = .current) -> String? {
        let hours = freeSeconds / 3600
        let half = (hours * 2).rounded() / 2   // nearest half hour
        var line: String
        if half < 0.5 {
            line = "The user has almost no free time left in the day."
        } else {
            let num = half == half.rounded() ? String(Int(half)) : String(format: "%.1f", half)
            line = "The user has about \(num) free hour\(half == 1 ? "" : "s") left in the day."
        }
        if let nextEvent {
            let f = DateFormatter()
            f.calendar = calendar
            f.timeStyle = .short
            f.dateStyle = .none
            line += " Their next commitment is at \(f.string(from: nextEvent))."
        }
        return line
    }
}

/// Reads today's remaining events via EventKit and produces the ambient context
/// line. Returns nil unless the user has granted calendar access — without it the
/// app stays exactly as today (local-first, no nags). Activation also needs an
/// Info.plist usage string (`INFOPLIST_KEY_NSCalendarsUsageDescription`); wire this
/// into `TaskStore`'s effective ranker context once that's added.
struct TimeContextProvider {
    private let store = EKEventStore()

    /// The ambient line for `now`, or nil if access isn't granted / nothing to say.
    func currentLine(now: Date = Date(), calendar: Calendar = .current) async -> String? {
        guard await hasAccess() else { return nil }
        let startOfDay = calendar.startOfDay(for: now)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay),
              endOfDay > now else { return nil }
        let predicate = store.predicateForEvents(withStart: now, end: endOfDay, calendars: nil)
        let events = store.events(matching: predicate)
            .filter { !$0.isAllDay }
            .map { DateInterval(start: $0.startDate, end: max($0.startDate, $0.endDate)) }
        let window = DateInterval(start: now, end: endOfDay)
        let free = TimeContext.freeSeconds(in: window, busy: events)
        let next = TimeContext.nextEventStart(after: now, in: events)
        return TimeContext.contextLine(freeSeconds: free, nextEvent: next, calendar: calendar)
    }

    private func hasAccess() async -> Bool {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess:
            return true
        case .notDetermined:
            return (try? await store.requestFullAccessToEvents()) ?? false
        default:
            return false
        }
    }
}
