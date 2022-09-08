import ReactiveSwift
import XCTest

@testable import ComposableArchitecture

// `@MainActor` introduces issues gathering tests on Linux
#if !os(Linux)
@MainActor
final class EffectTests: XCTestCase {
  let mainQueue = TestScheduler()

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
      .producer
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
      .producer
      .startWithValues { XCTAssertNoDifference($0, -1) }
  }

  func testConcatenate() {
    var values: [Int] = []

    let effect = Effect<Int, Never>.concatenate(
      Effect(value: 1).deferred(for: 1, scheduler: mainQueue),
      Effect(value: 2).deferred(for: 2, scheduler: mainQueue),
      Effect(value: 3).deferred(for: 3, scheduler: mainQueue)
    )

    effect.producer.startWithValues { values.append($0) }

    XCTAssertNoDifference(values, [])

    self.mainQueue.advance(by: 1)
    XCTAssertNoDifference(values, [1])

    self.mainQueue.advance(by: 2)
    XCTAssertNoDifference(values, [1, 2])

    self.mainQueue.advance(by: 3)
    XCTAssertNoDifference(values, [1, 2, 3])

    self.mainQueue.run()
    XCTAssertNoDifference(values, [1, 2, 3])
  }

  func testConcatenateOneEffect() {
    var values: [Int] = []

    let effect = Effect<Int, Never>.concatenate(
      Effect(value: 1).deferred(for: 1, scheduler: mainQueue)
    )

    effect.producer.startWithValues { values.append($0) }

    XCTAssertNoDifference(values, [])

    self.mainQueue.advance(by: 1)
    XCTAssertNoDifference(values, [1])

    self.mainQueue.run()
    XCTAssertNoDifference(values, [1])
  }

  func testMerge() {
    let effect = Effect<Int, Never>.merge(
      Effect(value: 1).deferred(for: 1, scheduler: mainQueue),
      Effect(value: 2).deferred(for: 2, scheduler: mainQueue),
      Effect(value: 3).deferred(for: 3, scheduler: mainQueue)
    )

    var values: [Int] = []
    effect.producer.startWithValues { values.append($0) }

    XCTAssertNoDifference(values, [])

    self.mainQueue.advance(by: 1)
    XCTAssertNoDifference(values, [1])

    self.mainQueue.advance(by: 1)
    XCTAssertNoDifference(values, [1, 2])

    self.mainQueue.advance(by: 1)
    XCTAssertNoDifference(values, [1, 2, 3])
  }

  func testEffectRunInitializer() {
    let effect = Effect<Int, Never>.run { observer in
      observer.send(value: 1)
      observer.send(value: 2)
      self.mainQueue.schedule(after: self.mainQueue.currentDate.addingTimeInterval(1)) {
        observer.send(value: 3)
      }
      self.mainQueue.schedule(after: self.mainQueue.currentDate.addingTimeInterval(2)) {
        observer.send(value: 4)
        observer.sendCompleted()
      }

      return AnyDisposable()
    }

    var values: [Int] = []
    var isComplete = false
    effect
      .producer
      .on(completed: { isComplete = true }, value: { values.append($0) })
      .start()

    XCTAssertNoDifference(values, [1, 2])
    XCTAssertNoDifference(isComplete, false)

    self.mainQueue.advance(by: 1)

    XCTAssertNoDifference(values, [1, 2, 3])
    XCTAssertNoDifference(isComplete, false)

    self.mainQueue.advance(by: 1)

    XCTAssertNoDifference(values, [1, 2, 3, 4])
    XCTAssertNoDifference(isComplete, true)
  }

  func testEffectRunInitializer_WithCancellation() {
    enum CancelID {}

    let effect = Effect<Int, Never>.run { subscriber in
      subscriber.send(value: 1)
      self.mainQueue.schedule(after: self.mainQueue.currentDate.addingTimeInterval(1)) {
        subscriber.send(value: 2)
      }
      return AnyDisposable()
    }
    .cancellable(id: CancelID.self)

    var values: [Int] = []
    var isComplete = false
    effect
      .producer
      .on(completed: { isComplete = true })
      .startWithValues { values.append($0) }

    XCTAssertNoDifference(values, [1])
    XCTAssertNoDifference(isComplete, false)

    Effect<Void, Never>.cancel(id: CancelID.self)
      .producer
      .startWithValues { _ in }

    self.mainQueue.advance(by: 1)

    XCTAssertNoDifference(values, [1])
    XCTAssertNoDifference(isComplete, true)
  }

  func testDoubleCancelInFlight() {
    var result: Int?

    _ = Effect(value: 42)
      .cancellable(id: "id", cancelInFlight: true)
      .cancellable(id: "id", cancelInFlight: true)
      .producer
      .startWithValues { result = $0 }

    XCTAssertEqual(result, 42)
  }

  #if !os(Linux)
  func testUnimplemented() {
      let effect = Effect<Never, Never>.failing("unimplemented")
      _ = XCTExpectFailure {
      effect
          .producer
          .start()
    } issueMatcher: { issue in
      issue.compactDescription == "unimplemented - An unimplemented effect ran."
    }
  }
  #endif

#if canImport(_Concurrency) && compiler(>=5.5.2)
  func testTask() async {
    guard #available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) else { return }
    let effect = Effect<Int, Never>.task { 42 }
    for await result in effect.producer.values {
      XCTAssertNoDifference(result, 42)
    }
  }

  func testCancellingTask_Infallible() {
    @Sendable func work() async -> Int {
      do {
        try await Task.sleep(nanoseconds: NSEC_PER_MSEC)
        XCTFail()
      } catch {
      }
      return 42
    }

      let disposable = Effect<Int, Never>.task { await work() }
        .producer
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
#endif
