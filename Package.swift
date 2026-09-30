// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "WhatsYourStatus",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "WhatsYourStatusCore",
            targets: ["WhatsYourStatusCore"]
        ),
        .executable(
            name: "WhatsYourStatus",
            targets: ["WhatsYourStatusApp"]
        )
    ],
    targets: [
        .target(
            name: "WhatsYourStatusCore",
            linkerSettings: [
                .linkedLibrary("sqlite3")
            ]
        ),
        .executableTarget(
            name: "WhatsYourStatusApp",
            dependencies: ["WhatsYourStatusCore"]
        ),
        .testTarget(
            name: "WhatsYourStatusTests",
            dependencies: ["WhatsYourStatusCore"]
        )
    ]
)
