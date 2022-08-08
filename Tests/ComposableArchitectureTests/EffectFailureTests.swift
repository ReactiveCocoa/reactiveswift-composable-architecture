import ReactiveSwift
import XCTest

@testable import ComposableArchitecture

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
        An 'Effect.task' returned from "ComposableArchitectureTests/EffectFailureTests.swift:10" \
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
        An 'Effect.run' returned from "ComposableArchitectureTests/EffectFailureTests.swift:33" \
        threw an unhandled error. …

            EffectFailureTests.Unexpected()

        All non-cancellation errors must be explicitly handled via the 'catch' parameter on \
        'Effect.run', or via a 'do' block.
        """
    }
  }
}
