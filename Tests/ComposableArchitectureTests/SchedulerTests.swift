import ComposableArchitecture
import ReactiveSwift
import XCTest

final class SchedulerTests: XCTestCase {
  func testAdvance() async {
    let mainQueue = TestScheduler()

    var value: Int?
    SignalProducer(value: 1)
      .delay(1, on: mainQueue)
      .startWithValues { value = $0 }

    XCTAssertNoDifference(value, nil)

    await mainQueue.advance(by: 0.25)

    XCTAssertNoDifference(value, nil)

    await mainQueue.advance(by: 0.25)

    XCTAssertNoDifference(value, nil)

    await mainQueue.advance(by: 0.25)

    XCTAssertNoDifference(value, nil)

    await mainQueue.advance(by: 0.25)

    XCTAssertNoDifference(value, 1)
  }

  func testRunScheduler() async {
    let mainQueue = TestScheduler()

    var value: Int?
    SignalProducer(value: 1)
      .delay(1_000_000_000, on: mainQueue)
      .startWithValues { value = $0 }

    XCTAssertNoDifference(value, nil)

    await mainQueue.advance(by: .seconds(1_000_000))

    XCTAssertNoDifference(value, nil)

    await mainQueue.run()

    XCTAssertNoDifference(value, 1)
  }

  func testDelay0Advance() async {
    let mainQueue = TestScheduler()

    var value: Int?
    SignalProducer(value: 1)
      .delay(0, on: mainQueue)
      .startWithValues { value = $0 }

    XCTAssertNoDifference(value, nil)

    await mainQueue.advance()

    XCTAssertNoDifference(value, 1)
  }

  func testSubscribeOnAdvance() async {
    let mainQueue = TestScheduler()

    var value: Int?
    SignalProducer(value: 1)
      .start(on: mainQueue)
      .startWithValues { value = $0 }

    XCTAssertNoDifference(value, nil)

    await mainQueue.advance()

    XCTAssertNoDifference(value, 1)
  }

  func testReceiveOnAdvance() async {
    let mainQueue = TestScheduler()

    var value: Int?
    SignalProducer(value: 1)
      .observe(on: mainQueue)
      .startWithValues { value = $0 }

    XCTAssertNoDifference(value, nil)

    await mainQueue.advance()

    XCTAssertNoDifference(value, 1)
  }

  func testTwoIntervalOrdering() {
    let testScheduler = TestScheduler()

    var values: [Int] = []

    testScheduler.schedule(after: .seconds(0), interval: .seconds(2)) { values.append(1) }

    testScheduler.schedule(after: .seconds(0), interval: .seconds(1)) { values.append(42) }

    XCTAssertNoDifference(values, [])
    testScheduler.advance()
    XCTAssertNoDifference(values, [1, 42])
    testScheduler.advance(by: 2)
    XCTAssertNoDifference(values, [1, 42, 42, 1, 42])
  }

  func testDebounceReceiveOn() async {
    let mainQueue = TestScheduler()

    let subject = Signal<Void, Never>.pipe()

    var count = 0
    subject.output
      .debounce(1, on: mainQueue)
      .observe(on: mainQueue)
      .observeValues { count += 1 }

    XCTAssertNoDifference(count, 0)

    subject.input.send(value: ())
    XCTAssertNoDifference(count, 0)

    await mainQueue.advance(by: 1)
    XCTAssertNoDifference(count, 1)

    await mainQueue.advance(by: 1)
    XCTAssertNoDifference(count, 1)

    await mainQueue.run()
    XCTAssertNoDifference(count, 1)
  }
}
