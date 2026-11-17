import AppKit
import Carbon.HIToolbox
import SwiftUI

@main
enum MenuNotesApp {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory) // menu bar only, no Dock icon
        withExtendedLifetime(delegate) { app.run() }
    }
}

/// Small bit of UI state shared between AppKit and SwiftUI.
@MainActor
final class UIState: ObservableObject {
    @Published var pinned = false { didSet { onPinChange?(pinned) } }
    var onPinChange: ((Bool) -> Void)?
    var close: () -> Void = {}
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    let store = NoteStore()
    let ui = UIState()
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var hotKey: HotKey?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = MainMenu.build(store: store, closePopover: { [weak self] in self?.closePopover() })

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "note.text", accessibilityDescription: "MenuNotes")
            button.image?.isTemplate = true
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        popover.contentSize = NSSize(width: ContentView.size.width, height: ContentView.size.height)
        popover.contentViewController = NSHostingController(
            rootView: ContentView().environmentObject(store).environmentObject(ui)
        )

        ui.close = { [weak self] in self?.closePopover() }
        ui.onPinChange = { [weak self] pinned in
            self?.popover.behavior = pinned ? .applicationDefined : .transient
        }

        // ⌥⌘N toggles the popover from anywhere.
        hotKey = HotKey(keyCode: UInt32(kVK_ANSI_N), modifiers: UInt32(cmdKey | optionKey)) { [weak self] in
            self?.togglePopover()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.flush()
    }

    // MARK: Popover

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    private func togglePopover() {
        popover.isShown ? closePopover() : showPopover()
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }
        store.reloadFromDisk()
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
        DispatchQueue.main.async { SmartTextView.active?.focus() }
    }

    private func closePopover() {
        popover.performClose(nil)
    }

    func popoverDidClose(_ notification: Notification) {
        store.flush()
    }

    private func showContextMenu() {
        let menu = NSMenu()
        menu.addItem(ActionMenuItem("New Note") { [weak self] in
            self?.store.newNote()
            self?.showPopover()
        })
        menu.addItem(ActionMenuItem("Show Notes in Finder") { [weak self] in
            self?.store.revealInFinder()
        })
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit MenuNotes", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }
}

/// NSMenuItem that runs a closure.
final class ActionMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(_ title: String, key: String = "", modifiers: NSEvent.ModifierFlags = .command, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(fire), keyEquivalent: key)
        keyEquivalentModifierMask = modifiers
        target = self
    }

    required init(coder: NSCoder) { fatalError("not supported") }

    @objc private func fire() { handler() }
}
