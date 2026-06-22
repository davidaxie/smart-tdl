import SwiftUI

/// The default vertical layout (iOS). A single shared spring keyed on
/// `store.items` animates every reflow — that glide is the only signal the
/// ambient sort gives.
struct TaskListView: View {
    @Environment(TaskStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @FocusState private var focusedDay: Date?
    @State private var selectedID: UUID?
    @State private var query = ""
    @State private var searchPresented = false

    private let rowInsets = EdgeInsets(top: 0, leading: Space.xl, bottom: 0, trailing: Space.xl)
    private var today: Date { Calendar.current.startOfDay(for: Date()) }

    var body: some View {
        List {
            ForEach(store.visibleDays, id: \.self) { day in
                daySection(day)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .animation(reduceMotion ? nil : Motion.settle, value: store.items)
        .searchable(text: $query, isPresented: $searchPresented, prompt: "Search tasks")
        .overlay(alignment: .bottomTrailing) { floatingAdd }
        .onAppear {
            if store.openTasks(on: today).isEmpty && store.completedTasks(on: today).isEmpty {
                focusedDay = today
            }
        }
        .onChange(of: store.newTaskToken) { _, _ in focusedDay = today }
        .onChange(of: store.findToken) { _, _ in searchPresented = true }
    }

    @ViewBuilder
    private func daySection(_ day: Date) -> some View {
        let open = filtered(store.openTasks(on: day))
        let done = filtered(store.completedTasks(on: day))
        let focusID = store.focusTaskID(for: day)
        let isToday = Calendar.current.isDateInToday(day)
        let searching = !query.isEmpty

        if !searching || !open.isEmpty || !done.isEmpty {
            DayMasthead(day: day, onActivate: { focusedDay = day }, onDropID: { drop($0, to: day) })
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(rowInsets)

            ForEach(open) { item in
                row(item, isFocus: !searching && item.id == focusID)
            }

            if open.isEmpty && done.isEmpty && isToday && !searching {
                EmptyLine()
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(rowInsets)
            }

            if !searching {
                AddRow(day: day, focusBinding: $focusedDay)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(rowInsets)
            }

            if !done.isEmpty {
                PoolDivider()
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(rowInsets)
                ForEach(done) { item in
                    row(item, isFocus: false)
                }
            }
        }
    }

    private func row(_ item: TodoItem, isFocus: Bool) -> some View {
        TaskRowView(
            item: item,
            isFocus: isFocus,
            onToggle: { store.toggle(item) },
            onSubmit: { store.rename(item, to: $0) },
            onDelete: { store.delete(item) },
            onPin: { store.togglePin(item) },
            onInteract: { store.setInteracting(item.id, $0) },
            onMove: { store.move(item, to: $0) },
            moveTargets: store.visibleDays
        )
        .listRowBackground(item.isCompleted ? Color.surfacePool : Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(rowInsets)
    }

    private func filtered(_ items: [TodoItem]) -> [TodoItem] {
        guard !query.isEmpty else { return items }
        return items.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }

    @ViewBuilder private var floatingAdd: some View {
        #if os(iOS)
        Button {
            focusedDay = today
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color.bgCanvas)
                .frame(width: 56, height: 56)
                .background(Circle().fill(Color.accentInk))
                .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
        }
        .padding(Space.xl)
        .accessibilityLabel("Add task to Today")
        #else
        EmptyView()
        #endif
    }

    private func drop(_ idString: String, to day: Date) {
        guard let id = UUID(uuidString: idString), let it = store.item(id) else { return }
        store.move(it, to: day)
    }
}

// MARK: - Shared building blocks

struct DayMasthead: View {
    let day: Date
    var onActivate: (() -> Void)? = nil
    var onDropID: ((String) -> Void)? = nil

    private var isToday: Bool { Calendar.current.isDateInToday(day) }

    #if os(macOS)
    private let mastheadStyle: Font.TextStyle = .title
    private let mastheadSize: CGFloat = 27
    #else
    private let mastheadStyle: Font.TextStyle = .largeTitle
    private let mastheadSize: CGFloat = 34
    #endif

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.s) {
            if isToday {
                Circle()
                    .fill(Color.accentInk)
                    .frame(width: 7, height: 7)
            }
            Text(day.dayLabel)
                .font(.display(mastheadSize, relativeTo: mastheadStyle))
                .foregroundStyle(isToday ? Color.accentInk : Color.inkPrimary)
            Text(day.daySubLabel)
                .font(.system(.subheadline, design: .serif))
                .foregroundStyle(Color.inkSecondary)
            Spacer(minLength: 0)
        }
        .padding(.top, Space.xxl)
        .padding(.bottom, Space.s)
        .contentShape(Rectangle())
        .onTapGesture { onActivate?() }
        .dropDestination(for: String.self) { ids, _ in
            if let s = ids.first { onDropID?(s) }
            return true
        }
    }
}

struct EmptyLine: View {
    var body: some View {
        Text("A clear page. What's first?")
            .font(.display(22, relativeTo: .title3))
            .foregroundStyle(Color.inkSecondary)
            .padding(.vertical, Space.s)
    }
}

struct PoolDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.hairline)
            .frame(height: 1)
            .padding(.top, Space.pool)
            .padding(.bottom, Space.s)
    }
}

