// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Atlas",
    platforms: [
        .macOS("27.0")
    ],
    products: [
        .executable(name: "Atlas", targets: ["Atlas"]),
        .library(name: "AtlasCore", targets: ["AtlasCore"])
    ],
    targets: [
        .target(
            name: "AtlasCore",
            path: "Sources/AtlasCore"
        ),
        .executableTarget(
            name: "Atlas",
            dependencies: ["AtlasCore"],
            path: "Sources/Atlas",
            // The Swift 6.4 plugin sandbox cannot exec swift-plugin-server, which
            // crashes macro expansion (@State, @Observable) with "malformed response".
            swiftSettings: [.unsafeFlags(["-Xfrontend", "-disable-sandbox"])]
        ),
        .testTarget(
            name: "AtlasCoreTests",
            dependencies: ["AtlasCore"],
            path: "Tests/AtlasCoreTests"
        )
    ],
    swiftLanguageModes: [.v6]
)
