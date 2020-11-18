// swift-tools-version:5.2

import PackageDescription

let package = Package(
  name: "reactiveswift-composable-architecture",
  platforms: [
    .iOS(.v11),
    .macOS(.v10_14),
    .tvOS(.v12),
    .watchOS(.v5),
  ],
  products: [
    .library(
      name: "ComposableArchitecture",
      targets: ["ComposableArchitecture"]
    )
  ],
  dependencies: [
    .package(url: "https://github.com/pointfreeco/swift-case-paths", from: "0.1.1"),
    .package(url: "https://github.com/ReactiveCocoa/ReactiveSwift", from: "6.4.0"),
  ],
  targets: [
    .target(
      name: "ComposableArchitecture",
      dependencies: [
        .product(name: "CasePaths", package: "swift-case-paths"),
        "ReactiveSwift",
      ]
    ),
    .testTarget(
      name: "ComposableArchitectureTests",
      dependencies: [
        "ComposableArchitecture"
      ]
    ),
  ]
)
