// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SMBWatchdog",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "SMBWatchdog", targets: ["SMBWatchdog"])
    ],
    targets: [
        .executableTarget(name: "SMBWatchdog"),
        .testTarget(name: "SMBWatchdogTests", dependencies: ["SMBWatchdog"])
    ]
)