/// A barely-there field of ink specks for warmth and depth — paper grain.
struct PaperGrain: View {
    var body: some View {
        Canvas { ctx, size in
            var seed: UInt64 = 0x9E3779B97F4A7C15
            func rnd() -> Double {
                seed ^= seed << 13; seed ^= seed >> 7; seed ^= seed << 17
                return Double(seed % 10_000) / 10_000
            }
            let count = Int(size.width * size.height / 1600)
            for _ in 0..<count {
                let x = rnd() * size.width
                let y = rnd() * size.height
                let a = 0.012 + rnd() * 0.022
                ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1.1, height: 1.1)),
                         with: .color(Color.inkPrimary.opacity(a)))
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
}

struct AddRow: View {
    @Environment(TaskStore.self) private var store
    let day: Date
    var focusBinding: FocusState<Date?>.Binding
    /// Called when the user presses Escape in the field (Mac: hand focus back to
    /// the keyboard-driven list).
    var onEscape: (() -> Void)? = nil

    @State private var text = ""

    private var active: Bool { focusBinding.wrappedValue == day }

    var body: some View {
        HStack(spacing: Space.m) {
            Image(systemName: "plus")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(active ? Color.accentInk : Color.placeholderInk)
                .scaleEffect(active ? 1.12 : 1)
                .frame(width: 34, height: 34)
                .animation(Motion.press, value: active)

            TextField("Add a task", text: $text)
                .textFieldStyle(.plain)
                .font(.system(.body, design: .default))
                .foregroundStyle(Color.inkBody)
                .focused(focusBinding, equals: day)
                .onSubmit(submit)
                #if os(macOS)
                .onExitCommand { focusBinding.wrappedValue = nil; onEscape?() }
                #endif
        }
        .padding(.vertical, Space.s)
    }

    private func submit() {
        let raw = text
        text = ""
        for line in raw.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            let rec = DateParser.parseRecurrence(trimmed)
            if let recurrence = rec.recurrence {
                store.add(rec.title, to: rec.day ?? day, recurrence: recurrence)
            } else {
                let parsed = DateParser.parse(trimmed, reference: day)
                store.add(parsed.title, to: parsed.day ?? day)
            }
        }
        focusBinding.wrappedValue = day
    }
}

#if os(macOS)
// MARK: - Bespoke Mac shell

