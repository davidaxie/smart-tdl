import SwiftUI

/// One task. Type size/color/air are a function of `isFocus` (the Focus Slot is
/// a promoted state of the ordinary row). Pin and recurrence show as quiet marks,
/// never badges. Draggable for reschedule; selectable for the keyboard layer.
struct TaskRowView: View {
    let item: TodoItem
    let isFocus: Bool
    var isSelected: Bool = false
    let onToggle: () -> Void
    let onSubmit: (String) -> Void
    let onDelete: () -> Void
    var onPin: () -> Void = {}
    var onInteract: (Bool) -> Void = { _ in }
    var onMove: (Date) -> Void = { _ in }
    var moveTargets: [Date] = []

    @State private var text: String
    @FocusState private var focused: Bool
    #if os(macOS)
    @State private var hovering = false
    #endif

    init(item: TodoItem,
         isFocus: Bool,
         isSelected: Bool = false,
         onToggle: @escaping () -> Void,
         onSubmit: @escaping (String) -> Void,
         onDelete: @escaping () -> Void,
         onPin: @escaping () -> Void = {},
         onInteract: @escaping (Bool) -> Void = { _ in },
         onMove: @escaping (Date) -> Void = { _ in },
         moveTargets: [Date] = []) {
        self.item = item
        self.isFocus = isFocus
        self.isSelected = isSelected
        self.onToggle = onToggle
        self.onSubmit = onSubmit
        self.onDelete = onDelete
        self.onPin = onPin
        self.onInteract = onInteract
        self.onMove = onMove
        self.moveTargets = moveTargets
        _text = State(initialValue: item.title)
    }

    private var textColor: Color {
        if item.isCompleted { return .inkTertiary }
        return isFocus ? .inkPrimary : .inkBody
    }

    private var rowFont: Font {
        .system(isFocus ? .title2 : .body, design: .default)
    }

    var body: some View {
        HStack(alignment: .center, spacing: Space.m) {
            Button(action: onToggle) {
                CompletionToggle(isOn: item.isCompleted)
                    .frame(width: 34, height: 34)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressScaleStyle())
            .accessibilityLabel(item.isCompleted ? "Mark as not done" : "Mark as done")

            TextField("", text: $text)
                .textFieldStyle(.plain)
                .font(rowFont)
                .foregroundStyle(textColor)
                .strikethrough(item.isCompleted, color: .inkTertiary)
                .lineSpacing(isFocus ? 5 : 3)
                .focused($focused)
                .onSubmit(commit)
                #if os(iOS)
                .submitLabel(.done)
                #endif

            marks

            #if os(macOS)
            if hovering && !focused {
                Button(action: onDelete) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.inkSecondary)
                        .padding(6)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }
            #endif
        }
        .padding(.vertical, isFocus ? Space.xxl : Space.m)
        .animation(Motion.settle, value: isFocus)
        .contentShape(Rectangle())
        .draggable(item.id.uuidString)
        #if os(macOS)
        .onHover { h in
            withAnimation(.easeOut(duration: 0.15)) { hovering = h }
            onInteract(focused || h)
        }
        #endif
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button(action: onToggle) {
                Label(item.isCompleted ? "Reopen" : "Done", systemImage: "checkmark")
            }
            .tint(Color.accentInk)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
            Button(action: onPin) {
                Label(item.isPinned ? "Unpin" : "Pin", systemImage: "pin")
            }
            .tint(Color.accentInk)
        }
        .contextMenu { contextMenu }
        .sensoryFeedback(.success, trigger: item.isCompleted)
        .onChange(of: focused) { _, isFocused in
            #if os(macOS)
            onInteract(isFocused || hovering)
            #else
            onInteract(isFocused)
            #endif
            if !isFocused { commit() }
        }
        .onChange(of: item.title) { _, newTitle in
            if !focused { text = newTitle }
        }
    }

    @ViewBuilder private var marks: some View {
        if item.isPinned || item.recurrence != nil {
            HStack(spacing: 5) {
                if item.isPinned {
                    Image(systemName: "pin.fill")
                        .rotationEffect(.degrees(45))
                }
                if item.recurrence != nil {
                    Image(systemName: "repeat")
                }
            }
            .font(.caption2)
            .foregroundStyle(Color.inkTertiary)
        }
    }

    @ViewBuilder private var contextMenu: some View {
        Button(item.isPinned ? "Unpin" : "Pin to top",
               systemImage: item.isPinned ? "pin.slash" : "pin",
               action: onPin)
        if !moveTargets.isEmpty {
            Menu("Move to…") {
                ForEach(moveTargets, id: \.self) { day in
                    if !Calendar.current.isDate(day, inSameDayAs: item.day) {
                        Button(day.dayLabel) { onMove(day) }
                    }
                }
            }
        }
        Divider()
        Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
    }

    private func commit() {
        if text != item.title { onSubmit(text) }
    }
}

/// Circle that fills with terracotta and draws an ink-stroke checkmark on
/// completion (< 150ms). Bounce allowed here — it's user-initiated.
struct CompletionToggle: View {
    let isOn: Bool

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(isOn ? Color.accentInk : Color.inkSecondary.opacity(0.55), lineWidth: 1.6)
            Circle()
                .fill(Color.accentInk)
                .scaleEffect(isOn ? 1 : 0.01)
                .opacity(isOn ? 1 : 0)
            Checkmark()
                .trim(from: 0, to: isOn ? 1 : 0)
                .stroke(Color.bgCanvas, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                .frame(width: 11, height: 9)
                .opacity(isOn ? 1 : 0)
        }
        .frame(width: 20, height: 20)
        .animation(Motion.complete, value: isOn)
    }
}

private struct Checkmark: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.midY + r.height * 0.08))
        p.addLine(to: CGPoint(x: r.minX + r.width * 0.36, y: r.maxY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        return p
    }
}

private struct PressScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.8 : 1)
            .animation(Motion.press, value: configuration.isPressed)
    }
}
