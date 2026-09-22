// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NotchTimer",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "NotchTimer", targets: ["NotchTimer"])],
    targets: [
        .target(name: "TimerCore"),
        .executableTarget(name: "NotchTimer", dependencies: ["TimerCore"]),
        .testTarget(name: "TimerCoreTests", dependencies: ["TimerCore"])
    ]
)
