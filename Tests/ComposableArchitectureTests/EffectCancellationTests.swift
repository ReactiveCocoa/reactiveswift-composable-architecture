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
      .producer
      .startWithValues { values.append($0) }

    XCTAssertNoDifference(values, [])
    subject.input.send(value: 1)
    XCTAssertNoDifference(values, [1])
    subject.input.send(value: 2)
    XCTAssertNoDifference(values, [1, 2])

    _ = Effect<Never, Never>.cancel(id: CancelToken())
      .producer
      .start()

    subject.input.send(value: 3)
    XCTAssertNoDifference(values, [1, 2])
  }

  func testCancelInFlight() {
    var values: [Int] = []

    let subject = Signal<Int, Never>.pipe()
    Effect(subject.output)
      .cancellable(id: CancelToken(), cancelInFlight: true)
      .producer
      .startWithValues { values.append($0) }

    XCTAssertNoDifference(values, [])
    subject.input.send(value: 1)
    XCTAssertNoDifference(values, [1])
    subject.input.send(value: 2)
    XCTAssertNoDifference(values, [1, 2])

    Effect(subject.output)
      .cancellable(id: CancelToken(), cancelInFlight: true)
      .producer
      .startWithValues { values.append($0) }

    subject.input.send(value: 3)
    XCTAssertNoDifference(values, [1, 2, 3])
    subject.input.send(value: 4)
    XCTAssertNoDifference(values, [1, 2, 3, 4])
  }

  func testCancellationAfterDelay() {
    var value: Int?

    Effect(value: 1)
      .deferred(for: 0.15, scheduler: QueueScheduler.main)
      .cancellable(id: CancelToken())
      .producer
      .startWithValues { value = $0 }

    XCTAssertNoDifference(value, nil)

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
      _ = Effect<Never, Never>.cancel(id: CancelToken())
        .producer
        .start()
    }

    _ = XCTWaiter.wait(for: [self.expectation(description: "")], timeout: 0.3)

    XCTAssertNoDifference(value, nil)
  }

  func testCancellationAfterDelay_WithTestScheduler() {
    let mainQueue = TestScheduler()
    var value: Int?

    Effect(value: 1)
      .deferred(for: 2, scheduler: mainQueue)
      .cancellable(id: CancelToken())
      .producer
      .startWithValues { value = $0 }

    XCTAssertNoDifference(value, nil)

    mainQueue.advance(by: 1)
    Effect<Never, Never>.cancel(id: CancelToken())
      .producer
      .start()

    mainQueue.run()

    XCTAssertNoDifference(value, nil)
  }

  func testCancellablesCleanUp_OnComplete() {
    Effect(value: 1)
      .cancellable(id: 1)
      .producer
      .startWithValues { _ in }

    XCTAssertNoDifference([:], cancellationCancellables)
  }

  func testCancellablesCleanUp_OnCancel() {
    let mainQueue = TestScheduler()
    Effect(value: 1)
      .deferred(for: 1, scheduler: mainQueue)
      .cancellable(id: 1)
      .producer
      .startWithValues { _ in }

    Effect<Int, Never>.cancel(id: 1)
      .producer
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
      .producer
      .startWithValues { values.append($0) }

    XCTAssertNoDifference(values, [])
    subject.input.send(value: 1)
    XCTAssertNoDifference(values, [1])

    _ = Effect<Never, Never>.cancel(id: CancelToken())
      .producer
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
      .producer
      .startWithValues { values.append($0) }

    subject.input.send(value: 1)
    XCTAssertNoDifference(values, [1])

    subject.input.sendCompleted()
    XCTAssertNoDifference(values, [1])

    _ = Effect<Never, Never>.cancel(id: CancelToken())
      .producer
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
            .deferred(
              for: Double.random(in: 1...100) / 1000,
              scheduler: QueueScheduler(internalQueue: queues.randomElement()!)
            )
            .cancellable(id: id),

          SignalProducer(value: ())
            .delay(
              Double.random(in: 1...100) / 1000,
              on: QueueScheduler(internalQueue: queues.randomElement()!)
            )
            .flatMap(.latest) { Effect.cancel(id: id).producer }
            .eraseToEffect()
        )
      }
    )

    let expectation = self.expectation(description: "wait")
    effect
      .producer
      .on(completed: { expectation.fulfill() }, value: { _ in })
      .start()
    self.wait(for: [expectation], timeout: 999)

    XCTAssertNoDifference([:], cancellationCancellables)
  }

  func testNestedCancels() {
    var effect = SignalProducer<Void, Never> { observer, _ in
      DispatchQueue.main.asyncAfter(deadline: .distantFuture) {
        observer.sendCompleted()
      }
    }
    .eraseToEffect()
    .cancellable(id: 1)

    for _ in 1 ... .random(in: 1...1_000) {
      effect = effect.cancellable(id: 1)
    }

    let disposable = effect.producer.start()
    disposable.dispose()

    XCTAssertNoDifference([:], cancellationCancellables)
  }

  func testSharedId() {
    let mainQueue = TestScheduler()

    let effect1 = Effect<Int, Never>(value: 1)
      .deferred(for: 1, scheduler: mainQueue)
      .cancellable(id: "id")

    let effect2 = Effect<Int, Never>(value: 2)
      .deferred(for: 2, scheduler: mainQueue)
      .cancellable(id: "id")

    var expectedOutput: [Int] = []
    effect1
      .producer
      .startWithValues { expectedOutput.append($0) }
    effect2
      .producer
      .startWithValues { expectedOutput.append($0) }

    XCTAssertNoDifference(expectedOutput, [])
    mainQueue.advance(by: 1)
    XCTAssertNoDifference(expectedOutput, [1])
    mainQueue.advance(by: 1)
    XCTAssertNoDifference(expectedOutput, [1, 2])
  }

  func testImmediateCancellation() {
    let mainQueue = TestScheduler()

    var expectedOutput: [Int] = []
    let disposable = SignalProducer.deferred { SignalProducer(value: 1) }
      .eraseToEffect()
      .deferred(for: 1, scheduler: mainQueue)
      .cancellable(id: "id")
      .producer
      .startWithValues { expectedOutput.append($0) }

    // Don't hold onto cancellable so that it is deallocated immediately.
    disposable.dispose()

    XCTAssertNoDifference(expectedOutput, [])
    mainQueue.advance(by: 1)
    XCTAssertNoDifference(expectedOutput, [])
  }

  func testNestedMergeCancellation() {
    let effect = Effect<Int, Never>.merge(
      [SignalProducer(1...2).eraseToEffect().cancellable(id: 1)]
    )
    .cancellable(id: 2)

    var output: [Int] = []
    effect
      .producer
      .startWithValues { output.append($0) }

    XCTAssertEqual(output, [1, 2])
  }

  func testMultipleCancellations() {
    let mainQueue = TestScheduler()
    var output: [AnyHashable] = []

    struct A: Hashable {}
    struct B: Hashable {}
    struct C: Hashable {}

    let ids: [AnyHashable] = [A(), B(), C()]
    let effects = ids.map { id in
      Effect<AnyHashable, Never>(value: id)
        .deferred(for: 1, scheduler: mainQueue)
        .cancellable(id: id)
    }

    Effect<AnyHashable, Never>.merge(effects)
      .producer
      .startWithValues { output.append($0) }

    Effect<AnyHashable, Never>
      .cancel(ids: [A(), C()])
      .producer
      .startWithValues { _ in }

    mainQueue.advance(by: 1)
    XCTAssertNoDifference(output, [B()])
  }
}
