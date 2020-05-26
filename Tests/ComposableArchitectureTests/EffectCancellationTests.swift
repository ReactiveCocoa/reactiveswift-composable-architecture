@testable import ReactiveSwift
import XCTest

@testable import ComposableArchitecture

final class EffectCancellationTests: XCTestCase {
  override func setUp() {
    super.setUp()
    resetCancellables()
  }

  func testCancellation() {
    struct CancelToken: Hashable {}
    var values: [Int] = []

    let subject = Signal<Int, Never>.pipe()
    let effect = Effect(subject.output)
      .cancellable(id: CancelToken())

    effect
      .startWithValues { values.append($0) }

    XCTAssertEqual(values, [])
    subject.input.send(value: 1)
    XCTAssertEqual(values, [1])
    subject.input.send(value: 2)
    XCTAssertEqual(values, [1, 2])

    _ = Effect<Never, Never>.cancel(id: CancelToken())
      .start()

    subject.input.send(value: 3)
    XCTAssertEqual(values, [1, 2])
  }

  func testCancelInFlight() {
    struct CancelToken: Hashable {}
    var values: [Int] = []

    let subject = Signal<Int, Never>.pipe()
    Effect(subject.output)
      .cancellable(id: CancelToken(), cancelInFlight: true)
      .startWithValues { values.append($0) }

    XCTAssertEqual(values, [])
    subject.input.send(value: 1)
    XCTAssertEqual(values, [1])
    subject.input.send(value: 2)
    XCTAssertEqual(values, [1, 2])

    Effect(subject.output)
      .cancellable(id: CancelToken(), cancelInFlight: true)
      .startWithValues { values.append($0) }

    subject.input.send(value: 3)
    XCTAssertEqual(values, [1, 2, 3])
    subject.input.send(value: 4)
    XCTAssertEqual(values, [1, 2, 3, 4])
  }

  func testCancellationAfterDelay() {
    struct CancelToken: Hashable {}
    var value: Int?

    Effect(value: 1)
      .delay(0.5, on: QueueScheduler.main)
      .cancellable(id: CancelToken())
      .startWithValues { value = $0 }

    XCTAssertEqual(value, nil)

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
      _ = Effect<Never, Never>.cancel(id: CancelToken())
        .start()
    }

    _ = XCTWaiter.wait(for: [self.expectation(description: "")], timeout: 0.1)

    XCTAssertEqual(value, nil)
  }

  func testCancellationAfterDelay_WithTestScheduler() {
    let scheduler = TestScheduler()
    struct CancelToken: Hashable {}
    var value: Int?

    Effect(value: 1)
      .delay(2, on: scheduler)
      .cancellable(id: CancelToken())
      .startWithValues { value = $0 }

    XCTAssertEqual(value, nil)

    scheduler.advance(by: .seconds(1))
    Effect<Never, Never>.cancel(id: CancelToken())
      .start()

    scheduler.run()

    XCTAssertEqual(value, nil)
  }

  func testCancellablesCleanUp_OnComplete() {
    Effect(value: 1)
      .cancellable(id: 1)
      .startWithValues { _ in }

    XCTAssertTrue(cancellationCancellables.isEmpty)
  }

  func testCancellablesCleanUp_OnCancel() {
    let scheduler = TestScheduler()
    Effect(value: 1)
      .delay(1, on: scheduler)
      .cancellable(id: 1)
      .startWithValues { _ in }

    Effect<Int, Never>.cancel(id: 1)
      .startWithValues { _ in }

    XCTAssertTrue(cancellationCancellables.isEmpty)
  }

  func testDoubleCancellation() {
    struct CancelToken: Hashable {}
    var values: [Int] = []

    let subject = Signal<Int, Never>.pipe()
    let effect = Effect(subject.output)
      .cancellable(id: CancelToken())
      .cancellable(id: CancelToken())

    effect
      .startWithValues { values.append($0) }

    XCTAssertEqual(values, [])
    subject.input.send(value: 1)
    XCTAssertEqual(values, [1])

    _ = Effect<Never, Never>.cancel(id: CancelToken())
      .start()

    subject.input.send(value: 2)
    XCTAssertEqual(values, [1])
  }

  func testCompleteBeforeCancellation() {
    struct CancelToken: Hashable {}
    var values: [Int] = []

    let subject = Signal<Int, Never>.pipe()
    let effect = Effect(subject.output)
      .cancellable(id: CancelToken())

    effect
      .startWithValues { values.append($0) }

    subject.input.send(value: 1)
    XCTAssertEqual(values, [1])

    subject.input.sendCompleted()
    XCTAssertEqual(values, [1])

    _ = Effect<Never, Never>.cancel(id: CancelToken())
      .start()

    XCTAssertEqual(values, [1])
  }

  func testConcurrentCancels() {
    let queues = [
      DispatchQueue.main,
      DispatchQueue.global(qos: .background),
      DispatchQueue.global(qos: .default),
      DispatchQueue.global(qos: .unspecified),
      DispatchQueue.global(qos: .userInitiated),
      DispatchQueue.global(qos: .userInteractive),
      DispatchQueue.global(qos: .utility),
    ]

    
    let effect = Effect.merge(
      (1...1_000).map { idx -> Effect<Int, Never> in
        let id = idx % 10

        return Effect.merge(
          Effect(value: idx)
            .delay(
              Double.random(in: 1...100) / 1000, on: QueueScheduler(internalQueue: queues.randomElement()!)
            )
            .cancellable(id: id),

          Effect(value: ())
            .delay(
              Double.random(in: 1...100) / 1000, on: QueueScheduler(internalQueue: queues.randomElement()!)
            )
            .flatMap(.latest) { Effect.cancel(id: id) }
        )
      }
    )

    let expectation = self.expectation(description: "wait")
    effect
      .on(completed: { expectation.fulfill() }, value: { _ in })
      .start()
    self.wait(for: [expectation], timeout: 999)

    XCTAssertTrue(cancellationCancellables.isEmpty)
  }
}

func resetCancellables() {
  for (id, _) in cancellationCancellables {
    cancellationCancellables[id] = [:]
  }
  cancellationCancellables = [:]
}
