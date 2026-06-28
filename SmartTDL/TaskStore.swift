import Foundation
import Observation

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
    private var undoStack: [UndoStep] = []

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
            if interacting.isEmpty { commitPendingRank() }
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

    private func rerank() async {
        let visible = Set(visibleDays)
        let toRank = items.filter { $0.list == nil && !$0.isCompleted && visible.contains($0.day) }
        guard !toRank.isEmpty else { return }
        guard let scores = try? await ranker.rank(toRank, context: context) else { return }
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

    // MARK: - Persistence

    private func save() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: saveURL, options: .atomic)
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
