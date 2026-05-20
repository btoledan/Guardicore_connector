// swift-tools-version: 5.10
// Package.swift — Helmsman library modules
// Used for: `swift build` (library modules only) and `swift test` in CI.
// The full .app bundle requires Xcode: run `make generate && make build`.

import PackageDescription

let package = Package(
    name: "Helmsman",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "SSHKit",     targets: ["SSHKit"]),
        .library(name: "VaultKit",   targets: ["VaultKit"]),
        .library(name: "KubeKit",    targets: ["KubeKit"]),
        .library(name: "NetScanKit", targets: ["NetScanKit"]),
        // TerminalKit depends on SwiftTerm (AppKit), so it's listed here
        // but excluded from swift test CI (requires graphical environment).
        .library(name: "TerminalKit", targets: ["TerminalKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm", from: "1.2.0"),
        .package(url: "https://github.com/sparkle-project/Sparkle",  from: "2.6.4"),
        .package(url: "https://github.com/armadsen/ORSSerialPort",   from: "2.1.0"),
    ],
    targets: [

        // ── SSHKit ────────────────────────────────────────────────────────────
        .target(
            name: "SSHKit",
            path: "Sources/SSHKit",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "SSHKitTests",
            dependencies: ["SSHKit"],
            path: "Tests/SSHKitTests",
            resources: [
                .copy("Fixtures")
            ]
        ),

        // ── VaultKit ──────────────────────────────────────────────────────────
        .target(
            name: "VaultKit",
            path: "Sources/VaultKit",
            linkerSettings: [
                .linkedFramework("Security"),
                .linkedFramework("LocalAuthentication")
            ]
        ),

        // ── KubeKit ───────────────────────────────────────────────────────────
        .target(
            name: "KubeKit",
            path: "Sources/KubeKit"
        ),
        .testTarget(
            name: "KubeKitTests",
            dependencies: ["KubeKit"],
            path: "Tests/KubeKitTests",
            resources: [
                .copy("Fixtures")
            ]
        ),

        // ── NetScanKit ────────────────────────────────────────────────────────
        .target(
            name: "NetScanKit",
            path: "Sources/NetScanKit",
            linkerSettings: [
                .linkedFramework("Network")
            ]
        ),

        // ── TerminalKit ───────────────────────────────────────────────────────
        // Depends on SwiftTerm (AppKit/Metal). Requires macOS with display server.
        .target(
            name: "TerminalKit",
            dependencies: [
                .product(name: "SwiftTerm", package: "SwiftTerm")
            ],
            path: "Sources/TerminalKit",
            linkerSettings: [
                .linkedFramework("AppKit")
            ]
        ),
    ]
)
