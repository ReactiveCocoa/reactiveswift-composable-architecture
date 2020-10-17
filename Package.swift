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
    ),
    .library(
      name: "ComposableCoreLocation",
      targets: ["ComposableCoreLocation"]
    ),
    .library(
      name: "ComposableCoreMotion",
      targets: ["ComposableCoreMotion"]
    ),
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
    .target(
      name: "ComposableCoreLocation",
      dependencies: [
        "ComposableArchitecture",
        "ReactiveSwift",
      ]
    ),
    .testTarget(
      name: "ComposableCoreLocationTests",
      dependencies: [
        "ComposableCoreLocation"
      ]
    ),
    .target(
      name: "ComposableCoreMotion",
      dependencies: [
        "ComposableArchitecture"
      ]
    ),
    .testTarget(
      name: "ComposableCoreMotionTests",
      dependencies: [
        "ComposableCoreMotion"
      ]
    ),
  ]
)

#if os(Linux)
package.targets.removeAll(where: { $0.type == .test && $0.name != "ComposableArchitectureTests" })
#endif