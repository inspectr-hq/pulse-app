// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Pulse",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Pulse", targets: ["Pulse"])
    ],
    targets: [
        .executableTarget(
            name: "Pulse",
            path: "Sources/Pulse"
        )
    ]
)
