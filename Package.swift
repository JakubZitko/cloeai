// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Cloe",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(
            name: "Cloe",
            targets: ["Cloe"]
        )
    ],
    dependencies: [
        // No external dependencies for now - using only native macOS frameworks
        // Future: Add ChromaDB Swift client, SQLite.swift, etc.
    ],
    targets: [
        .executableTarget(
            name: "Cloe",
            dependencies: [],
            path: "Cloe/Sources",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "CloeTests",
            dependencies: ["Cloe"],
            path: "Cloe/Tests"
        )
    ]
)
