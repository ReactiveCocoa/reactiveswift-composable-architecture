import ComposableArchitecture
import ReactiveSwift
import XCTest

// `@MainActor` introduces issues gathering tests on Linux
#if !os(Linux)
  @MainActor
  final class TimerTests: XCTestCase {
    func testTimer() async {
      let mainQueue = TestScheduler()

      var count = 0

      EffectProducer.timer(id: 1, every: .seconds(1), on: mainQueue)
        .producer
        .startWithValues { _ in count += 1 }

      await mainQueue.advance(by: 1)
      XCTAssertEqual(count, 1)

      await mainQueue.advance(by: 1)
      XCTAssertEqual(count, 2)

      await mainQueue.advance(by: 1)
      XCTAssertEqual(count, 3)

      await mainQueue.advance(by: 3)
      XCTAssertEqual(count, 6)
    }

    func testInterleavingTimer() async {
      let mainQueue = TestScheduler()

      var count2 = 0
      var count3 = 0

      EffectProducer.merge(
        EffectProducer.timer(id: 1, every: .seconds(2), on: mainQueue)
          .producer
          .on(value: { _ in count2 += 1 })
          .eraseToEffect(),
        EffectProducer.timer(id: 2, every: .seconds(3), on: mainQueue)
          .producer
          .on(value: { _ in count3 += 1 })
          .eraseToEffect()
      )
      .producer
      .start()

      await mainQueue.advance(by: 1)
      XCTAssertEqual(count2, 0)
      XCTAssertEqual(count3, 0)
      await mainQueue.advance(by: 1)
      XCTAssertEqual(count2, 1)
      XCTAssertEqual(count3, 0)
      await mainQueue.advance(by: 1)
      XCTAssertEqual(count2, 1)
      XCTAssertEqual(count3, 1)
      await mainQueue.advance(by: 1)
      XCTAssertEqual(count2, 2)
      XCTAssertEqual(count3, 1)
    }

    func testTimerCancellation() async {
      let mainQueue = TestScheduler()

      var firstCount = 0
      var secondCount = 0

      struct CancelToken: Hashable {}

      EffectProducer.timer(id: CancelToken(), every: .seconds(2), on: mainQueue)
        .producer
        .on(value: { _ in firstCount += 1 })
        .start()

      await mainQueue.advance(by: 2)

      XCTAssertEqual(firstCount, 1)

      await mainQueue.advance(by: 2)

      XCTAssertEqual(firstCount, 2)

      EffectProducer.timer(id: CancelToken(), every: .seconds(2), on: mainQueue)
        .producer
        .on(value: { _ in secondCount += 1 })
        .startWithValues { _ in }

      await mainQueue.advance(by: 2)

      XCTAssertEqual(firstCount, 2)
      XCTAssertEqual(secondCount, 1)

      await mainQueue.advance(by: 2)

      XCTAssertEqual(firstCount, 2)
      XCTAssertEqual(secondCount, 2)
    }

    func testTimerCompletion() async {
      let mainQueue = TestScheduler()

      var count = 0

      EffectProducer.timer(id: 1, every: .seconds(1), on: mainQueue)
        .producer
        .take(first: 3)
        .startWithValues { _ in count += 1 }

      await mainQueue.advance(by: 1)
      XCTAssertEqual(count, 1)

      await mainQueue.advance(by: 1)
      XCTAssertEqual(count, 2)

      await mainQueue.advance(by: 1)
      XCTAssertEqual(count, 3)

      await mainQueue.run()
      XCTAssertEqual(count, 3)
    }
  }
#endif
