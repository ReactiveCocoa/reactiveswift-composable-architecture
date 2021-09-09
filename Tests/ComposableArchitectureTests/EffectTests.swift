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

    SignalProducer<Int, Never>(result: .success(42))
      .catchToEffect {
        switch $0 {
        case let .success(val):
          return val
        case .failure:
          return -1
        }
      }
        .startWithValues { XCTAssertEqual($0, 42) }

    SignalProducer<Int, Error>(result: .failure(Error()))
      .catchToEffect {
        switch $0 {
        case let .success(val):
          return val
        case .failure:
          return -1
        }
      }
        .startWithValues { XCTAssertEqual($0, -1) }
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

    self.scheduler.advance(by: 1)
    XCTAssertEqual(values, [1])

    self.scheduler.advance(by: 2)
    XCTAssertEqual(values, [1, 2])

    self.scheduler.advance(by: 3)
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

    self.scheduler.advance(by: 1)
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

    self.scheduler.advance(by: 1)
    XCTAssertEqual(values, [1])

    self.scheduler.advance(by: 1)
    XCTAssertEqual(values, [1, 2])

    self.scheduler.advance(by: 1)
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

    self.scheduler.advance(by: 1)

    XCTAssertEqual(values, [1, 2, 3])
    XCTAssertEqual(isComplete, false)

    self.scheduler.advance(by: 1)

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

    self.scheduler.advance(by: 1)

    XCTAssertEqual(values, [1])
    XCTAssertEqual(isComplete, true)
  }

  #if compiler(>=5.5)
    func testTask() {
      guard #available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) else { return }

      let expectation = self.expectation(description: "Complete")
      var result: Int?
      Effect<Int, Never>.task {
        expectation.fulfill()
        return 42
      }
      .sink(receiveValue: { result = $0 })
      .store(in: &self.cancellables)
      self.wait(for: [expectation], timeout: 0)
      XCTAssertEqual(result, 42)
    }

  func testThrowingTask() {
    guard #available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) else { return }

    let expectation = self.expectation(description: "Complete")
    struct MyError: Error {}
    var result: Error?
    Effect<Int, Error>.task {
      expectation.fulfill()
      throw MyError()
    }
    .sink(
      receiveCompletion: {
        switch $0 {
        case .finished:
          XCTFail()
        case let .failure(error):
          result = error
        }
      },
      receiveValue: { _ in XCTFail() }
    )
    .store(in: &self.cancellables)
    self.wait(for: [expectation], timeout: 0)
    XCTAssertNotNil(result)
  }

  func testCancellingTask() {
    guard #available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) else { return }

    @Sendable func work() async throws -> Int {
      var task: Task<Int, Error>!
      task = Task {
        await Task.sleep(NSEC_PER_MSEC)
        try Task.checkCancellation()
        return 42
      }
      task.cancel()
      return try await task.value
    }

    let expectation = self.expectation(description: "Complete")
    Effect<Int, Error>.task {
      try await work()
    }
    .sink(
      receiveCompletion: { _ in expectation.fulfill() },
      receiveValue: { _ in XCTFail() }
    )
    .store(in: &self.cancellables)
    self.wait(for: [expectation], timeout: 0.2)
  }
  #endif
}
