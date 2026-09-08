// swift-tools-version: 6.2
import PackageDescription

// PraxisCore holds the semantic layer: intents and value types shared by the
// app and its adapters. It must stay free of AppKit, SwiftUI, and CoreGraphics
// so that it can be tested without a desktop session.
let package = Package(
    name: "PraxisCore",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "PraxisCore", targets: ["PraxisCore"]),
    ],
    targets: [
        .target(name: "PraxisCore"),
        .testTarget(name: "PraxisCoreTests", dependencies: ["PraxisCore"]),
    ]
)