/// Custom header: serif wordmark, hand-built layout toggle, and quiet action
/// glyphs. Sits over the edge-to-edge warm canvas, clearing the traffic lights.
struct MacHeader: View {
    @Binding var weekMode: Bool
    var onCapture: () -> Void
    var onFocus: () -> Void
    var onSettings: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: Space.m) {
            Text("Smart TDL")
                .font(.display(20, relativeTo: .title3))
                .foregroundStyle(Color.inkPrimary)
                .tracking(0.4)

            Spacer(minLength: Space.l)

            icon("scope", help: "Focus now (⌘J)", action: onFocus)
            icon("plus", help: "Quick capture (⌘K)", action: onCapture)
            LayoutToggle(weekMode: $weekMode)
            icon("slider.horizontal.3", help: "Settings (⌘,)", action: onSettings)
        }
        .padding(.top, 20)
        .padding(.leading, 82)
        .padding(.trailing, Space.xxl)
        .padding(.bottom, Space.m)
    }

    private func icon(_ name: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.inkSecondary)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

private struct LayoutToggle: View {
    @Binding var weekMode: Bool

    var body: some View {
        HStack(spacing: 2) {
            segment(symbol: "list.bullet", on: !weekMode) { set(false) }
            segment(symbol: "rectangle.split.3x1", on: weekMode) { set(true) }
        }
        .padding(3)
        .background(Capsule().fill(Color.inkPrimary.opacity(0.06)))
    }

    private func set(_ value: Bool) {
        withAnimation(Motion.press) { weekMode = value }
    }

    private func segment(symbol: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(on ? Color.bgCanvas : Color.inkSecondary)
                .frame(width: 32, height: 24)
                .background(Capsule().fill(on ? Color.accentInk : Color.clear))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// Keyboard-first custom list. Always-on selection cursor, vim keys, one-key
/// defer. Rows are plain text until you edit them, so the list keeps key focus.
struct MacListView: View {
    @Environment(TaskStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @FocusState private var listFocused: Bool
    @FocusState private var focusedDay: Date?
    @FocusState private var searchFocused: Bool
    @State private var selectedID: UUID?
    @State private var editingID: UUID?
    @State private var query = ""
    @State private var searchActive = false

    private var today: Date { Calendar.current.startOfDay(for: Date()) }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                greeting
                if searchActive { searchField }
                ForEach(store.visibleDays, id: \.self) { day in
                    section(day)
                }
                hintBar
            }
            .frame(maxWidth: 660, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Space.section)
            .padding(.top, Space.s)
            .padding(.bottom, 60)
        }
        .scrollContentBackground(.hidden)
        .animation(reduceMotion ? nil : Motion.settle, value: store.items)
        .focusable()
        .focusEffectDisabled()
        .focused($listFocused)
        .onKeyPress { press in handleKey(press) }
        .onAppear { focusList() }
        .onChange(of: store.newTaskToken) { _, _ in focusedDay = today }
        .onChange(of: store.findToken) { _, _ in searchActive = true; searchFocused = true }
        .onChange(of: store.refocusToken) { _, _ in focusList() }
    }

    @ViewBuilder
    private func section(_ day: Date) -> some View {
        let open = filtered(store.openTasks(on: day))
        let done = filtered(store.completedTasks(on: day))
        let focusID = store.focusTaskID(for: day)
        let isToday = Calendar.current.isDateInToday(day)
        let searching = !query.isEmpty

        if !searching || !open.isEmpty || !done.isEmpty {
            DayMasthead(day: day, onActivate: { focusedDay = day }, onDropID: { drop($0, to: day) })

            ForEach(open) { item in macRow(item, isFocus: !searching && item.id == focusID) }

            if open.isEmpty && done.isEmpty && isToday && !searching {
                EmptyLine()
            }

            if !searching {
                AddRow(day: day, focusBinding: $focusedDay, onEscape: { focusList() })
            }

            if !done.isEmpty {
                PoolDivider()
                ForEach(done) { item in macRow(item, isFocus: false) }
            }

            Color.clear.frame(height: Space.l)
        }
    }

