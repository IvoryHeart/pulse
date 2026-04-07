// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "housekeeping",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "HKCore",
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("CoreWLAN"),
                .linkedFramework("IOBluetooth"),
            ]
        ),
        .executableTarget(
            name: "hk",
            dependencies: ["HKCore"]
        ),
        .executableTarget(
            name: "HKApp",
            dependencies: ["HKCore"],
            linkerSettings: [
                .linkedFramework("SwiftUI"),
                .linkedFramework("Charts"),
            ]
        ),
        .testTarget(
            name: "HKCoreTests",
            dependencies: ["HKCore"],
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("CoreWLAN"),
                .linkedFramework("IOBluetooth"),
            ]
        ),
    ]
)
