// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "StatFocus",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "StatFocus",
            path: "StatFocus/Sources/StatFocus"
        )
    ]
)
