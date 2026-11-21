// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Corkboard",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "corkboard", targets: ["Corkboard"])
    ],
    targets: [
        .target(name: "CorkboardCore"),
        .executableTarget(
            name: "Corkboard",
            dependencies: ["CorkboardCore"]
        ),
        .testTarget(
            name: "CorkboardCoreTests",
            dependencies: ["CorkboardCore"]
        )
    ]
)
