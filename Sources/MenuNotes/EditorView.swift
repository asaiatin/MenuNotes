import AppKit
import SwiftUI

/// Bridges SmartTextView into SwiftUI.
struct EditorView: NSViewRepresentable {
    @Binding var text: String
    let noteID: String
    let fontSize: Double
    let monospaced: Bool
    let onEscape: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.borderType = .noBorder
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.scrollerStyle = .overlay

        let tv = SmartTextView(frame: NSRect(origin: .zero, size: scroll.contentSize))
        tv.minSize = .zero
        tv.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = false
        tv.autoresizingMask = [.width]
        tv.textContainer?.widthTracksTextView = true
        tv.baseFontSize = fontSize
        tv.monospaced = monospaced
        tv.onEscape = onEscape
        tv.configure()
        tv.delegate = context.coordinator
        tv.string = text
        tv.applyAppearance()
        tv.setSelectedRange(NSRange(location: (text as NSString).length, length: 0))

        context.coordinator.noteID = noteID
        scroll.documentView = tv
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let tv = scroll.documentView as? SmartTextView else { return }
        tv.onEscape = onEscape

        if tv.baseFontSize != fontSize || tv.monospaced != monospaced {
            tv.baseFontSize = fontSize
            tv.monospaced = monospaced
            tv.applyAppearance()
        }

        if context.coordinator.noteID != noteID {
            // Switched notes: load fresh text, reset undo, put cursor at the end.
            context.coordinator.noteID = noteID
            tv.string = text
            tv.undoManager?.removeAllActions()
            let end = NSRange(location: (text as NSString).length, length: 0)
            tv.setSelectedRange(end)
            tv.scrollRangeToVisible(end)
            tv.focus()
        } else if tv.string != text {
            // Changed on disk while not being edited.
            let sel = tv.selectedRange()
            tv.string = text
            tv.undoManager?.removeAllActions()
            tv.setSelectedRange(NSRange(location: min(sel.location, (text as NSString).length), length: 0))
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: EditorView
        var noteID = ""

        init(_ parent: EditorView) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            parent.text = tv.string
        }
    }
}
