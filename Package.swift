// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Solai",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "Solai",
            path: "Sources/Solai",
            resources: [
                .copy("Hooks/solai_hook.sh")
            ]
        )
    ]
)
