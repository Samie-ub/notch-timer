// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NotchTimer",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "NotchTimer", targets: ["NotchTimer"])],
    dependencies: [.package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.0")],
    targets: [
        .target(name: "TimerCore"),
        .executableTarget(name: "NotchTimer", dependencies: ["TimerCore", .product(name: "Sparkle", package: "Sparkle")],
                          linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]),
        .testTarget(name: "TimerCoreTests", dependencies: ["TimerCore"])
    ]
)
