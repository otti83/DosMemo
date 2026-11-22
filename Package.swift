// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "DosMemo",
    defaultLocalization: "en",
    platforms: [.macOS(.v13)],
    dependencies: [
        // GitHub Flavored Markdown reference parser (the engine behind
        // swift-markdown). Used directly because swift-markdown's
        // HTMLFormatter does not escape text or code blocks.
        .package(url: "https://github.com/swiftlang/swift-cmark.git", from: "0.9.0"),
    ],
    targets: [
        // Localizations live in Resources/*.lproj and are copied into
        // DosMemo.app/Contents/Resources by build.sh (see Localization.swift).
        .executableTarget(
            name: "DosMemo",
            dependencies: [
                .product(name: "cmark-gfm", package: "swift-cmark"),
                .product(name: "cmark-gfm-extensions", package: "swift-cmark"),
            ],
            path: "Sources/DosMemo"
        ),
        .testTarget(
            name: "DosMemoTests",
            dependencies: ["DosMemo"],
            path: "Tests/DosMemoTests"
        ),
    ]
)
