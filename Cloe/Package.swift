// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Cloe",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Cloe", targets: ["Cloe"])
    ],
    dependencies: [
        // SQLite for SpatialMemory
        .package(url: "https://github.com/stephencelis/SQLite.swift.git", from: "0.14.1"),
    ],
    targets: [
        .executableTarget(
            name: "Cloe",
            dependencies: [
                .product(name: "SQLite", package: "SQLite.swift"),
            ],
            path: "Sources",
            resources: [
                .process("Resources")
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("ScreenCaptureKit"),
                .linkedFramework("Vision"),
                .linkedFramework("Speech"),
                .linkedFramework("EventKit"),
                .linkedFramework("UserNotifications"),
            ]
        )
    ]
)
