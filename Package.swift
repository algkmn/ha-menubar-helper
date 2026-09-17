// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AKGHA",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "AKGHA",
            path: "Sources/AKGHA"
        )
    ]
)
