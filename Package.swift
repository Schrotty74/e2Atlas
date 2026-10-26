// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "e2AtlasModules",
    platforms: [.macOS("26.0")],
    products: [
        .library(name: "AtlasCore", targets: ["AtlasCore"]),
        .library(name: "AtlasReceiver", targets: ["AtlasReceiver"]),
        .library(name: "AtlasThemes", targets: ["AtlasThemes"]),
        .library(name: "AtlasPlayback", targets: ["AtlasPlayback"]),
        .library(name: "AtlasRecording", targets: ["AtlasRecording"])
    ],
    targets: [
        .target(name: "AtlasCore"),
        .target(name: "AtlasRecording"),
        .target(name: "AtlasReceiver", dependencies: ["AtlasCore"]),
        .target(name: "AtlasThemes", resources: [.process("Resources")]),
        .binaryTarget(name: "VLCKit", path: "Build/Dependencies/VLCKit - binary package/VLCKit.xcframework"),
        .target(name: "AtlasPlayback", dependencies: ["AtlasCore", "VLCKit"]),
        .testTarget(name: "AtlasRecordingTests", dependencies: ["AtlasRecording"]),
        .testTarget(name: "AtlasCoreTests", dependencies: ["AtlasCore"]),
        .testTarget(name: "AtlasReceiverTests", dependencies: ["AtlasReceiver", "AtlasCore"]),
        .testTarget(name: "AtlasThemesTests", dependencies: ["AtlasThemes"]),
        .testTarget(name: "AtlasPlaybackTests", dependencies: ["AtlasPlayback"])
    ],
    swiftLanguageModes: [.v6]
)
