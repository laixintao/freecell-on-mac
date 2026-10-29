// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FreeCell",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "FreeCell", targets: ["FreeCell"])],
    targets: [
        .target(name: "FreeCellCore"),
        .executableTarget(name: "FreeCell", dependencies: ["FreeCellCore"]),
        .testTarget(name: "FreeCellCoreTests", dependencies: ["FreeCellCore"])
    ]
)
