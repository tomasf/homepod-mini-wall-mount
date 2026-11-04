// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "homepod-mini-wall-mount",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(url: "https://github.com/tomasf/Cadova.git", from: "1.2.0"),
        .package(url: "https://github.com/tomasf/Helical.git", from: "1.2.0"),
        .package(url: "https://github.com/tomasf/Prepress.git", .upToNextMinor(from: "0.1.0")),
    ],
    targets: [
        .executableTarget(
            name: "homepod-mini-wall-mount",
            dependencies: ["Cadova", "Helical", "Prepress"],
            path: "Sources",
            swiftSettings: [.interoperabilityMode(.Cxx)]
        ),
        .testTarget(
            name: "HomePodMountTests",
            dependencies: ["homepod-mini-wall-mount", "Cadova", "Helical"],
            path: "Tests",
            swiftSettings: [.interoperabilityMode(.Cxx)]
        ),
    ]
)
