// swift-tools-version: 5.9
// This file is for reference - actual project should be created in Xcode

import PackageDescription

let package = Package(
    name: "sbog",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "sbog",
            targets: ["sbog"]),
    ],
    dependencies: [
        .package(url: "https://github.com/supabase/supabase-swift.git", from: "2.0.0"),
    ],
    targets: [
        .target(
            name: "sbog",
            dependencies: [
                .product(name: "Supabase", package: "supabase-swift"),
            ]),
    ]
)

