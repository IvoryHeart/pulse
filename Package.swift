// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "pulse",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "PulseCore",
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("CoreWLAN"),
                .linkedFramework("IOBluetooth"),
            ]
        ),
        .executableTarget(
            name: "pulse",
            dependencies: ["PulseCore"]
        ),
        .executableTarget(
            name: "PulseApp",
            dependencies: ["PulseCore"],
            linkerSettings: [
                .linkedFramework("SwiftUI"),
                .linkedFramework("Charts"),
            ]
        ),
        .testTarget(
            name: "PulseCoreTests",
            dependencies: ["PulseCore"],
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("CoreWLAN"),
                .linkedFramework("IOBluetooth"),
            ]
        ),
    ]
)
