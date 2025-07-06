// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "table",
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.1"),
        // .package(url: "https://github.com/groue/GRMustache.swift", from: "4.0.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .executableTarget(
            name: "table",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"), 
                // .product(name: "Mustache", package: "GRMustache.swift")
            ]),
        .testTarget(
            name: "table-Tests",
            dependencies: ["table"]),
    ]
)
