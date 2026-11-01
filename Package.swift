// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Kopru",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "KopruCore", targets: ["KopruCore"]),
        .executable(name: "KopruApp", targets: ["KopruApp"]),
        .executable(name: "kopru", targets: ["kopru-cli"]),
    ],
    targets: [
        .target(name: "KopruCore"),
        .executableTarget(name: "KopruApp", dependencies: ["KopruCore"]),
        .executableTarget(name: "kopru-cli", dependencies: ["KopruCore"]),
        .testTarget(name: "KopruCoreTests", dependencies: ["KopruCore"]),
    ]
)
