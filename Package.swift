// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MacPulse",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "MacPulse", targets: ["MacPulse"]),
        .library(name: "MacPulseCore", targets: ["MacPulseCore"])
    ],
    targets: [
        .target(
            name: "CSMC",
            path: "Sources/CSMC",
            publicHeadersPath: "include",
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("CoreFoundation")
            ]
        ),
        .target(
            name: "MacPulseCore",
            dependencies: ["CSMC"],
            path: "Sources/MacPulseCore"
        ),
        .executableTarget(
            name: "MacPulse",
            dependencies: ["MacPulseCore"],
            path: "Sources/MacPulse"
        ),
        .executableTarget(
            name: "MacPulseChecks",
            dependencies: ["MacPulseCore"],
            path: "Tests/MacPulseChecks"
        )
    ],
    swiftLanguageVersions: [.v5]
)
