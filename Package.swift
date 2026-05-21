// swift-tools-version: 5.9
import PackageDescription

// Build variants:
//   - Default (Developer ID / direct distribution): all features enabled.
//   - App Store: define APP_STORE via env var STATFOCUS_APP_STORE=1
//     (build-appstore.sh sets this). Gates sandbox-incompatible code.
let isAppStore = (Context.environment["STATFOCUS_APP_STORE"] ?? "") == "1"

let appStoreSwiftSettings: [SwiftSetting] = isAppStore
    ? [.define("APP_STORE")]
    : []

let package = Package(
    name: "StatFocus",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "StatFocus",
            path: "StatFocus/Sources/StatFocus",
            swiftSettings: appStoreSwiftSettings
        ),
        .testTarget(
            name: "StatFocusTests",
            dependencies: ["StatFocus"],
            path: "Tests/StatFocusTests",
            swiftSettings: appStoreSwiftSettings
        )
    ]
)
