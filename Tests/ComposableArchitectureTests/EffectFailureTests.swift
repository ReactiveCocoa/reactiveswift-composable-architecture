import ReactiveSwift
import XCTest

@testable import ComposableArchitecture

// `XCTExpectFailure` is not supported on Linux
#if !os(Linux)
  @MainActor
  final class EffectFailureTests: XCTestCase {
    func testTaskUnexpectedThrows() {
      XCTExpectFailure {
        Effect<Void, Never>.task {
          struct Unexpected: Error {}
          throw Unexpected()
        }
        .producer
        .start()

        _ = XCTWaiter.wait(for: [.init()], timeout: 0.1)
      } issueMatcher: {
        $0.compactDescription == """
          An 'Effect.task' returned from "ComposableArchitectureTests/EffectFailureTests.swift:12" \
          threw an unhandled error. …

              EffectFailureTests.Unexpected()

          All non-cancellation errors must be explicitly handled via the 'catch' parameter on \
          'Effect.task', or via a 'do' block.
          """
      }
    }

    func testRunUnexpectedThrows() {
      XCTExpectFailure {
        Effect<Void, Never>.run { _ in
          struct Unexpected: Error {}
          throw Unexpected()
        }
        .producer
        .start()

        _ = XCTWaiter.wait(for: [.init()], timeout: 0.1)
      } issueMatcher: {
        $0.compactDescription == """
          An 'Effect.run' returned from "ComposableArchitectureTests/EffectFailureTests.swift:35" \
          threw an unhandled error. …

              EffectFailureTests.Unexpected()

          All non-cancellation errors must be explicitly handled via the 'catch' parameter on \
          'Effect.run', or via a 'do' block.
          """
      }
    }
  }
#endif
