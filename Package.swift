// swift-tools-version: 5.9
import PackageDescription

// Kein Xcode auf dieser Maschine (nur CommandLineTools) -> Swift Package mit
// App-Target. Kein externes Schach-Package: Regeln sind selbst geschrieben.
let package = Package(
    name: "ChessApp",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "ChessAppKit",
            resources: [.process("Resources")]
        ),
        .executableTarget(
            name: "ChessApp",
            dependencies: ["ChessAppKit"]
        ),
        .testTarget(
            name: "ChessAppKitTests",
            dependencies: ["ChessAppKit"]
        ),
    ]
)
