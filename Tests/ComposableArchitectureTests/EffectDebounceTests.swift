import ComposableArchitecture
import ReactiveSwift
import XCTest

// `@MainActor` introduces issues gathering tests on Linux
#if !os(Linux)
  @MainActor
  final class EffectDebounceTests: XCTestCase {
    func testDebounce() async {
      let mainQueue = TestScheduler()
      var values: [Int] = []

      // NB: Explicit @MainActor is needed for Swift 5.5.2
      @MainActor func runDebouncedEffect(value: Int) {
        struct CancelToken: Hashable {}

        Effect(value: value)
          .debounce(id: CancelToken(), for: 1, scheduler: mainQueue)
          .producer
          .startWithValues { values.append($0) }
      }

      runDebouncedEffect(value: 1)

      // Nothing emits right away.
      XCTAssertEqual(values, [])

      // Waiting half the time also emits nothing
      await mainQueue.advance(by: 0.5)
      XCTAssertEqual(values, [])

      // Run another debounced effect.
      runDebouncedEffect(value: 2)

      // Waiting half the time emits nothing because the first debounced effect has been canceled.
      await mainQueue.advance(by: 0.5)
      XCTAssertEqual(values, [])

      // Run another debounced effect.
      runDebouncedEffect(value: 3)

      // Waiting half the time emits nothing because the second debounced effect has been canceled.
      await mainQueue.advance(by: 0.5)
      XCTAssertEqual(values, [])

      // Waiting the rest of the time emits the final effect value.
      await mainQueue.advance(by: 0.5)
      XCTAssertEqual(values, [3])

      // Running out the scheduler
      await mainQueue.run()
      XCTAssertEqual(values, [3])
    }

    func testDebounceIsLazy() async {
      let mainQueue = TestScheduler()
      var values: [Int] = []
      var effectRuns = 0

      // NB: Explicit @MainActor is needed for Swift 5.5.2
      @MainActor func runDebouncedEffect(value: Int) {
        struct CancelToken: Hashable {}

        SignalProducer.deferred { () -> SignalProducer<Int, Never> in
          effectRuns += 1
          return .init(value: value)
        }
        .eraseToEffect()
        .debounce(id: CancelToken(), for: 1, scheduler: mainQueue)
        .producer
        .startWithValues { values.append($0) }
      }

      runDebouncedEffect(value: 1)

      XCTAssertEqual(values, [])
      XCTAssertEqual(effectRuns, 0)

      await mainQueue.advance(by: 0.5)

      XCTAssertEqual(values, [])
      XCTAssertEqual(effectRuns, 0)

      await mainQueue.advance(by: 0.5)

      XCTAssertEqual(values, [1])
      XCTAssertEqual(effectRuns, 1)
    }
  }
#endif
