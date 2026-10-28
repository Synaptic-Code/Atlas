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
            path: "Sources/Atlas"
        ),
        .testTarget(
            name: "AtlasCoreTests",
            dependencies: ["AtlasCore"],
            path: "Tests/AtlasCoreTests"
        )
    ],
    swiftLanguageModes: [.v6]
)
