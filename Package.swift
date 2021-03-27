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
    .package(url: "https://github.com/ReactiveCocoa/ReactiveSwift", from: "6.4.0"),
    .package(url: "https://github.com/pointfreeco/swift-case-paths", from: "0.1.3"),
    .package(url: "https://github.com/pointfreeco/xctest-dynamic-overlay", from: "0.1.0"),
  ],
  targets: [
    .target(
      name: "ComposableArchitecture",
      dependencies: [
        "ReactiveSwift",
        .product(name: "CasePaths", package: "swift-case-paths"),
        .product(name: "XCTestDynamicOverlay", package: "xctest-dynamic-overlay"),
      ]
    ),
    .testTarget(
      name: "ComposableArchitectureTests",
      dependencies: [
        "ComposableArchitecture",
      ]
    ),
  ]
)
