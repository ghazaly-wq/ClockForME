// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "HabitCore",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [
        .library(name: "HabitCore", targets: ["HabitCore"])
    ],
    targets: [
        .target(name: "HabitCore"),
        .testTarget(name: "HabitCoreTests", dependencies: ["HabitCore"])
    ]
)
