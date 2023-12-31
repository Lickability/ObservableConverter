// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ObservableObject to @Observable Converter",
    platforms: [
        .iOS(.v14),
        .macOS(.v12)
    ],
    products: [
        .executable(name: "ObservableConverter", targets: ["ObservableConverter"]),
        .plugin(
            name: "Convert to @Observable",
            targets: [
                "Convert Target to Use @Observable"
            ]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-syntax.git", exact: "509.0.0-swift-DEVELOPMENT-SNAPSHOT-2023-08-15-a"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.2.0")
    ],
    targets: [
        .executableTarget(
            name: "ObservableConverter",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax"),
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]),
        .testTarget(name: "ObservableConverterTests",
                    dependencies: ["ObservableConverter"],
                    resources: [
                        .copy("Resources")
                    ]
                   ),
        .plugin(
            name: "Convert Target to Use @Observable",
            capability: .command(
                intent: .custom(
                    verb: "convert to observable",
                    description: "Converts usage of ObservableObjects to the new @Observable, updating associated property wrappers and view modifiers as well."
                ),
                permissions: [
                    .writeToPackageDirectory(reason: "To convert usage of ObservableObjects to the new @Observable, updating associated property wrappers and view modifiers as well.")
                ]
            ),
            dependencies: [
                .target(name: "ObservableConverter")
            ]
        )
    ]
)
