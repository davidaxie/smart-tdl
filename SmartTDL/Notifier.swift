import Foundation
#if canImport(UserNotifications)
import UserNotifications
#endif

/// The daily ritual nudge (PRD §7.6): exactly ONE calm notification a day inviting
/// the user to glance at their day — never a red badge, never a per-task pile of
/// alerts. Guilt-free by construction: the badge is always cleared, and rescheduling
/// reuses one stable identifier so it overwrites the pending nudge instead of stacking.
///
/// The scheduling math and the copy live here as pure, unit-tested functions. The
/// `UNUserNotificationCenter` calls are isolated in `Notifier` (below) and gated behind
/// an authorization the user grants explicitly, so nothing fires — and no permission
/// prompt appears — until opt-in. Until then the app behaves exactly as today.
enum DailyRitual {
    /// The stable identifier for the one-and-only ritual request. Reusing it means a
    /// reschedule overwrites the pending notification rather than adding another — the
    /// structural guarantee behind "one nudge, never a pile."
    static let requestIdentifier = "smarttdl.dailyRitual"

    /// The next moment at or after `now` matching the preferred time of day. If today's
    /// time has already passed, this rolls to tomorrow — we never schedule into the
    /// past. `.nextTime` advances cleanly across DST gaps. Returns nil only if the
    /// components can't be matched (never, for a plain hour/minute).
    static func nextFireDate(preferred: DateComponents, after now: Date,
                             calendar: Calendar = .current) -> Date? {
        calendar.nextDate(after: now, matching: preferred, matchingPolicy: .nextTime)
    }

    /// Normalize a chosen hour/minute into the components a repeating calendar trigger
    /// wants: hour + minute only (so it fires daily), seconds pinned to 0.
    static func dailyComponents(hour: Int, minute: Int) -> DateComponents {
        DateComponents(hour: hour, minute: minute, second: 0)
    }

    /// The gentle body for the nudge. It leads with the single most important task so
    /// the invitation is concrete, not a guilt-inducing tally. It never renders a bare
    /// count as pressure — zero is framed as open space, not failure (the badge problem,
    /// inverted). `topTitle` is the title of the day's #1 open task, if any.
    static func body(openCount: Int, topTitle: String?) -> String {
        switch (openCount, topTitle) {
        case (0, _):
            return "A clear day. Add what matters when you’re ready."
        case (1, let title?):
            return "One thing today: \(title)."
        case (_, let title?):
            return "Today starts with: \(title)."
        default:
            // Tasks exist but no title resolved — still no number on screen.
            return "A moment to set up your day."
        }
    }
}

#if canImport(UserNotifications)
/// Thin wrapper over `UNUserNotificationCenter` for the single daily ritual. Every
/// scheduling path is a no-op unless the user has already authorized, so it's safe to
/// call on launch without surfacing a prompt — requesting access is a deliberate opt-in
/// (`requestAccess`), mirroring `TimeContextProvider`.
struct Notifier {
    let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) { self.center = center }

    /// Non-prompting check — true only if the user has ALREADY authorized notifications.
    func isAuthorized() async -> Bool {
        await center.notificationSettings().authorizationStatus == .authorized
    }

    /// Explicitly request notification access. `.badge` is intentionally omitted — we
    /// never set a badge, so we never ask for the right to. Call from a user opt-in.
    func requestAccess() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    /// (Re)schedule the single daily ritual at `preferred` time. No-op unless already
    /// authorized. Removing-by-identifier before adding guarantees at most one pending
    /// ritual ever exists.
    func scheduleDailyRitual(preferred: DateComponents, openCount: Int, topTitle: String?) async {
        guard await isAuthorized() else { return }
        let content = UNMutableNotificationContent()
        content.title = "Smart TDL"
        content.body = DailyRitual.body(openCount: openCount, topTitle: topTitle)
        content.sound = .default
        content.badge = nil   // never a badge — the guilt-free guarantee

        let trigger = UNCalendarNotificationTrigger(dateMatching: preferred, repeats: true)
        let request = UNNotificationRequest(
            identifier: DailyRitual.requestIdentifier, content: content, trigger: trigger)

        center.removePendingNotificationRequests(withIdentifiers: [DailyRitual.requestIdentifier])
        try? await center.add(request)
    }

    /// Tear down the ritual and clear anything already delivered — leaving zero trace
    /// (and, crucially, zero badge) when the user turns it off.
    func cancelDailyRitual() {
        center.removePendingNotificationRequests(withIdentifiers: [DailyRitual.requestIdentifier])
        center.removeDeliveredNotifications(withIdentifiers: [DailyRitual.requestIdentifier])
    }
}
#endif
