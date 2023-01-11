// swift-tools-version:5.6

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
    ),
    .library(
      name: "Dependencies",
      targets: ["Dependencies"]
    ),
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0"),
    .package(url: "https://github.com/google/swift-benchmark", from: "0.1.0"),
    .package(url: "https://github.com/ReactiveCocoa/ReactiveSwift", from: "7.1.0"),
    .package(url: "https://github.com/pointfreeco/swift-case-paths", from: "0.10.0"),
    .package(url: "https://github.com/pointfreeco/swift-clocks", from: "0.1.4"),
    .package(url: "https://github.com/pointfreeco/swift-custom-dump", from: "0.6.0"),
    .package(url: "https://github.com/pointfreeco/swift-identified-collections", from: "0.4.1"),
    .package(url: "https://github.com/pointfreeco/swiftui-navigation", from: "0.4.2"),
    .package(url: "https://github.com/pointfreeco/xctest-dynamic-overlay", from: "0.5.0"),
  ],
  targets: [
    .target(
      name: "ComposableArchitecture",
      dependencies: [
        "Dependencies",
        .product(name: "CasePaths", package: "swift-case-paths"),
        .product(name: "CustomDump", package: "swift-custom-dump"),
        .product(name: "IdentifiedCollections", package: "swift-identified-collections"),
        .product(name: "ReactiveSwift", package: "ReactiveSwift"),
        .product(name: "_SwiftUINavigationState", package: "swiftui-navigation"),
        .product(name: "XCTestDynamicOverlay", package: "xctest-dynamic-overlay"),
      ]
    ),
    .testTarget(
      name: "ComposableArchitectureTests",
      dependencies: [
        "ComposableArchitecture"
      ]
    ),
    .target(
      name: "Dependencies",
      dependencies: [
        .product(name: "Clocks", package: "swift-clocks"),
        .product(name: "ReactiveSwift", package: "ReactiveSwift"),
        .product(name: "XCTestDynamicOverlay", package: "xctest-dynamic-overlay"),
      ]
    ),
    .testTarget(
      name: "DependenciesTests",
      dependencies: [
        "ComposableArchitecture",
        "Dependencies",
      ]
    ),
    .executableTarget(
      name: "swift-composable-architecture-benchmark",
      dependencies: [
        "ComposableArchitecture",
        .product(name: "Benchmark", package: "swift-benchmark"),
      ]
    ),
  ]
)

//for target in package.targets {
//  target.swiftSettings = target.swiftSettings ?? []
//  target.swiftSettings?.append(
//    .unsafeFlags([
//      "-Xfrontend", "-warn-concurrency",
//      "-Xfrontend", "-enable-actor-data-race-checks",
//      "-enable-library-evolution",
//    ])
//  )
//}

#if os(Linux)
  for target in package.targets {
    target.dependencies = target.dependencies.filter {
      if case .productItem("_SwiftUINavigationState", _, _, _) = $0 {
        return false
      }
      return true
    }
  }
#endif
