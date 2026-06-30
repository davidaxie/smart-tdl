import Foundation
import Observation

/// A sink for local content changes so a sync layer can mirror them upward. Pure
/// Foundation (ids only, no CloudKit) — defined here, conformed to by the CloudKit
/// `SyncCoordinator`. A nil `syncSink` means no sync is active and the store behaves
/// exactly as it always has.
protocol LocalChangeSink: AnyObject {
    func localStoreDidChange(upserts: [UUID], deletions: [UUID])
}

/// Single source of truth. Day-bucketed tasks, JSON persistence, and an
/// invisible auto-sort powered by a pluggable `Ranker`. New importance scores
/// are buffered and only applied at "safe moments" so the list never reshuffles
/// under the user's finger/cursor.
@MainActor
@Observable
final class TaskStore {
    static let contextKey = "smarttdl.context"

    private(set) var items: [TodoItem] = []
    var context: String
    /// Tokens bumped by global keyboard commands; views observe and react.
    private(set) var newTaskToken = 0
    private(set) var findToken = 0
    private(set) var commandToken = 0
    private(set) var focusToken = 0
    /// Bumped when a modal/overlay dismisses so the main list re-grabs key focus.
    private(set) var refocusToken = 0

    private let saveURL: URL
    private let calendar = Calendar.current
    private var ranker: Ranker = HeuristicRanker()
    /// True once a real AI ranker (Haiku) is active — gates the honest-confidence
    /// hedge, which only makes sense when the scores carry genuine uncertainty.
    private(set) var usingAI = false
    private var rankTask: Task<Void, Never>?
    private var idleCommitTask: Task<Void, Never>?
    private var pendingScores: [UUID: Double] = [:]
    private var interacting: Set<UUID> = []
    // Remote task changes from sync, buffered like pendingScores so they apply only
    // at safe moments — a remote edit must never reorder a row under the hand (P5).
    private var pendingRemoteUpserts: [UUID: TodoItem] = [:]
    private var pendingRemoteDeletes: Set<UUID> = []
    private var undoStack: [UndoStep] = []

    // Sync mirroring (inert until a SyncCoordinator attaches; see LocalChangeSink).
    @ObservationIgnored weak var syncSink: (any LocalChangeSink)?
    @ObservationIgnored private var syncSnapshot: [UUID: Date] = [:]   // id → last-emitted modifiedAt
    @ObservationIgnored private var syncSuppress: Set<UUID> = []       // ids changed by remote — don't echo back

    private enum UndoStep {
        case toggle(UUID, Bool, UUID?)   // id, previous-completed, spawned-recurrence id
        case delete(TodoItem)
        case move(UUID, Date)
    }

    func requestNewTask() { newTaskToken &+= 1 }
    func requestFind() { findToken &+= 1 }
    func requestCommandBar() { commandToken &+= 1 }
    func requestFocusMode() { focusToken &+= 1 }
    func requestListRefocus() { refocusToken &+= 1 }

    func item(_ id: UUID) -> TodoItem? { items.first { $0.id == id } }

    /// The single most important open task across the visible window (Today first).
    func nextFocusTask() -> TodoItem? {
        for day in visibleDays {
            if let first = openTasks(on: day).first { return first }
        }
        return nil
    }

