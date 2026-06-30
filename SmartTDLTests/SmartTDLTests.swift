import XCTest
import CloudKit
@testable import SmartTDL

// MARK: - The ordering rule (TaskStore.order)
// completed sink → pinned first → importance desc (unranked = -1, last) → sortIndex.
// This is the single invariant that drives what the user sees at the top of every day.

@MainActor
final class OrderingTests: XCTestCase {
    private func task(_ title: String, importance: Double? = nil, pinned: Bool = false,
                      completed: Bool = false, sortIndex: Double = 0) -> TodoItem {
        var t = TodoItem(title: title, day: Date(), sortIndex: sortIndex, isCompleted: completed)
        t.importance = importance
        t.isPinned = pinned
        return t
    }

    func testOpenSortsBeforeCompleted() {
        let open = task("open")
        let done = task("done", completed: true)
        XCTAssertTrue(TaskStore.order(open, done))
        XCTAssertFalse(TaskStore.order(done, open))
    }

    func testPinnedBeatsHigherImportance() {
        let pinnedLow = task("pinned", importance: 0.1, pinned: true)
        let unpinnedHigh = task("unpinned", importance: 0.9)
        XCTAssertTrue(TaskStore.order(pinnedLow, unpinnedHigh),
                      "a pinned task sorts first regardless of AI importance")
    }

    func testHigherImportanceFirstAmongUnpinned() {
        let high = task("high", importance: 0.8)
        let low = task("low", importance: 0.2)
        XCTAssertTrue(TaskStore.order(high, low))
        XCTAssertFalse(TaskStore.order(low, high))
    }

    func testUnrankedSortsLast() {
        let ranked = task("ranked", importance: 0.5)
        let unranked = task("unranked", importance: nil)
        XCTAssertTrue(TaskStore.order(ranked, unranked),
                      "an unranked task (treated as -1) sorts after any ranked task")
    }

    func testTieBreaksOnSortIndex() {
        let a = task("a", importance: 0.5, sortIndex: 1)
        let b = task("b", importance: 0.5, sortIndex: 2)
        XCTAssertTrue(TaskStore.order(a, b))
        XCTAssertFalse(TaskStore.order(b, a))
    }
}

// MARK: - Recurrence date math

final class RecurrenceTests: XCTestCase {
    private var cal: Calendar { Calendar(identifier: .gregorian) }
    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d))!
    }

    func testDailyNext() {
        let next = Recurrence.daily.nextDate(after: date(2026, 6, 28), calendar: cal)
        XCTAssertEqual(cal.startOfDay(for: next), date(2026, 6, 29))
    }

    func testMonthlyNext() {
        let next = Recurrence.monthly.nextDate(after: date(2026, 1, 15), calendar: cal)
        XCTAssertEqual(cal.startOfDay(for: next), date(2026, 2, 15))
    }

    func testWeekdaysSkipsTheWeekend() {
        let friday = date(2026, 6, 26)
        XCTAssertEqual(cal.component(.weekday, from: friday), 6, "sanity: 2026-06-26 is a Friday")
        let next = Recurrence.weekdays.nextDate(after: friday, calendar: cal)
        XCTAssertEqual(cal.startOfDay(for: next), date(2026, 6, 29), "Friday → next weekday is Monday")
    }

    func testWeeklyLandsOnTargetWeekday() {
        // weekly(target weekday 4 = Wednesday). After Mon 2026-06-29 → Wed 2026-07-01.
        let monday = date(2026, 6, 29)
        let next = Recurrence.weekly(4).nextDate(after: monday, calendar: cal)
        XCTAssertEqual(cal.component(.weekday, from: next), 4)
        XCTAssertEqual(cal.startOfDay(for: next), date(2026, 7, 1))
    }

    func testFirstWeekdayOccurrenceFromWeekendMovesForward() {
        let saturday = date(2026, 6, 27)
        let first = Recurrence.weekdays.firstOccurrence(onOrAfter: saturday, calendar: cal)
        XCTAssertEqual(cal.startOfDay(for: first), date(2026, 6, 29), "Saturday → Monday")
    }

    func testFirstDailyOccurrenceIsSameDay() {
        let d = date(2026, 6, 27)
        let first = Recurrence.daily.firstOccurrence(onOrAfter: d, calendar: cal)
        XCTAssertEqual(cal.startOfDay(for: first), d)
    }
}

