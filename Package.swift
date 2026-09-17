// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ZedFlow",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "ZedFlow", targets: ["ZedFlow"])
    ],
    targets: [
        .executableTarget(
            name: "ZedFlow",
            path: "Sources/ZedFlow",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "ZedFlowTests",
            dependencies: ["ZedFlow"],
            path: "Tests/ZedFlowTests"
        ),
    ]
)
