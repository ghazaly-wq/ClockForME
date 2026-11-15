// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "HabitCore",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [
        .library(name: "HabitCore", targets: ["HabitCore"])
    ],
    dependencies: [
        .package(url: "https://github.com/batoulapps/adhan-swift", from: "1.4.0")
    ],
    targets: [
        .target(name: "HabitCore", dependencies: [.product(name: "Adhan", package: "adhan-swift")]),
        .testTarget(name: "HabitCoreTests", dependencies: ["HabitCore"])
    ]
)
