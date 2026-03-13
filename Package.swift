// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Helios",
    platforms: [
        .macOS(.v15),
    ],
    dependencies: [
        .package(url: "https://github.com/nicklockwood/Expression", from: "0.13.0"),
        .package(url: "https://github.com/groue/GRDB.swift", from: "7.0.0"),
        .package(url: "https://github.com/jpsim/Yams", from: "5.0.0"),
    ],
    targets: [
        .target(
            name: "HeliosPluginProtocol",
            path: "Sources/HeliosPluginProtocol",
        ),
        .executableTarget(
            name: "Helios",
            dependencies: [
                "Expression",
                "HeliosPluginProtocol",
                "Yams",
            ],
            path: "Sources/Helios",
            resources: [
                .copy("Resources"),
            ],
        ),
        .executableTarget(
            name: "firefox-bookmarks",
            dependencies: [
                "HeliosPluginProtocol",
                .product(name: "GRDB", package: "GRDB.swift"),
            ],
            path: "Plugins/firefox-bookmarks",
            exclude: ["manifest.yaml"],
        ),
        .executableTarget(
            name: "chrome-bookmarks",
            dependencies: [
                "HeliosPluginProtocol",
            ],
            path: "Plugins/chrome-bookmarks",
            exclude: ["manifest.yaml"],
        ),
        .executableTarget(
            name: "safari-bookmarks",
            dependencies: [
                "HeliosPluginProtocol",
            ],
            path: "Plugins/safari-bookmarks",
            exclude: ["manifest.yaml"],
        ),
        .testTarget(
            name: "HeliosTests",
            dependencies: [
                "Helios",
                "Expression",
                "Yams",
            ],
            path: "Tests/HeliosTests",
        ),
    ],
)
