import ComposableArchitecture
import ReactiveSwift
import XCTest

final class TimerTests: XCTestCase {
  func testTimer() {
    let mainQueue = TestScheduler()

    var count = 0

    Effect.timer(id: 1, every: .seconds(1), on: mainQueue)
      .startWithValues { _ in count += 1 }

    mainQueue.advance(by: 1)
    XCTAssertNoDifference(count, 1)

    mainQueue.advance(by: 1)
    XCTAssertNoDifference(count, 2)

    mainQueue.advance(by: 1)
    XCTAssertNoDifference(count, 3)

    mainQueue.advance(by: 3)
    XCTAssertNoDifference(count, 6)
  }

  func testInterleavingTimer() {
    let mainQueue = TestScheduler()

    var count2 = 0
    var count3 = 0

    Effect.merge(
      Effect.timer(id: 1, every: .seconds(2), on: mainQueue)
        .on(value: { _ in count2 += 1 }),
      Effect.timer(id: 2, every: .seconds(3), on: mainQueue)
        .on(value: { _ in count3 += 1 })
    )
    .start()

    mainQueue.advance(by: 1)
    XCTAssertNoDifference(count2, 0)
    XCTAssertNoDifference(count3, 0)
    mainQueue.advance(by: 1)
    XCTAssertNoDifference(count2, 1)
    XCTAssertNoDifference(count3, 0)
    mainQueue.advance(by: 1)
    XCTAssertNoDifference(count2, 1)
    XCTAssertNoDifference(count3, 1)
    mainQueue.advance(by: 1)
    XCTAssertNoDifference(count2, 2)
    XCTAssertNoDifference(count3, 1)
  }

  func testTimerCancellation() {
    let mainQueue = TestScheduler()

    var firstCount = 0
    var secondCount = 0

    struct CancelToken: Hashable {}

    Effect.timer(id: CancelToken(), every: .seconds(2), on: mainQueue)
      .on(value: { _ in firstCount += 1 })
      .start()

    mainQueue.advance(by: 2)

    XCTAssertNoDifference(firstCount, 1)

    mainQueue.advance(by: 2)

    XCTAssertNoDifference(firstCount, 2)

    Effect.timer(id: CancelToken(), every: .seconds(2), on: mainQueue)
      .on(value: { _ in secondCount += 1 })
      .startWithValues { _ in }

    mainQueue.advance(by: 2)

    XCTAssertNoDifference(firstCount, 2)
    XCTAssertNoDifference(secondCount, 1)

    mainQueue.advance(by: 2)

    XCTAssertNoDifference(firstCount, 2)
    XCTAssertNoDifference(secondCount, 2)
  }

  func testTimerCompletion() {
    let mainQueue = TestScheduler()

    var count = 0

    Effect.timer(id: 1, every: .seconds(1), on: mainQueue)
      .take(first: 3)
      .startWithValues { _ in count += 1 }

    mainQueue.advance(by: 1)
    XCTAssertNoDifference(count, 1)

    mainQueue.advance(by: 1)
    XCTAssertNoDifference(count, 2)

    mainQueue.advance(by: 1)
    XCTAssertNoDifference(count, 3)

    mainQueue.run()
    XCTAssertNoDifference(count, 3)
  }
}