// MARK: - Codable resilience (never break old saved files)

final class CodableResilienceTests: XCTestCase {
    func testDecodesLegacyJSONMissingNewerFields() throws {
        // An old tasks.json entry written before importance/isPinned/recurrence/list existed.
        let json = Data("""
        {"id":"7E0F0E2A-0000-0000-0000-000000000001","title":"Legacy task","isCompleted":false,"day":0,"sortIndex":3}
        """.utf8)
        let item = try JSONDecoder().decode(TodoItem.self, from: json)
        XCTAssertEqual(item.title, "Legacy task")
        XCTAssertEqual(item.sortIndex, 3)
        XCTAssertNil(item.importance)
        XCTAssertFalse(item.isPinned)
        XCTAssertNil(item.recurrence)
        XCTAssertNil(item.list)
    }

    func testRoundTripsAllFields() throws {
        var t = TodoItem(title: "Round trip", day: Date(), sortIndex: 2, recurrence: .weekdays, list: "Later")
        t.importance = 0.7
        t.isPinned = true
        let data = try JSONEncoder().encode(t)
        let back = try JSONDecoder().decode(TodoItem.self, from: data)
        XCTAssertEqual(back.id, t.id)
        XCTAssertEqual(back.title, t.title)
        XCTAssertEqual(back.importance, 0.7)
        XCTAssertTrue(back.isPinned)
        XCTAssertEqual(back.recurrence, .weekdays)
        XCTAssertEqual(back.list, "Later")
    }

    func testDecodesMissingIDByGeneratingOne() throws {
        let json = Data("""
        {"title":"No id","isCompleted":false,"day":0,"sortIndex":1}
        """.utf8)
        let item = try JSONDecoder().decode(TodoItem.self, from: json)
        XCTAssertEqual(item.title, "No id")   // a fresh UUID is generated, no throw
    }
}

// MARK: - The trust invariant: never reorder under the hand (P5) + honest-confidence (P6)

@MainActor
final class TrustTests: XCTestCase {
    private var today: Date { Calendar.current.startOfDay(for: Date()) }

    /// AC-T-4: committing buffered scores is a no-op while any row is being touched,
    /// and it applies the moment nothing is being interacted with.
    func testCommitIsNoOpWhileInteracting() {
        let a = TodoItem(title: "A", day: today, sortIndex: 1)
        let b = TodoItem(title: "B", day: today, sortIndex: 2)
        let store = TaskStore(testItems: [a, b])

        store.setInteracting(a.id, true)
        store._testSetPendingScores([a.id: 0.9, b.id: 0.1])
        store.commitPendingRank()   // a row is being touched → must NOT apply

        XCTAssertNil(store.item(a.id)?.importance, "scores must not commit while interacting")
        XCTAssertNil(store.item(b.id)?.importance)

        store.setInteracting(a.id, false)   // interacting empties → auto-commit
        XCTAssertEqual(store.item(a.id)?.importance, 0.9, "scores commit once nothing is touched")
        XCTAssertEqual(store.item(b.id)?.importance, 0.1)
    }

    /// P6: the honest-confidence hedge only fires with a real AI ranker AND close scores.
    func testClusteredOnlyWithAIAndCloseScores() {
        var a = TodoItem(title: "A", day: today, sortIndex: 1)
        var b = TodoItem(title: "B", day: today, sortIndex: 2)
        a.importance = 0.50
        b.importance = 0.48   // 0.02 apart, within the 0.06 threshold
        let store = TaskStore(testItems: [a, b])

        XCTAssertFalse(store.topScoresClustered(on: today), "no hedge without a real AI ranker")
        store._testSetUsingAI(true)
        XCTAssertTrue(store.topScoresClustered(on: today), "0.02 apart → clustered")
    }

