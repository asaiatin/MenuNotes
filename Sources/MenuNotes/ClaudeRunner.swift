import Foundation

enum ClaudeRunner {
    static func run(filePath: String, prompt: String, completion: @escaping (String) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            // Find claude binary (handles both direct install and nvm/homebrew paths)
            let claudePath = resolvedClaudePath()

            guard let claude = claudePath else {
                completion("Error: `claude` CLI not found. Install it with: npm install -g @anthropic-ai/claude-code")
                return
            }

            let fullPrompt = """
            \(prompt)

            File: \(filePath)
            """

            let process = Process()
            process.executableURL = URL(fileURLWithPath: claude)
            process.arguments = ["-p", fullPrompt, "--allowedTools", "Read"]

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            do {
                try process.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                let output = String(data: data, encoding: .utf8) ?? "No output"
                completion(output.trimmingCharacters(in: .whitespacesAndNewlines))
            } catch {
                completion("Error running claude: \(error.localizedDescription)")
            }
        }
    }

    private static func resolvedClaudePath() -> String? {
        // Common install locations
        let candidates = [
            "/usr/local/bin/claude",
            "/opt/homebrew/bin/claude",
            "/usr/bin/claude",
            (ProcessInfo.processInfo.environment["HOME"] ?? "") + "/.npm-global/bin/claude",
            (ProcessInfo.processInfo.environment["HOME"] ?? "") + "/.local/bin/claude",
        ]

        for path in candidates {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }

        // Try `which claude` as fallback
        let which = Process()
        which.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        which.arguments = ["claude"]
        let pipe = Pipe()
        which.standardOutput = pipe
        try? which.run()
        which.waitUntilExit()
        let result = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return result?.isEmpty == false ? result : nil
    }
}
