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
