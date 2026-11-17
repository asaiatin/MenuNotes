import AppKit
import ServiceManagement

struct Note: Identifiable, Equatable {
    let id: String
    var text: String
    var created: Date

    private static let prefixPattern = try! NSRegularExpression(
        pattern: #"^[\s#>*+•-]*(\d+[.)]\s*)?(\[[ xX]\]\s*)?"#
    )

    /// First non-empty line, stripped of Markdown markers.
    var title: String {
        for raw in text.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = String(raw)
            let ns = line as NSString
            let match = Note.prefixPattern.firstMatch(in: line, range: NSRange(location: 0, length: ns.length))
            let stripped = ns.substring(from: match?.range.length ?? 0).trimmingCharacters(in: .whitespaces)
            if !stripped.isEmpty { return String(stripped.prefix(28)) }
        }
        return "Untitled"
    }

    var isBlank: Bool { text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}

/// Keeps notes as plain `.md` files in
/// ~/Library/Application Support/MenuNotes/Notes and saves them as you type.
@MainActor
final class NoteStore: ObservableObject {
    @Published private(set) var notes: [Note] = []
    @Published private(set) var selectedID: String = ""
    @Published private(set) var isSaving = false

    let folder: URL
    private var pendingSaves: [String: DispatchWorkItem] = [:]
    private let fm = FileManager.default
    private let saveDelay: TimeInterval = 0.4

    private enum Keys {
        static let order = "noteOrder"
        static let selected = "selectedNote"
        static let launched = "hasLaunchedBefore"
    }

    init() {
        let support = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        folder = support.appendingPathComponent("MenuNotes/Notes", isDirectory: true)
        try? fm.createDirectory(at: folder, withIntermediateDirectories: true)

        load()
        if notes.isEmpty {
            let first = !UserDefaults.standard.bool(forKey: Keys.launched)
            createNote(text: first ? Note.welcome : "")
            UserDefaults.standard.set(true, forKey: Keys.launched)
        }
        let saved = UserDefaults.standard.string(forKey: Keys.selected) ?? ""
        selectedID = notes.contains { $0.id == saved } ? saved : notes[0].id
    }

    var selected: Note? { notes.first { $0.id == selectedID } }

    // MARK: Editing

    func text(for id: String) -> String {
        notes.first { $0.id == id }?.text ?? ""
    }

    func update(_ id: String, text: String) {
        guard let i = notes.firstIndex(where: { $0.id == id }), notes[i].text != text else { return }
        notes[i].text = text
        scheduleSave(id)
    }

    func newNote() {
        // Don't pile up blank tabs: reuse the current one if it's empty.
        if let current = selected, current.isBlank { return }
        createNote(text: "")
    }

    func select(_ id: String) {
        guard id != selectedID, notes.contains(where: { $0.id == id }) else { return }
        let previous = selectedID
        selectedID = id
        UserDefaults.standard.set(id, forKey: Keys.selected)
        discardIfBlank(previous)
    }

    func select(index: Int) {
        guard notes.indices.contains(index) else { return }
        select(notes[index].id)
    }

    func selectAdjacent(_ offset: Int) {
        guard let i = notes.firstIndex(where: { $0.id == selectedID }), notes.count > 1 else { return }
        select(notes[(i + offset + notes.count) % notes.count].id)
    }

    /// Moves the note's file to the Trash so it can be recovered.
    func delete(_ id: String) {
        guard let i = notes.firstIndex(where: { $0.id == id }) else { return }
        cancelSave(id)
        try? fm.trashItem(at: url(for: id), resultingItemURL: nil)
        notes.remove(at: i)
        saveOrder()
        if notes.isEmpty {
            createNote(text: "")
        } else if selectedID == id {
            selectedID = notes[min(i, notes.count - 1)].id
            UserDefaults.standard.set(selectedID, forKey: Keys.selected)
        }
    }