    func testNotClusteredWhenTopScoresAreSeparated() {
        var a = TodoItem(title: "A", day: today, sortIndex: 1)
        var b = TodoItem(title: "B", day: today, sortIndex: 2)
        a.importance = 0.90
        b.importance = 0.20   // a clear #1
        let store = TaskStore(testItems: [a, b])
        store._testSetUsingAI(true)
        XCTAssertFalse(store.topScoresClustered(on: today), "0.70 apart → a confident crown")
    }
}

// MARK: - Stress: the model stays cheap and correct at 500 tasks (PRD §9.3)

@MainActor
final class StressTests: XCTestCase {
    private func make500() -> [TodoItem] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (0..<500).map { i in
            let day = cal.date(byAdding: .day, value: i % 7, to: today) ?? today
            var t = TodoItem(title: "Task \(i)", day: day, sortIndex: Double(i),
                             isCompleted: i % 5 == 0)
            t.importance = Double(i % 97) / 97.0
            return t
        }
    }

    /// The board re-runs these per-lane queries on every render; they must stay cheap.
    func testVisibleWindowQueriesAreCheapAt500() {
        let store = TaskStore(testItems: make500())
        measure {
            for day in store.visibleDays {
                _ = store.openTasks(on: day)
                _ = store.completedTasks(on: day)
            }
        }
    }

    /// The ordering rule stays internally consistent across a large set.
    func testOrderingIsConsistentAt500() {
        let store = TaskStore(testItems: make500())
        let today = Calendar.current.startOfDay(for: Date())
        let open = store.openTasks(on: today)
        XCTAssertGreaterThan(open.count, 1)
        for i in 1..<open.count {
            XCTAssertFalse(TaskStore.order(open[i], open[i - 1]),
                           "sorted output must never have a later item rank before an earlier one")
        }
    }
}

// MARK: - modifiedAt: the last-writer-wins sync timestamp (docs/sync-plan.md §4)

@MainActor
final class ModifiedAtTests: XCTestCase {
    private var today: Date { Calendar.current.startOfDay(for: Date()) }

    func testLegacyFileBackfillsModifiedAtFromCreatedAt() throws {
        // Old tasks.json has createdAt but no modifiedAt.
        let json = Data("""
        {"id":"7E0F0E2A-0000-0000-0000-000000000002","title":"Old","isCompleted":false,"day":0,"sortIndex":1,"createdAt":12345}
        """.utf8)
        let item = try JSONDecoder().decode(TodoItem.self, from: json)
        XCTAssertEqual(item.modifiedAt, item.createdAt, "missing modifiedAt back-fills from createdAt")
    }

    func testNewItemModifiedAtEqualsCreatedAt() {
        let t = TodoItem(title: "New", day: today, sortIndex: 1)
        XCTAssertEqual(t.modifiedAt, t.createdAt)
    }

    func testContentMutationBumpsModifiedAt() {
        var t = TodoItem(title: "A", day: today, sortIndex: 1)
        t.modifiedAt = Date(timeIntervalSinceNow: -3600)   // an hour ago
        let store = TaskStore(testItems: [t])
        let before = store.item(t.id)!.modifiedAt
        store.togglePin(store.item(t.id)!)
        XCTAssertGreaterThan(store.item(t.id)!.modifiedAt, before, "a content change must bump modifiedAt")
    }

    func testRankCommitDoesNotBumpModifiedAt() {
        var t = TodoItem(title: "A", day: today, sortIndex: 1)
        t.modifiedAt = Date(timeIntervalSinceNow: -3600)
        let store = TaskStore(testItems: [t])
        let before = store.item(t.id)!.modifiedAt
        store._testSetPendingScores([t.id: 0.9])
        store.commitPendingRank()
        XCTAssertEqual(store.item(t.id)?.importance, 0.9, "importance is applied")
        XCTAssertEqual(store.item(t.id)!.modifiedAt, before,
                       "an importance/rank commit must NOT bump modifiedAt (importance is local, not synced)")
    }
}

