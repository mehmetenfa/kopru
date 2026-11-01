// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Kopru",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "KopruCore", targets: ["KopruCore"]),
        .executable(name: "Kopru", targets: ["Kopru"]),
        .executable(name: "kopru", targets: ["kopru-cli"]),
    ],
    targets: [
        .target(name: "KopruCore"),
        .executableTarget(name: "Kopru", dependencies: ["KopruCore"]),
        .executableTarget(name: "kopru-cli", dependencies: ["KopruCore"]),
        .testTarget(name: "KopruCoreTests", dependencies: ["KopruCore"]),
    ]
)
