// swift-tools-version: 6.0
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
// Copyright (c) 2026 The bare-swift Project Authors.

import PackageDescription

let package = Package(
    name: "swift-jsonpatch",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "JSONPatch", targets: ["JSONPatch"])
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-docc-plugin.git", from: "1.4.0"),
        .package(url: "https://github.com/bare-swift/swift-json.git", from: "0.1.0"),
        .package(url: "https://github.com/bare-swift/swift-jsonpointer.git", from: "0.1.0")
    ],
    targets: [
        .target(
            name: "JSONPatch",
            dependencies: [
                .product(name: "JSON", package: "swift-json"),
                .product(name: "JSONPointer", package: "swift-jsonpointer")
            ]
        ),
        .testTarget(
            name: "JSONPatchTests",
            dependencies: ["JSONPatch"]
        )
    ]
)
