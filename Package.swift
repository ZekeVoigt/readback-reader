// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "ReadbackReader",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "ReadbackReader", targets: ["ReadbackReader"])
    ],
    targets: [
        .executableTarget(
            name: "ReadbackReader",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon")
            ]
        )
    ]
)
