// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "DosMemo",
    defaultLocalization: "en",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "DosMemo",
            path: "Sources/DosMemo",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
