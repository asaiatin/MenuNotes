// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MenuNotes",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "MenuNotes", path: "Sources/MenuNotes")
    ]
)
