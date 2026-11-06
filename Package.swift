// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "Sandpaper",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "SandpaperCore", targets: ["SandpaperCore"]),
        .executable(name: "sandpaper-evaluate", targets: ["SandpaperEvaluate"])
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", exact: "7.12.0")
    ],
    targets: [
        .target(name: "SandpaperCore", dependencies: [.product(name: "GRDB", package: "GRDB.swift")]),
        .executableTarget(name: "SandpaperEvaluate", dependencies: ["SandpaperCore"]),
        .testTarget(name: "SandpaperCoreTests", dependencies: ["SandpaperCore", .product(name: "GRDB", package: "GRDB.swift")])
    ],
    swiftLanguageModes: [.v6]
)
