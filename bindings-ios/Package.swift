// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "E2EESDK",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "E2EESDK",
            targets: ["E2EESDK"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "E2EESDK",
            dependencies: []
        ),
        .testTarget(
            name: "E2EESDKTests",
            dependencies: ["E2EESDK"]
        ),
    ]
)

