import ReactiveSwift
import XCTest

@testable import ComposableArchitecture

#if os(Linux)
  import let CDispatch.NSEC_PER_MSEC
#endif

final class EffectTests: XCTestCase {
  let scheduler = TestScheduler()

  func testEraseToEffectWithError() {
    struct Error: Swift.Error, Equatable {}

    SignalProducer<Int, Error>(result: .success(42))
      .startWithResult { XCTAssertNoDifference($0, .success(42)) }

    SignalProducer<Int, Error>(result: .failure(Error()))
      .startWithResult { XCTAssertNoDifference($0, .failure(Error())) }

    SignalProducer<Int, Never>(result: .success(42))
      .startWithResult { XCTAssertNoDifference($0, .success(42)) }

    SignalProducer<Int, Never>(result: .success(42))
      .catchToEffect {
        switch $0 {
        case let .success(val):
          return val
        case .failure:
          return -1
        }
      }
      .startWithValues { XCTAssertNoDifference($0, 42) }

    SignalProducer<Int, Error>(result: .failure(Error()))
      .catchToEffect {
        switch $0 {
        case let .success(val):
          return val
        case .failure:
          return -1
        }
      }
      .startWithValues { XCTAssertNoDifference($0, -1) }
  }

  func testConcatenate() {
    var values: [Int] = []

    let effect = Effect<Int, Never>.concatenate(
      Effect(value: 1).delay(1, on: scheduler),
      Effect(value: 2).delay(2, on: scheduler),
      Effect(value: 3).delay(3, on: scheduler)
    )

    effect.startWithValues { values.append($0) }

    XCTAssertNoDifference(values, [])

    self.scheduler.advance(by: 1)
    XCTAssertNoDifference(values, [1])

    self.scheduler.advance(by: 2)
    XCTAssertNoDifference(values, [1, 2])

    self.scheduler.advance(by: 3)
    XCTAssertNoDifference(values, [1, 2, 3])

    self.scheduler.run()
    XCTAssertNoDifference(values, [1, 2, 3])
  }

  func testConcatenateOneEffect() {
    var values: [Int] = []

    let effect = Effect<Int, Never>.concatenate(
      Effect(value: 1).delay(1, on: scheduler)
    )

    effect.startWithValues { values.append($0) }

    XCTAssertNoDifference(values, [])

    self.scheduler.advance(by: 1)
    XCTAssertNoDifference(values, [1])

    self.scheduler.run()
    XCTAssertNoDifference(values, [1])
  }

  func testMerge() {
    let effect = Effect<Int, Never>.merge(
      Effect(value: 1).delay(1, on: scheduler),
      Effect(value: 2).delay(2, on: scheduler),
      Effect(value: 3).delay(3, on: scheduler)
    )

    var values: [Int] = []
    effect.startWithValues { values.append($0) }

    XCTAssertNoDifference(values, [])

    self.scheduler.advance(by: 1)
    XCTAssertNoDifference(values, [1])

    self.scheduler.advance(by: 1)
    XCTAssertNoDifference(values, [1, 2])

    self.scheduler.advance(by: 1)
    XCTAssertNoDifference(values, [1, 2, 3])
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

    XCTAssertNoDifference(values, [1, 2])
    XCTAssertNoDifference(isComplete, false)

    self.scheduler.advance(by: 1)

    XCTAssertNoDifference(values, [1, 2, 3])
    XCTAssertNoDifference(isComplete, false)

    self.scheduler.advance(by: 1)

    XCTAssertNoDifference(values, [1, 2, 3, 4])
    XCTAssertNoDifference(isComplete, true)
  }

  func testEffectSubscriberInitializer_WithCancellation() {
    enum CancelId {}

    let effect = Effect<Int, Never> { subscriber, _ in
      subscriber.send(value: 1)
      self.scheduler.schedule(after: self.scheduler.currentDate.addingTimeInterval(1)) {
        subscriber.send(value: 2)
      }
    }
    .cancellable(id: CancelId.self)

    var values: [Int] = []
    var isComplete = false
    effect
      .on(completed: { isComplete = true })
      .startWithValues { values.append($0) }

    XCTAssertNoDifference(values, [1])
    XCTAssertNoDifference(isComplete, false)

    Effect<Void, Never>.cancel(id: CancelId.self)
      .startWithValues { _ in }

    self.scheduler.advance(by: 1)

    XCTAssertNoDifference(values, [1])
    XCTAssertNoDifference(isComplete, true)
  }

  func testDoubleCancelInFlight() {
    var result: Int?

    _ = Effect(value: 42)
      .cancellable(id: "id", cancelInFlight: true)
      .cancellable(id: "id", cancelInFlight: true)
      .startWithValues { result = $0 }

    XCTAssertEqual(result, 42)
  }

  #if compiler(>=5.4) && !os(Linux)
    func testFailing() {
      let effect = Effect<Never, Never>.failing("failing")
      _ = XCTExpectFailure {
        effect
          .start()
      } issueMatcher: { issue in
        issue.compactDescription == "failing - A failing effect ran."
      }
    }
  #endif

  #if canImport(_Concurrency) && compiler(>=5.5.2)
    func testTask() {
      let expectation = self.expectation(description: "Complete")
      var result: Int?
      Effect<Int, Never>.task { @MainActor in
        expectation.fulfill()
        return 42
      }
      .startWithValues { result = $0 }
      self.wait(for: [expectation], timeout: 1)
      XCTAssertNoDifference(result, 42)
    }

    func testThrowingTask() {
      let expectation = self.expectation(description: "Complete")
      struct MyError: Error {}
      var result: Error?
      let disposable = Effect<Int, Error>.task { @MainActor in
        expectation.fulfill()
        throw MyError()
      }
      .on(
        failed: { error in
          result = error
        },
        completed: {
          XCTFail()
        },
        value: { _ in
            XCTFail()
          }
      )
      .start()

      self.wait(for: [expectation], timeout: 1)
      XCTAssertNotNil(result)
      disposable.dispose()
    }

    func testCancellingTask_Failable() {
      @Sendable func work() async throws -> Int {
        try await Task.sleep(nanoseconds: NSEC_PER_MSEC)
        XCTFail()
        return 42
      }

       let disposable = Effect<Int, Error>.task { try await work() }
       .on(
          completed: { XCTFail() },
          value: { _ in XCTFail() }
       )
       .start(on: QueueScheduler.main)
       .start()

      disposable.dispose()

      _ = XCTWaiter.wait(for: [.init()], timeout: 1.1)
    }

    func testCancellingTask_Infalable() {
      @Sendable func work() async -> Int {
        do {
          try await Task.sleep(nanoseconds: NSEC_PER_MSEC)
          XCTFail()
        } catch {
        }
        return 42
      }

      let disposable = Effect<Int, Never >.task { await work() }
        .on(
           completed: { XCTFail() },
           value: { _ in XCTFail() }
        )
        .start(on: QueueScheduler.main)
        .start()

      disposable.dispose()

      _ = XCTWaiter.wait(for: [.init()], timeout: 1.1)
    }
  #endif
}
