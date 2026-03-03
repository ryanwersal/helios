// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Helios",
    platforms: [
        .macOS(.v15)
    ],
    dependencies: [
        .package(url: "https://github.com/nicklockwood/Expression", from: "0.13.0"),
        .package(url: "https://github.com/groue/GRDB.swift", from: "7.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "Helios",
            dependencies: [
                "Expression",
                .product(name: "GRDB", package: "GRDB.swift"),
            ],
            path: "Sources/Helios",
            resources: [
                .copy("Resources"),
            ]
        ),
        .testTarget(
            name: "HeliosTests",
            dependencies: [
                "Helios",
                "Expression",
            ],
            path: "Tests/HeliosTests"
        ),
    ]
)
