// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PhotoCull",
    platforms: [.macOS(.v14), .iOS(.v16)],
    products: [
        .library(name: "PhotoCullCore", targets: ["PhotoCullCore"]),
        .executable(name: "PhotoCullApp", targets: ["PhotoCullApp"]),
    ],
    targets: [
        .target(name: "PhotoCullCore", path: "Sources/PhotoCullCore"),
        .executableTarget(
            name: "PhotoCullApp",
            dependencies: ["PhotoCullCore"],
            path: "Sources/PhotoCullApp"
        ),
        .testTarget(
            name: "PhotoCullCoreTests",
            dependencies: ["PhotoCullCore"],
            path: "Tests/PhotoCullCoreTests",
            resources: [.copy("TestDataset")]
        ),
    ]
)
