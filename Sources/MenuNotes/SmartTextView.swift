import AppKit

enum Markdown {
    /// indent, marker, gap, optional checkbox
    static let listItem = try! NSRegularExpression(
        pattern: #"^([ \t]*)([-*+•]|\d{1,9}[.)])([ \t]+)(\[[ xX]\](?:[ \t]+|$))?"#
    )
    static let heading = try! NSRegularExpression(pattern: #"^(#{1,6})[ \t]+\S"#)
    static let quote = try! NSRegularExpression(pattern: #"^[ \t]*>"#)
    static let inlineCode = try! NSRegularExpression(pattern: #"`[^`\n]+`"#)
    static let links = try! NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
}

/// Plain-text editor with smart list handling and light Markdown styling.
/// The file on disk always stays plain Markdown; styling is display-only.
final class SmartTextView: NSTextView, NSTextStorageDelegate {
    static weak var active: SmartTextView?

    var onEscape: (() -> Void)?
    var baseFontSize: CGFloat = 14
    var monospaced = false

    // MARK: Setup

    func configure() {
        isRichText = false
        importsGraphics = false
        allowsUndo = true
        drawsBackground = false
        isAutomaticQuoteSubstitutionEnabled = false
        isAutomaticDashSubstitutionEnabled = false
        isAutomaticTextReplacementEnabled = false
        isAutomaticSpellingCorrectionEnabled = false
        isAutomaticLinkDetectionEnabled = false
        isContinuousSpellCheckingEnabled = false
        smartInsertDeleteEnabled = true
        usesFindBar = true
        isIncrementalSearchingEnabled = true
        textContainerInset = NSSize(width: 12, height: 12)
        textContainer?.lineFragmentPadding = 4
        insertionPointColor = .controlAccentColor
        linkTextAttributes = [
            .foregroundColor: NSColor.linkColor,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .cursor: NSCursor.pointingHand,
        ]
        textStorage?.delegate = self
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil { SmartTextView.active = self }
    }

    func focus() {
        window?.makeFirstResponder(self)
    }

    func applyAppearance() {
        typingAttributes = baseAttributes
        if let storage = textStorage {
            restyle(storage, range: NSRange(location: 0, length: storage.length))
        }
    }

    // MARK: Styling

    private func font(size: CGFloat? = nil, weight: NSFont.Weight = .regular, mono: Bool? = nil) -> NSFont {
        let s = size ?? baseFontSize
        return (mono ?? monospaced)
            ? .monospacedSystemFont(ofSize: s, weight: weight)
            : .systemFont(ofSize: s, weight: weight)
    }

    private var paragraphStyle: NSParagraphStyle {
        let p = NSMutableParagraphStyle()
        p.lineSpacing = round(baseFontSize * 0.28)
        p.paragraphSpacing = round(baseFontSize * 0.12)
        p.tabStops = []
        p.defaultTabInterval = baseFontSize * 1.7
        return p
    }

    private var baseAttributes: [NSAttributedString.Key: Any] {
        [.font: font(), .foregroundColor: NSColor.labelColor, .paragraphStyle: paragraphStyle]
    }

    func textStorage(
        _ textStorage: NSTextStorage, didProcessEditing editedMask: NSTextStorageEditActions,
        range editedRange: NSRange, changeInLength delta: Int
    ) {
        guard editedMask.contains(.editedCharacters) else { return }
        let range = (textStorage.string as NSString).paragraphRange(for: editedRange)
        restyle(textStorage, range: range)
    }

    private func restyle(_ storage: NSTextStorage, range: NSRange) {
        guard range.length > 0, NSMaxRange(range) <= storage.length else { return }
        let text = storage.string as NSString
        storage.setAttributes(baseAttributes, range: range)

        text.enumerateSubstrings(in: range, options: [.byParagraphs]) { line, lineRange, _, _ in
            guard let line else { return }
            let ns = line as NSString
            let all = NSRange(location: 0, length: ns.length)
            func abs(_ r: NSRange) -> NSRange { NSRange(location: lineRange.location + r.location, length: r.length) }

            if let m = Markdown.heading.firstMatch(in: line, range: all) {
                let level = m.range(at: 1).length
                let size = self.baseFontSize + CGFloat(max(0, 4 - level)) * 1.5
                storage.addAttribute(.font, value: self.font(size: size, weight: .semibold), range: lineRange)
                storage.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: abs(m.range(at: 1)))
            } else if let m = Markdown.listItem.firstMatch(in: line, range: all) {
                storage.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: abs(m.range(at: 2)))
                let box = m.range(at: 4)
                if box.location != NSNotFound {
                    let boxRange = abs(NSRange(location: box.location, length: 3))
                    let checked = ns.substring(with: NSRange(location: box.location + 1, length: 1)) != " "
                    storage.addAttribute(.foregroundColor,
                                         value: checked ? NSColor.tertiaryLabelColor : NSColor.controlAccentColor,
                                         range: boxRange)
                    let contentStart = NSMaxRange(m.range)
                    if checked, contentStart < ns.length {
                        let content = abs(NSRange(location: contentStart, length: ns.length - contentStart))
                        storage.addAttributes([
                            .foregroundColor: NSColor.tertiaryLabelColor,
                            .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                        ], range: content)
                    }
                }
            } else if Markdown.quote.firstMatch(in: line, range: all) != nil {
                storage.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: lineRange)
            }

            for m in Markdown.inlineCode.matches(in: line, range: all) {
                storage.addAttributes([
                    .font: self.font(size: self.baseFontSize * 0.92, mono: true),
                    .backgroundColor: NSColor.quaternaryLabelColor.withAlphaComponent(0.12),
                ], range: abs(m.range))
            }
        }

        Markdown.links.enumerateMatches(in: storage.string, range: range) { result, _, _ in
            guard let result, let url = result.url else { return }
            storage.addAttribute(.link, value: url, range: result.range)
        }
    }

