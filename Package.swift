// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "DosMemo",
    defaultLocalization: "en",
    platforms: [.macOS(.v13)],
    targets: [
        // Localizations live in Resources/*.lproj and are copied into
        // DosMemo.app/Contents/Resources by build.sh (see Localization.swift).
        .executableTarget(
            name: "DosMemo",
            path: "Sources/DosMemo"
        ),
        .testTarget(
            name: "DosMemoTests",
            dependencies: ["DosMemo"],
            path: "Tests/DosMemoTests"
        ),
    ]
)
