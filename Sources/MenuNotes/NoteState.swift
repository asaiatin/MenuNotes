import Foundation
import Combine

final class NoteState: ObservableObject {
    static let filePath = "/Users/shobhit.asai/Documents/Personal/personal.md"

    @Published var text: String = ""
    @Published var claudeOutput: String = ""
    @Published var isRunningClaude: Bool = false

    private var saveCancellable: AnyCancellable?

    init() {
        // Load existing content
        text = (try? String(contentsOfFile: Self.filePath, encoding: .utf8)) ?? ""

        // Debounced autosave — writes 1s after last keystroke
        saveCancellable = $text
            .dropFirst()
            .debounce(for: .seconds(1), scheduler: DispatchQueue.global(qos: .background))
            .sink { [weak self] newText in
                self?.save(newText)
            }
    }

    private func save(_ text: String) {
        try? text.write(toFile: Self.filePath, atomically: true, encoding: .utf8)
    }

    func runClaude(prompt: String) {
        guard !isRunningClaude else { return }
        isRunningClaude = true
        claudeOutput = ""

        ClaudeRunner.run(filePath: Self.filePath, prompt: prompt) { [weak self] output in
            DispatchQueue.main.async {
                self?.claudeOutput = output
                self?.isRunningClaude = false
            }
        }
    }
}
