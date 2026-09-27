// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Biqli",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "Biqli", targets: ["Biqli"]),
    ],
    targets: [
        .target(
            name: "Biqli",
            resources: [.process("Resources/PrivacyInfo.xcprivacy")]
        ),
        .testTarget(name: "BiqliTests", dependencies: ["Biqli"]),
    ]
)
