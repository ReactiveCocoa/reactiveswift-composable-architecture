// swift-tools-version:5.3

import PackageDescription

let package = Package(
  name: "reactiveswift-composable-architecture",
  platforms: [
    .iOS(.v13),
    .macOS(.v10_15),
    .tvOS(.v13),
    .watchOS(.v6),
  ],
  products: [
    .library(
      name: "ComposableArchitecture",
      targets: ["ComposableArchitecture"]
    )
  ],
  dependencies: [
    .package(name: "Benchmark", url: "https://github.com/google/swift-benchmark", from: "0.1.0"),
    .package(url: "https://github.com/ReactiveCocoa/ReactiveSwift", from: "6.7.0"),
    .package(url: "https://github.com/pointfreeco/swift-case-paths", from: "0.8.0"),
    .package(url: "https://github.com/pointfreeco/swift-custom-dump", from: "0.3.0"),
    .package(url: "https://github.com/pointfreeco/swift-identified-collections", from: "0.3.2"),
    .package(url: "https://github.com/pointfreeco/xctest-dynamic-overlay", from: "0.2.1"),
  ],
  targets: [
    .target(
      name: "ComposableArchitecture",
      dependencies: [
        "ReactiveSwift",
        .product(name: "CasePaths", package: "swift-case-paths"),
        .product(name: "CustomDump", package: "swift-custom-dump"),
        .product(name: "IdentifiedCollections", package: "swift-identified-collections"),
        .product(name: "XCTestDynamicOverlay", package: "xctest-dynamic-overlay"),
      ]
    ),
    .testTarget(
      name: "ComposableArchitectureTests",
      dependencies: [
        "ComposableArchitecture"
      ]
    ),
    .executableTarget(
      name: "swift-composable-architecture-benchmark",
      dependencies: [
        "ComposableArchitecture",
        .product(name: "Benchmark", package: "Benchmark"),
      ]
    ),
  ]
)
