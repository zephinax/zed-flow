// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ZedFlow",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "ZedFlowKit", targets: ["ZedFlowKit"]),
        .executable(name: "ZedFlow", targets: ["ZedFlow"]),
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
            name: "ZedFlowTests",
            dependencies: ["ZedFlowKit"],
            path: "Tests/ZedFlowTests"
        ),
    ]
)