    // MARK: Smart editing

    /// Range of the line containing `location`, without the line break.
    private func lineRange(at location: Int) -> NSRange {
        let ns = string as NSString
        var start = 0, end = 0, contentsEnd = 0
        ns.getLineStart(&start, end: &end, contentsEnd: &contentsEnd, for: NSRange(location: location, length: 0))
        return NSRange(location: start, length: contentsEnd - start)
    }

    private func listMatch(in line: String) -> NSTextCheckingResult? {
        Markdown.listItem.firstMatch(in: line, range: NSRange(location: 0, length: (line as NSString).length))
    }

    private func replace(_ range: NSRange, with replacement: String) {
        guard shouldChangeText(in: range, replacementString: replacement) else { return }
        textStorage?.replaceCharacters(in: range, with: replacement)
        didChangeText()
    }

    override func insertNewline(_ sender: Any?) {
        let sel = selectedRange()
        guard sel.length == 0 else { return super.insertNewline(sender) }

        let lr = lineRange(at: sel.location)
        let line = (string as NSString).substring(with: lr)
        let cursor = sel.location - lr.location

        if let m = listMatch(in: line), cursor >= m.range.length {
            let l = line as NSString
            let content = l.substring(from: m.range.length).trimmingCharacters(in: .whitespaces)
            if content.isEmpty {
                // Return on an empty item: outdent if nested, otherwise end the list.
                if m.range(at: 1).length > 0 {
                    shiftLines(by: -1)
                } else {
                    replace(lr, with: "")
                    setSelectedRange(NSRange(location: lr.location, length: 0))
                }
                return
            }
            var marker = l.substring(with: m.range(at: 2))
            if let n = Int(marker.dropLast()), let delimiter = marker.last {
                marker = "\(n + 1)\(delimiter)"
            }
            let box = m.range(at: 4).location != NSNotFound ? "[ ] " : ""
            let next = l.substring(with: m.range(at: 1)) + marker + l.substring(with: m.range(at: 3)) + box
            insertText("\n" + next, replacementRange: sel)
            return
        }

        // Keep indentation on plain lines.
        let indent = String(line.prefix { $0 == " " || $0 == "\t" }.prefix(cursor))
        if indent.isEmpty {
            super.insertNewline(sender)
        } else {
            insertText("\n" + indent, replacementRange: sel)
        }
    }

    override func insertTab(_ sender: Any?) {
        let sel = selectedRange()
        let ns = string as NSString
        let multiLine = sel.length > 0 && ns.substring(with: sel).contains("\n")
        let onListItem = listMatch(in: ns.substring(with: lineRange(at: sel.location))) != nil
        if multiLine || onListItem {
            shiftLines(by: 1)
        } else {
            super.insertTab(sender)
        }
    }

