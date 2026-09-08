// swift-tools-version: 6.2
import PackageDescription

// The native app target. `scripts/build-app` wraps the built executable in a
// .app bundle (App/Resources/Info.plist) so the menu bar item, bundle identity,
// and later permission grants behave like an ordinary macOS application.
let package = Package(
    name: "Praxis",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(path: "../Packages/PraxisCore"),
    ],
    targets: [
        .executableTarget(
            name: "Praxis",
            dependencies: [
                .product(name: "PraxisCore", package: "PraxisCore"),
            ]
        ),
    ]
)
