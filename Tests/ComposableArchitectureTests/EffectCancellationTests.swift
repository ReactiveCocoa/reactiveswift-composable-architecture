@_spi(Internals) import ComposableArchitecture
import XCTest

#if DEBUG
  @testable import ReactiveSwift
#else
  import ReactiveSwift
#endif

final class EffectCancellationTests: XCTestCase {
  struct CancelID: Hashable {}

  override func tearDown() {
    super.tearDown()
  }

  func testCancellation() {
    var values: [Int] = []

    let subject = Signal<Int, Never>.pipe()
    let effect = EffectProducer(subject.output)
      .cancellable(id: CancelID())

    effect
      .producer
      .startWithValues { values.append($0) }

    XCTAssertEqual(values, [])
    subject.input.send(value: 1)
    XCTAssertEqual(values, [1])
    subject.input.send(value: 2)
    XCTAssertEqual(values, [1, 2])

    _ = EffectTask<Never>.cancel(id: CancelID())
      .producer
      .start()

    subject.input.send(value: 3)
    XCTAssertEqual(values, [1, 2])
  }

  func testCancelInFlight() {
    var values: [Int] = []

    let subject = Signal<Int, Never>.pipe()
    EffectProducer(subject.output)
      .cancellable(id: CancelID(), cancelInFlight: true)
      .producer
      .startWithValues { values.append($0) }

    XCTAssertEqual(values, [])
    subject.input.send(value: 1)
    XCTAssertEqual(values, [1])
    subject.input.send(value: 2)
    XCTAssertEqual(values, [1, 2])

    EffectProducer(subject.output)
      .cancellable(id: CancelID(), cancelInFlight: true)
      .producer
      .startWithValues { values.append($0) }

    subject.input.send(value: 3)
    XCTAssertEqual(values, [1, 2, 3])
    subject.input.send(value: 4)
    XCTAssertEqual(values, [1, 2, 3, 4])
  }

  func testCancellationAfterDelay() {
    var value: Int?

    let scheduler = QueueScheduler()

    Effect(value: 1)
      .deferred(for: 0.5, scheduler: scheduler)
      .cancellable(id: CancelID())
      .producer
      .startWithValues { value = $0 }

    XCTAssertEqual(value, nil)

    scheduler.queue.asyncAfter(deadline: .now() + 0.05) {
      _ = EffectTask<Never>.cancel(id: CancelID())
        .producer
        .start()
    }

    _ = XCTWaiter.wait(for: [self.expectation(description: "")], timeout: 1)
    XCTAssertEqual(value, nil)
  }

  func testCancellationAfterDelay_WithTestScheduler() {
    let mainQueue = TestScheduler()
    var value: Int?

    Effect(value: 1)
      .deferred(for: 2, scheduler: mainQueue)
      .cancellable(id: CancelID())
      .producer
      .startWithValues { value = $0 }

    XCTAssertEqual(value, nil)

    mainQueue.advance(by: 1)
    EffectTask<Never>.cancel(id: CancelID())
      .producer
      .start()

    mainQueue.run()

    XCTAssertEqual(value, nil)
  }

  func testCancellablesCleanUp_OnComplete() {
    let id = UUID()

    Effect(value: 1)
      .cancellable(id: id)
      .producer
      .startWithValues { _ in }

    XCTAssertNil(_cancellationCancellables[_CancelToken(id: id)])
  }

  func testCancellablesCleanUp_OnCancel() {
    let id = UUID()

    let mainQueue = TestScheduler()
    Effect(value: 1)
      .deferred(for: 1, scheduler: mainQueue)
      .cancellable(id: id)
      .producer
      .startWithValues { _ in }

    EffectProducer<Int, Never>.cancel(id: id)
      .producer
      .startWithValues { _ in }

    XCTAssertNil(_cancellationCancellables[_CancelToken(id: id)])
  }

  func testDoubleCancellation() {
    var values: [Int] = []

    let subject = Signal<Int, Never>.pipe()
    let effect = EffectProducer(subject.output)
      .cancellable(id: CancelID())
      .cancellable(id: CancelID())

    effect
      .producer
      .startWithValues { values.append($0) }

    XCTAssertEqual(values, [])
    subject.input.send(value: 1)
    XCTAssertEqual(values, [1])

    _ = EffectTask<Never>.cancel(id: CancelID())
      .producer
      .start()

    subject.input.send(value: 2)
    XCTAssertEqual(values, [1])
  }

  func testCompleteBeforeCancellation() {
    var values: [Int] = []

    let subject = Signal<Int, Never>.pipe()
    let effect = EffectProducer(subject.output)
      .cancellable(id: CancelID())

    effect
      .producer
      .startWithValues { values.append($0) }

    subject.input.send(value: 1)
    XCTAssertEqual(values, [1])

    subject.input.sendCompleted()
    XCTAssertEqual(values, [1])

    _ = EffectTask<Never>.cancel(id: CancelID())
      .producer
      .start()

    XCTAssertEqual(values, [1])
  }

  #if DEBUG
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
      let ids = (1...10).map { _ in UUID() }

      let effect = EffectProducer.merge(
        // Original upper bound was 1000, but it was triggering EXC_BAD_ACCESS crashes...
        // Enabling ThreadSanitizer reveals data races in RAS internals, more specifically
        // `TransformerCore.start` (accessing `hasDeliveredTerminalEvent` var), which can
        // be the cause?
        (1...200).map { idx -> EffectProducer<Int, Never> in
          let id = ids[idx % 10]

          return EffectProducer.merge(
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
              .flatMap(.latest) { EffectProducer.cancel(id: id).producer }
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

      for id in ids {
        XCTAssertNil(
          _cancellationCancellables[_CancelToken(id: id)],
          "cancellationCancellables should not contain id \(id)"
        )
      }
    }
  #endif

  func testNestedCancels() {
    let id = UUID()

    var effect = SignalProducer<Void, Never> { observer, _ in
      DispatchQueue.main.asyncAfter(deadline: .distantFuture) {
        observer.sendCompleted()
      }
    }
    .eraseToEffect()
    .cancellable(id: id)

    for _ in 1...1_000 {
      effect = effect.cancellable(id: id)
    }

    let disposable = effect.producer.start()
    disposable.dispose()

    XCTAssertNil(_cancellationCancellables[_CancelToken(id: id)])
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

    XCTAssertEqual(expectedOutput, [])
    mainQueue.advance(by: 1)
    XCTAssertEqual(expectedOutput, [1])
    mainQueue.advance(by: 1)
    XCTAssertEqual(expectedOutput, [1, 2])
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

    XCTAssertEqual(expectedOutput, [])
    mainQueue.advance(by: 1)
    XCTAssertEqual(expectedOutput, [])
  }

  func testNestedMergeCancellation() {
    let effect = EffectProducer<Int, Never>.merge(
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

    EffectTask<AnyHashable>.merge(effects)
      .producer
      .startWithValues { output.append($0) }

    EffectTask<AnyHashable>
      .cancel(ids: [A(), C()])
      .producer
      .startWithValues { _ in }

    mainQueue.advance(by: 1)
    XCTAssertEqual(output, [B()])
  }
}
