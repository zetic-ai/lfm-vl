// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "SessionHistory",
    platforms: [.iOS("18.0"), .macOS(.v13)],
    products: [.library(name: "SessionHistory", targets: ["SessionHistory"])],
    targets: [
        .target(name: "SessionHistory"),
        .testTarget(name: "SessionHistoryTests", dependencies: ["SessionHistory"]),
    ]
)