// MARK: - TodoItem <-> CKRecord mapping (docs/sync-plan.md §3)

final class CloudKitMappingTests: XCTestCase {
    private let zoneID = CKRecordZone.ID(zoneName: TodoItem.Sync.zoneName, ownerName: CKCurrentUserDefaultName)
    private var today: Date { Calendar.current.startOfDay(for: Date()) }

    func testRecordTypeAndNameAreStable() {
        let t = TodoItem(title: "x", day: today, sortIndex: 1)
        let record = t.makeRecord(in: zoneID)
        XCTAssertEqual(record.recordType, "Task")
        XCTAssertEqual(record.recordID.recordName, t.id.uuidString, "record name must be the task id")
    }

    func testRoundTripPreservesSyncedFields() throws {
        var t = TodoItem(title: "Email Dana", day: today, sortIndex: 3, recurrence: .weekdays, list: nil)
        t.isPinned = true
        t.importance = 0.8                       // local-only — must NOT survive
        t.modifiedAt = Date(timeIntervalSinceNow: -120)

        let back = try XCTUnwrap(TodoItem(record: t.makeRecord(in: zoneID)))

        XCTAssertEqual(back.id, t.id)
        XCTAssertEqual(back.title, t.title)
        XCTAssertEqual(back.day, t.day)
        XCTAssertEqual(back.sortIndex, t.sortIndex)
        XCTAssertEqual(back.isCompleted, t.isCompleted)
        XCTAssertTrue(back.isPinned)
        XCTAssertEqual(back.recurrence, .weekdays)
        XCTAssertNil(back.list)
        XCTAssertEqual(back.createdAt, t.createdAt)
        XCTAssertEqual(back.modifiedAt, t.modifiedAt)
        XCTAssertNil(back.importance, "importance must not round-trip through CloudKit (local-only)")
    }

    func testParkingLotTaskRoundTrips() throws {
        let t = TodoItem(title: "Plan offsite", day: today, sortIndex: 1, list: "Later")
        let back = try XCTUnwrap(TodoItem(record: t.makeRecord(in: zoneID)))
        XCTAssertEqual(back.list, "Later")
        XCTAssertNil(back.recurrence)
    }

    func testInitRejectsWrongTypeAndNonUUIDName() {
        let wrongType = CKRecord(recordType: "NotATask",
                                 recordID: CKRecord.ID(recordName: UUID().uuidString, zoneID: zoneID))
        XCTAssertNil(TodoItem(record: wrongType))

        let badName = CKRecord(recordType: "Task",
                               recordID: CKRecord.ID(recordName: "not-a-uuid", zoneID: zoneID))
        XCTAssertNil(TodoItem(record: badName))
    }
}

// MARK: - Remote sync merges: LWW + local-importance preservation + safe-moment (P5)

@MainActor
final class RemoteMergeTests: XCTestCase {
    private var today: Date { Calendar.current.startOfDay(for: Date()) }

    func testNewerRemoteWinsAndPreservesLocalImportance() {
        var local = TodoItem(title: "A", day: today, sortIndex: 1)
        local.modifiedAt = Date(timeIntervalSinceNow: -100)
        local.importance = 0.7
        let store = TaskStore(testItems: [local])

        var remote = local
        remote.title = "A edited on another device"
        remote.importance = nil                 // came from CloudKit (importance not synced)
        remote.modifiedAt = Date()              // newer
        store.applyRemoteChanges(upserts: [remote])

        XCTAssertEqual(store.item(local.id)?.title, "A edited on another device", "newer remote wins (LWW)")
        XCTAssertEqual(store.item(local.id)?.importance, 0.7, "local importance is preserved")
    }

    func testOlderRemoteIsIgnored() {
        var local = TodoItem(title: "A", day: today, sortIndex: 1)
        local.modifiedAt = Date()
        let store = TaskStore(testItems: [local])

        var remote = local
        remote.title = "stale"
        remote.modifiedAt = Date(timeIntervalSinceNow: -100)   // older
        store.applyRemoteChanges(upserts: [remote])

        XCTAssertEqual(store.item(local.id)?.title, "A", "older remote loses (LWW)")
    }