    override func insertBacktab(_ sender: Any?) {
        shiftLines(by: -1)
    }

    /// Indent (+1) or outdent (-1) every line touched by the selection.
    private func shiftLines(by direction: Int) {
        let ns = string as NSString
        let sel = selectedRange()
        let block = ns.lineRange(for: sel)
        let original = ns.substring(with: block)
        let endsWithNewline = original.hasSuffix("\n")
        var lines = original.components(separatedBy: "\n")
        var firstDelta = 0

        for i in lines.indices {
            if endsWithNewline && i == lines.count - 1 { continue }
            var delta = 0
            if direction > 0 {
                lines[i] = "\t" + lines[i]
                delta = 1
            } else if lines[i].hasPrefix("\t") {
                lines[i].removeFirst()
                delta = -1
            } else {
                let spaces = min(4, lines[i].prefix { $0 == " " }.count)
                lines[i].removeFirst(spaces)
                delta = -spaces
            }
            if i == 0 { firstDelta = delta }
        }

        let updated = lines.joined(separator: "\n")
        guard updated != original else { return }
        replace(block, with: updated)

        if sel.length == 0 {
            setSelectedRange(NSRange(location: max(block.location, sel.location + firstDelta), length: 0))
        } else {
            let length = (updated as NSString).length - (endsWithNewline ? 1 : 0)
            setSelectedRange(NSRange(location: block.location, length: max(0, length)))
        }
    }

    /// Ticks/unticks a checkbox, or turns the line into a checkbox item.
    func toggleCheckbox(at location: Int) {
        let sel = selectedRange()
        let lr = lineRange(at: location)
        let line = (string as NSString).substring(with: lr)

        if let m = listMatch(in: line) {
            let box = m.range(at: 4)
            if box.location != NSNotFound {
                let mark = NSRange(location: lr.location + box.location + 1, length: 1)
                let checked = (string as NSString).substring(with: mark) != " "
                replace(mark, with: checked ? " " : "x")
                setSelectedRange(sel)
            } else {
                let at = lr.location + m.range.length
                replace(NSRange(location: at, length: 0), with: "[ ] ")
                setSelectedRange(NSRange(location: sel.location >= at ? sel.location + 4 : sel.location, length: 0))
            }
        } else {
            let at = lr.location + line.prefix { $0 == " " || $0 == "\t" }.utf16.count
            replace(NSRange(location: at, length: 0), with: "- [ ] ")
            setSelectedRange(NSRange(location: sel.location >= at ? sel.location + 6 : sel.location, length: 0))
        }
    }

    private func checkboxRange(at index: Int) -> NSRange? {
        guard index <= (string as NSString).length else { return nil }
        let lr = lineRange(at: index)
        let line = (string as NSString).substring(with: lr)
        guard let m = listMatch(in: line), m.range(at: 4).location != NSNotFound else { return nil }
        let r = NSRange(location: lr.location + m.range(at: 4).location, length: 3)
        return (index >= r.location && index < NSMaxRange(r)) ? r : nil
    }

    // Typing "[]" + space at the start of a line makes a checkbox.
    override func insertText(_ insertString: Any, replacementRange: NSRange) {
        if let s = insertString as? String, s == " ", replacementRange.location == NSNotFound {
            let sel = selectedRange()
            if sel.length == 0 {
                let lr = lineRange(at: sel.location)
                let before = (string as NSString).substring(with: NSRange(location: lr.location, length: sel.location - lr.location))
                if before.trimmingCharacters(in: .whitespaces) == "[]" {
                    let start = lr.location + (before as NSString).range(of: "[]").location
                    super.insertText("- [ ] ", replacementRange: NSRange(location: start, length: sel.location - start))
                    return
                }
            }
        }
        super.insertText(insertString, replacementRange: replacementRange)
    }

    // MARK: Events

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 1, event.modifierFlags.intersection([.shift, .command]).isEmpty {
            let point = convert(event.locationInWindow, from: nil)
            let index = characterIndexForInsertion(at: point)
            if let box = checkboxRange(at: index) {
                focus()
                toggleCheckbox(at: box.location)
                return
            }
        }
        super.mouseDown(with: event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if event.keyCode == 36, flags == .command, window?.firstResponder === self {
            toggleCheckbox(at: selectedRange().location)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    override func cancelOperation(_ sender: Any?) {
        onEscape?()
    }
}
