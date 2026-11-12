// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RadirKit",
    defaultLocalization: "hu",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [.library(name: "RadirKit", targets: ["RadirKit"])],
    targets: [
        .target(name: "RadirKit"),
        .testTarget(name: "RadirKitTests", dependencies: ["RadirKit"], resources: [.copy("Fixtures")]),
    ]
)
