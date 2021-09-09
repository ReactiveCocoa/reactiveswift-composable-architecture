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
      .throttle(id: CancelToken(), for: 1, scheduler: scheduler, latest: true)
      .startWithValues { values.append($0) }
    }

    runThrottledEffect(value: 1)

    scheduler.advance()

    // A value emits right away.
    XCTAssertEqual(values, [1])

    runThrottledEffect(value: 2)

    scheduler.advance()

    // A second value is throttled.
    XCTAssertEqual(values, [1])

    scheduler.advance(by: 0.25)

    runThrottledEffect(value: 3)

    scheduler.advance(by: 0.25)

    runThrottledEffect(value: 4)

    scheduler.advance(by: 0.25)

    runThrottledEffect(value: 5)

    // A third value is throttled.
    XCTAssertEqual(values, [1])

    scheduler.advance(by: 0.25)

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
      .throttle(id: CancelToken(), for: 1, scheduler: scheduler, latest: false)
      .startWithValues { values.append($0) }
    }

    runThrottledEffect(value: 1)

    scheduler.advance()

    // A value emits right away.
    XCTAssertEqual(values, [1])

    runThrottledEffect(value: 2)

    scheduler.advance()

    // A second value is throttled.
    XCTAssertEqual(values, [1])

    scheduler.advance(by: 0.25)

    runThrottledEffect(value: 3)

    scheduler.advance(by: 0.25)

    runThrottledEffect(value: 4)

    scheduler.advance(by: 0.25)

    runThrottledEffect(value: 5)

    scheduler.advance(by: 0.25)

    // The second (throttled) value emits.
    XCTAssertEqual(values, [1, 2])

    scheduler.advance(by: 0.25)

    runThrottledEffect(value: 6)

    scheduler.advance(by: 0.50)

    // A third value is throttled.
    XCTAssertEqual(values, [1, 2])

    runThrottledEffect(value: 7)

    scheduler.advance(by: 0.25)

    // The third (throttled) value emits.
    XCTAssertEqual(values, [1, 2, 6])
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
      .throttle(id: CancelToken(), for: 1, scheduler: scheduler, latest: true)
      .startWithValues { values.append($0) }
    }

    runThrottledEffect(value: 1)

    scheduler.advance()

    // A value emits right away.
    XCTAssertEqual(values, [1])

    scheduler.advance(by: 2)

    runThrottledEffect(value: 2)

    scheduler.advance()

    // A second value is emitted right away.
    XCTAssertEqual(values, [1, 2])

    scheduler.advance(by: 2)

    runThrottledEffect(value: 3)

    scheduler.advance()

    // A third value is emitted right away.
    XCTAssertEqual(values, [1, 2, 3])
  }

  func testThrottleEmitsFirstValueOnce() {
    var values: [Int] = []
    var effectRuns = 0

    func runThrottledEffect(value: Int) {
      struct CancelToken: Hashable {}

      Effect.deferred { () -> Effect<Int, Never> in
        effectRuns += 1
        return .init(value: value)
      }
      .throttle(
        id: CancelToken(), for: 1, scheduler: scheduler, latest: false
      )
      .startWithValues { values.append($0) }
    }

    runThrottledEffect(value: 1)

    scheduler.advance()

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
