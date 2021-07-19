import ReactiveSwift
import XCTest

@testable import ComposableArchitecture

final class EffectThrottleTests: XCTestCase {
  let scheduler = TestScheduler()

  func testThrottleLatest() {
    var values: [Int] = []
    var effectRuns = 0

    func runThrottledEffect(value: Int) {
      struct CancelToken: Hashable {}

      Effect.deferred { () -> Effect<Int, Never> in
        effectRuns += 1
        return .init(value: value)
      }
      .throttle(id: CancelToken(), interval: 1, on: scheduler, latest: true)
      .startWithValues { values.append($0) }
    }

    runThrottledEffect(value: 1)

    // A value emits right away.
    XCTAssertEqual(values, [1])

    runThrottledEffect(value: 2)

    // A second value is throttled.
    XCTAssertEqual(values, [1])

    scheduler.advance(by: .milliseconds(250))

    runThrottledEffect(value: 3)

    scheduler.advance(by: .milliseconds(250))

    runThrottledEffect(value: 4)

    scheduler.advance(by: .milliseconds(250))

    runThrottledEffect(value: 5)

    // A third value is throttled.
    XCTAssertEqual(values, [1])

    scheduler.advance(by: .milliseconds(250))

    // The latest value emits.
    XCTAssertEqual(values, [1, 5])
  }

  func testThrottleFirst() {
    var values: [Int] = []
    var effectRuns = 0

    func runThrottledEffect(value: Int) {
      struct CancelToken: Hashable {}

      Effect.deferred { () -> Effect<Int, Never> in
        effectRuns += 1
        return .init(value: value)
      }
      .throttle(id: CancelToken(), interval: 1, on: scheduler, latest: false)
      .startWithValues { values.append($0) }
    }

    runThrottledEffect(value: 1)

    // A value emits right away.
    XCTAssertEqual(values, [1])

    runThrottledEffect(value: 2)

    // A second value is throttled.
    XCTAssertEqual(values, [1])

    scheduler.advance(by: .milliseconds(250))

    runThrottledEffect(value: 3)

    scheduler.advance(by: .milliseconds(250))

    runThrottledEffect(value: 4)

    scheduler.advance(by: .milliseconds(250))

    runThrottledEffect(value: 5)

    // A third value is throttled.
    XCTAssertEqual(values, [1])

    scheduler.advance(by: .milliseconds(250))

    // The first throttled value emits.
    XCTAssertEqual(values, [1, 2])
  }

  func testThrottleAfterInterval() {
    var values: [Int] = []
    var effectRuns = 0

    func runThrottledEffect(value: Int) {
      struct CancelToken: Hashable {}

      Effect.deferred { () -> Effect<Int, Never> in
        effectRuns += 1
        return .init(value: value)
      }
      .throttle(id: CancelToken(), interval: 1, on: scheduler, latest: true)
      .startWithValues { values.append($0) }
    }

    runThrottledEffect(value: 1)

    // A value emits right away.
    XCTAssertEqual(values, [1])

    scheduler.advance(by: .seconds(2))

    runThrottledEffect(value: 2)

    // A second value is emitted right away.
    XCTAssertEqual(values, [1, 2])
  }

  func testThrottleEmitsFirstValueOnce() {
    var values: [Int] = []
    var effectRuns = 0

    func runThrottledEffect(value: Int) {
      struct CancelToken: Hashable {}

      Deferred { () -> Just<Int> in
        effectRuns += 1
        return Just(value)
      }
      .eraseToEffect()
      .throttle(
        id: CancelToken(), for: 1, scheduler: scheduler.eraseToAnyScheduler(), latest: false
      )
      .sink { values.append($0) }
      .store(in: &self.cancellables)
    }

    runThrottledEffect(value: 1)

    // A value emits right away.
    XCTAssertEqual(values, [1])

    scheduler.advance(by: 0.5)

    runThrottledEffect(value: 2)

    scheduler.advance(by: 0.5)

    runThrottledEffect(value: 3)

    // A second value is emitted right away.
    XCTAssertEqual(values, [1, 2])
  }
}
