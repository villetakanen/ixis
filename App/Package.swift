// swift-tools-version: 6.2
import PackageDescription

// The native app. `PraxisDesktop` holds the macOS adapters (CoreGraphics event
// construction/posting and event-posting access) and is testable without
// posting anything. `Praxis` is the executable that `scripts/build-app` wraps
// in a .app bundle (App/Resources/Info.plist).
let package = Package(
    name: "Praxis",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(path: "../Packages/PraxisCore"),
    ],
    targets: [
        .target(
            name: "PraxisDesktop",
            dependencies: [
                .product(name: "PraxisCore", package: "PraxisCore"),
            ]
        ),
        .executableTarget(
            name: "Praxis",
            dependencies: [
                "PraxisDesktop",
                .product(name: "PraxisCore", package: "PraxisCore"),
            ]
        ),
        .testTarget(
            name: "PraxisDesktopTests",
            dependencies: [
                "PraxisDesktop",
                .product(name: "PraxisCore", package: "PraxisCore"),
            ]
        ),
    ]
)