    private func macRow(_ item: TodoItem, isFocus: Bool) -> some View {
        MacRow(item: item,
               isFocus: isFocus,
               isSelected: item.id == selectedID,
               isEditing: item.id == editingID,
               moveTargets: store.visibleDays,
               onSelect: { selectedID = item.id; listFocused = true },
               onBeginEdit: { selectedID = item.id; editingID = item.id },
               onEndEdit: { editingID = nil; listFocused = true })
    }

    private var greeting: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text(Self.greetingText())
                .font(.display(42, relativeTo: .largeTitle))
                .foregroundStyle(Color.inkPrimary)
            Text(Self.fullDate())
                .font(.system(.subheadline, design: .serif)).italic()
                .foregroundStyle(Color.inkSecondary)
        }
        .padding(.top, Space.l)
        .padding(.bottom, Space.xl)
    }

    private static func greetingText() -> String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 0..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default: return "Late night"
        }
    }

    private static func fullDate() -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f.string(from: Date())
    }

    private var hintBar: some View {
        Text("j/k move · space done · e edit · p pin · t·m·1–7 defer · ⌘K capture · ⌘J focus")
            .font(.caption2)
            .foregroundStyle(Color.inkTertiary)
            .padding(.top, Space.l)
    }

    private var searchField: some View {
        HStack(spacing: Space.s) {
            Image(systemName: "magnifyingglass").font(.system(size: 13)).foregroundStyle(Color.inkSecondary)
            TextField("Search tasks", text: $query)
                .textFieldStyle(.plain).font(.system(.body, design: .default)).foregroundStyle(Color.inkPrimary)
                .focused($searchFocused)
            Button(action: closeSearch) {
                Image(systemName: "xmark.circle.fill").foregroundStyle(Color.inkTertiary)
            }.buttonStyle(.plain)
        }
        .padding(.horizontal, Space.m).padding(.vertical, Space.s)
        .background(Capsule().fill(Color.inkPrimary.opacity(0.05)))
        .padding(.bottom, Space.m)
        .onAppear { searchFocused = true }
        .onExitCommand(perform: closeSearch)
    }

    private func closeSearch() { query = ""; searchActive = false; searchFocused = false }

    private func filtered(_ items: [TodoItem]) -> [TodoItem] {
        guard !query.isEmpty else { return items }
        return items.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }

    private func drop(_ idString: String, to day: Date) {
        guard let id = UUID(uuidString: idString), let it = store.item(id) else { return }
        store.move(it, to: day)
    }

    private func focusList() {
        if selectedID == nil { selectedID = store.nextFocusTask()?.id }
        if selectedID != nil {
            listFocused = true
        } else if store.openTasks(on: today).isEmpty && store.completedTasks(on: today).isEmpty {
            focusedDay = today
        }
    }

    // MARK: keyboard layer

    private func navOrder() -> [TodoItem] {
        store.visibleDays.flatMap { filtered(store.openTasks(on: $0)) + filtered(store.completedTasks(on: $0)) }
    }

    private func handleKey(_ press: KeyPress) -> KeyPress.Result {
        guard editingID == nil else { return .ignored }
        let order = navOrder()

        switch press.key {
        case .upArrow: move(-1, order); return .handled
        case .downArrow: move(1, order); return .handled
        case .return: beginEdit(); return .handled
        case .space: complete(); return .handled
        case .delete: deleteSelected(order); return .handled
        case .escape:
            if searchActive { closeSearch() } else { selectedID = nil }
            return .handled
        default:
            break
        }

        if press.modifiers.contains(.command) {
            switch press.characters {
            case "]": nudge(1); return .handled
            case "[": nudge(-1); return .handled
            default: return .ignored
            }
        }

        switch press.characters {
        case "j": move(1, order); return .handled
        case "k": move(-1, order); return .handled
        case "x": complete(); return .handled
        case "e": beginEdit(); return .handled
        case "p": pinSelected(); return .handled
        case "#": deleteSelected(order); return .handled
        case "o", "a": focusedDay = selectedDay() ?? today; return .handled
        case "t": deferSelected(to: today); return .handled
        case "m": deferSelected(to: dayOffset(1)); return .handled
        case "]": nudge(1); return .handled
        case "[": nudge(-1); return .handled
        default: break
        }

        if let n = Int(press.characters), (1...7).contains(n), n - 1 < store.visibleDays.count {
            deferSelected(to: store.visibleDays[n - 1])
            return .handled
        }
        return .ignored
    }

    private func move(_ delta: Int, _ order: [TodoItem]) {
        guard !order.isEmpty else { return }
        if let id = selectedID, let idx = order.firstIndex(where: { $0.id == id }) {
            selectedID = order[max(0, min(order.count - 1, idx + delta))].id
        } else {
            selectedID = delta >= 0 ? order.first?.id : order.last?.id
        }
    }

    private func complete() {
        guard let id = selectedID, let it = store.item(id) else { return }
        // When checking a task off, march the cursor down to the next open task
        // (computed before the toggle reshuffles it into the completed pool), so
        // space-space-space sweeps the list instead of stranding the cursor.
        if !it.isCompleted {
            let openOrder = store.visibleDays.flatMap { filtered(store.openTasks(on: $0)) }
            if let idx = openOrder.firstIndex(where: { $0.id == id }), idx + 1 < openOrder.count {
                let next = openOrder[idx + 1].id
                store.toggle(it)
                selectedID = next
                return
            }
        }
        store.toggle(it)
    }
    private func beginEdit() { if selectedID != nil { editingID = selectedID } }
    private func pinSelected() { if let id = selectedID, let it = store.item(id) { store.togglePin(it) } }

    private func deleteSelected(_ order: [TodoItem]) {
        guard let id = selectedID, let it = store.item(id) else { return }
        if let idx = order.firstIndex(where: { $0.id == id }) {
            let nextIdx = idx + 1 < order.count ? idx + 1 : idx - 1
            selectedID = (nextIdx >= 0 && nextIdx < order.count) ? order[nextIdx].id : nil
        }
        store.delete(it)
    }

    private func selectedDay() -> Date? { selectedID.flatMap { store.item($0)?.day } }
    private func dayOffset(_ n: Int) -> Date { Calendar.current.date(byAdding: .day, value: n, to: today) ?? today }
    private func deferSelected(to day: Date) { if let id = selectedID, let it = store.item(id) { store.move(it, to: day) } }

    private func nudge(_ delta: Int) {
        guard let id = selectedID, let it = store.item(id),
              let target = Calendar.current.date(byAdding: .day, value: delta, to: it.day) else { return }
        if target >= today { store.move(it, to: target) }
    }
}

