import AppKit

// Custom NSApplication subclass that holds AppDelegate strongly
final class Application: NSApplication {
    let strongDelegate = AppDelegate()

    override init() {
        super.init()
        self.delegate = strongDelegate
    }

    required init?(coder: NSCoder) {
        fatalError()
    }
}