    func testRemoteUpsertForNewIDAppends() {
        let store = TaskStore(testItems: [])
        let remote = TodoItem(title: "from the phone", day: today, sortIndex: 1)
        store.applyRemoteChanges(upserts: [remote])
        XCTAssertEqual(store.item(remote.id)?.title, "from the phone")
    }

    func testRemoteDeletionRemovesTask() {
        let local = TodoItem(title: "A", day: today, sortIndex: 1)
        let store = TaskStore(testItems: [local])
        store.applyRemoteChanges(deletions: [local.id])
        XCTAssertNil(store.item(local.id))
    }

    func testRemoteChangesBufferWhileInteracting() {
        var local = TodoItem(title: "A", day: today, sortIndex: 1)
        local.modifiedAt = Date(timeIntervalSinceNow: -100)
        let store = TaskStore(testItems: [local])

        store.setInteracting(local.id, true)
        var remote = local
        remote.title = "edited"
        remote.modifiedAt = Date()
        store.applyRemoteChanges(upserts: [remote])
        XCTAssertEqual(store.item(local.id)?.title, "A", "a remote change must not apply under the hand (P5)")

        store.setInteracting(local.id, false)   // safe moment → flush
        XCTAssertEqual(store.item(local.id)?.title, "edited", "buffered remote change applies once interaction ends")
    }
}

// MARK: - TimeContext: free-time interval math (pain #4, PRD §7.4)

final class TimeContextTests: XCTestCase {
    private let base = Date(timeIntervalSinceReferenceDate: 0)
    private func iv(_ startHour: Double, _ endHour: Double) -> DateInterval {
        DateInterval(start: base.addingTimeInterval(startHour * 3600), end: base.addingTimeInterval(endHour * 3600))
    }
    private func window(_ startHour: Double, _ endHour: Double) -> DateInterval { iv(startHour, endHour) }

    func testNoBusyMeansWholeWindowFree() {
        XCTAssertEqual(TimeContext.freeSeconds(in: window(0, 8), busy: []), 8 * 3600, accuracy: 1)
    }

    func testBusyTimeIsSubtracted() {
        let busy = [iv(1, 2), iv(3, 4)]   // 2h busy in an 8h window
        XCTAssertEqual(TimeContext.freeSeconds(in: window(0, 8), busy: busy), 6 * 3600, accuracy: 1)
    }

    func testOverlappingBusyIntervalsMerge() {
        let busy = [iv(1, 3), iv(2, 4)]   // overlap → busy 1–4 = 3h, not 4h
        XCTAssertEqual(TimeContext.freeSeconds(in: window(0, 8), busy: busy), 5 * 3600, accuracy: 1)
    }

    func testBusyClampedToWindow() {
        let busy = [iv(0, 3)]             // 0–3 clamped to a 2–6 window = 1h busy
        XCTAssertEqual(TimeContext.freeSeconds(in: window(2, 6), busy: busy), 3 * 3600, accuracy: 1)
    }

    func testFullyBookedIsZero() {
        let busy = [iv(-1, 5)]            // covers the whole 0–4 window
        XCTAssertEqual(TimeContext.freeSeconds(in: window(0, 4), busy: busy), 0, accuracy: 1)
    }

    func testNextEventStart() {
        let events = [iv(2, 3), iv(5, 6)]
        XCTAssertEqual(TimeContext.nextEventStart(after: base.addingTimeInterval(3600), in: events),
                       base.addingTimeInterval(2 * 3600))
        XCTAssertNil(TimeContext.nextEventStart(after: base.addingTimeInterval(7 * 3600), in: events))
    }