/// A keyboard-first Mac row: plain text until edited (so the list keeps key
/// focus), with a soft hover wash and selection tint.
private struct MacRow: View {
    @Environment(TaskStore.self) private var store
    let item: TodoItem
    let isFocus: Bool
    let isSelected: Bool
    let isEditing: Bool
    let moveTargets: [Date]
    var onSelect: () -> Void
    var onBeginEdit: () -> Void
    var onEndEdit: () -> Void

    @State private var text: String
    @State private var hovering = false
    @State private var didCommit = false
    @FocusState private var fieldFocused: Bool

    init(item: TodoItem, isFocus: Bool, isSelected: Bool, isEditing: Bool, moveTargets: [Date],
         onSelect: @escaping () -> Void, onBeginEdit: @escaping () -> Void, onEndEdit: @escaping () -> Void) {
        self.item = item
        self.isFocus = isFocus
        self.isSelected = isSelected
        self.isEditing = isEditing
        self.moveTargets = moveTargets
        self.onSelect = onSelect
        self.onBeginEdit = onBeginEdit
        self.onEndEdit = onEndEdit
        _text = State(initialValue: item.title)
    }

    private var textColor: Color {
        if item.isCompleted { return .inkTertiary }
        return isFocus ? .inkPrimary : .inkBody
    }
    private var rowFont: Font { .system(isFocus ? .title2 : .body, design: .default) }

