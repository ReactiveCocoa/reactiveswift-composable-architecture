import ReactiveSwift
import XCTest

@testable import ComposableArchitecture

final class EffectDeferredTests: XCTestCase {
  func testDeferred() async {
    let mainQueue = TestScheduler()
    var values: [Int] = []

    func runDeferredEffect(value: Int) {
      SignalProducer(value: value)
        .eraseToEffect()
        .deferred(for: 1, scheduler: mainQueue)
        .producer
        .startWithValues { values.append($0) }
    }

    runDeferredEffect(value: 1)

    // Nothing emits right away.
    XCTAssertEqual(values, [])

    // Waiting half the time also emits nothing
    await mainQueue.advance(by: 0.5)
    XCTAssertEqual(values, [])

    // Run another deferred effect.
    runDeferredEffect(value: 2)

    // Waiting half the time emits first deferred effect received.
    await mainQueue.advance(by: 0.5)
    XCTAssertEqual(values, [1])

    // Run another deferred effect.
    runDeferredEffect(value: 3)

    // Waiting half the time emits second deferred effect received.
    await mainQueue.advance(by: 0.5)
    XCTAssertEqual(values, [1, 2])

    // Waiting the rest of the time emits the final effect value.
    await mainQueue.advance(by: 0.5)
    XCTAssertEqual(values, [1, 2, 3])

    // Running out the scheduler
    await mainQueue.run()
    XCTAssertEqual(values, [1, 2, 3])
  }

  func testDeferredIsLazy() async {
    let mainQueue = TestScheduler()
    var values: [Int] = []
    var effectRuns = 0

    func runDeferredEffect(value: Int) {
      SignalProducer.deferred { () -> SignalProducer<Int, Never> in
        effectRuns += 1
        return SignalProducer(value: value)
      }
      .eraseToEffect()
      .deferred(for: 1, scheduler: mainQueue)
      .producer
      .startWithValues { values.append($0) }
    }

    runDeferredEffect(value: 1)

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
