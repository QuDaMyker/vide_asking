// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftUIEnterpriseArchitecture",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "SwiftUIEnterpriseArchitecture",
            targets: ["SwiftUIEnterpriseArchitecture"]
        ),
    ],
    dependencies: [
        // Alamofire for networking
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.8.0"),
        
        // Optional: KeychainAccess for secure storage
        // .package(url: "https://github.com/kishikawakatsumi/KeychainAccess.git", from: "4.2.2"),
    ],
    targets: [
        .target(
            name: "SwiftUIEnterpriseArchitecture",
            dependencies: [
                "Alamofire",
                // "KeychainAccess",
            ],
            path: "."
        ),
        .testTarget(
            name: "SwiftUIEnterpriseArchitectureTests",
            dependencies: ["SwiftUIEnterpriseArchitecture"],
            path: "Testing"
        ),
    ]
)
