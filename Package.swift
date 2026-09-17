// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ZedFlow",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "ZedFlowKit", targets: ["ZedFlowKit"]),
        .executable(name: "ZedFlowApp", targets: ["ZedFlow"]),
        .executable(name: "zedflow", targets: ["ZedFlowCLI"]),
        .executable(name: "ZedFlowTests", targets: ["ZedFlowTests"])
    ],
    targets: [
        .target(
            name: "ZedFlowKit",
            path: "Sources/ZedFlowKit"
        ),
        .executableTarget(
            name: "ZedFlow",
            dependencies: ["ZedFlowKit"],
            path: "Sources/ZedFlow"
        ),
        .executableTarget(
            name: "ZedFlowCLI",
            dependencies: ["ZedFlowKit"],
            path: "Sources/ZedFlowCLI"
        ),
        .executableTarget(
            name: "ZedFlowTests",
            dependencies: ["ZedFlowKit"],
            path: "Tests/ZedFlowTests"
        ),
    ]
)