    var body: some View {
        HStack(alignment: .center, spacing: Space.m) {
            Button { store.toggle(item) } label: {
                CompletionToggle(isOn: item.isCompleted)
                    .frame(width: 30, height: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isEditing {
                TextField("", text: $text)
                    .textFieldStyle(.plain)
                    .font(rowFont)
                    .foregroundStyle(textColor)
                    .focused($fieldFocused)
                    .onSubmit(commit)
                    .onExitCommand(perform: commit)
            } else {
                Text(item.title.isEmpty ? " " : item.title)
                    .font(rowFont)
                    .foregroundStyle(textColor)
                    .strikethrough(item.isCompleted, color: .inkTertiary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) { onBeginEdit() }
                    .onTapGesture { onSelect() }
            }

            marks

            if hovering && !isEditing {
                Button { store.delete(item) } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.inkSecondary)
                        .padding(6)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, isFocus ? Space.l : 7)
        .padding(.horizontal, Space.s)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(background))
        .overlay(alignment: .leading) {
            if isSelected {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.accentInk)
                    .frame(width: 3)
                    .padding(.vertical, 5)
            }
        }
        .animation(Motion.settle, value: isFocus)
        .onHover { h in hovering = h; store.setInteracting(item.id, h) }
        .draggable(item.id.uuidString)
        .contextMenu { contextMenu }
        .onChange(of: isEditing) { _, editing in
            if editing { text = item.title; fieldFocused = true; didCommit = false }
        }
        .onChange(of: item.title) { _, t in if !isEditing { text = t } }
        .onChange(of: fieldFocused) { _, focused in
            if !focused && isEditing { commit() }
        }
    }

    private var background: Color {
        if item.isCompleted { return Color.surfacePool.opacity(0.5) }
        if isSelected { return Color.accentInk.opacity(0.06) }
        if hovering { return Color.inkPrimary.opacity(0.035) }
        return .clear
    }

    @ViewBuilder private var marks: some View {
        if item.isPinned || item.recurrence != nil {
            HStack(spacing: 5) {
                if item.isPinned { Image(systemName: "pin.fill").rotationEffect(.degrees(45)) }
                if item.recurrence != nil { Image(systemName: "repeat") }
            }
            .font(.caption2)
            .foregroundStyle(Color.inkTertiary)
        }
    }

    @ViewBuilder private var contextMenu: some View {
        Button(item.isPinned ? "Unpin" : "Pin to top",
               systemImage: item.isPinned ? "pin.slash" : "pin") { store.togglePin(item) }
        Menu("Move to…") {
            ForEach(moveTargets, id: \.self) { day in
                if !Calendar.current.isDate(day, inSameDayAs: item.day) {
                    Button(day.dayLabel) { store.move(item, to: day) }
                }
            }
        }
        Divider()
        Button("Delete", systemImage: "trash", role: .destructive) { store.delete(item) }
    }

    private func commit() {
        guard !didCommit else { return }   // Return + blur can both fire; commit once.
        didCommit = true
        if text != item.title { store.rename(item, to: text) }
        onEndEdit()
    }
}

// MARK: - Command bar (⌘K)

struct CommandBarView: View {
    @Environment(TaskStore.self) private var store
    @Binding var isPresented: Bool

    @State private var text = ""
    @State private var addedCount = 0
    @FocusState private var focused: Bool

