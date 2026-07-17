// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HardenedAuth",
    platforms: [
        .macOS(.v13),
        .iOS(.v14),
    ],
    products: [
        .library(name: "HardenedAuth", targets: ["HardenedAuth"]),
    ],
    targets: [
        .target(
            name: "HardenedAuth",
            dependencies: [],
            path: "Sources/HardenedAuth"
        ),
        .testTarget(
            name: "HardenedAuthTests",
            dependencies: ["HardenedAuth"],
            path: "Tests/HardenedAuthTests"
        ),
    ]
)
