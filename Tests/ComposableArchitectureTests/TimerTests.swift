import ComposableArchitecture
import ReactiveSwift
import XCTest

final class TimerTests: XCTestCase {
  func testTimer() {
    let scheduler = TestScheduler()

    var count = 0

    Effect.timer(id: 1, every: .seconds(1), on: scheduler)
      .startWithValues { _ in count += 1 }

    scheduler.advance(by: .seconds(1))
    XCTAssertEqual(count, 1)

    scheduler.advance(by: .seconds(1))
    XCTAssertEqual(count, 2)

    scheduler.advance(by: .seconds(1))
    XCTAssertEqual(count, 3)

    scheduler.advance(by: .seconds(3))
    XCTAssertEqual(count, 6)
  }

  func testInterleavingTimer() {
    let scheduler = TestScheduler()

    var count2 = 0
    var count3 = 0

    Effect.merge(
      Effect.timer(id: 1, every: .seconds(2), on: scheduler)
        .on(value: { _ in count2 += 1 }),
      Effect.timer(id: 2, every: .seconds(3), on: scheduler)
        .on(value: { _ in count3 += 1 })
    )
    .start()

    scheduler.advance(by: .seconds(1))
    XCTAssertEqual(count2, 0)
    XCTAssertEqual(count3, 0)
    scheduler.advance(by: .seconds(1))
    XCTAssertEqual(count2, 1)
    XCTAssertEqual(count3, 0)
    scheduler.advance(by: .seconds(1))
    XCTAssertEqual(count2, 1)
    XCTAssertEqual(count3, 1)
    scheduler.advance(by: .seconds(1))
    XCTAssertEqual(count2, 2)
    XCTAssertEqual(count3, 1)
  }

  func testTimerCancellation() {
    let scheduler = TestScheduler()

    var firstCount = 0
    var secondCount = 0

    struct CancelToken: Hashable {}

    Effect.timer(id: CancelToken(), every: .seconds(2), on: scheduler)
      .on(value: { _ in firstCount += 1 })
      .start()

    scheduler.advance(by: .seconds(2))

    XCTAssertEqual(firstCount, 1)

    scheduler.advance(by: .seconds(2))

    XCTAssertEqual(firstCount, 2)

    Effect.timer(id: CancelToken(), every: .seconds(2), on: scheduler)
      .on(value: { _ in secondCount += 1 })
      .startWithValues { _ in }

    scheduler.advance(by: .seconds(2))

    XCTAssertEqual(firstCount, 2)
    XCTAssertEqual(secondCount, 1)

    scheduler.advance(by: .seconds(2))

    XCTAssertEqual(firstCount, 2)
    XCTAssertEqual(secondCount, 2)
  }

  func testTimerCompletion() {
    let scheduler = TestScheduler()

    var count = 0

    Effect.timer(id: 1, every: .seconds(1), on: scheduler)
      .take(first: 3)
      .startWithValues { _ in count += 1 }

    scheduler.advance(by: .seconds(1))
    XCTAssertEqual(count, 1)

    scheduler.advance(by: .seconds(1))
    XCTAssertEqual(count, 2)

    scheduler.advance(by: .seconds(1))
    XCTAssertEqual(count, 3)

    scheduler.run()
    XCTAssertEqual(count, 3)
  }
}
