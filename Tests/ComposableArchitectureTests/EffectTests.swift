import ReactiveSwift
import XCTest

@testable import ComposableArchitecture

final class EffectTests: XCTestCase {
  let scheduler = TestScheduler()

  func testEraseToEffectWithError() {
    struct Error: Swift.Error, Equatable {}

    SignalProducer<Int, Error>(result: .success(42))
      .startWithResult { XCTAssertEqual($0, .success(42)) }
    
    SignalProducer<Int, Error>(result: .failure(Error()))
      .startWithResult { XCTAssertEqual($0, .failure(Error())) }

    SignalProducer<Int, Never>(result: .success(42))
      .startWithResult { XCTAssertEqual($0, .success(42)) }
  }

  func testConcatenate() {
    var values: [Int] = []

    let effect = Effect<Int, Never>.concatenate(
      Effect(value: 1).delay(1, on: scheduler),
      Effect(value: 2).delay(2, on: scheduler),
      Effect(value: 3).delay(3, on: scheduler)
    )

    effect.startWithValues { values.append($0) }

    XCTAssertEqual(values, [])

    self.scheduler.advance(by: .seconds(1))
    XCTAssertEqual(values, [1])

    self.scheduler.advance(by: .seconds(2))
    XCTAssertEqual(values, [1, 2])

    self.scheduler.advance(by: .seconds(3))
    XCTAssertEqual(values, [1, 2, 3])

    self.scheduler.run()
    XCTAssertEqual(values, [1, 2, 3])
  }

  func testConcatenateOneEffect() {
    var values: [Int] = []

    let effect = Effect<Int, Never>.concatenate(
      Effect(value: 1).delay(1, on: scheduler)
    )

    effect.startWithValues { values.append($0) }

    XCTAssertEqual(values, [])

    self.scheduler.advance(by: .seconds(1))
    XCTAssertEqual(values, [1])

    self.scheduler.run()
    XCTAssertEqual(values, [1])
  }

  func testMerge() {
    let effect = Effect<Int, Never>.merge(
      Effect(value: 1).delay(1, on: scheduler),
      Effect(value: 2).delay(2, on: scheduler),
      Effect(value: 3).delay(3, on: scheduler)
    )

    var values: [Int] = []
    effect.startWithValues { values.append($0) }

    XCTAssertEqual(values, [])

    self.scheduler.advance(by: .seconds(1))
    XCTAssertEqual(values, [1])

    self.scheduler.advance(by: .seconds(1))
    XCTAssertEqual(values, [1, 2])

    self.scheduler.advance(by: .seconds(1))
    XCTAssertEqual(values, [1, 2, 3])
  }

  func testEffectSubscriberInitializer() {
    let effect = Effect<Int, Never> { subscriber, _ in
      subscriber.send(value: 1)
      subscriber.send(value: 2)
      self.scheduler.schedule(after: self.scheduler.currentDate.addingTimeInterval(1)) {
        subscriber.send(value: 3)
      }
      self.scheduler.schedule(after: self.scheduler.currentDate.addingTimeInterval(2)) {
        subscriber.send(value: 4)
        subscriber.sendCompleted()
      }
    }

    var values: [Int] = []
    var isComplete = false
    effect
      .on(completed: { isComplete = true }, value: { values.append($0) })
      .start()
      

    XCTAssertEqual(values, [1, 2])
    XCTAssertEqual(isComplete, false)

    self.scheduler.advance(by: .seconds(1))

    XCTAssertEqual(values, [1, 2, 3])
    XCTAssertEqual(isComplete, false)

    self.scheduler.advance(by: .seconds(1))

    XCTAssertEqual(values, [1, 2, 3, 4])
    XCTAssertEqual(isComplete, true)
  }

  func testEffectSubscriberInitializer_WithCancellation() {
    struct CancelId: Hashable {}

    let effect = Effect<Int, Never> { subscriber, _ in
      subscriber.send(value: 1)
      self.scheduler.schedule(after: self.scheduler.currentDate.addingTimeInterval(1)) {
        subscriber.send(value: 2)
      }
    }
    .cancellable(id: CancelId())

    var values: [Int] = []
    var isComplete = false
    effect
      .on(completed: { isComplete = true })
      .startWithValues { values.append($0) }

    XCTAssertEqual(values, [1])
    XCTAssertEqual(isComplete, false)

    Effect<Void, Never>.cancel(id: CancelId())
      .startWithValues { _ in }

    self.scheduler.advance(by: .seconds(1))

    XCTAssertEqual(values, [1])
    XCTAssertEqual(isComplete, true)
  }
}
