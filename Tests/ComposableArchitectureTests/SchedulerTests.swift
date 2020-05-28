import ReactiveSwift
import ComposableArchitecture
import XCTest

final class SchedulerTests: XCTestCase {
  func testAdvance() {
    let scheduler = TestScheduler() 

    var value: Int?
    Effect(value: 1)
      .delay(1, on: scheduler)
      .startWithValues { value = $0 }
  
    XCTAssertEqual(value, nil)

    scheduler.advance(by: .milliseconds(250))

    XCTAssertEqual(value, nil)

    scheduler.advance(by: .milliseconds(250))

    XCTAssertEqual(value, nil)

    scheduler.advance(by: .milliseconds(250))

    XCTAssertEqual(value, nil)

    scheduler.advance(by: .milliseconds(250))

    XCTAssertEqual(value, 1)
  }

  func testRunScheduler() {
    let scheduler = TestScheduler() 

    var value: Int?
    Effect(value: 1)
      .delay(1_000_000_000, on: scheduler)
      .startWithValues { value = $0 }

    XCTAssertEqual(value, nil)

    scheduler.advance(by: .seconds(1_000_000))

    XCTAssertEqual(value, nil)

    scheduler.run()

    XCTAssertEqual(value, 1)
  }

  func testDelay0Advance() {
    let scheduler = TestScheduler() 

    var value: Int?
    Effect(value: 1)
      .delay(0, on: scheduler)
      .startWithValues { value = $0 }

    XCTAssertEqual(value, nil)

    scheduler.advance()

    XCTAssertEqual(value, 1)
  }

  func testSubscribeOnAdvance() {
    let scheduler = TestScheduler() 

    var value: Int?
    Effect(value: 1)
      .start(on: scheduler)
      .startWithValues { value = $0 }

    XCTAssertEqual(value, nil)

    scheduler.advance()

    XCTAssertEqual(value, 1)
  }

  func testReceiveOnAdvance() {
    let scheduler = TestScheduler() 

    var value: Int?
    Effect(value: 1)
      .observe(on: scheduler)
      .startWithValues { value = $0 }

    XCTAssertEqual(value, nil)

    scheduler.advance()

    XCTAssertEqual(value, 1)
  }

  func testTwoIntervalOrdering() {
    let testScheduler = TestScheduler() 

    var values: [Int] = []

    testScheduler.schedule(after: .seconds(0), interval: .seconds(2)) { values.append(1) }

    testScheduler.schedule(after: .seconds(0), interval: .seconds(1)) { values.append(42) }

    XCTAssertEqual(values, [])
    testScheduler.advance()
    XCTAssertEqual(values, [1, 42])
    testScheduler.advance(by: .seconds(2))
    XCTAssertEqual(values, [1, 42, 42, 1, 42])
  }
}