    private var today: Date { Calendar.current.startOfDay(for: Date()) }

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.opacity(0.16).ignoresSafeArea().onTapGesture { isPresented = false }

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: Space.m) {
                    Image(systemName: "plus.circle.fill").font(.system(size: 18)).foregroundStyle(Color.accentInk)
                    TextField("Add a task…  try “call Sam friday” or “standup every weekday”", text: $text)
                        .textFieldStyle(.plain)
                        .font(.system(.title3, design: .default))
                        .foregroundStyle(Color.inkPrimary)
                        .focused($focused)
                        .onSubmit(submit)
                }
                .padding(.horizontal, Space.l)
                .padding(.vertical, 14)

                Rectangle().fill(Color.hairline).frame(height: 1)

                HStack(spacing: Space.l) {
                    keycap("return", "add")
                    keycap("esc", "close")
                    if addedCount > 0 {
                        Spacer()
                        Label("\(addedCount) added", systemImage: "checkmark.circle.fill")
                            .font(.caption).foregroundStyle(Color.accentInk)
                    }
                }
                .padding(.horizontal, Space.l)
                .padding(.vertical, Space.s)
            }
            .frame(maxWidth: 540)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.bgCanvas))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.hairline, lineWidth: 1))
            .shadow(color: .black.opacity(0.12), radius: 24, y: 10)
            .padding(.top, 110)
        }
        .onAppear { focused = true }
        .onDisappear { store.requestListRefocus() }
        .onExitCommand { isPresented = false }
    }

    private func submit() {
        let raw = text
        text = ""
        for line in raw.split(whereSeparator: \.isNewline) {
            let t = line.trimmingCharacters(in: .whitespaces)
            guard !t.isEmpty else { continue }
            let rec = DateParser.parseRecurrence(t)
            if let r = rec.recurrence {
                store.add(rec.title, to: rec.day ?? today, recurrence: r)
            } else {
                let p = DateParser.parse(t, reference: today)
                store.add(p.title, to: p.day ?? today)
            }
            addedCount += 1
        }
        focused = true
    }

    private func keycap(_ key: String, _ label: String) -> some View {
        HStack(spacing: 5) {
            Text(key).font(.caption2.monospaced())
                .padding(.horizontal, 5).padding(.vertical, 1)
                .background(RoundedRectangle(cornerRadius: 4).fill(Color.inkPrimary.opacity(0.06)))
            Text(label).font(.caption2)
        }
        .foregroundStyle(Color.inkTertiary)
    }
}

// MARK: - Focus / "now" mode

struct FocusModeView: View {
    @Environment(TaskStore.self) private var store
    @Binding var isPresented: Bool
    @FocusState private var focused: Bool

    var body: some View {
        let task = store.nextFocusTask()
        let remaining = store.visibleDays.reduce(0) { $0 + store.openTasks(on: $1).count }

        ZStack {
            Color.bgCanvas.ignoresSafeArea()
            VStack(spacing: Space.xl) {
                if let task {
                    Text("NOW")
                        .font(.system(.caption, design: .serif)).tracking(4)
                        .foregroundStyle(Color.accentInk)
                    Text(task.title)
                        .font(.system(size: 36, weight: .regular, design: .default))
                        .foregroundStyle(Color.inkPrimary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 80)
                    Button { store.toggle(task) } label: {
                        Label("Complete", systemImage: "checkmark")
                            .font(.system(.body, design: .default))
                            .foregroundStyle(Color.bgCanvas)
                            .padding(.horizontal, Space.xl).padding(.vertical, 10)
                            .background(Capsule().fill(Color.accentInk))
                    }
                    .buttonStyle(.plain)
                    Text("\(remaining) left   ·   return done   ·   → defer   ·   esc exit")
                        .font(.caption).foregroundStyle(Color.inkTertiary)
                } else {
                    Text("All clear.")
                        .font(.display(40, relativeTo: .largeTitle))
                        .foregroundStyle(Color.inkSecondary)
                    Text("esc to exit").font(.caption).foregroundStyle(Color.inkTertiary)
                }
            }
            .padding(40)
        }
        .focusable()
        .focusEffectDisabled()
        .focused($focused)
        .onAppear { focused = true }
        .onDisappear { store.requestListRefocus() }
        .onKeyPress { press in
            switch press.key {
            case .return, .space:
                if let t = store.nextFocusTask() { store.toggle(t) }
                return .handled
            case .rightArrow, .downArrow:
                if let t = store.nextFocusTask(),
                   let tm = Calendar.current.date(byAdding: .day, value: 1, to: t.day) {
                    store.move(t, to: tm)
                }
                return .handled
            case .escape:
                isPresented = false
                return .handled
            default:
                return .ignored
            }
        }
        .onExitCommand { isPresented = false }
    }
}

