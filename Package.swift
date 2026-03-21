// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PhotoCull",
    platforms: [.macOS(.v14), .iOS(.v16)],
    products: [
        .library(name: "PhotoCullCore", targets: ["PhotoCullCore"]),
        .library(name: "PhotoCullAppLib", targets: ["PhotoCullAppLib"]),
        .executable(name: "PhotoCullApp", targets: ["PhotoCullApp"]),
    ],
    targets: [
        .target(name: "PhotoCullCore", path: "Sources/PhotoCullCore"),
        .target(
            name: "PhotoCullAppLib",
            dependencies: ["PhotoCullCore"],
            path: "Sources/PhotoCullAppLib"
        ),
        .executableTarget(
            name: "PhotoCullApp",
            dependencies: ["PhotoCullAppLib"],
            path: "Sources/PhotoCullApp"
        ),
        .testTarget(
            name: "PhotoCullCoreTests",
            dependencies: ["PhotoCullCore"],
            path: "Tests/PhotoCullCoreTests",
            resources: [.copy("TestDataset")]
        ),
        .testTarget(
            name: "PhotoCullAppTests",
            dependencies: ["PhotoCullAppLib"],
            path: "Tests/PhotoCullAppTests"
        ),
    ]
)
