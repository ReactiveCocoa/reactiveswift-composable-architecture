import XCTest

@testable import ComposableArchitecture
@testable import ReactiveSwift

final class EffectCancellationTests: XCTestCase {
  struct CancelToken: Hashable {}

  override func tearDown() {
    super.tearDown()
  }

  func testCancellation() {
    var values: [Int] = []

    let subject = Signal<Int, Never>.pipe()
    let effect = Effect(subject.output)
      .cancellable(id: CancelToken())

    effect
      .startWithValues { values.append($0) }

    XCTAssertNoDifference(values, [])
    subject.input.send(value: 1)
    XCTAssertNoDifference(values, [1])
    subject.input.send(value: 2)
    XCTAssertNoDifference(values, [1, 2])

    _ = Effect<Never, Never>.cancel(id: CancelToken())
      .start()

    subject.input.send(value: 3)
    XCTAssertNoDifference(values, [1, 2])
  }

  func testCancelInFlight() {
    var values: [Int] = []

    let subject = Signal<Int, Never>.pipe()
    Effect(subject.output)
      .cancellable(id: CancelToken(), cancelInFlight: true)
      .startWithValues { values.append($0) }

    XCTAssertNoDifference(values, [])
    subject.input.send(value: 1)
    XCTAssertNoDifference(values, [1])
    subject.input.send(value: 2)
    XCTAssertNoDifference(values, [1, 2])

    Effect(subject.output)
      .cancellable(id: CancelToken(), cancelInFlight: true)
      .startWithValues { values.append($0) }

    subject.input.send(value: 3)
    XCTAssertNoDifference(values, [1, 2, 3])
    subject.input.send(value: 4)
    XCTAssertNoDifference(values, [1, 2, 3, 4])
  }

  func testCancellationAfterDelay() {
    var value: Int?

    Effect(value: 1)
      .delay(0.15, on: QueueScheduler.main)
      .cancellable(id: CancelToken())
      .startWithValues { value = $0 }

    XCTAssertNoDifference(value, nil)

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
      _ = Effect<Never, Never>.cancel(id: CancelToken())
        .start()
    }

    _ = XCTWaiter.wait(for: [self.expectation(description: "")], timeout: 0.3)

    XCTAssertNoDifference(value, nil)
  }

  func testCancellationAfterDelay_WithTestScheduler() {
    let scheduler = TestScheduler()
    var value: Int?

    Effect(value: 1)
      .delay(2, on: scheduler)
      .cancellable(id: CancelToken())
      .startWithValues { value = $0 }

    XCTAssertNoDifference(value, nil)

    scheduler.advance(by: 1)
    Effect<Never, Never>.cancel(id: CancelToken())
      .start()

    scheduler.run()

    XCTAssertNoDifference(value, nil)
  }

  func testCancellablesCleanUp_OnComplete() {
    Effect(value: 1)
      .cancellable(id: 1)
      .startWithValues { _ in }

    XCTAssertNoDifference([:], cancellationCancellables)
  }

  func testCancellablesCleanUp_OnCancel() {
    let scheduler = TestScheduler()
    Effect(value: 1)
      .delay(1, on: scheduler)
      .cancellable(id: 1)
      .startWithValues { _ in }

    Effect<Int, Never>.cancel(id: 1)
      .startWithValues { _ in }

    XCTAssertNoDifference([:], cancellationCancellables)
  }

  func testDoubleCancellation() {
    var values: [Int] = []

    let subject = Signal<Int, Never>.pipe()
    let effect = Effect(subject.output)
      .cancellable(id: CancelToken())
      .cancellable(id: CancelToken())

    effect
      .startWithValues { values.append($0) }

    XCTAssertNoDifference(values, [])
    subject.input.send(value: 1)
    XCTAssertNoDifference(values, [1])

    _ = Effect<Never, Never>.cancel(id: CancelToken())
      .start()

    subject.input.send(value: 2)
    XCTAssertNoDifference(values, [1])
  }

  func testCompleteBeforeCancellation() {
    var values: [Int] = []

    let subject = Signal<Int, Never>.pipe()
    let effect = Effect(subject.output)
      .cancellable(id: CancelToken())

    effect
      .startWithValues { values.append($0) }

    subject.input.send(value: 1)
    XCTAssertNoDifference(values, [1])

    subject.input.sendCompleted()
    XCTAssertNoDifference(values, [1])

    _ = Effect<Never, Never>.cancel(id: CancelToken())
      .start()

    XCTAssertNoDifference(values, [1])
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
              Double.random(in: 1...100) / 1000,
              on: QueueScheduler(internalQueue: queues.randomElement()!)
            )
            .cancellable(id: id),

          Effect(value: ())
            .delay(
              Double.random(in: 1...100) / 1000,
              on: QueueScheduler(internalQueue: queues.randomElement()!)
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

    XCTAssertNoDifference([:], cancellationCancellables)
  }

  func testNestedCancels() {
    var effect = Effect<Void, Never> { observer, _ in
      DispatchQueue.main.asyncAfter(deadline: .distantFuture) {
        observer.sendCompleted()
      }
    }
    .cancellable(id: 1)

    for _ in 1 ... .random(in: 1...1_000) {
      effect = effect.cancellable(id: 1)
    }

    let disposable = effect.start()
    disposable.dispose()

    XCTAssertNoDifference([:], cancellationCancellables)
  }

  func testSharedId() {
    let scheduler = TestScheduler()

    let effect1 = Effect(value: 1)
      .delay(1, on: scheduler)
      .cancellable(id: "id")

    let effect2 = Effect(value: 2)
      .delay(2, on: scheduler)
      .cancellable(id: "id")

    var expectedOutput: [Int] = []
    effect1
      .startWithValues { expectedOutput.append($0) }
    effect2
      .startWithValues { expectedOutput.append($0) }

    XCTAssertNoDifference(expectedOutput, [])
    scheduler.advance(by: 1)
    XCTAssertNoDifference(expectedOutput, [1])
    scheduler.advance(by: 1)
    XCTAssertNoDifference(expectedOutput, [1, 2])
  }

  func testImmediateCancellation() {
    let scheduler = TestScheduler()

    var expectedOutput: [Int] = []
    let disposable = Effect.deferred { Effect(value: 1) }
      .delay(1, on: scheduler)
      .cancellable(id: "id")
      .startWithValues { expectedOutput.append($0) }

    // Don't hold onto cancellable so that it is deallocated immediately.
    disposable.dispose()

    XCTAssertNoDifference(expectedOutput, [])
    scheduler.advance(by: 1)
    XCTAssertNoDifference(expectedOutput, [])
  }

  func testNestedMergeCancellation() {
    let effect = Effect<Int, Never>.merge(
      [Effect(1...2).cancellable(id: 1)]
    )
    .cancellable(id: 2)

    var output: [Int] = []
    effect
      .startWithValues { output.append($0) }

    XCTAssertEqual(output, [1, 2])
  }

  func testMultipleCancellations() {
    let scheduler = TestScheduler()
    var output: [AnyHashable] = []

    struct A: Hashable {}
    struct B: Hashable {}
    struct C: Hashable {}

    let ids: [AnyHashable] = [A(), B(), C()]
    let effects = ids.map { id in
      Effect(value: id)
        .delay(1, on: scheduler)
        .cancellable(id: id)
    }

    Effect<AnyHashable, Never>.merge(effects)
      .startWithValues { output.append($0) }

    Effect<AnyHashable, Never>
      .cancel(ids: [A(), C()])
      .startWithValues { _ in }

    scheduler.advance(by: 1)
    XCTAssertNoDifference(output, [B()])
  }
}
