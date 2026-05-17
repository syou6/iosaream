// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "OkiMission",
    platforms: [
        .iOS(.v26),
        .macOS(.v15)
    ],
    products: [
        .library(name: "OkiMissionCore", targets: ["OkiMissionCore"]),
        .library(name: "OkiMissionEngine", targets: ["OkiMissionEngine"]),
        .library(name: "OkiMissionDomain", targets: ["OkiMissionDomain"]),
        .library(name: "OkiMissionServices", targets: ["OkiMissionServices"]),
        .library(name: "OkiMissionDesignSystem", targets: ["OkiMissionDesignSystem"]),
        .library(name: "OkiMissionPlatformKit", targets: ["OkiMissionPlatformKit"]),
        .library(name: "OkiMissionFeatureKit", targets: ["OkiMissionFeatureKit"]),
        .library(name: "OkiMissionVoicePack", targets: ["OkiMissionVoicePack"])
    ],
    targets: [
        .target(
            name: "OkiMissionCore",
            path: "Sources/OkiMissionCore"
        ),
        .target(
            name: "OkiMissionEngine",
            dependencies: ["OkiMissionCore", "OkiMissionVoicePack"],
            path: "Sources/OkiMissionEngine"
        ),
        .target(
            name: "OkiMissionDomain",
            dependencies: ["OkiMissionCore", "OkiMissionVoicePack"],
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
            dependencies: ["OkiMissionCore", "OkiMissionServices", "OkiMissionVoicePack"],
            path: "Sources/OkiMissionPlatformKit"
        ),
        .target(
            name: "OkiMissionFeatureKit",
            dependencies: [
                "OkiMissionCore",
                "OkiMissionEngine",
                "OkiMissionDomain",
                "OkiMissionServices",
                "OkiMissionDesignSystem",
                "OkiMissionVoicePack"
            ],
            path: "Sources/OkiMissionFeatureKit"
        ),
        .target(
            name: "OkiMissionVoicePack",
            dependencies: ["OkiMissionCore"],
            path: "Sources/OkiMissionVoicePack"
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
        ),
        .testTarget(
            name: "OkiMissionVoicePackTests",
            dependencies: ["OkiMissionVoicePack", "OkiMissionCore"],
            path: "Tests/OkiMissionVoicePackTests"
        ),
        .testTarget(
            name: "OkiMissionEngineVoiceTests",
            dependencies: ["OkiMissionEngine", "OkiMissionCore", "OkiMissionVoicePack"],
            path: "Tests/OkiMissionEngineVoiceTests"
        )
    ]
)