    /// End-of-day sweep: move every unfinished task from today to tomorrow.
    func pushAllToTomorrow() {
        let today = calendar.startOfDay(for: Date())
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) else { return }
        var changed = false
        for i in items.indices where items[i].list == nil && !items[i].isCompleted && calendar.isDate(items[i].day, inSameDayAs: today) {
            items[i].day = tomorrow
            items[i].modifiedAt = Date()
            changed = true
        }
        if changed { save(); scheduleRank(); commitPendingRank() }
    }

    init() {
        let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SmartTDL", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        saveURL = dir.appendingPathComponent("tasks.json")
        context = UserDefaults.standard.string(forKey: Self.contextKey) ?? ""

        load()
        rollForward()
        refreshRanker()
    }

    #if DEBUG
    /// Deterministic, disk-free store for tests: known items, a throwaway save URL,
    /// no load / roll-forward / ranker resolution. Stays on the local heuristic with
    /// `usingAI == false` until a test opts in via the seams below.
    init(testItems: [TodoItem]) {
        saveURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("SmartTDLTest-\(UUID().uuidString).json")
        context = ""
        items = testItems
    }

    /// Test seam: inject the buffered importance scores `rerank` would normally write.
    func _testSetPendingScores(_ scores: [UUID: Double]) { pendingScores = scores }
    /// Test seam: pretend a real AI ranker is active (gates the honest-confidence hedge).
    func _testSetUsingAI(_ value: Bool) { usingAI = value }
    #endif

    // MARK: - Days & queries

    /// Today plus the next six days.
    var visibleDays: [Date] {
        let today = calendar.startOfDay(for: Date())
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
    }

    func openTasks(on day: Date) -> [TodoItem] {
        items.filter { $0.list == nil && !$0.isCompleted && calendar.isDate($0.day, inSameDayAs: day) }
            .sorted(by: Self.order)
    }

    func completedTasks(on day: Date) -> [TodoItem] {
        items.filter { $0.list == nil && $0.isCompleted && calendar.isDate($0.day, inSameDayAs: day) }
            .sorted { $0.sortIndex < $1.sortIndex }
    }

    /// The fixed parking-lot lists shown in the desktop right rail.
    static let listNames = ["Later", "Misc", "Reminders"]

    func listTasks(_ name: String, completed: Bool) -> [TodoItem] {
        items.filter { $0.list == name && $0.isCompleted == completed }
            .sorted { a, b in
                if a.isPinned != b.isPinned { return a.isPinned }
                return a.sortIndex < b.sortIndex
            }
    }

    /// The focus task = the top open task of Today.
    func focusTaskID(for day: Date) -> UUID? {
        calendar.isDateInToday(day) ? openTasks(on: day).first?.id : nil
    }

    /// True when the top two open tasks' AI scores cluster so tightly that
    /// crowning a single #1 would assert false confidence. The gravity ramp then
    /// flattens and the hero label hedges ("a few things matter"). Honest UI over
    /// an uncertain system avoids teaching blind trust. Needs both top tasks ranked.
    func topScoresClustered(on day: Date) -> Bool {
        guard usingAI else { return false }   // heuristic scores tie too often to be honest signal
        let top = Array(openTasks(on: day).prefix(2))
        guard top.count == 2, let a = top[0].importance, let b = top[1].importance else { return false }
        return (a - b) < 0.06
    }

    /// Pinned-first → importance desc (unranked last) → manual order. (Completed sink.)
    static func order(_ a: TodoItem, _ b: TodoItem) -> Bool {
        if a.isCompleted != b.isCompleted { return !a.isCompleted }
        if a.isPinned != b.isPinned { return a.isPinned }
        let ai = a.importance ?? -1, bi = b.importance ?? -1
        if ai != bi { return ai > bi }
        return a.sortIndex < b.sortIndex
    }

    // MARK: - Mutations

    func add(_ title: String, to day: Date, recurrence: Recurrence? = nil) {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        let d = calendar.startOfDay(for: day)
        let nextIndex = (items.filter { $0.list == nil && calendar.isDate($0.day, inSameDayAs: d) }
            .map(\.sortIndex).max() ?? 0) + 1
        items.append(TodoItem(title: t, day: d, sortIndex: nextIndex, recurrence: recurrence))
        save()
        scheduleRank()
        commitPendingRank()
    }

    /// Add a task to an undated parking-lot list (Later/Misc/…).
    func add(_ title: String, toList list: String) {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        let nextIndex = (items.filter { $0.list == list }.map(\.sortIndex).max() ?? 0) + 1
        let today = calendar.startOfDay(for: Date())
        items.append(TodoItem(title: t, day: today, sortIndex: nextIndex, list: list))
        save()
    }

    /// Park a task into a list (from a day), or re-file it between lists.
    func moveToList(_ item: TodoItem, list: String) {
        guard let i = items.firstIndex(where: { $0.id == item.id }) else { return }
        pushUndo(.move(item.id, items[i].day))
        items[i].list = list
        items[i].importance = nil
        let nextIndex = (items.filter { $0.list == list }.map(\.sortIndex).max() ?? 0) + 1
        items[i].sortIndex = nextIndex
        items[i].modifiedAt = Date()
        save()
        commitPendingRank()
    }

    func toggle(_ item: TodoItem) {
        guard let i = items.firstIndex(where: { $0.id == item.id }) else { return }
        let prev = items[i].isCompleted
        let nowCompleting = !prev
        items[i].isCompleted = nowCompleting
        items[i].modifiedAt = Date()

        // Recurring task just completed → spawn the next occurrence.
        var spawnedID: UUID?
        if nowCompleting, let rec = items[i].recurrence {
            let next = rec.nextDate(after: items[i].day)
            var copy = TodoItem(title: items[i].title, day: next, sortIndex: items[i].sortIndex, recurrence: rec)
            copy.isPinned = items[i].isPinned
            spawnedID = copy.id
            items.append(copy)
        }
        pushUndo(.toggle(item.id, prev, spawnedID))
        save()
        scheduleRank()
        commitPendingRank()
    }

    func togglePin(_ item: TodoItem) {
        guard let i = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[i].isPinned.toggle()
        items[i].modifiedAt = Date()
        save()
        commitPendingRank()
    }

    func rename(_ item: TodoItem, to title: String) {
        guard let i = items.firstIndex(where: { $0.id == item.id }) else { return }
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty {
            pushUndo(.delete(items[i]))
            items.remove(at: i)
        } else if items[i].title != t {
            items[i].title = t
            items[i].importance = nil   // re-rank since the text changed
            items[i].modifiedAt = Date()
            scheduleRank()
        }
        save()
        commitPendingRank()
    }

    func delete(_ item: TodoItem) {
        guard let i = items.firstIndex(where: { $0.id == item.id }) else { return }
        pushUndo(.delete(items[i]))
        items.remove(at: i)
        save()
        commitPendingRank()
    }

    func move(_ item: TodoItem, to day: Date) {
        guard let i = items.firstIndex(where: { $0.id == item.id }) else { return }
        pushUndo(.move(item.id, items[i].day))
        items[i].day = calendar.startOfDay(for: day)
        items[i].list = nil   // scheduling onto a day un-files it from any list
        items[i].modifiedAt = Date()
        save()
        scheduleRank()
        commitPendingRank()
    }

    func updateContext(_ value: String) {
        context = value
        UserDefaults.standard.set(value, forKey: Self.contextKey)
        scheduleRank()
    }

    func undo() {
        guard let step = undoStack.popLast() else { return }
        switch step {
        case .toggle(let id, let prev, let spawned):
            if let i = items.firstIndex(where: { $0.id == id }) { items[i].isCompleted = prev; items[i].modifiedAt = Date() }
            if let spawned { items.removeAll { $0.id == spawned } }
        case .delete(let item):
            if !items.contains(where: { $0.id == item.id }) { items.append(item) }
        case .move(let id, let prevDay):
            if let i = items.firstIndex(where: { $0.id == id }) { items[i].day = prevDay; items[i].modifiedAt = Date() }
        }
        save()
    }

    private func pushUndo(_ step: UndoStep) {
        undoStack.append(step)
        if undoStack.count > 50 { undoStack.removeFirst() }
    }

    /// Roll unfinished tasks from past days forward to today.
    private func rollForward() {
        let today = calendar.startOfDay(for: Date())
        var changed = false
        for i in items.indices where items[i].list == nil && !items[i].isCompleted && items[i].day < today {
            items[i].day = today
            items[i].modifiedAt = Date()
            changed = true
        }
        if changed { save() }
    }

    // MARK: - Ranking (buffered, safe-moment commit)

    /// Mark a row as being touched/hovered/edited so the AI won't reorder it.
    func setInteracting(_ id: UUID, _ active: Bool) {
        if active {
            interacting.insert(id)
        } else {
            interacting.remove(id)
            if interacting.isEmpty { commitPendingRank(); commitPendingRemote() }
        }
    }

    /// Apply any buffered importance scores — but only when nothing is being touched.
    func commitPendingRank() {
        guard interacting.isEmpty, !pendingScores.isEmpty else { return }
        var changed = false
        for (id, score) in pendingScores {
            if let i = items.firstIndex(where: { $0.id == id }), items[i].importance != score {
                items[i].importance = score
                changed = true
            }
        }
        pendingScores.removeAll()
        if changed { save() }
    }

    // MARK: - Remote sync merges (buffered, safe-moment commit; honors P5)

    /// Merge remote task changes from sync. LWW on `modifiedAt`; local `importance`
    /// is preserved (it isn't synced). Buffered and applied only at safe moments so a
    /// remote change never reorders a row under the user's hand (P5). The
    /// `SyncCoordinator` (added once the CloudKit container exists) calls this.
    func applyRemoteChanges(upserts: [TodoItem] = [], deletions: [UUID] = []) {
        for item in upserts {
            pendingRemoteDeletes.remove(item.id)
            pendingRemoteUpserts[item.id] = item
        }
        for id in deletions {
            pendingRemoteUpserts[id] = nil
            pendingRemoteDeletes.insert(id)
        }
        commitPendingRemote()
    }

    /// Apply buffered remote changes — but only when nothing is being touched.
    func commitPendingRemote() {
        guard interacting.isEmpty,
              !pendingRemoteUpserts.isEmpty || !pendingRemoteDeletes.isEmpty else { return }
        var changed = false
        var appliedRemotely: Set<UUID> = []   // suppress these from the next outbound sync emit
        for (id, remote) in pendingRemoteUpserts {
            if let i = items.firstIndex(where: { $0.id == id }) {
                guard remote.modifiedAt > items[i].modifiedAt else { continue }   // LWW
                let localImportance = items[i].importance   // importance is local-only
                items[i] = remote
                items[i].importance = localImportance
                changed = true
                appliedRemotely.insert(id)
            } else {
                items.append(remote)   // a new task from another device; this device ranks it
                changed = true
                appliedRemotely.insert(id)
            }
        }
        for id in pendingRemoteDeletes where items.contains(where: { $0.id == id }) {
            items.removeAll { $0.id == id }
            changed = true
            appliedRemotely.insert(id)
        }
        pendingRemoteUpserts.removeAll()
        pendingRemoteDeletes.removeAll()
        if changed { syncSuppress = appliedRemotely; save(); scheduleRank() }
    }

    // MARK: - Sync mirroring (outbound delta; inert until a sink attaches)

    /// Attach the sync layer. Resets the snapshot so the next emit flags every current
    /// task as an upsert — the initial push of local data into the empty cloud zone.
    func attachSync(_ sink: any LocalChangeSink) {
        syncSink = sink
        syncSnapshot = [:]
        emitSyncDelta()
    }

    /// Re-push the entire local store (e.g. after an iCloud sign-in). Same mechanism as
    /// a fresh attach: clear the snapshot, then emit all as upserts.
    func resyncAll() {
        guard syncSink != nil else { return }
        syncSnapshot = [:]
        emitSyncDelta()
    }

    /// Compute the id-level delta since the last emit and hand it to the sink. Cheap
    /// O(n) and a no-op when no sink is attached. Importance-only saves don't advance
    /// `modifiedAt`, so they never produce a delta — importance stays local (sync-plan
    /// §3). Ids the remote layer just applied are skipped once, to avoid echoing a
    /// just-received change straight back to the cloud.
    private func emitSyncDelta() {
        guard let sink = syncSink else { return }
        var current: [UUID: Date] = [:]
        var upserts: [UUID] = []
        for item in items {
            current[item.id] = item.modifiedAt
            if syncSnapshot[item.id] != item.modifiedAt, !syncSuppress.contains(item.id) {
                upserts.append(item.id)
            }
        }
        let deletions = syncSnapshot.keys.filter { current[$0] == nil && !syncSuppress.contains($0) }
        syncSnapshot = current
        syncSuppress.removeAll()
        if !upserts.isEmpty || !deletions.isEmpty {
            sink.localStoreDidChange(upserts: upserts, deletions: Array(deletions))
        }
    }

    /// Resolve which ranker to use. The Keychain read can surface a blocking
    /// system prompt, so it runs off the main thread — never stalling launch or
    /// the first frame. Defaults to the local heuristic until the key resolves.
    func refreshRanker() {
        // No key configured → never touch the Keychain (no system prompt).
        guard Keychain.hasKey else {
            ranker = HeuristicRanker()
            scheduleRank()
            return
        }
        Task { [weak self] in
            let key = await Task.detached { Keychain.apiKey }.value
            guard let self else { return }
            if let key, !key.isEmpty {
                self.ranker = HaikuRanker(apiKey: key)
                self.usingAI = true
            } else {
                self.ranker = HeuristicRanker()
                self.usingAI = false
            }
            self.scheduleRank()
        }
    }

    func scheduleRank() {
        rankTask?.cancel()
        rankTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            await self?.rerank()
        }
    }

    /// Composes the ranker's effective context from the user's note + connectors
    /// (the calendar time-layer today; Gmail/etc. later). Lazy so unit tests that
    /// never rerank don't spin up EventKit. Connectors stay inert until the user
    /// opts in, so this never prompts for access on its own.
    @ObservationIgnored private lazy var contextAggregator = ContextAggregator(connectors: [
        TimeContextProvider(),                      // calendar — live once access is granted
        GmailConnector(reader: GmailInbox()),       // email — silent until OAuth is configured
    ])

    private func rerank() async {
        let visible = Set(visibleDays)
        let toRank = items.filter { $0.list == nil && !$0.isCompleted && visible.contains($0.day) }
        guard !toRank.isEmpty else { return }
        let effectiveContext = await contextAggregator.compose(userContext: context)
        guard let scores = try? await ranker.rank(toRank, context: effectiveContext) else { return }
        pendingScores = scores
        scheduleIdleCommit()
    }

    /// After scores arrive, settle them in once the user has been idle a beat.
    private func scheduleIdleCommit() {
        idleCommitTask?.cancel()
        idleCommitTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard !Task.isCancelled else { return }
            self?.commitPendingRank()
        }
    }

    // MARK: - Capture inbox (drain share-extension / widget captures into today)

    /// Pull anything queued by a capture surface (Share Extension, widget) into today's
    /// list, in capture order. Called on app activation. A no-op when the queue is empty
    /// (the common case), so it's cheap to call on every foreground. Returns the count.
    @discardableResult
    func drainCaptures(from inbox: CaptureInbox = CaptureInbox()) -> Int {
        let captured = inbox.drain()
        guard !captured.isEmpty else { return 0 }
        let today = calendar.startOfDay(for: Date())
        for text in captured { add(text, to: today) }
        return captured.count
    }

    // MARK: - Daily ritual notification (opt-in; no-op until the user authorizes)

    /// The inputs the ritual copy needs, drawn from *today's* list: how many open
    /// day-tasks remain and the single most important one (today's #1). The ritual is a
    /// morning glance at today, so it deliberately ignores the rest of the week.
    var ritualSnapshot: (openCount: Int, topTitle: String?) {
        let open = openTasks(on: calendar.startOfDay(for: Date()))
        return (open.count, open.first?.title)
    }

    #if canImport(UserNotifications)
    /// (Re)schedule the daily ritual at the user's chosen time, drawing copy from the
    /// current list. A no-op unless notifications are already authorized, so it's safe
    /// to call on launch or after edits without surfacing a prompt. The Settings opt-in
    /// (which calls `Notifier.requestAccess()` first) is the single activation point.
    func refreshDailyRitual(hour: Int, minute: Int, notifier: Notifier = Notifier()) {
        let snapshot = ritualSnapshot
        let preferred = DailyRitual.dailyComponents(hour: hour, minute: minute)
        Task {
            await notifier.scheduleDailyRitual(
                preferred: preferred, openCount: snapshot.openCount, topTitle: snapshot.topTitle)
        }
    }
    #endif

    // MARK: - Persistence

    private func save() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: saveURL, options: .atomic)
        emitSyncDelta()   // mirror the change upward if a sync layer is attached (else no-op)
    }

    private func load() {
        guard
            let data = try? Data(contentsOf: saveURL),
            let decoded = try? JSONDecoder().decode([TodoItem].self, from: data)
        else {
            items = Self.sampleData
            return
        }
        items = decoded
    }

    static var sampleData: [TodoItem] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let tomorrow = cal.date(byAdding: .day, value: 1, to: today) ?? today
        func mk(_ title: String, _ day: Date, _ i: Double, done: Bool = false) -> TodoItem {
            TodoItem(title: title, day: day, sortIndex: i, isCompleted: done)
        }
        func list(_ title: String, _ name: String, _ i: Double) -> TodoItem {
            TodoItem(title: title, day: today, sortIndex: i, list: name)
        }
        return [
            mk("Finish the board deck for Friday", today, 1),
            mk("Reply to Dana about the contract", today, 2),
            mk("Book a dentist appointment", today, 3),
            mk("Morning walk", today, 4, done: true),
            mk("Call Sam about logistics", tomorrow, 1),
            mk("Review the open pull requests", tomorrow, 2),
            list("Plan the offsite", "Later", 1),
            list("Learn a bit of Rust", "Later", 2),
            list("Return the Amazon package", "Misc", 1),
            list("Water the plants Tuesday", "Reminders", 1),
        ]
    }
}
