// swift-tools-version: 6.0
import PackageDescription

// Kein Xcode auf dieser Maschine (nur CommandLineTools) -> Swift Package mit
// App-Target. Kein externes Schach-Package: Regeln sind selbst geschrieben.
// Sprachmodus 5, damit der vorhandene Code ohne Concurrency-Anpassungen baut.
// Tests laufen mit Swift-Testing (die CommandLineTools liefern XCTest nicht mit);
// das Testing-Framework liegt in der CLT hinter diesem -F-Suchpfad.
let cltFrameworkPath = "/Library/Developer/CommandLineTools/Library/Developer/Frameworks"

let package = Package(
    name: "ChessApp",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "ChessAppKit",
            resources: [.process("Resources")],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "ChessApp",
            dependencies: ["ChessAppKit"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        // Selbstgebauter Test-Runner, weil `swift test` ohne Xcode (nur CLT) das
        // Test-Bundle nicht ausführen kann. Gleiche Assertions wie Tests/ChessAppKitTests.
        .executableTarget(
            name: "TestRunner",
            dependencies: ["ChessAppKit"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "ChessAppKitTests",
            dependencies: ["ChessAppKit"],
            swiftSettings: [
                .swiftLanguageMode(.v5),
                .unsafeFlags(["-F", cltFrameworkPath]),
            ],
            linkerSettings: [
                .unsafeFlags(["-F", cltFrameworkPath, "-framework", "Testing"]),
            ]
        ),
    ]
)