    func testContextLinePhrasing() {
        XCTAssertEqual(TimeContext.contextLine(freeSeconds: 0, nextEvent: nil)?.contains("almost no free time"), true)
        XCTAssertEqual(TimeContext.contextLine(freeSeconds: 2 * 3600, nextEvent: nil)?.contains("2 free hours"), true)
        XCTAssertEqual(TimeContext.contextLine(freeSeconds: 2.5 * 3600, nextEvent: nil)?.contains("2.5 free hours"), true)
        let one = TimeContext.contextLine(freeSeconds: 3600, nextEvent: nil)
        XCTAssertEqual(one?.contains("1 free hour "), true, "singular phrasing")
        XCTAssertEqual(one?.contains("1 free hours"), false)
    }
}

// MARK: - ContextAggregator: composing the ranker's context from connectors (PRD §7.5)

final class ContextAggregatorTests: XCTestCase {
    private struct Stub: ContextConnector {
        let value: String?
        func fragment() async -> String? { value }
    }

    func testComposesUserContextThenFragments() async {
        let agg = ContextAggregator(connectors: [Stub(value: "About 2 free hours left."),
                                                 Stub(value: nil),
                                                 Stub(value: "   ")])
        let out = await agg.compose(userContext: "writing the board deck")
        XCTAssertTrue(out.hasPrefix("writing the board deck"), "the user's own note comes first")
        XCTAssertTrue(out.contains("About 2 free hours left."))
        XCTAssertFalse(out.contains("   "), "blank fragments are dropped")
    }

    func testUserContextOnlyWhenNoConnectors() async {
        let agg = ContextAggregator(connectors: [])
        let out = await agg.compose(userContext: "focus: taxes")
        XCTAssertEqual(out, "focus: taxes")
    }

    func testEmptyWhenNothingToSay() async {
        let agg = ContextAggregator(connectors: [Stub(value: nil)])
        let out = await agg.compose(userContext: "  ")
        XCTAssertTrue(out.isEmpty)
    }
}

// MARK: - Daily ritual notifier: fire-time scheduling + guilt-free copy (PRD §7.6)
// The one nudge a day. These cover the pure core — when it fires and what it says —
// independent of UNUserNotificationCenter (which only runs once the user authorizes).

final class DailyRitualTests: XCTestCase {
    private let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/New_York")!
        return c
    }()

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    func testFireRollsToTomorrowWhenTimeHasPassed() {
        let now = date(2026, 6, 30, 10, 0)                                // 10:00, past 08:00
        let preferred = DailyRitual.dailyComponents(hour: 8, minute: 0)
        let fire = DailyRitual.nextFireDate(preferred: preferred, after: now, calendar: cal)
        let c = cal.dateComponents([.month, .day, .hour, .minute], from: fire!)
        XCTAssertEqual(c.month, 7); XCTAssertEqual(c.day, 1)             // next day
        XCTAssertEqual(c.hour, 8);  XCTAssertEqual(c.minute, 0)
    }

    func testFireStaysTodayWhenTimeIsStillAhead() {
        let now = date(2026, 6, 30, 10, 0)                                // 10:00, before 20:30
        let preferred = DailyRitual.dailyComponents(hour: 20, minute: 30)
        let fire = DailyRitual.nextFireDate(preferred: preferred, after: now, calendar: cal)
        let c = cal.dateComponents([.day, .hour, .minute], from: fire!)
        XCTAssertEqual(c.day, 30); XCTAssertEqual(c.hour, 20); XCTAssertEqual(c.minute, 30)
    }

    func testFireIsStrictlyAfterNow() {
        let now = date(2026, 6, 30, 8, 0)                                 // exactly 08:00
        let preferred = DailyRitual.dailyComponents(hour: 8, minute: 0)
        let fire = DailyRitual.nextFireDate(preferred: preferred, after: now, calendar: cal)!
        XCTAssertGreaterThan(fire, now, "never schedules into the present instant or past")
    }

    func testBodyZeroIsOpenSpaceNotFailure() {
        let body = DailyRitual.body(openCount: 0, topTitle: "ignored when empty")
        XCTAssertTrue(body.lowercased().contains("clear day"), "zero reads as space, not guilt")
    }

    func testBodyOneLeadsWithTheTask() {
        XCTAssertEqual(DailyRitual.body(openCount: 1, topTitle: "Pay rent"),
                       "One thing today: Pay rent.")
    }

    func testBodyManyLeadsWithTopTask() {
        XCTAssertEqual(DailyRitual.body(openCount: 7, topTitle: "Pay rent"),
                       "Today starts with: Pay rent.")
    }

    func testBodyNeverShowsARawCount() {
        // The badge problem, inverted: a morning nudge must never surface "7 things".
        XCTAssertFalse(DailyRitual.body(openCount: 7, topTitle: "Pay rent").contains("7"))
    }

    func testRescheduleIdentifierIsStable() {
        // One identifier ⇒ a reschedule overwrites the pending nudge rather than stacking.
        XCTAssertEqual(DailyRitual.requestIdentifier, "smarttdl.dailyRitual")
    }
}

