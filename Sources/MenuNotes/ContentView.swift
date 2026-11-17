import SwiftUI

struct ContentView: View {
    static let size = CGSize(width: 400, height: 480)

    @EnvironmentObject private var store: NoteStore
    @EnvironmentObject private var ui: UIState
    @AppStorage(Settings.fontSizeKey) private var fontSize = Settings.defaultFontSize
    @AppStorage(Settings.monospacedKey) private var monospaced = false
    @State private var launchAtLogin = LoginItem.isEnabled

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.6)
            if let note = store.selected {
                EditorView(
                    text: Binding(
                        get: { store.text(for: note.id) },
                        set: { store.update(note.id, text: $0) }
                    ),
                    noteID: note.id,
                    fontSize: fontSize,
                    monospaced: monospaced,
                    onEscape: ui.close
                )
            }
            footer
        }
        .frame(width: Self.size.width, height: Self.size.height)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 4) {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 2) {
                        ForEach(store.notes) { note in
                            TabPill(
                                title: note.title,
                                isSelected: note.id == store.selectedID,
                                select: { store.select(note.id) },
                                delete: { store.delete(note.id) }
                            )
                            .id(note.id)
                        }
                    }
                    .padding(.horizontal, 6)
                }
                .onChange(of: store.selectedID) { id in
                    withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(id) }
                }
            }

            IconButton(symbol: "plus", help: "New Note (⌘N)") {
                store.newNote()
                DispatchQueue.main.async { SmartTextView.active?.focus() }
            }
            IconButton(symbol: ui.pinned ? "pin.fill" : "pin",
                       help: ui.pinned ? "Unpin (closes when you click away)" : "Pin (stay open)",
                       active: ui.pinned) {
                ui.pinned.toggle()
            }
            optionsMenu
        }
        .padding(.leading, 2)
        .padding(.trailing, 8)
        .frame(height: 40)
    }

    private var optionsMenu: some View {
        Menu {
            if let note = store.selected {
                Button("Copy Note") { store.copyToClipboard(note.id) }
                Button("Show in Finder") { store.revealInFinder() }
                Button("Delete Note") { store.delete(note.id) }
                Divider()
            }
            Toggle("Monospaced Font", isOn: $monospaced)
            Button("Bigger Text") { Settings.adjustFontSize(+1) }
            Button("Smaller Text") { Settings.adjustFontSize(-1) }
            Divider()
            Toggle("Launch at Login", isOn: Binding(
                get: { launchAtLogin },
                set: { LoginItem.set($0); launchAtLogin = LoginItem.isEnabled }
            ))
            Divider()
            Button("Quit MenuNotes") { NSApp.terminate(nil) }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 13, weight: .medium))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .frame(width: 26, height: 26)
        .help("More")
    }

    // MARK: Footer

    private var footer: some View {
        HStack {
            Text(stats)
                .monospacedDigit()
            Spacer()
            HStack(spacing: 5) {
                Circle()
                    .fill(store.isSaving ? Color.orange : Color.green)
                    .frame(width: 5, height: 5)
                    .opacity(0.8)
                Text(store.isSaving ? "Saving" : "Saved")
            }
            .animation(.easeInOut(duration: 0.2), value: store.isSaving)
        }
        .font(.system(size: 11))
        .foregroundStyle(.tertiary)
        .padding(.horizontal, 14)
        .frame(height: 28)
    }

    private var stats: String {
        let text = store.selected?.text ?? ""
        let words = text.split { $0.isWhitespace || $0.isNewline }.count
        return "\(words) \(words == 1 ? "word" : "words") · \(text.count) chars"
    }
}

// MARK: - Components

private struct TabPill: View {
    let title: String
    let isSelected: Bool
    let select: () -> Void
    let delete: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: select) {
            Text(title)
                .font(.system(size: 12, weight: isSelected ? .medium : .regular))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: 120)
                .foregroundStyle(isSelected ? .primary : .secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule().fill(Color.primary.opacity(isSelected ? 0.09 : (hovering ? 0.05 : 0)))
                )
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .contextMenu {
            Button("Delete Note", action: delete)
        }
    }
}

private struct IconButton: View {
    let symbol: String
    let help: String
    var active = false
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(active ? Color.accentColor : (hovering ? Color.primary : Color.secondary))
                .frame(width: 26, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(hovering ? 0.06 : 0))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(help)
    }
}