// MARK: - Menu-bar quick capture

struct CaptureMenuView: View {
    @Environment(TaskStore.self) private var store
    @State private var text = ""
    @State private var added = false
    @FocusState private var focused: Bool

    private var today: Date { Calendar.current.startOfDay(for: Date()) }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text("Quick capture")
                .font(.system(.subheadline, design: .serif).weight(.semibold))
                .foregroundStyle(Color.inkPrimary)
            TextField("Add a task…", text: $text)
                .textFieldStyle(.roundedBorder)
                .frame(width: 260)
                .focused($focused)
                .onSubmit(add)
            Text(added ? "Added ✓" : "↩ to add · date words route it")
                .font(.caption2)
                .foregroundStyle(added ? Color.accentInk : Color.inkTertiary)
        }
        .padding(Space.l)
        .onAppear { focused = true }
    }

    private func add() {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        let rec = DateParser.parseRecurrence(t)
        if let r = rec.recurrence {
            store.add(rec.title, to: rec.day ?? today, recurrence: r)
        } else {
            let p = DateParser.parse(t, reference: today)
            store.add(p.title, to: p.day ?? today)
        }
        text = ""
        added = true
        focused = true
    }
}

// MARK: - Mac week-columns layout (optional, the "plan my week" view)

struct WeekBoardView: View {
    @Environment(TaskStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var focusedDay: Date?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: Space.xxl) {
                ForEach(store.visibleDays, id: \.self) { day in
                    DayColumn(day: day, focusBinding: $focusedDay)
                        .frame(width: 250)
                }
            }
            .padding(.horizontal, Space.xl)
            .padding(.bottom, Space.l)
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .scrollContentBackground(.hidden)
        .animation(reduceMotion ? nil : Motion.settle, value: store.items)
        .onChange(of: store.newTaskToken) { _, _ in
            focusedDay = Calendar.current.startOfDay(for: Date())
        }
    }
}

private struct DayColumn: View {
    @Environment(TaskStore.self) private var store
    let day: Date
    var focusBinding: FocusState<Date?>.Binding

    var body: some View {
        let open = store.openTasks(on: day)
        let done = store.completedTasks(on: day)
        let isToday = Calendar.current.isDateInToday(day)

        VStack(alignment: .leading, spacing: 0) {
            DayMasthead(day: day, onActivate: { focusBinding.wrappedValue = day })
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: Space.xs) {
                    ForEach(open) { item in ColumnRow(item: item) }

                    if open.isEmpty && done.isEmpty && isToday {
                        EmptyLine()
                    }

                    AddRow(day: day, focusBinding: focusBinding)

                    if !done.isEmpty {
                        PoolDivider()
                        ForEach(done) { item in ColumnRow(item: item) }
                    }
                }
                .padding(.bottom, Space.l)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .dropDestination(for: String.self) { ids, _ in
            if let s = ids.first, let id = UUID(uuidString: s), let it = store.item(id) {
                store.move(it, to: day)
            }
            return true
        }
    }
}

private struct ColumnRow: View {
    @Environment(TaskStore.self) private var store
    let item: TodoItem

    var body: some View {
        TaskRowView(
            item: item,
            isFocus: false,
            onToggle: { store.toggle(item) },
            onSubmit: { store.rename(item, to: $0) },
            onDelete: { store.delete(item) },
            onPin: { store.togglePin(item) },
            onInteract: { store.setInteracting(item.id, $0) },
            onMove: { store.move(item, to: $0) },
            moveTargets: store.visibleDays
        )
        .background(item.isCompleted ? Color.surfacePool : Color.clear)
    }
}
#endif
