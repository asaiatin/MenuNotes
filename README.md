# MenuNotes

A tiny, fast scratchpad that lives in your Mac menu bar. Click the icon (or press **⌥⌘N** anywhere), type, and close. It saves as you type.

- **Lives in the menu bar.** No Dock icon and no windows to manage.
- **Saves as you type.** Notes are written to disk moments after you stop typing, and again when you close the popover or quit.
- **Plain Markdown files.** Your notes are ordinary `.md` files in `~/Library/Application Support/MenuNotes/Notes`. Sync, back up or grep them however you like. Changes made outside the app show up the next time you open it.
- **Smart editing**
  - `-`, `*`, `1.` and `- [ ]` lists continue when you press Return. Return on an empty item ends the list.
  - Tab / Shift-Tab indents and outdents list items or any selected lines.
  - Type `[]` + space to make a checkbox. Click it or press **⌘↩** to tick it off (finished items get struck through).
  - Light Markdown styling for headings, checkboxes, quotes, `inline code` and clickable links. The file stays plain text.
- **Multiple notes** as tabs. Blank notes tidy themselves away when you switch.
- **Clean UI** using native materials, with light and dark mode.

## Shortcuts

| Keys | Action |
| --- | --- |
| ⌥⌘N | Show / hide from anywhere |
| ⌘N | New note |
| ⌘1 … ⌘9 | Jump to note |
| ⌘[ / ⌘] | Previous / next note |
| ⌘↩ | Toggle checkbox on current line |
| ⌘+ / ⌘− / ⌘0 | Text size |
| ⌘F | Find |
| Esc / ⌘W | Close |

Right-click the menu bar icon for a quick menu. Use the 📌 button to keep the popover open while you work in other apps.

## Install

Requires macOS 13 Ventura or later and Xcode command line tools.

```sh
git clone https://github.com/asaiatin/MenuNotes.git
cd MenuNotes
make install     # builds MenuNotes.app and copies it to /Applications
```

Other targets: `make run` (build and launch from ./build), `make universal` (arm64 + x86_64), `make clean`.

Turn on **··· → Launch at Login** to start it automatically.

## Project layout

```
Sources/MenuNotes/
  MenuNotesApp.swift   app entry, status item, popover
  ContentView.swift    SwiftUI UI (tabs, footer, options menu)
  EditorView.swift     SwiftUI ↔ NSTextView bridge
  SmartTextView.swift  smart lists, checkboxes, Markdown styling
  NoteStore.swift      notes on disk + debounced autosave
  MainMenu.swift       keyboard shortcuts
  HotKey.swift         global hotkey (Carbon, no permissions needed)
scripts/build-app.sh   builds and ad-hoc signs the .app bundle
```

No third-party dependencies.

## Contributing

Issues and PRs are welcome. Please keep the app small and simple.

## License

MIT
