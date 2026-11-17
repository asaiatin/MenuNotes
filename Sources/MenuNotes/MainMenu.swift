import AppKit

/// A menu bar app has no visible main menu, but AppKit still routes key
/// equivalents (⌘C, ⌘V, ⌘Z, ⌘N…) through it, so we build one.
@MainActor
enum MainMenu {
    static func build(store: NoteStore, closePopover: @escaping () -> Void) -> NSMenu {
        let main = NSMenu()

        // App
        let app = NSMenu()
        app.addItem(NSMenuItem(title: "Quit MenuNotes", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        add(app, to: main)

        // Edit
        let edit = NSMenu(title: "Edit")
        edit.addItem(NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z"))
        let redo = NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        edit.addItem(redo)
        edit.addItem(.separator())
        edit.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        edit.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        edit.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        edit.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        edit.addItem(.separator())
        let find = NSMenuItem(title: "Find…", action: #selector(NSTextView.performFindPanelAction(_:)), keyEquivalent: "f")
        find.tag = Int(NSFindPanelAction.showFindPanel.rawValue)
        edit.addItem(find)
        let findNext = NSMenuItem(title: "Find Next", action: #selector(NSTextView.performFindPanelAction(_:)), keyEquivalent: "g")
        findNext.tag = Int(NSFindPanelAction.next.rawValue)
        edit.addItem(findNext)
        add(edit, to: main)

        // Notes
        let notes = NSMenu(title: "Notes")
        notes.addItem(ActionMenuItem("New Note", key: "n") { store.newNote(); focusEditor() })
        notes.addItem(ActionMenuItem("Close", key: "w") { closePopover() })
        notes.addItem(ActionMenuItem("Previous Note", key: "[") { store.selectAdjacent(-1); focusEditor() })
        notes.addItem(ActionMenuItem("Next Note", key: "]") { store.selectAdjacent(1); focusEditor() })
        for i in 1...9 {
            notes.addItem(ActionMenuItem("Note \(i)", key: "\(i)") { store.select(index: i - 1); focusEditor() })
        }
        notes.addItem(.separator())
        notes.addItem(ActionMenuItem("Bigger Text", key: "=") { Settings.adjustFontSize(+1) })
        notes.addItem(ActionMenuItem("Bigger Text", key: "+") { Settings.adjustFontSize(+1) })
        notes.addItem(ActionMenuItem("Smaller Text", key: "-") { Settings.adjustFontSize(-1) })
        notes.addItem(ActionMenuItem("Default Text Size", key: "0") { Settings.resetFontSize() })
        add(notes, to: main)

        return main
    }

    private static func add(_ submenu: NSMenu, to main: NSMenu) {
        let item = NSMenuItem()
        item.submenu = submenu
        main.addItem(item)
    }

    private static func focusEditor() {
        DispatchQueue.main.async { SmartTextView.active?.focus() }
    }
}

enum Settings {
    static let fontSizeKey = "fontSize"
    static let monospacedKey = "monospaced"
    static let defaultFontSize = 14.0

    static func adjustFontSize(_ delta: Double) {
        let current = UserDefaults.standard.object(forKey: fontSizeKey) as? Double ?? defaultFontSize
        UserDefaults.standard.set(min(28, max(10, current + delta)), forKey: fontSizeKey)
    }

    static func resetFontSize() {
        UserDefaults.standard.set(defaultFontSize, forKey: fontSizeKey)
    }
}