// MARK: - Sync mirroring: the outbound delta TaskStore hands the SyncCoordinator
// (sync-plan.md §5). The CKSyncEngine itself needs a live container to run, but the
// local→cloud delta computation and the P5 echo-suppression are pure and tested here.

@MainActor
final class SyncMirrorTests: XCTestCase {
    /// Captures everything the store would push upward.
    final class Sink: LocalChangeSink {
        var upserts: [UUID] = []
        var deletions: [UUID] = []
        func localStoreDidChange(upserts: [UUID], deletions: [UUID]) {
            self.upserts.append(contentsOf: upserts)
            self.deletions.append(contentsOf: deletions)
        }
    }

    private func task(_ title: String) -> TodoItem { TodoItem(title: title, day: Date(), sortIndex: 1) }

    func testAttachPushesEveryCurrentTask() {
        let a = task("a"), b = task("b")
        let store = TaskStore(testItems: [a, b])
        let sink = Sink()
        store.attachSync(sink)
        XCTAssertEqual(Set(sink.upserts), Set([a.id, b.id]), "initial attach pushes the whole store")
    }

    func testAddEmitsAnUpsert() {
        let store = TaskStore(testItems: [])
        let sink = Sink(); store.attachSync(sink); sink.upserts.removeAll()
        store.add("new task", to: Date())
        XCTAssertEqual(sink.upserts.count, 1)
    }

    func testImportanceCommitNeverSyncs() {
        let a = task("a")
        let store = TaskStore(testItems: [a])
        let sink = Sink(); store.attachSync(sink); sink.upserts.removeAll()
        store._testSetPendingScores([a.id: 0.9])
        store.commitPendingRank()
        XCTAssertTrue(sink.upserts.isEmpty, "importance is local-only — it never advances modifiedAt, so it never syncs")
    }

    func testDeleteEmitsADeletion() {
        let a = task("a")
        let store = TaskStore(testItems: [a])
        let sink = Sink(); store.attachSync(sink); sink.upserts.removeAll()
        store.delete(a)
        XCTAssertEqual(sink.deletions, [a.id])
    }

    func testRemoteChangeIsNotEchoedBack() {
        // A change that just arrived FROM the cloud must not bounce straight back to it.
        let a = task("a")
        let store = TaskStore(testItems: [a])
        let sink = Sink(); store.attachSync(sink)
        sink.upserts.removeAll(); sink.deletions.removeAll()

        var remote = a
        remote.title = "edited on another device"
        remote.modifiedAt = a.modifiedAt.addingTimeInterval(100)   // newer ⇒ wins LWW
        store.applyRemoteChanges(upserts: [remote])

        XCTAssertTrue(sink.upserts.isEmpty && sink.deletions.isEmpty,
                      "the just-applied remote edit is suppressed from the next outbound emit (no echo)")
    }
}

// MARK: - Gmail connector: inbox → one quiet ranker line (PRD §7.5)
// The OAuth read isn't wired, but the prose composition and the connector seam are.

final class GmailConnectorTests: XCTestCase {
    private struct StubInbox: InboxReading {
        let snap: InboxSnapshot?
        func snapshot() async -> InboxSnapshot? { snap }
    }

    func testNothingToSayWhenInboxIsQuiet() {
        XCTAssertNil(GmailConnector.line(for: InboxSnapshot(awaitingReply: 0, highlight: nil)))
    }