    func copyToClipboard(_ id: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text(for: id), forType: .string)
    }

    func revealInFinder() {
        flush()
        if let selected {
            NSWorkspace.shared.activateFileViewerSelecting([url(for: selected.id)])
        } else {
            NSWorkspace.shared.open(folder)
        }
    }

    // MARK: Persistence

    func flush() {
        for (id, work) in pendingSaves {
            work.cancel()
            write(id)
        }
        pendingSaves.removeAll()
        isSaving = false
    }

    /// Picks up files that were added or edited outside the app.
    func reloadFromDisk() {
        guard pendingSaves.isEmpty else { return }
        let before = notes
        load()
        if notes.isEmpty { notes = before; return }
        if !notes.contains(where: { $0.id == selectedID }) { selectedID = notes[0].id }
    }

    private func load() {
        let urls = (try? fm.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: [.creationDateKey], options: [.skipsHiddenFiles]
        )) ?? []
        var loaded: [Note] = urls.filter { $0.pathExtension.lowercased() == "md" }.compactMap { url in
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
            let created = (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            return Note(id: url.deletingPathExtension().lastPathComponent, text: text, created: created)
        }
        let order = UserDefaults.standard.stringArray(forKey: Keys.order) ?? []
        loaded.sort { a, b in
            let ia = order.firstIndex(of: a.id) ?? .max
            let ib = order.firstIndex(of: b.id) ?? .max
            return ia != ib ? ia < ib : a.created < b.created
        }
        notes = loaded
    }

    private func createNote(text: String) {
        let note = Note(id: Self.makeID(), text: text, created: Date())
        notes.append(note)
        write(note.id)
        saveOrder()
        let previous = selectedID
        selectedID = note.id
        UserDefaults.standard.set(note.id, forKey: Keys.selected)
        discardIfBlank(previous)
    }

    private func discardIfBlank(_ id: String) {
        guard notes.count > 1, let i = notes.firstIndex(where: { $0.id == id }), notes[i].isBlank else { return }
        cancelSave(id)
        try? fm.removeItem(at: url(for: id))
        notes.remove(at: i)
        saveOrder()
    }

    private func scheduleSave(_ id: String) {
        pendingSaves[id]?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.pendingSaves[id] = nil
            self.write(id)
            self.isSaving = !self.pendingSaves.isEmpty
        }
        pendingSaves[id] = work
        isSaving = true
        DispatchQueue.main.asyncAfter(deadline: .now() + saveDelay, execute: work)
    }

    private func cancelSave(_ id: String) {
        pendingSaves[id]?.cancel()
        pendingSaves[id] = nil
        isSaving = !pendingSaves.isEmpty
    }

    private func write(_ id: String) {
        guard let note = notes.first(where: { $0.id == id }) else { return }
        do {
            try note.text.write(to: url(for: id), atomically: true, encoding: .utf8)
        } catch {
            NSLog("MenuNotes: failed to save \(id): \(error)")
        }
    }

    private func saveOrder() {
        UserDefaults.standard.set(notes.map(\.id), forKey: Keys.order)
    }

    private func url(for id: String) -> URL {
        folder.appendingPathComponent(id).appendingPathExtension("md")
    }

    private static func makeID() -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyyMMdd-HHmmss"
        let suffix = UUID().uuidString.prefix(4).lowercased()
        return "note-\(f.string(from: Date()))-\(suffix)"
    }
}

enum LoginItem {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    static func set(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("MenuNotes: launch at login failed: \(error)")
        }
    }
}

extension Note {
    static let welcome = """
    # Welcome to MenuNotes

    A tiny scratchpad that lives in your menu bar. Everything saves as you type.

    ## Smart editing
    - Lists continue when you press Return
    - Press Return on an empty item to end the list
    - Tab / Shift-Tab indents list items
    - [ ] Type [] and a space to make a checkbox
    - [x] Click a box (or press ⌘↩) to tick it off
    - Links like https://github.com are clickable

    ## Shortcuts
    - ⌥⌘N  show or hide from anywhere
    - ⌘N  new note, ⌘1–9 jump to a note
    - ⌘[ and ⌘]  previous and next note
    - ⌘+ and ⌘−  text size
    - ⌘F  find, Esc  close

    Notes are plain Markdown files. Open ··· → Show in Finder to see them.
    """
}
