import AppKit
import SwiftUI

final class NoteViewController: NSViewController {
    private let noteState: NoteState

    init(noteState: NoteState) {
        self.noteState = noteState
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func loadView() {
        let hostingView = NSHostingView(rootView: NoteView().environmentObject(noteState))
        self.view = hostingView
    }
}

struct NoteView: View {
    @EnvironmentObject var state: NoteState
    @State private var showingClaude = false

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text("MenuNotes")
                    .font(.headline)
                Spacer()
                Button(action: { NSApp.terminate(nil) }) {
                    Image(systemName: "xmark.circle")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // Text editor
            NoteTextEditor(text: $state.text)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            // Action bar
            HStack(spacing: 8) {
                Text(state.isRunningClaude ? "Running Claude..." : "autosaved")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Button("Summarise") {
                    showingClaude = true
                    state.runClaude(prompt: "Read the file at the given path and provide a concise summary of the notes, then list clear action items.")
                }
                .disabled(state.isRunningClaude || state.text.isEmpty)

                Button("Action Items") {
                    showingClaude = true
                    state.runClaude(prompt: "Read the file at the given path and extract only the action items / todos / next steps as a numbered list. Be specific and actionable.")
                }
                .disabled(state.isRunningClaude || state.text.isEmpty)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            // Claude output panel
            if showingClaude {
                Divider()
                ClaudeOutputView(output: state.claudeOutput, isLoading: state.isRunningClaude) {
                    showingClaude = false
                }
            }
        }
        .frame(width: 380)
    }
}

struct ClaudeOutputView: View {
    let output: String
    let isLoading: Bool
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Claude")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            if isLoading {
                HStack {
                    ProgressView().scaleEffect(0.6)
                    Text("Thinking...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                ScrollView {
                    Text(output.isEmpty ? "No output" : output)
                        .font(.system(.caption, design: .default))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(maxHeight: 200)
            }
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
    }
}