    func testSingleReplyLine() {
        XCTAssertEqual(GmailConnector.line(for: InboxSnapshot(awaitingReply: 1, highlight: nil)),
                       "One email is waiting on a reply.")
    }

    func testManyRepliesLine() {
        XCTAssertEqual(GmailConnector.line(for: InboxSnapshot(awaitingReply: 3, highlight: nil)),
                       "3 emails are waiting on a reply.")
    }

    func testHighlightOnlyLine() {
        XCTAssertEqual(GmailConnector.line(for: InboxSnapshot(awaitingReply: 0, highlight: "the lease")),
                       "An email about the lease may need attention.")
    }

    func testCountWithHighlightLine() {
        XCTAssertEqual(
            GmailConnector.line(for: InboxSnapshot(awaitingReply: 2, highlight: "Dana about the contract")),
            "2 emails are waiting on a reply, including Dana about the contract.")
    }

    func testConnectorComposesFromReader() async {
        let connector = GmailConnector(reader: StubInbox(snap: InboxSnapshot(awaitingReply: 1, highlight: nil)))
        let out = await connector.fragment()
        XCTAssertEqual(out, "One email is waiting on a reply.")
    }

    func testConnectorSilentWhenReaderUnavailable() async {
        let connector = GmailConnector(reader: StubInbox(snap: nil))
        let out = await connector.fragment()
        XCTAssertNil(out, "no account / no access ⇒ the connector says nothing")
    }

    func testProductionInboxIsInertUntilOAuth() async {
        // GmailInbox returns nil until OAuth is configured — the app stays unaffected.
        let out = await GmailInbox().snapshot()
        XCTAssertNil(out)
    }
}

// MARK: - Capture inbox: share-extension/widget hand-off → tasks (capture anywhere)
// The App Group is account-gated, so tests inject a throwaway suite — the queue and the
// drain-into-today logic are exercised exactly as they'll run with the real group.

final class CaptureInboxTests: XCTestCase {
    private func freshInbox() -> (CaptureInbox, UserDefaults, String) {
        let name = "smarttdl.test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        return (CaptureInbox(defaults: defaults), defaults, name)
    }

    func testEnqueueThenDrainRoundTripsInOrder() {
        let (inbox, defaults, name) = freshInbox()
        defer { defaults.removePersistentDomain(forName: name) }
        inbox.enqueue("Buy milk")
        inbox.enqueue("Call Sam")
        XCTAssertEqual(inbox.pendingCount, 2)
        XCTAssertEqual(inbox.drain(), ["Buy milk", "Call Sam"])
        XCTAssertEqual(inbox.pendingCount, 0, "drain empties the queue")
    }

    func testEnqueueIgnoresBlanks() {
        let (inbox, defaults, name) = freshInbox()
        defer { defaults.removePersistentDomain(forName: name) }
        inbox.enqueue("   ")
        inbox.enqueue("")
        XCTAssertEqual(inbox.pendingCount, 0)
    }

    @MainActor
    func testDrainCapturesBecomeTodaysTasks() {
        let (inbox, defaults, name) = freshInbox()
        defer { defaults.removePersistentDomain(forName: name) }
        inbox.enqueue("Buy milk")
        inbox.enqueue("Email the landlord")

        let store = TaskStore(testItems: [])
        let created = store.drainCaptures(from: inbox)

        XCTAssertEqual(created, 2)
        let today = Calendar.current.startOfDay(for: Date())
        let titles = Set(store.openTasks(on: today).map(\.title))
        XCTAssertEqual(titles, ["Buy milk", "Email the landlord"])
        XCTAssertEqual(inbox.pendingCount, 0, "captures are consumed, not duplicated on next launch")
    }

    @MainActor
    func testDrainIsANoOpWhenEmpty() {
        let (inbox, defaults, name) = freshInbox()
        defer { defaults.removePersistentDomain(forName: name) }
        let store = TaskStore(testItems: [])
        XCTAssertEqual(store.drainCaptures(from: inbox), 0)
    }
}
