// swift-tools-version:5.1

import PackageDescription

let package = Package(
  name: "swift-composable-architecture",
  platforms: [
    .iOS(.v12),
    .macOS(.v10_14),
    .tvOS(.v12),
    .watchOS(.v5),
  ],
  products: [
    .library(
      name: "ComposableArchitecture",
      targets: ["ComposableArchitecture"]
    ),
    .library(
      name: "ComposableCoreLocation",
      targets: ["ComposableCoreLocation"]
    ),
  ],
  dependencies: [
    .package(url: "https://github.com/pointfreeco/swift-case-paths", from: "0.1.1"),
    .package(url: "https://github.com/ReactiveCocoa/ReactiveSwift", from: "6.3.0")
  ],
  targets: [
    .target(
      name: "ComposableArchitecture",
      dependencies: [
        "CasePaths",
        "ReactiveSwift",
      ]
    ),
    .testTarget(
      name: "ComposableArchitectureTests",
      dependencies: [
        "ComposableArchitecture",
      ]
    ),
    .target(
      name: "ComposableCoreLocation",
      dependencies: [
        "ComposableArchitecture"
      ]
    ),
    .testTarget(
      name: "ComposableCoreLocationTests",
      dependencies: [
        "ComposableCoreLocation",
      ]
    ),
  ]
)
