// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "Sandpaper",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "SandpaperCore", targets: ["SandpaperCore"]),
        .executable(name: "Sandpaper", targets: ["SandpaperApp"])
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", exact: "7.12.0"),
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", exact: "0.9.20")
    ],
    targets: [
        .target(name: "SandpaperCore", dependencies: [.product(name: "GRDB", package: "GRDB.swift"), .product(name: "ZIPFoundation", package: "ZIPFoundation")]),
        .executableTarget(name: "SandpaperApp", dependencies: ["SandpaperCore"]),
        .testTarget(name: "SandpaperCoreTests", dependencies: ["SandpaperCore", .product(name: "GRDB", package: "GRDB.swift"), .product(name: "ZIPFoundation", package: "ZIPFoundation")])
    ],
    swiftLanguageModes: [.v6]
)
