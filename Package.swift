// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OkiMission",
    platforms: [
        .iOS(.v18),
        .macOS(.v15)
    ],
    products: [
        .library(name: "OkiMissionCore", targets: ["OkiMissionCore"]),
        .library(name: "OkiMissionEngine", targets: ["OkiMissionEngine"]),
        .library(name: "OkiMissionDomain", targets: ["OkiMissionDomain"]),
        .library(name: "OkiMissionServices", targets: ["OkiMissionServices"]),
        .library(name: "OkiMissionDesignSystem", targets: ["OkiMissionDesignSystem"]),
        .library(name: "OkiMissionPlatformKit", targets: ["OkiMissionPlatformKit"])
    ],
    targets: [
        .target(
            name: "OkiMissionCore",
            path: "Sources/OkiMissionCore"
        ),
        .target(
            name: "OkiMissionEngine",
            dependencies: ["OkiMissionCore"],
            path: "Sources/OkiMissionEngine"
        ),
        .target(
            name: "OkiMissionDomain",
            dependencies: ["OkiMissionCore"],
            path: "Sources/OkiMissionDomain"
        ),
        .target(
            name: "OkiMissionServices",
            dependencies: ["OkiMissionCore"],
            path: "Sources/OkiMissionServices"
        ),
        .target(
            name: "OkiMissionDesignSystem",
            path: "Sources/OkiMissionDesignSystem"
        ),
        .target(
            name: "OkiMissionPlatformKit",
            dependencies: ["OkiMissionCore", "OkiMissionServices"],
            path: "Sources/OkiMissionPlatformKit"
        ),
        .testTarget(
            name: "OkiMissionCoreTests",
            dependencies: ["OkiMissionCore"],
            path: "Tests/OkiMissionCoreTests"
        ),
        .testTarget(
            name: "OkiMissionEngineTests",
            dependencies: ["OkiMissionEngine", "OkiMissionCore"],
            path: "Tests/OkiMissionEngineTests"
        ),
        .testTarget(
            name: "OkiMissionServicesTests",
            dependencies: ["OkiMissionServices", "OkiMissionCore"],
            path: "Tests/OkiMissionServicesTests"
        )
    ]
)
